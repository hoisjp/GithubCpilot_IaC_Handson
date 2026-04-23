# Step 2: 設計図をもとに Bicep ファイルを作る

Step 1 で生成したアーキテクチャ図を GitHub Copilot に渡し、**Bicep テンプレート** に落としていきます。

---

## 🎯 このステップのゴール

- 設計図 → Bicep への変換を Copilot で行える
- **モジュール分割** された保守性の高い Bicep を作れる
- `.bicepparam` を使って環境ごとのパラメータを分離できる
- Bicep linter の指摘を Copilot と一緒に潰せる
- **Azure Verified Modules (AVM)** を使った実装との違いを理解できる

---

## 0. 2 つのトラック — 自作モジュール vs Azure Verified Modules

本ステップでは、同じ設計を **2 通りの方法** で Bicep に落とします。

| | Track A: 自作モジュール | Track B: Azure Verified Modules (AVM) |
|---|---|---|
| 方針 | すべて自分で `resource` を書く | 公式モジュールを `br/public:avm/res/...` で呼び出す |
| 学習効果 | リソースの構造が深く理解できる | 実務パターン・ベストプラクティスに触れられる |
| コード量 | 多い (1 モジュール 30〜80 行) | 少ない (モジュール呼出 10〜20 行) |
| セキュリティ既定値 | 自分で正しく設定する必要あり | **Microsoft が検証済みの安全側デフォルト** |
| 向いている場面 | 学習 / 特殊要件で AVM が使えない時 | **ほとんどの実案件** |

> 💡 **推奨ルート**: まず **Track A** を一通り作って原理を掴んでから、**Track B** で「AVM ならどれだけシンプルになるか」を体験してください。

サンプル実装はどちらも [`sample/`](../sample/) に置いています。

- Track A: [`sample/main.bicep`](../sample/main.bicep) + [`sample/modules/`](../sample/modules/)
- Track B: [`sample/avm/main.bicep`](../sample/avm/main.bicep)

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

---

## 6. Track B: Azure Verified Modules (AVM) で書き直す

Track A で「自作の大変さ」を体験したら、同じ設計を **AVM** で書き直してみます。**同じ成果物が半分以下のコードで書ける** ことを体感するのが目的です。

### 6-1. AVM とは (復習)

- **Microsoft 公式** の Bicep / Terraform モジュール集 (👉 [README 冒頭の説明](../README.md#-azure-verified-modules-avm-とは))
- Bicep 版は **Public Module Registry** で配布: `br/public:avm/res/<provider>/<resource>:<version>`
- **診断設定 (diagnosticSettings)・Managed Identity・RBAC・ネットワーク ACL** といった "毎回書く定型" が標準搭載
- セキュリティ既定値が **Microsoft 推奨値** に寄せられている (例: storage の `allowSharedKeyAccess: false`)

### 6-2. 使うモジュール

今回の構成に対応する AVM モジュールはこちら。

| 用途 | AVM モジュール | ドキュメント |
|---|---|---|
| Log Analytics | `avm/res/operational-insights/workspace` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/operational-insights/workspace) |
| Application Insights | `avm/res/insights/component` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/insights/component) |
| Key Vault | `avm/res/key-vault/vault` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault) |
| Storage Account | `avm/res/storage/storage-account` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/storage/storage-account) |
| SQL Server + DB | `avm/res/sql/server` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/sql/server) |
| App Service Plan | `avm/res/web/serverfarm` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/web/serverfarm) |
| App Service (Site) | `avm/res/web/site` | [Link](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/web/site) |

