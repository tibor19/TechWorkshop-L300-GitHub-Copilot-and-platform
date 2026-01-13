// Microsoft Foundry Hub module
@description('The name of the AI Foundry Hub')
param name string

@description('The location for the AI Foundry Hub')
param location string = resourceGroup().location

@description('The friendly name of the AI Foundry Hub')
param friendlyName string = name

@description('The description of the AI Foundry Hub')
param hubDescription string = 'AI Foundry Hub for ZavaStorefront'

@description('Storage Account ID')
param storageAccountId string

@description('Key Vault ID')
param keyVaultId string

@description('Application Insights ID')
param appInsightsId string

@description('Container Registry ID')
param containerRegistryId string

@description('Tags for the resource')
param tags object = {}

resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: friendlyName
    description: hubDescription
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    containerRegistry: containerRegistryId
    publicNetworkAccess: 'Enabled'
    v1LegacyMode: false
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output id string = aiFoundryHub.id
output name string = aiFoundryHub.name
output principalId string = aiFoundryHub.identity.principalId
