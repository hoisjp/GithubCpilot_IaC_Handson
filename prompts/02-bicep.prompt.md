# サンプルプロンプト: Bicep 一気に生成

Step 2 で使う、設計図から **一気に** Bicep を生成するためのプロンプトです。
そのまま GitHub Copilot Chat に貼り付けて使えます。

---

あなたは Azure ソリューションアーキテクトです。
先ほど設計したアーキテクチャ (App Service + Blob Storage、Managed Identity + RBAC によるパスワードレス接続) を、
Resource Group スコープの Bicep として **一気に** 実装してください。

# 構成

- App Service (Linux, System Assigned Managed Identity)
- Storage Account (Blob)
- App Service の Managed Identity に対し、Storage Account 上で `Storage Blob Data Contributor` ロールを付与
- 接続はパスワードレス (接続文字列・アカウントキーは使わない)

# パラメータ

- `environmentName` (allowed: `dev` | `prod`) で SKU 等を切替 (dev=B1, prod=P1v3)
- `location` のデフォルトは `japaneast`
- `workloadName` (例: `web`) を命名プレフィックスに使用

# 出力ファイル

- `sample/main.bicep` (エントリーポイント)
- `sample/modules/appservice.bicep`
- `sample/modules/storage.bicep`
- `sample/main.dev.bicepparam`
- `sample/main.prod.bicepparam`

# 実装ルール

- App Service の App Settings には `STORAGE_BLOB_ENDPOINT` と `STORAGE_ACCOUNT_NAME` のみ設定 (接続文字列は入れない)
- Storage は `allowSharedKeyAccess: false` / `allowBlobPublicAccess: false` / `minimumTlsVersion: 'TLS1_2'`
- App Service は `httpsOnly: true` / `siteConfig.minTlsVersion: '1.2'` / `ftpsState: 'Disabled'`
- ロール割り当ての `name` は `guid(scope.id, principalId, roleDefinitionId)` で冪等化
- すべての `param` に `@description`、`environmentName` には `@allowed(['dev','prod'])` を付与
- `tags` 共通オブジェクト (`workload`, `environment`, `managedBy`) を全モジュールに伝播
- Storage Account 名は `uniqueString(resourceGroup().id)` でグローバル一意化、24 文字以内・小文字英数のみ

# 出力フォーマット

ファイル単位でコードブロックとして返し、ファイル名を明記してください。
最後に、`az bicep build` と `az deployment group what-if` の検証コマンド例も併記してください。
