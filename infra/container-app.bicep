// Azure Container Apps with GPU Support Bicep Template
// This template creates a Container App with A100 GPU support for Wan 2.2 model inference

@description('Name of the Container App')
param containerAppName string

@description('Name of the Container App Environment')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Registry login server')
param containerRegistryServer string

@description('Container Registry username')
@secure()
param containerRegistryUsername string

@description('Container Registry password')
@secure()
param containerRegistryPassword string

@description('Container image name with tag')
param containerImage string

@description('Minimum number of replicas')
param minReplicas int = 1

@description('Maximum number of replicas')
param maxReplicas int = 3

@description('CPU cores (in cores)')
param cpu string = '4.0'

@description('Memory (in Gi)')
param memory string = '16Gi'

@description('GPU type and count')
param gpu object = {
  type: 'nvidia-a100'
  count: 1
}

@description('Target port for the container')
param targetPort int = 8000

@description('Tags to apply to resources')
param tags object = {
  application: 'wan-video-api'
  environment: 'production'
}

@description('Model type to use (ti2v-5B, t2v-A14B, i2v-A14B)')
param modelType string = 'ti2v-5B'

// Create Log Analytics Workspace for monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${environmentName}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Container App Environment with GPU support
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'gpu-a100'
        workloadProfileType: 'NC24ads-A100-v4'
        minimumCount: 1
        maximumCount: 3
      }
    ]
  }
}

// Create Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    workloadProfileName: 'gpu-a100'
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistryPassword
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'wan-api'
          image: containerImage
          resources: {
            cpu: json(cpu)
            memory: memory
            gpu: {
              type: gpu.type
              count: gpu.count
            }
          }
          env: [
            {
              name: 'MODEL_TYPE'
              value: modelType
            }
            {
              name: 'MODEL_PATH'
              value: '/app/models'
            }
            {
              name: 'DEVICE_ID'
              value: '0'
            }
            {
              name: 'OUTPUT_DIR'
              value: '/tmp/outputs'
            }
            {
              name: 'HOST'
              value: '0.0.0.0'
            }
            {
              name: 'PORT'
              value: string(targetPort)
            }
            {
              name: 'CUDA_VISIBLE_DEVICES'
              value: '0'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
output containerAppUrl string = containerApp.properties.configuration.ingress.fqdn
output containerAppName string = containerApp.name
output environmentName string = containerAppEnvironment.name
output logAnalyticsWorkspaceId string = logAnalytics.id
