// Log Analytics Workspace module
@description('The name of the Log Analytics Workspace')
param name string

@description('The location for the Log Analytics Workspace')
param location string = resourceGroup().location

@description('The SKU of the Log Analytics Workspace')
param sku string = 'PerGB2018'

@description('Tags for the resource')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
