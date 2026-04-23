# Step 2: 設計図をもとに Bicep ファイルを作る

Step 1 で生成したアーキテクチャ図を GitHub Copilot に渡し、**Bicep テンプレート** に落としていきます。

---

## 🎯 このステップのゴール

- 設計図 → Bicep への変換を Copilot で行える
- **モジュール分割** された保守性の高い Bicep を作れる
- `.bicepparam` を使って環境ごとのパラメータを分離できる
- Bicep linter の指摘を Copilot と一緒に潰せる

---

## 1. 完成イメージ

最終的に以下の構成を目指します。

```
bicep/
├── main.bicep                # エントリーポイント (サブスクリプション or リソースグループ スコープ)
├── main.dev.bicepparam       # dev 用パラメータ
├── main.prod.bicepparam      # prod 用パラメータ
└── modules/
    ├── appservice.bicep      # App Service + Plan
    ├── sql.bicep             # SQL Server + DB (Entra ID 認証)
    ├── keyvault.bicep        # Key Vault (RBAC mode)
    ├── monitoring.bicep      # Log Analytics + App Insights
    └── storage.bicep         # Storage Account
```

参考実装は [`sample/`](../sample/) に置いてあります (答え合わせ用)。

---

## 2. プロンプトの進め方 — 「一気に」ではなく「段階的に」

Copilot に `main.bicep を全部作って` と頼むと、長大で検証しづらいコードが返ってきます。以下のように **段階的** に進めるのがおすすめです。

1. **骨格を作る** — `main.bicep` のパラメータ・変数・モジュール呼び出しだけ
2. **モジュールを 1 つずつ作る** — 監視 → Key Vault → Storage → SQL → App Service の順
3. **パラメータファイルを作る** — dev / prod
4. **lint と what-if で検証する**

この順序は **「依存されるリソースを先に作る」** ことで、後続モジュールの参照 (`existing` や出力) を書きやすくなるためです。

---

## 3. ステップごとのプロンプト例

### 3-1. `main.bicep` の骨格

````text
先ほど設計したアーキテクチャ (App Service + SQL + Key Vault + Monitoring + Storage) を
Bicep で実装します。まず main.bicep の骨格だけ作ってください。

# 要件
- targetScope は resourceGroup
- パラメータ: environmentName (dev|prod), location, workloadName, sqlAdminLoginName, sqlAdminObjectId
- 命名規則: `${workloadName}-${environmentName}-${resourceType省略形}` (例: web-dev-app)
- tags 共通オブジェクトを定義し、全モジュールに伝播
- モジュール呼び出し: monitoring → keyvault → storage → sql → appservice の順
- 出力: App Service の default host name, Key Vault の名前

# スタイル
- Bicep ベストプラクティスに従う (param description 必須、@allowed / @minLength などを活用)
- まだ各モジュールの中身は書かない (ファイルは空で OK)
````

### 3-2. モジュール: monitoring

````text
modules/monitoring.bicep を作成してください。

# 内容
- Log Analytics Workspace (PerGB2018, retention 30 日)
- Application Insights (workspace-based, type=web)
- 出力: workspaceId, appInsightsConnectionString, appInsightsInstrumentationKey

# 要件
- location, tags, namePrefix をパラメータ化
- Application Insights は Log Analytics に紐づける (workspaceResourceId)
- Bicep linter の警告が出ない形で
````

### 3-3. モジュール: keyvault

````text
modules/keyvault.bicep を作成してください。

- RBAC 認可モデル (enableRbacAuthorization: true)
- soft delete 有効 / purge protection 有効 (prod のみ true にできるようパラメータ化)
- public network access は Allow (ハンズオン簡易化のため) ※本番は Deny + Private Endpoint が推奨とコメントで明記
- 出力: keyVaultName, keyVaultUri
````

### 3-4. モジュール: storage

````text
modules/storage.bicep を作成してください。

- Standard_LRS, StorageV2, TLS 1.2 minimum
- allowBlobPublicAccess: false
- supportsHttpsTrafficOnly: true
- デフォルトで blob サービスの logging / soft delete (7 日) を有効化
- 出力: storageAccountName, blobEndpoint
````

### 3-5. モジュール: sql

````text
modules/sql.bicep を作成してください。

# 要件
- SQL Server (Azure AD / Entra ID 認証のみ有効, SQL 認証は無効)
- administrators ブロックで Entra ID 管理者 (object id) を設定
- SQL Database は Serverless (GP_S_Gen5_1), autoPauseDelay 60 分
- publicNetworkAccess は Enabled (簡易化, 本番は Private Endpoint 推奨とコメント)
- Firewall rule で Azure サービスからのアクセスを許可 (0.0.0.0)
- 出力: sqlServerFqdn, databaseName
````

### 3-6. モジュール: appservice

````text
modules/appservice.bicep を作成してください。

# 要件
- Linux App Service Plan (B1, dev) / (P1v3, prod) をパラメータで切り替え
- App Service (linuxFxVersion: 'NODE|20-lts')
- System-assigned Managed Identity を有効化
- httpsOnly: true, minTlsVersion: '1.2', ftpsState: 'Disabled'
- App Settings:
    - APPLICATIONINSIGHTS_CONNECTION_STRING (monitoring モジュールから受け取る)
    - KEY_VAULT_URI (keyvault モジュールから)
    - STORAGE_BLOB_ENDPOINT (storage モジュールから)
    - SQL_SERVER_FQDN, SQL_DATABASE (sql モジュールから)
- App Service の Managed Identity に対して:
    - Key Vault 上で "Key Vault Secrets User" ロール
    - Storage 上で "Storage Blob Data Contributor" ロール
  を付与する roleAssignment リソースを同じモジュール内または main から作成

# 注意
- RBAC 付与は existing で参照したリソースに対して scope を設定
````

### 3-7. パラメータファイル

````text
main.bicep に対応する bicepparam を 2 つ作ってください。
- main.dev.bicepparam:  environmentName='dev',  location='japaneast', workloadName='web', ...
- main.prod.bicepparam: environmentName='prod', location='japaneast', workloadName='web', ...

sqlAdminLoginName / sqlAdminObjectId はプレースホルダ ('<YOUR_...>') とし、
読み手が置き換える前提でコメントを残してください。
````

---

## 4. Copilot の出力を受け取ったら

### 4-1. 即座に `bicep build` で検証

```powershell
az bicep build --file bicep/main.bicep
```

linter 警告 (`BCP***`) が出たら、そのまま Copilot に貼って質問します。

````text
以下の警告が出ました。どう直すのがベストプラクティスですか?
<警告内容を貼る>
````

### 4-2. よくある修正ポイント

- `listKeys()` や `listConnectionStrings()` を避け、Managed Identity + 出力の ID 情報だけを渡す
- `secureString` を持つパラメータは `@secure()` を付与
- `resource ... existing` を使い、モジュール間の循環参照を避ける
- `tags` を共通変数として上から伝播させる
- 役割 ID は `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '<GUID>')` で指定

---

## 5. 成果物

- `bicep/main.bicep`
- `bicep/modules/*.bicep`
- `bicep/main.dev.bicepparam` / `bicep/main.prod.bicepparam`
- linter 警告 0 件 / `az bicep build` 成功

次はこれをデプロイします。

👉 次へ: [Step 3: Azure にデプロイする](03-deploy.md)