> 🔍 **モジュール検索**: AVM モジュールは [Bicep Registry Modules リポジトリ](https://github.com/Azure/bicep-registry-modules/tree/main/avm) で全件参照できます。バージョンは各モジュールの `version.json` を確認してください。

### 6-3. サンプルプロンプト (AVM 版)

Copilot Chat に以下を投げます。

````text
同じアーキテクチャを、今度は Azure Verified Modules (AVM) を使って
sample/avm/main.bicep に書き直してください。

# ルール
- すべてのリソースは AVM モジュール (`br/public:avm/res/...`) を使う
- モジュールバージョンは各モジュールの最新 stable (0.x 系) を使用し、コメントで明記
- RBAC 付与は各 AVM モジュールの `roleAssignments` パラメータで設定する
  (別途 roleAssignment リソースは書かない)
- diagnosticSettings パラメータで Log Analytics にログを送る (App Service / Key Vault / SQL / Storage)
- App Service の Managed Identity は `managedIdentities: { systemAssigned: true }` で有効化
- パラメータや命名規則は Track A と揃える

# 出力
- sample/avm/main.bicep (モジュール呼び出しだけのエントリポイント)
- sample/avm/main.dev.bicepparam

# 参考にするドキュメント
各モジュールの README:
https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/...
````

### 6-4. AVM モジュール呼び出しの基本形

```bicep
module kv 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'kv-deploy'
  params: {
    name: kvName
    location: location
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: isProd
    roleAssignments: [
      {
        principalId: appServicePrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        principalType: 'ServicePrincipal'
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsId
      }
    ]
  }
}
```

**ポイント**:
- `roleDefinitionIdOrName` には **ロール名をそのまま文字列で** 書ける (GUID を探す必要なし)
- `diagnosticSettings` を指定するだけで、そのリソースのログ/メトリクスが Log Analytics に流れる
- セキュリティ関連プロパティ (`enableRbacAuthorization`, `publicNetworkAccess` など) の **デフォルトが安全側**

### 6-5. Track A と Track B のコード量比較

完成版サンプルでの実測 (概算):

| 項目 | Track A (自作) | Track B (AVM) |
|---|---|---|
| ファイル数 | 7 (main + 5 modules + 1 param) | 2 (main + 1 param) |
| 総行数 | 約 450 行 | 約 180 行 |
| ロール割り当て記述 | 手動で `guid()` + `roleDefinitionId` | モジュールパラメータに名前指定するだけ |
| 診断設定の網羅性 | 基本は自分で追加 | モジュール側で自動追加 |

### 6-6. AVM で気をつけること

- ⚠️ **バージョン固定**: モジュールは `:0.11.0` のように **バージョンを固定** する。`:latest` は使わない
- ⚠️ **モジュール更新の確認**: 定期的にリリースノートを確認 (破壊的変更があることも)
- ⚠️ **利用不可なプロパティ**: 稀にモジュールが露出していないプロパティがある。その場合は issue を立てるか、ひとまず自作モジュールに戻す
- ⚠️ **依存関係**: AVM 同士で出力 (`.outputs.resourceId` など) を渡すときは **プロパティ名がモジュールごとに異なる** ので README を確認

### 6-7. what-if 差分で Track A ↔ B の等価性を確認

両方のトラックで **同じリソースグループにデプロイしたら同じ結果になるか** を what-if で比較できます。

```powershell
# Track A
az deployment group what-if -g rg-web-dev-japaneast `
  --template-file sample/main.bicep --parameters sample/main.dev.bicepparam

# Track B
az deployment group what-if -g rg-web-dev-japaneast `
  --template-file sample/avm/main.bicep --parameters sample/avm/main.dev.bicepparam
```

差分を Copilot に貼って、**「AVM 版のほうが追加で有効化しているセキュリティ機能は何か？」** を質問すると、AVM の安全側デフォルトが浮き彫りになります。

---

## 7. トラック選定ガイド

実務でどちらを選ぶか迷ったら、以下を参考に。

| 状況 | 推奨 |
|---|---|
| 初学者の学習 | Track A |
| 社内標準として IaC を整備 | **Track B (AVM)** |
| CAF / Landing Zone 準拠を要求される | **Track B (AVM)** |
| AVM に存在しない特殊リソース (preview 機能等) | Track A |
| ハイブリッド (大部分は AVM, 一部だけ自作) | **Track B をベースに一部 Track A** |

次はこれをデプロイします。

👉 次へ: [Step 3: Azure にデプロイする](03-deploy.md)
