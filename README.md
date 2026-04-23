# GitHub Copilot で学ぶ IaC ハンズオン (Bicep × Azure)

本ハンズオンでは、**GitHub Copilot (Chat / Agent モード)** を活用して、Azure 上に Web アプリケーション基盤を **Bicep** でデプロイするまでの一連の流れを体験します。

「AI にコードを書かせる」のではなく、**AI と対話しながら設計 → 実装 → デプロイ → 振り返り** を進める、実務に近いワークフローを学ぶことを目的としています。

---

## 🎯 ゴール

- GitHub Copilot を使って、要件から **Azure アーキテクチャ設計図 (Mermaid / draw.io)** を生成できる
- 設計図をもとに **Bicep テンプレート** を Copilot と対話しながら作成できる
- **Azure Verified Modules (AVM)** を使って、Microsoft が品質保証した公式モジュールで IaC を組み立てられる
- GitHub Copilot Agent (Azure MCP) を活用して、**対話的に Azure へデプロイ** できる
- 生成された IaC に対して **Azure Well-Architected Framework / Bicep ベストプラクティス** の観点でレビューできる

---

## 📦 Azure Verified Modules (AVM) とは

本ハンズオンでは、後半で **Azure Verified Modules (AVM)** を使った IaC 実装も扱います。AVM を一言でいうと:

> **Microsoft が「WAF に準拠している」と検証・保証した、再利用可能な公式 IaC モジュール群**

より具体的には:

- 🏅 **Microsoft 公式** — Azure プロダクトチームと FastTrack for Azure が共同で提供
- 🧩 **Bicep / Terraform 両対応** — 同じ思想でマルチ IaC 言語をカバー
- ✅ **WAF に準拠** — 信頼性 / セキュリティ / 運用性のデフォルトが "安全側" に倒されている
- 🔁 **バージョン管理された公開レジストリで配布** — Bicep は `br/public:avm/res/...`、Terraform は Terraform Registry
- 🧪 **自動テスト済み** — PSRule for Azure などによる静的解析と CI が走っている

ゼロから自作する Bicep と比べて、**セキュリティのデフォルト値・diagnosticSettings・Managed Identity・RBAC** といった「毎回書くけれど間違えやすい部分」を大幅に省略でき、**レビューコストが下がる** のが最大のメリットです。

公式情報:

- 📘 [Azure Verified Modules (公式サイト)](https://azure.github.io/Azure-Verified-Modules/)
- 📘 [Bicep Public Module Registry](https://github.com/Azure/bicep-registry-modules/tree/main/avm)
- 📘 [Terraform AVM Modules](https://registry.terraform.io/namespaces/Azure)

ハンズオン内では **"自作 Bicep" と "AVM ベース" の両方** を提示し、実務での使い分け判断ができるようになることを目指します。

---

## 🏗️ 題材とする構成

シンプルな Web アプリケーション向けの基盤です。

| レイヤー | リソース |
|---------|---------|
| アプリ実行基盤 | Azure App Service (Linux) + App Service Plan |
| データストア | Azure SQL Database (Serverless) |
| シークレット管理 | Azure Key Vault |
| 監視・ログ | Log Analytics Workspace + Application Insights |
| ストレージ | Azure Storage Account (Blob) |
| ID | System-assigned Managed Identity (App Service → Key Vault / SQL) |

> 🔒 **設計方針**: パスワードレス (Managed Identity)、最小権限 (RBAC)、観測可能性、環境ごとのパラメータ分離を重視します。

---

## 📚 ハンズオンの流れ

| Step | 内容 | ドキュメント |
|------|------|---|
| ① | プロンプトで設計図 (アーキテクチャ図) を作る | [docs/01-design.md](docs/01-design.md) |
| ② | 設計図をもとに Bicep ファイルを作る | [docs/02-bicep.md](docs/02-bicep.md) |
| ③ | GitHub Copilot と対話しながら Azure にデプロイする | [docs/03-deploy.md](docs/03-deploy.md) |
| ④ | 設計ポイントとベストプラクティスを振り返る | [docs/04-bestpractices.md](docs/04-bestpractices.md) |

---

## 🔧 事前準備

### 必要なもの

- [VS Code](https://code.visualstudio.com/)
- [GitHub Copilot 拡張機能](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) (Chat 有効化済み)
- [Bicep 拡張機能](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)
- [Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli) (v2.60 以降推奨)
- Azure サブスクリプション (共同作成者 権限)

### 推奨拡張機能 (MCP / Agent 利用時)

- [Azure Tools for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)
- [Azure MCP Server](https://github.com/Azure/azure-mcp) (Copilot Agent モードから Azure 操作するため)

### サインイン

```powershell
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

---

## 📁 ディレクトリ構成

```
.
├── README.md                  # 本ファイル
├── docs/
│   ├── 01-design.md           # Step1: 設計図作成
│   ├── 02-bicep.md            # Step2: Bicep 作成
│   ├── 03-deploy.md           # Step3: 対話的デプロイ
│   └── 04-bestpractices.md    # Step4: 解説
├── prompts/
│   ├── 01-design.prompt.md    # 設計図生成用サンプルプロンプト
│   ├── 02-bicep.prompt.md     # Bicep 生成用サンプルプロンプト (自作 & AVM 両対応)
│   └── 03-review.prompt.md    # レビュー用サンプルプロンプト
└── sample/                    # 完成版サンプル (答え合わせ用)
    ├── main.bicep             # Track A: 自作モジュール版
    ├── main.dev.bicepparam
    ├── main.prod.bicepparam
    ├── modules/               # 自作モジュール
    │   ├── appservice.bicep
    │   ├── sql.bicep
    │   ├── keyvault.bicep
    │   ├── monitoring.bicep
    │   └── storage.bicep
    └── avm/                   # Track B: Azure Verified Modules 版
        ├── main.bicep
        └── main.dev.bicepparam
```

> 🧭 **2 つのトラック**: `modules/` は「まず仕組みを理解する」ための自作版、`avm/` は「実務でそのまま使える」公式モジュール版です。両方を見比べることで、AVM の威力が実感できます。

---

## 🚀 はじめかた

まずは [docs/01-design.md](docs/01-design.md) から進めてください。

各ステップは **プロンプト例 → 期待されるアウトプット → 解説** の構成になっています。自分で Copilot に投げかけ、出力を比較しながら読み進めるのがおすすめです。

---

## ⚖️ ライセンス

MIT
