$aks_cluster_name = "kubernetesbro8635"
$resource_group = "teamResources"
$acr_registry_name = "registrybro8635"
$location = "northeurope"
$keyvault_name = "keyvaultbro8635"
$tenant_id = (az account tenant list --query "[].tenantId" -o tsv)

# create the cluster
#az aks create -n $aks_cluster_name -g $resource_group --generate-ssh-keys --attach-acr $acr_registry_name --uptime-sla --node-count 3 --enable-cluster-auto-upgrade
# Enable the keyvault addon for AKS
az aks enable-addons --addons azure-keyvault-secrets-provider --name $aks_cluster_name --resource-group $resource_group
$identity_client_id = az aks show -g $resource_group -n $aks_cluster_name --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv

# Create the keyvault
az keyvault create -n $keyvault_name -g $resource_group -l $location
# Assign the secrets
az keyvault secret set --vault-name $keyvault_name -n "SQLUSER" --value "sqladminbRo8635"
az keyvault secret set --vault-name $keyvault_name -n "" --value ""
az keyvault secret set --vault-name $keyvault_name -n "SQLSERVER" --value ""
az keyvault secret set --vault-name $keyvault_name -n "SQLDBNAME" --value  ""

# set policy to access keys in your key vault
az keyvault set-policy -n $keyvault_name --key-permissions get --spn $identity_client_id
# set policy to access secrets in your key vault
az keyvault set-policy -n $keyvault_name --secret-permissions get --spn $identity_client_id
# set policy to access certs in your key vault
az keyvault set-policy -n $keyvault_name --certificate-permissions get --spn $identity_client_id


$secret_provider_class = @"
# This is a SecretProviderClass example using user-assigned identity to access your key vault
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kvname-user-msi
  namespace: api
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"                  # Set to true for using managed identity
    userAssignedIdentityID: $identity_client_id   # Set the clientID of the user-assigned managed identity to use
    keyvaultName: $keyvault_name          # Set to the name of your key vault
    cloudName: ""                         # [OPTIONAL for Azure] if not provided, the Azure environment defaults to AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: SQLDBNAME
          objectType: secret              # object types: secret, key, or cert
          objectVersion: ""               # [OPTIONAL] object versions, default to latest if empty
          objectAlias: SQL_DBNAME               
        - |
          objectName: SQLPASSWORD
          objectType: secret              # object types: secret, key, or cert
          objectVersion: ""               # [OPTIONAL] object versions, default to latest if empty
          objectAlias: SQL_PASSWORD               
        - |
          objectName: SQLSERVER
          objectType: secret              # object types: secret, key, or cert
          objectVersion: ""               # [OPTIONAL] object versions, default to latest if empty
          objectAlias: SQL_SERVER               
        - |
          objectName: SQLUSER
          objectType: secret              # object types: secret, key, or cert
          objectVersion: ""               # [OPTIONAL] object versions, default to latest if empty
          objectAlias: SQL_USER               
    tenantId: $tenant_id                 # The tenant ID of the key vault
"@

$secret_provider_class_file = ".\secretproviderclass.yaml"
$secret_provider_class | Out-File $secret_provider_class_file
kubectl apply -f $secret_provider_class_file


$pod_name = "busybox-secrets-store-inline-user-msi"
$example_yaml = @"
# This is a sample pod definition for using SecretProviderClass and the user-assigned identity to access your key vault
kind: Pod
apiVersion: v1
metadata:
  name: $pod_name
spec:
  containers:
    - name: busybox
      image: k8s.gcr.io/e2e-test-images/busybox:1.29-1
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kvname-user-msi"
"@
$example_yaml_path = ".\example_deployment_for_secret.yaml"
$example_yaml | Out-File $example_yaml_path
kubectl apply -f $example_yaml_path

function test_secret_access {
    param(
        $pod_name,
        $namespace
    )
    ## show secrets held in secrets-store
    kubectl  exec -n $namespace $pod_name -- ls /mnt/secretks-store/ 
    ## print a test secret 'ExampleSecret' held in secrets-store
    kubectl  exec -n $namespace $pod_name -- cat /mnt/secrets-store/SQLUSER
    Write-Host
}

test_secret_access -pod_name $pod_name -namespace "default"

