// Main Bicep template for ZavaStorefront infrastructure
targetScope = 'resourceGroup'

@description('Environment name (e.g., dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Location for all resources')
param location string = 'westus3'

@description('Base name for resources')
param baseName string = 'zavastore'

@description('Docker image and tag to deploy')
param dockerImageAndTag string = 'zavastorefront:latest'

@description('Tags for all resources')
param tags object = {
  environment: environmentName
  application: 'ZavaStorefront'
  managedBy: 'Bicep'
}

// Generate unique resource names
var acrName = 'acr${baseName}${environmentName}${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp-${baseName}-${environmentName}-${location}'
var webAppName = 'app-${baseName}-${environmentName}-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'log-${baseName}-${environmentName}-${location}'
var appInsightsName = 'appi-${baseName}-${environmentName}-${location}'
var storageAccountName = 'st${baseName}${environmentName}${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv-${baseName}-${environmentName}-${uniqueString(resourceGroup().id)}'
var aiFoundryHubName = 'aih-${baseName}-${environmentName}-${location}'
var aiFoundryProjectName = 'aip-${baseName}-${environmentName}-${location}'

// Deploy Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'containerRegistryDeployment'
  params: {
    name: acrName
    location: location
    sku: 'Basic'
    tags: tags
  }
}

// Deploy App Service Plan
module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'appServicePlanDeployment'
  params: {
    name: appServicePlanName
    location: location
    sku: {
      name: 'B1'
      tier: 'Basic'
      size: 'B1'
      family: 'B'
      capacity: 1
    }
    tags: tags
  }
}

// Deploy Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalyticsDeployment'
  params: {
    name: logAnalyticsName
    location: location
    sku: 'PerGB2018'
    tags: tags
  }
}

// Deploy Application Insights
module appInsights 'modules/app-insights.bicep' = {
  name: 'appInsightsDeployment'
  params: {
    name: appInsightsName
    location: location
    workspaceId: logAnalytics.outputs.id
    tags: tags
  }
}

// Deploy Web App
module webApp 'modules/web-app.bicep' = {
  name: 'webAppDeployment'
  params: {
    name: webAppName
    location: location
    appServicePlanId: appServicePlan.outputs.id
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    dockerImageAndTag: dockerImageAndTag
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    tags: tags
  }
}

// Assign AcrPull role to Web App managed identity
module roleAssignment 'modules/role-assignment.bicep' = {
  name: 'roleAssignmentDeployment'
  params: {
    principalId: webApp.outputs.principalId
    containerRegistryId: containerRegistry.outputs.id
  }
}

// Deploy Storage Account for AI Foundry
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storageAccountDeployment'
  params: {
    name: storageAccountName
    location: location
    sku: 'Standard_LRS'
    tags: tags
  }
}

// Deploy Key Vault for AI Foundry
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    name: keyVaultName
    location: location
    tags: tags
  }
}

// Deploy AI Foundry Hub
module aiFoundryHub 'modules/ai-foundry-hub.bicep' = {
  name: 'aiFoundryHubDeployment'
  params: {
    name: aiFoundryHubName
    location: location
    friendlyName: 'ZavaStorefront AI Hub'
    hubDescription: 'AI Foundry Hub for ZavaStorefront with GPT-4o-mini and Phi-4 access'
    storageAccountId: storageAccount.outputs.id
    keyVaultId: keyVault.outputs.id
    appInsightsId: appInsights.outputs.id
    containerRegistryId: containerRegistry.outputs.id
    tags: tags
  }
}

// Deploy AI Foundry Project
module aiFoundryProject 'modules/ai-foundry-project.bicep' = {
  name: 'aiFoundryProjectDeployment'
  params: {
    name: aiFoundryProjectName
    location: location
    friendlyName: 'ZavaStorefront AI Project'
    projectDescription: 'AI Foundry Project for ZavaStorefront development'
    hubId: aiFoundryHub.outputs.id
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output webAppName string = webApp.outputs.name
output webAppUrl string = 'https://${webApp.outputs.defaultHostName}'
output appInsightsName string = appInsights.outputs.name
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
output appInsightsConnectionString string = appInsights.outputs.connectionString
output aiFoundryHubName string = aiFoundryHub.outputs.name
output aiFoundryProjectName string = aiFoundryProject.outputs.name
output storageAccountName string = storageAccount.outputs.name
output keyVaultName string = keyVault.outputs.name
