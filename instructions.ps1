

# Networking and SQL configs
$NETWORK_NAME = ""
$SQL_SERVER_PASSWORD = ""
$SQL_SERVER = ""

# ACR Creds
$ACR_USN = ""
$ACR_PWD = ""
$ACR_URL = ""


# Pull the image hosting the sql server
docker pull mcr.microsoft.com/mssql/server:2017-latest

# Clone the repo containing all of the source 
git clone https://github.com/Microsoft-OpenHack/containers_artifacts.git

cp ./containers_artifacts/dockerfiles/Dockerfile_0 ./containers_artifacts/src/user-java/Dockerfile
cp ./containers_artifacts/dockerfiles/Dockerfile_1 ./containers_artifacts/src/tripviewer/Dockerfile
cp ./containers_artifacts/dockerfiles/Dockerfile_2 ./containers_artifacts/src/userprofile/Dockerfile
cp ./containers_artifacts/dockerfiles/Dockerfile_3 ./containers_artifacts/src/poi/Dockerfile
cp ./containers_artifacts/dockerfiles/Dockerfile_4 ./containers_artifacts/src/trips/Dockerfile

docker build ./containers_artifacts/src/user-java/ -t user-java:latest
docker build ./containers_artifacts/src/tripviewer/ -t tripviewer:latest
docker build ./containers_artifacts/src/userprofile/ -t userprofile:latest
docker build ./containers_artifacts/src/poi/ -t poi:latest
docker build ./containers_artifacts/src/trips/ -t trips:latest

# Create a shared network
docker network create $NETWORK_NAME
# Make a MSSQL Server on port 1433
docker run --network $NETWORK_NAME --name $SQL_SERVER -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=$SQL_SERVER_PASSWORD" -p 1433:1433 -d mcr.microsoft.com/mssql/server:latest

# Create config to make required database
docker exec $SQL_SERVER /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SQL_SERVER_PASSWORD -q "CREATE DATABASE mydrivingDB" -j


# Authenticate against azure ACR
docker login $ACR_URL -u $ACR_USN -p $ACR_PWD
# Pull data loader from azure ACR
docker pull $ACR_URL/dataload:1.0

# RUn the data loader container to populate the database
docker run --network $NETWORK_NAME -e SQLFQDN=mssql_server -e SQLUSER=sa -e SQLPASS=Password123! -e SQLDB=mydrivingDB registrybro8635.azurecr.io/dataload:1.0

# Spin up the POI API 
docker run --network $NETWORK_NAME -d -p 8080:80 --name poi -e "SQL_PASSWORD=$SQL_SERVER_PASSWORD" -e "SQL_SERVER=$SQL_SERVER" -e "SQL_USER=sa" -e "ASPNETCORE_ENVIRONMENT=Local" poi:latest

# Check it's available
(invoke-webrequest 'http://localhost:8080/api/poi/healthcheck').content


$images_to_upload = @(
    "user-java",
    "tripviewer",
    "userprofile",
    "poi",
    "trips"
)

foreach ($image_name in $images_to_upload) {
    # Tag all of the build containers with an alias to the ACR instance
    $i = $image_name + ":latest"
    docker tag $i registrybro8635.azurecr.io/bro_team/$image_name
    # Push all of the tagged containers to the actual ACR instance 
    docker push registrybro8635.azurecr.io/bro_team/$image_name
}


