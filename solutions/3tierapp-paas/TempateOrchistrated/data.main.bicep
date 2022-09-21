targetScope = 'subscription'

@description('Required. Name of the Resource Group.')
param resourceGroupName string

@description('Optional. Name of cosmosdb account')
param cosmosdbName string

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object = {}

@description('Optional. Location of Resources/Resource group deployed in this file')
param location string = 'uksouth'

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock for all resources/resource group defined in this template.')
param lock string = ''

@allowed([
  'CosmosDB'
  'Postgress Sql'
  'SQL database'
])
@description('Optional. To choose one of the database service')
param choiceOfDatabase string = 'CosmosDB'

@description('Optional. Locations enabled for the Cosmos DB account.')
param locations array

@description('Optional. SQL Databases configurations.')
param sqlDatabases array

@description('Optional. Resource ID of the storage account to be used for diagnostic logs.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the Log Analytics workspace to be used for diagnostic logs.')
param workspaceId string = ''

@description('Optional. Authorization ID of the Event Hub Namespace to be used for diagnostic logs.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the Event Hub to be used for diagnostic logs.')
param eventHubName string = ''

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

// Resource Group

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// CosmosDB

param cosmosdbParams object = {}

module Cosmosdb '../../../modules/Microsoft.DocumentDB/databaseAccounts/deploy.bicep' = if (choiceOfDatabase == 'CosmosDB') {
  name: 'Deployment_CosmosDB'
  scope: ResourceGroup
  params: {
    name: !empty(cosmosdbName) ? cosmosdbName : cosmosdbParams.name
    location: !empty(location) ? location : cosmosdbParams.location
    locations: !empty(locations) ? locations : cosmosdbParams.locations
    sqlDatabases: !empty(sqlDatabases) ? sqlDatabases : cosmosdbParams.sqlDatabases
    tags: !empty(tags) ? tags : cosmosdbParams.tags
    lock: !empty(lock) ? lock : cosmosdbParams.lock
    diagnosticWorkspaceId: !empty(workspaceId) ? workspaceId : cosmosdbParams.workspaceId
    diagnosticStorageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : cosmosdbParams.diagnosticStorageAccountId
    diagnosticEventHubName: !empty(eventHubName) ? eventHubName : cosmosdbParams.eventHubName
    diagnosticEventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : cosmosdbParams.eventHubAuthorizationRuleId
    diagnosticLogsRetentionInDays: diagnosticLogsRetentionInDays
  }
}
