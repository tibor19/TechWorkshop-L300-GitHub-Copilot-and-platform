// Role Assignment module for AcrPull
@description('The principal ID to assign the role to')
param principalId string

@description('The Container Registry ID')
param containerRegistryId string

@description('The role definition ID for AcrPull')
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistryId, principalId, acrPullRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = roleAssignment.id
output name string = roleAssignment.name
