@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Naming prefix.')
param namePrefix string

@description('Unique suffix to ensure Key Vault name is globally unique.')
param uniqueSuffix string

@description('Enable Key Vault purge protection. Recommended true for prod.')
param enablePurgeProtection bool = false

// NOTE: For production, set publicNetworkAccess to 'Disabled' and use Private Endpoint.
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: take('${namePrefix}-kv-${uniqueSuffix}', 24)
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultResourceId string = keyVault.id
