# Appendix: 生成された Bicep モジュールをベストプラクティス観点でチェックする

Copilot が生成した `sample/main.bicep` と `sample/modules/*.bicep` が **Azure / Bicep のベストプラクティスに沿っているか** を、複数のツール・手段でセルフチェックする方法をまとめます。

> 💡 ベストプラクティス準拠の確認は「Copilot に聞く」だけではなく、**機械的に検出できる層 (linter / PSRule / what-if)** と **人間 or AI による観点レビュー (WAF)** を組み合わせるのがコツです。

---

## 🎯 このステップのゴール

- 生成された Bicep を **5 つの異なるレイヤー** で検証する手順を理解する
- 指摘を Copilot にフィードバックして自動修正するループを回せるようになる
- 本番投入前の **品質ゲート** として使えるチェックリストを手に入れる

---

## 1. レイヤー全体像

| # | 手段 | 何を検出するか | 所要時間 |
|---|---|---|---|
| 1 | `az bicep build` | 構文エラー / 型エラー | 数秒 |
| 2 | `az bicep lint` (Bicep linter) | API バージョン, 命名, セキュア既定値など **Bicep レベルのベストプラクティス** | 数秒 |
| 3 | `az deployment group what-if` | 実際にデプロイした際の **差分と失敗要因** | 10〜30 秒 |
| 4 | **PSRule for Azure** | Azure WAF (信頼性 / セキュリティ / コスト / 運用 / パフォーマンス) の **ルールベースチェック** | 30 秒〜 |
| 5 | **Copilot によるレビュー** | 観点レビュー / 設計意図との整合性 / 改善提案 | プロンプト次第 |

下に行くほど「検出できる指摘の抽象度」が高くなります。**1〜4 は CI に組み込める、5 は設計レビュー的に使う**、という棲み分けがおすすめです。

---

## 2. Bicep linter でチェックする

Bicep CLI には **linter** が内蔵されており、`bicep build` 時に警告として出力されます。

```powershell
az bicep build --file sample/main.bicep
```

よく出る指摘の例:

| 警告コード | 意味 | 対処 |
|---|---|---|
| `no-hardcoded-env-urls` | `*.azure.com` などの URL を直書きしている | `environment().suffixes.storage` など環境関数を使う |
| `secure-parameter-default` | `@secure()` パラメータにデフォルト値がある | デフォルトを削除 |
| `outputs-should-not-contain-secrets` | 出力に秘匿情報が含まれる可能性 | 出力から削除 |
| `use-recent-api-versions` | API バージョンが古い | 最新安定版に更新 |
| `prefer-interpolation` | 文字列連結を `${...}` に書き換え推奨 | インターポレーションに置換 |

### `bicepconfig.json` で厳格化

プロジェクト直下に `bicepconfig.json` を置くと、警告を **エラー化** してビルドを落とせます。

```json
{
  "analyzers": {
    "core": {
      "rules": {
        "no-hardcoded-env-urls": { "level": "error" },
        "secure-parameter-default": { "level": "error" },
        "outputs-should-not-contain-secrets": { "level": "error" },
        "use-recent-api-versions": { "level": "warning" }
      }
    }
  }
}
```

参考: [Bicep linter](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)

---

## 3. `what-if` で実デプロイ前の差分確認

```powershell
az deployment group what-if `
  -g <your-rg> `
  --template-file sample/main.bicep `
  --parameters sample/main.dev.bicepparam
```

`what-if` は **ポリシー違反や RBAC 不足、命名重複など「実デプロイで初めて落ちる」系のエラー** を事前に炙り出せます。ベストプラクティス検証ではなく「動くか」の検証ですが、併用が必須です。

---

## 4. PSRule for Azure で WAF ルールチェック

[**PSRule for Azure**](https://azure.github.io/PSRule.Rules.Azure/) は Microsoft 公式の **Azure Well-Architected Framework ベースのルールセット** (数百件) を提供する PowerShell モジュールです。Bicep / ARM / Terraform の IaC を **静的解析** できます。

### 4-1. インストール

```powershell
Install-Module -Name 'Az.Accounts', 'PSRule.Rules.Azure' -Scope CurrentUser -Force
```

> Bicep の解析には Bicep CLI が必要です (`az bicep install` で入っていれば OK)。

### 4-2. 実行 (最小)

```powershell
# ワークスペースルートから実行
Invoke-PSRule `
  -Module PSRule.Rules.Azure `
  -InputPath 'sample/' `
  -Format File `
  -OutputFormat Yaml
```

### 4-3. パラメータファイル経由で解析 (推奨)

`.bicepparam` を入力にすると、実際にデプロイされるパラメータ値を使って評価されます。

```powershell
Invoke-PSRule `
  -Module PSRule.Rules.Azure `
  -InputPath 'sample/main.dev.bicepparam' `
  -Format File
```

### 4-4. よく出る指摘の例 (本ハンズオン構成の場合)

