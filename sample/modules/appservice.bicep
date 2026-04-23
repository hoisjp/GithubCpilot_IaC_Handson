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

@description('Key Vault name (existing, from keyvault module).')
param keyVaultName string

@description('Key Vault URI.')
param keyVaultUri string

@description('Storage Account name (existing, from storage module).')
param storageAccountName string

@description('Blob endpoint URL.')
param storageBlobEndpoint string

@description('SQL Server FQDN.')
param sqlServerFqdn string

@description('SQL Database name.')
param sqlDatabaseName string

@description('Application Insights connection string.')
param appInsightsConnectionString string

var appServicePlanName = '${namePrefix}-asp'
var appServiceName = take('${namePrefix}-app-${uniqueSuffix}', 40)

// Role definition IDs (built-in)
var roleKeyVaultSecretsUser       = '4633458b-17de-408a-b874-0445c86b69e6'
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
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
        {
          name: 'STORAGE_BLOB_ENDPOINT'
          value: storageBlobEndpoint
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'SQL_SERVER_FQDN'
          value: sqlServerFqdn
        }
        {
          name: 'SQL_DATABASE'
          value: sqlDatabaseName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

// Reference existing resources to scope role assignments
resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Grant App's Managed Identity: Key Vault Secrets User
resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, app.id, roleKeyVaultSecretsUser)
  properties: {
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultSecretsUser)
  }
}

// Grant App's Managed Identity: Storage Blob Data Contributor
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
