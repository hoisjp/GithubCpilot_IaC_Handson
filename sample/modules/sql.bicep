@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Naming prefix.')
param namePrefix string

@description('Unique suffix for globally unique SQL server name.')
param uniqueSuffix string

@description('Entra ID login name for SQL Server administrator.')
param sqlAdminLoginName string

@description('Object ID of the Entra ID principal (user/group) to make SQL admin.')
param sqlAdminObjectId string

var sqlServerName = take(toLower('${namePrefix}-sql-${uniqueSuffix}'), 63)
var databaseName = '${namePrefix}-db'

// NOTE: For production, set publicNetworkAccess to 'Disabled' and use Private Endpoint.
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      azureADOnlyAuthentication: true
      login: sqlAdminLoginName
      sid: sqlAdminObjectId
      tenantId: tenant().tenantId
    }
    version: '12.0'
  }
}

resource database 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    autoPauseDelay: 60
    minCapacity: json('0.5')
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