| ルール ID | 指摘 | 対応方針 |
|---|---|---|
| `Azure.Storage.SecureTransfer` | HTTPS のみを強制しているか | `supportsHttpsTrafficOnly: true` (既定で OK) |
| `Azure.Storage.Firewall` | ネットワーク制限がない | 本番では `defaultAction: 'Deny'` + 許可リスト |
| `Azure.Storage.BlobPublicAccess` | 匿名アクセスが有効 | `allowBlobPublicAccess: false` (本ハンズオンで対応済み) |
| `Azure.AppService.ManagedIdentity` | Managed Identity 未使用 | `identity.type: 'SystemAssigned'` (対応済み) |
| `Azure.AppService.MinTLS` | 最小 TLS バージョン | `minTlsVersion: '1.2'` (対応済み) |
| `Azure.AppService.AlwaysOn` | Always On 無効 | prod で `alwaysOn: true` |
| `Azure.AppService.HTTP2` | HTTP/2 未有効 | `http20Enabled: true` |
| `Azure.Resource.UseTags` | タグ未設定 | 共通 `tags` オブジェクトを全リソースに伝播 |

### 4-5. ベースラインを指定して "Azure 推奨" セットだけ適用

```powershell
Invoke-PSRule `
  -Module PSRule.Rules.Azure `
  -InputPath 'sample/' `
  -Baseline 'Azure.Default' `
  -Format File
```

ベースライン:

- `Azure.Default` — 汎用ワークロード向け (まずはこれ)
- `Azure.Preview` — プレビュー機能を含む
- `Azure.GA_YYYY_MM` — GA 済みルールのみの月次スナップショット (CI 向け)

### 4-6. CI 組み込み (GitHub Actions)

```yaml
- name: PSRule analysis
  uses: microsoft/ps-rule@v2
  with:
    modules: PSRule.Rules.Azure
    inputPath: sample/
    baseline: Azure.Default
```

PR に対して自動で WAF 準拠状況をレポートできます。

参考: [PSRule for Azure — Quickstart](https://azure.github.io/PSRule.Rules.Azure/quickstart/standalone-bicep/)

---

## 5. Copilot にベストプラクティスレビューをさせる

機械的に検出できない「**設計意図との整合性**」や「**本番化にあたって不足しているもの**」は Copilot に聞くのが早いです。

プロンプト例 (そのまま貼って実行):

````text
あなたは Azure の FTE シニアクラウドアーキテクトです。
`sample/main.bicep` と `sample/modules/*.bicep` を読み、次の観点でレビューしてください。

# 観点
1. Azure Well-Architected Framework の 5 本柱 (信頼性 / セキュリティ / コスト / 運用 / パフォーマンス)
2. Bicep ベストプラクティス (linter ルール、命名、モジュール分割、出力の妥当性)
3. 本構成 (App Service + Blob Storage + Managed Identity + RBAC) で「本番化するなら」まだ不足しているもの

# 出力
- High / Medium / Low の 3 段階で重大度を付けた指摘一覧
- 各指摘に対する **Bicep の修正例** (before / after の diff 形式)
- 「今回の学習スコープとしては対応不要だが、本番では必ず入れるべき項目」セクション

# 制約
- 現状のハンズオン方針 (App Service + Blob Storage のみ、MI + RBAC、public endpoint 可) は尊重する
- 接続文字列・アカウントキー認証への "後退" は提案しない
````

完全版は [`prompts/03-review.prompt.md`](../prompts/03-review.prompt.md) にあります。

### レビュー結果を linter / PSRule と突き合わせる

Copilot の指摘と `bicep lint` / PSRule の指摘が **重複している** 部分は「機械的に検証可能 = CI に入れるべき」、**Copilot にしか出せなかった** 指摘は「設計レビューの観点」として扱うと、チェックを二重化できます。

---

## 6. ベストプラクティス準拠チェックリスト (手動)

最後に、目視でさっと確認するためのチェックリストです。

### セキュリティ

- [ ] App Service に `identity.type: 'SystemAssigned'` が設定されている
- [ ] Storage に対する `Storage Blob Data Contributor` ロール割り当てが存在する
- [ ] Storage の `allowSharedKeyAccess` が `false`
- [ ] Storage の `allowBlobPublicAccess` が `false`
- [ ] Storage / App Service の `minimumTlsVersion` / `minTlsVersion` が `TLS1_2` (`1.2`)
- [ ] App Service の `httpsOnly: true`, `ftpsState: 'Disabled'`
- [ ] App Settings に **接続文字列・アカウントキーが含まれていない**
- [ ] `outputs` に秘匿情報が含まれていない

### 信頼性 / 運用

- [ ] Blob の soft delete / versioning が有効
- [ ] prod 環境で App Service Plan の SKU が Basic より上 (P1v3 など)
- [ ] タグが全リソースに一貫して付与されている
- [ ] モジュール間の依存が **出力参照のみ** で解決できている (`dependsOn` を多用していない)

### Bicep コード品質

- [ ] 全パラメータに `@description` が付いている
- [ ] 列挙型パラメータに `@allowed` が付いている
- [ ] API バージョンが最新の安定版 (`use-recent-api-versions` 警告なし)
- [ ] リソース名に `uniqueString(resourceGroup().id)` 等で衝突回避の仕組みがある
- [ ] `main.bicep` にロジックがなく、モジュール呼び出しのオーケストレーションに徹している

---

## 7. 参考リンク

- [Bicep linter](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)
- [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Best practices for Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) — より厳密な準拠が必要な場合は AVM モジュールへの置換も検討
- [microsoft/ps-rule GitHub Action](https://github.com/marketplace/actions/psrule)

---

👈 戻る: [Step 4: ベストプラクティス解説](04-bestpractices.md)
