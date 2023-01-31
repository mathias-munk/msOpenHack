$resource_group = ""
$acr_registry_name = ""
$aks_cluster_name = ""

$acr_registry_name = $acr_registry_name.ToLower() 


# Dn not need group or ACR
# Create Resource Group
#az group create --location $location --name $resource_group
# Create ACR in the above resource group
#az acr create -n $acr_registry_name -g $resource_group --sku Standard
# Get credentials to ACR
az acr login --name $acr_registry_name.ToLower()
# Create AKS instance in resource group, and mount the above ACR to it

#Doesnt fully work - need to set SLA to standard somehow???
az aks create -n $aks_cluster_name -g $resource_group --generate-ssh-keys --attach-acr $acr_registry_name --uptime-sla --node-count 3 --enable-cluster-auto-upgrade



