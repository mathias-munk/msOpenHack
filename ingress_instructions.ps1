$aks_cluster_name = "kubernetesbro8635"
$resource_group = "teamResources"
$acr_registry_name = "registrybro8635"
$location = "northeurope"
$keyvault_name = "keyvaultbro8635"
$tenant_id = (az account tenant list --query "[].tenantId" -o tsv)

az aks enable-addons --resource-group $resource_group --name $aks_cluster_name --addons http_application_routing

$dns_zone_name = az aks show --resource-group $resource_group --name $aks_cluster_name --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o tsv

$application_routing_yaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld
  template:
    metadata:
      labels:
        app: aks-helloworld
    spec:
      containers:
      - name: aks-helloworld
        image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "Welcome to Azure Kubernetes Service (AKS)"
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld  
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: aks-helloworld
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aks-helloworld
  annotations:
    kubernetes.io/ingress.class: addon-http-application-routing
spec:
  rules:
  - host: aks-helloworld.$dns_zone_name
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: 
            name: aks-helloworld
            port: 
              number: 80
"@


$application_routing_yaml | out-file ".\samples-http-application-routing.yaml"

$actual_ingress_yaml = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-bro
  namespace: api
  annotations:
    kubernetes.io/ingress.class: addon-http-application-routing
spec:
  rules:
  - host: host-bro.$dns_zone_name
    http:
      paths:
      - pathType: Prefix
        path: "/api/poi"
        backend:
          service:
            name: poi-service
            # namespace: api
            port:
              number: 80      
      - pathType: Prefix
        path: "/api/trips"
        backend:
          service:
            name: trips-service
            # namespace: api
            port:
              number: 80
      - pathType: Prefix
        path: "/api/user-java"
        backend:
          service:
            name: user-java-service
            # namespace: api
            port:
              number: 80
      - pathType: Prefix
        path: "/api/userprofile"
        backend:
          service:
            name: userprofile-service
            port:
              number: 80
      - pathType: Prefix
        path: /
        backend:
          service: 
            name: trip-viewer-web
            port: 
              number: 80
"@

$actual_ingress_yaml | out-file ingress2.yml
kubectl apply -f .\ingress2.yml
