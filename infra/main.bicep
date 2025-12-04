// Main Bicep Template for Wan 2.2 Video API Infrastructure
// This orchestrates the creation of ACR and Container Apps

targetScope = 'resourceGroup'

@description('Base name for all resources')
param baseName string = 'wan-video-api'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container image name with tag (e.g., wan-api:latest)')
param containerImageTag string = 'latest'

@description('Model type to use')
param modelType string = 'ti2v-5B'

@description('Minimum replicas for the container app')
param minReplicas int = 1

@description('Maximum replicas for the container app')
param maxReplicas int = 3

@description('Tags to apply to all resources')
param tags object = {
  application: 'wan-video-api'
  environment: 'production'
  managedBy: 'bicep'
}

// Generate unique names
var uniqueSuffix = uniqueString(resourceGroup().id)
var registryName = 'acr${replace(baseName, '-', '')}${uniqueSuffix}'
var containerAppName = '${baseName}-app'
var environmentName = '${baseName}-env'

// Deploy Azure Container Registry
module acr 'acr.bicep' = {
  name: 'acr-deployment'
  params: {
    registryName: registryName
    location: location
    registrySku: 'Premium'
    adminUserEnabled: true
    tags: tags
  }
}

// Get ACR credentials
resource existingRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: registryName
}

// Deploy Container App
module containerApp 'container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    containerAppName: containerAppName
    environmentName: environmentName
    location: location
    containerRegistryServer: acr.outputs.loginServer
    containerRegistryUsername: registryName
    containerRegistryPassword: listCredentials(acr.outputs.registryId, '2023-07-01').passwords[0].value
    containerImage: '${acr.outputs.loginServer}/wan-api:${containerImageTag}'
    modelType: modelType
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cpu: '4.0'
    memory: '16Gi'
    gpu: {
      type: 'nvidia-a100'
      count: 1
    }
    targetPort: 8000
    tags: tags
  }
  dependsOn: [
    acr
  ]
}

// Outputs
output registryName string = acr.outputs.registryName
output registryLoginServer string = acr.outputs.loginServer
output containerAppUrl string = 'https://${containerApp.outputs.containerAppUrl}'
output containerAppName string = containerApp.outputs.containerAppName
output resourceGroupName string = resourceGroup().name
