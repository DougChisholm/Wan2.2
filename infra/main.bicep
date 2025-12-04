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

// Create Azure Container Registry directly (not as module) to access credentials
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
  }
}

// Deploy Container App
module containerApp 'container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    containerAppName: containerAppName
    environmentName: environmentName
    location: location
    containerRegistryServer: containerRegistry.properties.loginServer
    containerRegistryUsername: registryName
    containerRegistryPassword: listCredentials(containerRegistry.id, '2023-07-01').passwords[0].value
    containerImage: '${containerRegistry.properties.loginServer}/wan-api:${containerImageTag}'
    modelType: modelType
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cpu: 4
    memory: '16Gi'
    targetPort: 8000
    tags: tags
  }
}

// Outputs
output registryName string = containerRegistry.name
output registryLoginServer string = containerRegistry.properties.loginServer
output containerAppUrl string = 'https://${containerApp.outputs.containerAppUrl}'
output containerAppName string = containerApp.outputs.containerAppName
output resourceGroupName string = resourceGroup().name
