# GitHub Copilot で学ぶ IaC ハンズオン (Bicep × Azure)

本ハンズオンでは、**GitHub Copilot (Chat / Agent モード)** を活用して、Azure 上に Web アプリケーション基盤を **Bicep** でデプロイするまでの一連の流れを体験します。

「AI にコードを書かせる」のではなく、**AI と対話しながら設計 → 実装 → デプロイ → 振り返り** を進める、実務に近いワークフローを学ぶことを目的としています。

---

## 🎯 ゴール

- GitHub Copilot を使って、要件から **Azure アーキテクチャ設計図 (Mermaid / draw.io)** を生成できる
- 設計図をもとに **Bicep テンプレート** を Copilot と対話しながら作成できる
- GitHub Copilot Agent (Azure MCP) を活用して、**対話的に Azure へデプロイ** できる
- 生成された IaC に対して **Azure Well-Architected Framework / Bicep ベストプラクティス** の観点でレビューできる

---

## 🏗️ 題材とする構成

学習に集中できるよう、構成は **App Service + Blob Storage** の最小 2 リソースのみ。両者の接続は **System Assigned Managed Identity + RBAC** によるパスワードレスで実現します。

| レイヤー | リソース |
|---------|---------|
| アプリ実行基盤 | Azure App Service (Linux) + App Service Plan |
| ストレージ | Azure Storage Account (Blob) |
| ID | System-assigned Managed Identity (App Service → Blob Storage) |
| 権限 | RBAC: `Storage Blob Data Contributor` を Storage Account スコープで付与 |

> 🔒 **設計方針**: パスワードレス (Managed Identity)、最小権限 (RBAC)、環境ごとのパラメータ分離を重視します。SQL や Key Vault といった「依存が増える」要素はあえて含めず、Copilot との対話のサイクルを短く保ちます。

---

## 📚 ハンズオンの流れ

| Step | 内容 | ドキュメント |
|------|------|---|
| ① | プロンプトで設計図 (アーキテクチャ図) を作る | [docs/01-design.md](docs/01-design.md) |
| ② | 設計図をもとに Bicep ファイルを一気に作る | [docs/02-bicep.md](docs/02-bicep.md) |
| ③ | GitHub Copilot と対話しながら Azure にデプロイする | [docs/03-deploy.md](docs/03-deploy.md) |
| ④ | 設計ポイントとベストプラクティスを振り返る | [docs/04-bestpractices.md](docs/04-bestpractices.md) |
| 付録 | 生成された Bicep をベストプラクティス観点で検証する | [docs/05-appendix.md](docs/05-appendix.md) |

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
│   ├── 04-bestpractices.md    # Step4: 解説
│   └── 05-appendix.md         # 付録: ベストプラクティス検証
├── prompts/
│   ├── 01-design.prompt.md    # 設計図生成用サンプルプロンプト
│   ├── 02-bicep.prompt.md     # Bicep 生成用サンプルプロンプト
│   └── 03-review.prompt.md    # レビュー用サンプルプロンプト
└── sample/                    # 完成版サンプル (答え合わせ用)
    ├── main.bicep
    ├── main.dev.bicepparam
    ├── main.prod.bicepparam
    └── modules/
        ├── appservice.bicep
        └── storage.bicep
```

---

## 🚀 はじめかた

まずは [docs/01-design.md](docs/01-design.md) から進めてください。

各ステップは **プロンプト例 → 期待されるアウトプット → 解説** の構成になっています。自分で Copilot に投げかけ、出力を比較しながら読み進めるのがおすすめです。

---

## ⚖️ ライセンス

MIT
