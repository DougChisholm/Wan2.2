// Azure Container Registry Bicep Template
// This template creates an Azure Container Registry for storing Docker images

@description('Name of the Azure Container Registry')
param registryName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('SKU for the container registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param registrySku string = 'Premium'

@description('Enable admin user for the registry')
param adminUserEnabled bool = true

@description('Tags to apply to resources')
param tags object = {
  application: 'wan-video-api'
  environment: 'production'
}

// Create Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
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

// Outputs
output registryName string = containerRegistry.name
output registryId string = containerRegistry.id
output loginServer string = containerRegistry.properties.loginServer
output registryResourceGroup string = resourceGroup().name
