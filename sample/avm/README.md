# AVM 版サンプル (Track B)

このディレクトリは、`../main.bicep` (Track A: 自作モジュール版) と **同じアーキテクチャ** を **Azure Verified Modules (AVM)** のみで実装したサンプルです。

## 📂 ファイル

| ファイル | 内容 |
|---|---|
| [main.bicep](main.bicep) | AVM モジュール呼び出しのみで構成されたエントリポイント |
| [main.dev.bicepparam](main.dev.bicepparam) | dev 環境用パラメータ |

## 🚀 デプロイ方法

```powershell
# パラメータを置き換え (初回のみ)
# main.dev.bicepparam の <REPLACE_ME...> を実際の値に

# リソースグループ作成
az group create -n rg-web-dev-avm-japaneast -l japaneast

# what-if で差分確認
az deployment group what-if `
  -g rg-web-dev-avm-japaneast `
  --template-file main.bicep `
  --parameters main.dev.bicepparam

# 本デプロイ
az deployment group create `
  -n avm-dev-$(Get-Date -Format 'yyyyMMdd-HHmm') `
  -g rg-web-dev-avm-japaneast `
  --template-file main.bicep `
  --parameters main.dev.bicepparam
```

> 💡 初回実行時は `br/public:avm/...` のモジュールを自動ダウンロードするため、数秒〜数十秒かかります。

## 🔍 Track A との差分を確認する

Track A (自作) と比較する手順は [docs/02-bicep.md §6-7](../../docs/02-bicep.md) を参照。

## 📚 使用している AVM モジュール

| 用途 | モジュール | バージョン |
|---|---|---|
| Log Analytics | `avm/res/operational-insights/workspace` | 0.9.0 |
| App Insights | `avm/res/insights/component` | 0.4.1 |
| Key Vault | `avm/res/key-vault/vault` | 0.11.0 |
| Storage | `avm/res/storage/storage-account` | 0.14.3 |
| SQL Server | `avm/res/sql/server` | 0.11.1 |
| App Service Plan | `avm/res/web/serverfarm` | 0.4.1 |
| App Service (Site) | `avm/res/web/site` | 0.12.0 |

> ⚠️ バージョンは **執筆時点の参考値** です。利用前に [Bicep Registry Modules](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res) で最新 stable を確認してください。

## ⚠️ サンプル上の注意点

`main.bicep` の末尾にある `rbacKeyVault` / `rbacStorage` モジュールは **解説目的で分離** しています。実運用では、各リソースモジュール (`keyVault`, `storage`) 定義の `roleAssignments` パラメータに、直接 App Service の Managed Identity の principalId を渡す方がシンプルです。ただしその場合、App Service が先に作られている必要があるため、デプロイ順序を制御するために `dependsOn` が必要です。
