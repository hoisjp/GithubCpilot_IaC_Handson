@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Naming prefix.')
param namePrefix string

@description('Unique suffix.')
param uniqueSuffix string

@description('App Service Plan SKU name, e.g. B1, P1v3.')
param skuName string

@description('Storage Account name (existing, from storage module).')
param storageAccountName string

@description('Blob endpoint URL.')
param storageBlobEndpoint string

var appServicePlanName = '${namePrefix}-asp'
var appServiceName = take('${namePrefix}-app-${uniqueSuffix}', 40)

// Built-in role definition: Storage Blob Data Contributor
var roleStorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: skuName
  }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: skuName != 'B1'
      appSettings: [
        {
          name: 'STORAGE_BLOB_ENDPOINT'
          value: storageBlobEndpoint
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

// Reference Storage Account to scope role assignment
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Grant App's Managed Identity: Storage Blob Data Contributor on the Storage Account
resource storageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, app.id, roleStorageBlobDataContributor)
  properties: {
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataContributor)
  }
}

output appServiceName string = app.name
output appServiceDefaultHostName string = app.properties.defaultHostName
output appServicePrincipalId string = app.identity.principalId
