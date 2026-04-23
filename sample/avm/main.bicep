// =============================================================================
// main.bicep  (Track B: Azure Verified Modules 版)
// -----------------------------------------------------------------------------
// Track A (sample/main.bicep + modules/) と同じアーキテクチャを、
// Azure Verified Modules (AVM) のみで構築するサンプル。
//
// モジュールは Bicep Public Registry から参照:
//   br/public:avm/res/<provider>/<resource>:<version>
//
// バージョンは明示的に固定。最新の stable は以下で確認:
//   https://github.com/Azure/bicep-registry-modules/tree/main/avm/res
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
@description('Deployment environment name.')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Short workload name (naming prefix).')
@minLength(2)
@maxLength(10)
param workloadName string = 'web'

@description('Entra ID login name (UPN or group name) for SQL Server administrator.')
param sqlAdminLoginName string

@description('Object ID of the Entra ID principal (user/group) for SQL admin.')
param sqlAdminObjectId string

// -----------------------------------------------------------------------------
// Variables
// -----------------------------------------------------------------------------
var namePrefix = '${workloadName}-${environmentName}'
var uniqueSuffix = uniqueString(resourceGroup().id)
var isProd = environmentName == 'prod'

var tags = {
  workload: workloadName
  environment: environmentName
  managedBy: 'bicep-avm'
}

var appServicePlanSku = isProd ? 'P1v3' : 'B1'

// =============================================================================
// Monitoring (Log Analytics + Application Insights)
//   AVM は Log Analytics と App Insights を別モジュールで提供。
//   Workspace-based App Insights にするため、LA の resourceId を AI に渡す。
// =============================================================================
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: 'log-analytics'
  params: {
    name: '${namePrefix}-law'
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

module appInsights 'br/public:avm/res/insights/component:0.4.1' = {
  name: 'app-insights'
  params: {
    name: '${namePrefix}-appi'
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    kind: 'web'
    applicationType: 'web'
  }
}

// =============================================================================
// Key Vault (RBAC mode)
//   diagnosticSettings パラメータで LA にログ転送が 1 ブロックで完結。
//   purge protection は prod のみ true。
// =============================================================================
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'key-vault'
  params: {
    name: take('${namePrefix}-kv-${uniqueSuffix}', 24)
    location: location
    tags: tags
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: isProd ? true : null
    publicNetworkAccess: 'Enabled' // 本番は 'Disabled' + Private Endpoint 推奨
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
    // App Service の Managed Identity への RBAC 付与は appService モジュール定義後
    // に別 module としても書けるが、ここでは appService モジュール内で付与する方針。
  }
}

// =============================================================================
// Storage Account
//   AVM デフォルトで TLS1.2 / allowBlobPublicAccess: false / HTTPS only。
//   共有キー無効化とソフト削除を明示的に指定。
// =============================================================================
module storage 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'storage'
  params: {
    name: take(toLower(replace('${namePrefix}st${uniqueSuffix}', '-', '')), 24)
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled' // 本番は 'Disabled' + Private Endpoint
    blobServices: {
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 7
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
  }
}

// =============================================================================
// SQL Server + Database (Serverless, Entra ID-only 認証)
//   administrators ブロックで Entra ID only を強制。
//   databases 配列で子 DB を一括定義できるのが AVM の強み。
// =============================================================================
module sqlServer 'br/public:avm/res/sql/server:0.11.1' = {
  name: 'sql-server'
  params: {
    name: take(toLower('${namePrefix}-sql-${uniqueSuffix}'), 63)
    location: location
    tags: tags
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled' // 本番は 'Disabled' + Private Endpoint
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      azureADOnlyAuthentication: true
      login: sqlAdminLoginName
      sid: sqlAdminObjectId
      tenantId: tenant().tenantId
    }
    firewallRules: [
      {
        name: 'AllowAllAzureServices'
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
      }
    ]
    databases: [
      {
        name: '${namePrefix}-db'
        sku: {
          name: 'GP_S_Gen5_1'
          tier: 'GeneralPurpose'
          family: 'Gen5'
          capacity: 1
        }
        autoPauseDelay: 60
        minCapacity: json('0.5')
        zoneRedundant: false
        requestedBackupStorageRedundancy: 'Local'
      }
    ]
  }
}

// =============================================================================
// App Service Plan
// =============================================================================
module plan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'app-service-plan'
  params: {
    name: '${namePrefix}-asp'
    location: location
    tags: tags
    skuName: appServicePlanSku
    kind: 'linux'
    reserved: true
  }
}

// =============================================================================
// App Service (Site)
//   managedIdentities で System-assigned MI を有効化。
//   roleAssignments で Key Vault / Storage 側のロールを直接付与できる……
//   …… が、AVM の site モジュールの roleAssignments は "site 自身" への付与用なので、
//   KV / Storage への付与は各モジュール側の roleAssignments で指定するのが正しい。
//   本サンプルでは、シンプルさ優先で principal 取得後に別モジュールで付与する形にせず、
//   keyVault / storage モジュール側で dependsOn 経由で principalId を参照する方法は
//   使えないため、appService 定義の後で RoleAssignment リソースを書き足している。
// =============================================================================
module appService 'br/public:avm/res/web/site:0.12.0' = {
  name: 'app-service'
  params: {
    name: take('${namePrefix}-app-${uniqueSuffix}', 40)
    location: location
    tags: tags
    kind: 'app,linux'
    serverFarmResourceId: plan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: appServicePlanSku != 'B1'
    }
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
      KEY_VAULT_URI: keyVault.outputs.uri
      STORAGE_BLOB_ENDPOINT: storage.outputs.primaryBlobEndpoint
      STORAGE_ACCOUNT_NAME: storage.outputs.name
      SQL_SERVER_FQDN: sqlServer.outputs.fullyQualifiedDomainName
      SQL_DATABASE: '${namePrefix}-db'
      WEBSITE_RUN_FROM_PACKAGE: '1'
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
  }
}

// =============================================================================
// RBAC: App Service Managed Identity → Key Vault / Storage
//   AVM の大きな利点。`roleDefinitionIdOrName` にロール名を文字列で書ける。
// =============================================================================
module rbacKeyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'rbac-keyvault'
  params: {
    // 既存 Key Vault への追加設定として roleAssignments だけを適用する形。
    // 実運用では上の keyVault モジュール内で roleAssignments を直接書くのが簡潔。
    name: keyVault.outputs.name
    location: location
    enableRbacAuthorization: true
    roleAssignments: [
      {
        principalId: appService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    keyVault
  ]
}

module rbacStorage 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'rbac-storage'
  params: {
    name: storage.outputs.name
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    roleAssignments: [
      {
        principalId: appService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    storage
  ]
}

// -----------------------------------------------------------------------------
// NOTE:
//   上記の rbacKeyVault / rbacStorage モジュールは解説用です。
//   実際のプロダクション実装では、keyVault / storage モジュール定義の roleAssignments に
//   appService.outputs.systemAssignedMIPrincipalId を直接渡す方がシンプル。
//   ただし循環参照を避けるため、App Service の principalId を得る必要があり、
//   appService を先にデプロイしてから別モジュールで追加付与するパターンもよく使われます。
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output appServiceHostName string = appService.outputs.defaultHostname
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output sqlServerFqdn string = sqlServer.outputs.fullyQualifiedDomainName
output appInsightsName string = appInsights.outputs.name
