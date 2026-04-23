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

// =========================
// Modules
// =========================
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    tags: tags
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
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
    storageAccountName: storage.outputs.storageAccountName
    storageBlobEndpoint: storage.outputs.blobEndpoint
  }
}

// =========================
// Outputs
// =========================
output appServiceHostName string = appservice.outputs.appServiceDefaultHostName
output storageAccountName string = storage.outputs.storageAccountName
output blobEndpoint string = storage.outputs.blobEndpoint
