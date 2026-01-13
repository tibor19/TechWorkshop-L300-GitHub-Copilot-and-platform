// Microsoft Foundry Project module
@description('The name of the AI Foundry Project')
param name string

@description('The location for the AI Foundry Project')
param location string = resourceGroup().location

@description('The friendly name of the AI Foundry Project')
param friendlyName string = name

@description('The description of the AI Foundry Project')
param projectDescription string = 'AI Foundry Project for ZavaStorefront'

@description('AI Foundry Hub ID')
param hubId string

@description('Tags for the resource')
param tags object = {}

resource aiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: friendlyName
    description: projectDescription
    hubResourceId: hubId
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output id string = aiFoundryProject.id
output name string = aiFoundryProject.name
output principalId string = aiFoundryProject.identity.principalId
