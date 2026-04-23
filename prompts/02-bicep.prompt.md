# サンプルプロンプト: Bicep 生成 (段階的)

Step 2 で使う、段階的な Bicep 生成プロンプトのコレクション。**1 つずつ順番に** Copilot Chat に投げてください。

---

## Prompt 1 — `main.bicep` の骨格

先ほど設計したアーキテクチャ (App Service + SQL + Key Vault + Monitoring + Storage) を Bicep で実装します。
まず `bicep/main.bicep` の骨格だけを作ってください。

### 要件
- `targetScope` は `resourceGroup`
- パラメータ: `environmentName` ('dev'|'prod'), `location`, `workloadName`, `sqlAdminLoginName`, `sqlAdminObjectId` (`@secure` 不要)
- 命名規則: `${workloadName}-${environmentName}-${リソース種別}`、必要に応じて `uniqueString(resourceGroup().id)` でサフィックス
- `tags` 共通オブジェクトを変数として定義し、全モジュールに伝播
- モジュール呼び出しは **monitoring → keyvault → storage → sql → appservice** の順
- 出力: App Service の `defaultHostName`、Key Vault の `name` と `uri`

### スタイル
- すべての `param` に `@description`
- `@allowed(['dev','prod'])` を `environmentName` に付与
- 各 `module` の `params` には後で足すので空オブジェクト `{}` で OK
- 各モジュール `.bicep` ファイルはまだ作らなくて良い (`main` から参照だけ書く)

---

## Prompt 2 — monitoring モジュール

`bicep/modules/monitoring.bicep` を作成してください。

- リソース: Log Analytics Workspace (`PerGB2018`, retention 30 日) + Application Insights (workspace-based, `kind: 'web'`)
- App Insights の `WorkspaceResourceId` に Log Analytics を紐づける
- パラメータ: `location`, `tags`, `namePrefix`
- 出力: `workspaceId`, `appInsightsConnectionString`, `appInsightsName`
- Bicep linter 警告ゼロを目指す

---

## Prompt 3 — keyvault モジュール

`bicep/modules/keyvault.bicep` を作成してください。

- SKU: `standard`, テナント ID: `tenant().tenantId`
- `enableRbacAuthorization: true` (RBAC モード)
- `enableSoftDelete: true`, `softDeleteRetentionInDays: 7`
- `enablePurgeProtection`: パラメータで受け取る (`false` デフォルト、prod では `true`)
- `publicNetworkAccess: 'Enabled'` (コメントで本番 Disabled 推奨と明記)
- 出力: `keyVaultName`, `keyVaultUri`, `keyVaultResourceId`

---

## Prompt 4 — storage モジュール

`bicep/modules/storage.bicep` を作成してください。

- `kind: 'StorageV2'`, SKU: `Standard_LRS`
- `minimumTlsVersion: 'TLS1_2'`
- `allowBlobPublicAccess: false`, `supportsHttpsTrafficOnly: true`, `allowSharedKeyAccess: false`
- Blob service: soft delete 7 日, container soft delete 7 日
- 出力: `storageAccountName`, `blobEndpoint`, `storageAccountResourceId`

---

## Prompt 5 — sql モジュール

`bicep/modules/sql.bicep` を作成してください。

### 要件
- SQL Server
    - `administrators` ブロック: `administratorType: 'ActiveDirectory'`, `login`, `sid` (objectId), `tenantId`, `azureADOnlyAuthentication: true`
    - `publicNetworkAccess: 'Enabled'` (コメントで本番 Disabled + Private Endpoint 推奨を明記)
    - `minimalTlsVersion: '1.2'`
- SQL Database
    - SKU: `GP_S_Gen5_1` (Serverless), `autoPauseDelay: 60`, `minCapacity: 0.5`
    - `zoneRedundant: false` (dev)
- Firewall rule: `AllowAllAzureServices` (`0.0.0.0` - `0.0.0.0`)
- パラメータ: `location`, `tags`, `namePrefix`, `sqlAdminLoginName`, `sqlAdminObjectId`
- 出力: `sqlServerFqdn`, `databaseName`

---

## Prompt 6 — appservice モジュール

`bicep/modules/appservice.bicep` を作成してください。

### リソース
- Linux App Service Plan
    - `sku`: `B1` (dev) / `P1v3` (prod) をパラメータで切り替え
    - `kind: 'linux'`, `reserved: true`
- App Service (Web App)
    - `linuxFxVersion: 'NODE|20-lts'`
    - System-assigned Managed Identity (`identity.type: 'SystemAssigned'`)
    - `httpsOnly: true`
    - `siteConfig.minTlsVersion: '1.2'`, `ftpsState: 'Disabled'`, `http20Enabled: true`
    - `appSettings`:
        - `APPLICATIONINSIGHTS_CONNECTION_STRING`
        - `KEY_VAULT_URI`
        - `STORAGE_BLOB_ENDPOINT`
        - `SQL_SERVER_FQDN`, `SQL_DATABASE`
        - `WEBSITE_RUN_FROM_PACKAGE: '1'`

### RBAC (同ファイル内で)
App Service の Managed Identity に対して次のロールを付与:

