targetScope = 'resourceGroup'

// =========================
// Parameters
// =========================
@description('Deployment environment name. Used in naming and to toggle SKUs.')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short workload name. Used as naming prefix.')
@minLength(2)
@maxLength(10)
param workloadName string = 'web'

@description('Entra ID (Azure AD) login name used as SQL Server administrator (UPN or group name).')
param sqlAdminLoginName string

@description('Object ID of the Entra ID principal (user/group) that becomes SQL Server administrator.')
param sqlAdminObjectId string

// =========================
// Variables
// =========================
var namePrefix = '${workloadName}-${environmentName}'
var uniqueSuffix = uniqueString(resourceGroup().id)

var isProd = environmentName == 'prod'

var tags = {
  workload: workloadName
  environment: environmentName
  managedBy: 'bicep'
}

var appServicePlanSku = isProd ? 'P1v3' : 'B1'
var enableKeyVaultPurgeProtection = isProd

// =========================
// Modules
// =========================
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    enablePurgeProtection: enableKeyVaultPurgeProtection
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    sqlAdminLoginName: sqlAdminLoginName
    sqlAdminObjectId: sqlAdminObjectId
  }
}

module appservice 'modules/appservice.bicep' = {
  name: 'appservice'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    skuName: appServicePlanSku
    keyVaultName: keyvault.outputs.keyVaultName
    keyVaultUri: keyvault.outputs.keyVaultUri
    storageAccountName: storage.outputs.storageAccountName
    storageBlobEndpoint: storage.outputs.blobEndpoint
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.databaseName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// =========================
// Outputs
// =========================
output appServiceHostName string = appservice.outputs.appServiceDefaultHostName
output keyVaultName string = keyvault.outputs.keyVaultName
output keyVaultUri string = keyvault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output appInsightsName string = monitoring.outputs.appInsightsName