| scope | role | roleDefinitionId |
|---|---|---|
| Key Vault | Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` |
| Storage Account | Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |

- `scope` は対応するリソースを `existing` で参照
- `name` は `guid(scope.id, principalId, roleDefinitionId)` で生成
- `roleDefinitionId` は `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '<GUID>')`

### パラメータ
`location`, `tags`, `namePrefix`, `skuName`, `keyVaultName`, `keyVaultUri`, `storageAccountName`, `storageBlobEndpoint`, `sqlServerFqdn`, `sqlDatabaseName`, `appInsightsConnectionString`

### 出力
`appServiceName`, `appServiceDefaultHostName`, `appServicePrincipalId`

---

## Prompt 7 — bicepparam

`bicep/main.dev.bicepparam` と `bicep/main.prod.bicepparam` を作ってください。

- `using './main.bicep'`
- dev: `environmentName='dev'`, `location='japaneast'`, `workloadName='web'`
- prod: `environmentName='prod'`, `location='japaneast'`, `workloadName='web'`
- `sqlAdminLoginName` と `sqlAdminObjectId` はプレースホルダ (`'<REPLACE_ME>'`) とし、  
  コメントで `az ad signed-in-user show --query id -o tsv` で取得する旨を明記

---

## Prompt 8 — 検証と修正

作成した Bicep を `az bicep build` で検証して、linter 警告があれば修正案を提示してください。
警告の根拠 (Bicep 公式ドキュメントのどのルールか) も併記してください。

---

# 🧩 Track B: Azure Verified Modules (AVM) 版

ここからは、同じ構成を **AVM (Azure Verified Modules)** で書き直します。Track A (自作モジュール) を終わらせた後に進めてください。

---

## Prompt B1 — AVM 版 main.bicep 全体

`sample/avm/main.bicep` と `sample/avm/main.dev.bicepparam` を作成してください。

### 方針
- 既存の `sample/main.bicep` と **同じアーキテクチャ** を、Azure Verified Modules (AVM) のみで実装する
- モジュールは **Bicep Public Registry** から参照する (`br/public:avm/res/...`)
- モジュールバージョンは **0.x 系の stable** を明示的に固定 (例: `:0.11.0`)

### 使用する AVM モジュール

| 用途 | モジュールパス |
|---|---|
| Log Analytics Workspace | `br/public:avm/res/operational-insights/workspace` |
| Application Insights | `br/public:avm/res/insights/component` |
| Key Vault | `br/public:avm/res/key-vault/vault` |
| Storage Account | `br/public:avm/res/storage/storage-account` |
| SQL Server + Database | `br/public:avm/res/sql/server` |
| App Service Plan | `br/public:avm/res/web/serverfarm` |
| App Service (Site) | `br/public:avm/res/web/site` |

※ 各モジュールの最新バージョンと入力仕様は https://github.com/Azure/bicep-registry-modules/tree/main/avm/res で確認してください。

### AVM モジュール活用ルール

- **RBAC**: 各モジュールの `roleAssignments` パラメータを使い、`roleDefinitionIdOrName` にロール名 (例 `'Key Vault Secrets User'`) を文字列指定
- **診断設定**: 各モジュールの `diagnosticSettings` パラメータで Log Analytics の `workspaceResourceId` を指定し、ログ/メトリクスを一括転送
- **Managed Identity**: App Service の `managedIdentities: { systemAssigned: true }` を有効化
- **セキュリティ**: AVM のデフォルト (TLS 1.2 最低, public access 制限など) を尊重し、必要な場合のみ明示的に上書き
- **Key Vault**: `enableRbacAuthorization: true`, `enablePurgeProtection` は prod のみ true
- **SQL Server**: `administrators` に Entra ID のみ認証 (`azureADOnlyAuthentication: true`)
- **Storage**: `allowSharedKeyAccess: false`, `allowBlobPublicAccess: false`
- **App Service の App Settings**: 既存と同じ (APPLICATIONINSIGHTS_CONNECTION_STRING, KEY_VAULT_URI, ...)

### パラメータ

Track A と同じパラメータを使用:
- `environmentName` ('dev'|'prod'), `location`, `workloadName`, `sqlAdminLoginName`, `sqlAdminObjectId`

### 出力

- `appServiceHostName`
- `keyVaultName`, `keyVaultUri`
- `sqlServerFqdn`
- `appInsightsName`

### スタイル

- すべての `module` 呼び出しの直前に、**なぜこのモジュール・なぜこのパラメータか** を 1〜2 行コメント
- Track A とのコード量比較ができるよう、**できるだけ簡潔に**

---

## Prompt B2 — Track A と Track B の差分解説

作成した Track A (`sample/main.bicep` + `modules/`) と Track B (`sample/avm/main.bicep`) を比較し、次の観点で違いを表形式で解説してください。

1. 総行数 / ファイル数
2. セキュリティ既定値の違い (AVM がデフォルトで有効化している項目)
3. 診断設定の書きやすさ
4. RBAC 付与の書き方の違い
5. 学習コスト vs 保守コスト
6. この構成で Track B を採用できる / できない条件

結論として、本構成では Track A と Track B のどちらを推奨するかを明記してください。
