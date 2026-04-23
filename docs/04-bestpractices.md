# Step 4: 設計ポイントとベストプラクティス解説

ここまでで動く IaC は出来上がりました。最後に、**「なぜこの作りにしたのか」** を Azure Well-Architected Framework (WAF) と Bicep のベストプラクティスに照らして振り返ります。

---

## 🎯 このステップのゴール

- 今回の設計の各ポイントが、どのベストプラクティスに基づくかを言語化できる
- 本番展開時に **追加で考えるべき項目** を把握できる
- Copilot にレビューさせる際の観点を身につける

---

## 1. 採用した設計ポイントと根拠

### 1-1. パスワードレス (Managed Identity + RBAC)

| Before (NG 例) | After (本ハンズオン) |
|---|---|
| App Settings に接続文字列を直書き | System-assigned Managed Identity で Azure AD 認証 |
| Key Vault から接続文字列を Secret として取得 | Key Vault も RBAC モード + Secrets User ロール |
| SQL 認証 (ユーザー名 + パスワード) | SQL は **Entra ID 認証のみ** (`azureADOnlyAuthentication: true`) |

**根拠:**
- [Azure security baseline — Identity Management](https://learn.microsoft.com/azure/security/fundamentals/identity-management-best-practices)
- WAF セキュリティ柱 `SE:05 Identity and access management`
- シークレットを「持たない」ことが最強のシークレット管理

### 1-2. 最小権限の RBAC

App Service の Managed Identity に付与するのは、必要なロールだけに絞っています。

| 対象 | ロール | 用途 |
|---|---|---|
| Key Vault | Key Vault Secrets User | アプリから Secret を読むだけ |
| Storage Account | Storage Blob Data Contributor | Blob の読み書き |
| SQL Database | (SQL 側で CREATE USER FROM EXTERNAL PROVIDER で付与) | DB レベルで `db_datareader` / `db_datawriter` 等 |

**避けたこと:**
- Contributor / Owner の付与
- サブスクリプションスコープでのロール付与 (リソース単位に絞る)

### 1-3. 観測可能性 (Observability)

- **Application Insights は Workspace-based** — Log Analytics と統合し、KQL で横断クエリ可能
- App Service から App Insights への接続は **接続文字列** を使用 (旧 Instrumentation Key 単独利用は非推奨)
- 保持期間は dev=30日 / prod はより長く

**参考:** [Migrate from classic to workspace-based Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/convert-classic-resource)

### 1-4. ネットワーク (本ハンズオンではあえて簡易化)

ハンズオンでは Public Endpoint のままにしています。本番では以下を追加検討:

| リソース | 本番で推奨する強化 |
|---|---|
| App Service | VNet 統合 + Private Endpoint 受信 |
| SQL Database | Private Endpoint / `publicNetworkAccess: 'Disabled'` |
| Key Vault | Private Endpoint / firewall で VNet 限定 |
| Storage | Private Endpoint / `publicNetworkAccess: 'Disabled'` |

→ 本番運用時は **Hub-Spoke + Private DNS Zone** を前提に再設計してください。

### 1-5. 環境分離 (dev / prod)

- **同じ Bicep + 異なる `.bicepparam`** で切り替え
- 環境差分はパラメータに集約 (SKU, retention, purgeProtection, autoPauseDelay)
- 命名規則 `${workload}-${env}-${resourceType}` で一目で識別可能

**避けたこと:**
- 環境ごとに Bicep ファイルをコピペ (ドリフトの温床)

### 1-6. モジュール分割

- リソース種別で 1 ファイル = 1 責務
- モジュール間連携は **出力値の受け渡し**、`existing` 参照の最小化
- `main.bicep` はオーケストレーション役に徹する (ロジックを書かない)

---

## 2. Bicep のベストプラクティス (コード観点)

今回の Bicep で意識したポイント:

| カテゴリ | 具体例 |
|---|---|
| パラメータ | `@description`, `@allowed`, `@minLength`, `@secure()` を必須レベルで付与 |
| 命名 | `${workloadName}-${environmentName}-${type}` + `uniqueString(resourceGroup().id)` でグローバル一意化 |
| タグ | `tags` を共通オブジェクトで定義し全モジュールに伝播 |
| API バージョン | Bicep linter が推奨する最新安定版を使用 |
| secureString | 出力に秘匿情報を含めない |
| 依存関係 | `dependsOn` は原則書かず、参照の連鎖でビルド順を解決させる |
| RBAC の冪等性 | `guid(scope, principalId, roleDefinitionId)` で `name` を生成 |

詳細は Bicep 公式ベストプラクティスを参照してください: [Best practices for Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)

---

## 3. Azure Verified Modules (AVM) — 「そもそも自作しない」という選択肢

ここまで述べてきた Bicep ベストプラクティスは、**すべてを自分で実装する場合** の話です。しかし実務では、**Microsoft 自身が "推奨の書き方" をモジュール化して公開** しています。それが **Azure Verified Modules (AVM)** です。

### 3-1. AVM が解決する "毎回問題"

自作 Bicep で陥りがちな落とし穴と、AVM のアプローチを対比します。

| 陥りやすいポイント | 自作時の状況 | AVM ではどうか |
|---|---|---|
| 診断設定 (diagnosticSettings) の付け忘れ | リソースごとに `Microsoft.Insights/diagnosticSettings` を手書き | `diagnosticSettings` パラメータを渡すだけ |
| Managed Identity の設定漏れ | `identity.type` を手書き、モジュールごとにブレる | `managedIdentities` パラメータで統一的に指定 |
| RBAC の書き方が冗長 | `guid()` + `roleDefinitionId` + `scope` を毎回書く | `roleAssignments` にロール名文字列で指定 |
| セキュリティ既定値の調査コスト | `allowBlobPublicAccess`, `minimumTlsVersion` 等を毎回調べる | **Microsoft 推奨値がデフォルト** |
| Private Endpoint の設定 | 関連リソース (NIC, DNS zone group) を手で組む | `privateEndpoints` パラメータで 1 ブロック |
| モジュールの出力仕様のバラつき | チームごとに `outputs` が違い再利用性が低い | **全 AVM モジュール共通** (resourceId, name, ...) |

### 3-2. AVM を "採用すべき" 判断基準

- ✅ 社内標準として **複数プロジェクトで IaC を書き捨てにしたくない**
- ✅ **CAF (Cloud Adoption Framework) / Landing Zone** への準拠を求められている
- ✅ **セキュリティレビュー / コンプライアンス監査** が頻繁に入る
- ✅ チームメンバーの IaC スキルにばらつきがあり、**底上げしたい**
- ✅ Bicep / Terraform 両方に対応したい (AVM は両方提供)

### 3-3. AVM を使う時に気をつけること

- ⚠️ **バージョンを必ず固定** — `:0.11.0` のようにピン留めし、定期的に更新 PR を上げる運用に
- ⚠️ **モジュールの README を読む習慣** — 公開プロパティが限定される場合がある
- ⚠️ **preview 機能は未カバー** のことがある — その時だけ部分的に自作モジュールを併用
- ⚠️ **依存グラフの把握** — モジュール同士の出力を渡すときは、各モジュールの `outputs` 定義を確認

### 3-4. AVM のスキルマップ

Bicep を書ける人が次にキャッチアップするべき AVM のトピック:

1. **モジュール一覧の把握** — `avm/res/...` (リソース単位) と `avm/ptn/...` (パターン) の違い
2. **共通インターフェース** — `location`, `tags`, `managedIdentities`, `roleAssignments`, `diagnosticSettings`, `privateEndpoints`, `lock` のパラメータ契約
3. **Bicep Public Registry の仕組み** — `br/public:` プレフィックスとキャッシュ (`~/.bicep/...`)
4. **PSRule for Azure** — AVM と組み合わせて CI で自動検証
5. **AVM Pattern Modules** — 単体リソースだけでなく「Hub-Spoke」「AKS Landing Zone」などのアーキテクチャパターン

### 3-5. 参考リンク (AVM)

- [Azure Verified Modules 公式サイト](https://azure.github.io/Azure-Verified-Modules/)
- [Bicep Public Registry — AVM](https://github.com/Azure/bicep-registry-modules/tree/main/avm)
- [AVM 共通インターフェース仕様](https://azure.github.io/Azure-Verified-Modules/specs/shared/interfaces/)
- [Terraform AVM](https://registry.terraform.io/namespaces/Azure)
- [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)

---

## 4. WAF 5 本柱でのセルフチェック

| 柱 | 本ハンズオンでの対応 | 本番追加検討 |
|---|---|---|
| 信頼性 (Reliability) | SQL Serverless の auto-pause / App Service の Always On (prod) | ゾーン冗長 / ジオレプリケーション / バックアップ戦略 |
| セキュリティ (Security) | Managed Identity, RBAC, HTTPS only, minTlsVersion 1.2 | Private Endpoint, WAF (Front Door / App Gateway), Defender for Cloud |
| コスト最適化 | dev は B1 + SQL Serverless, prod は P1v3 | 予算アラート, Reserved Instance, Autoscale |
| 運用 (Operational Excellence) | IaC 化, 環境分離, モジュール構造, App Insights, **AVM 採用で標準化** | CI/CD, blue-green, 変更管理 |
| パフォーマンス | Workspace-based AI で監視, SKU をパラメータ化 | CDN, Cache (Redis), 自動スケール |

---

## 5. Copilot にレビューさせるプロンプト

仕上げに、作成した Bicep を Copilot 自身にレビューさせます。

````text
あなたは Azure の FTE (シニアクラウドアーキテクト) です。
以下の Bicep を Azure Well-Architected Framework の 5 本柱 (信頼性, セキュリティ, コスト, 運用, パフォーマンス) と
Bicep ベストプラクティスの観点でレビューしてください。
また、Azure Verified Modules (AVM) に置き換えることでシンプル化・安全化できる箇所があれば指摘してください。

# 出力
1. 重大度 (High / Medium / Low) ごとの指摘一覧 (箇条書き)
2. 具体的な修正例 (diff または before/after)
3. AVM への移行候補 (モジュール名 + 移行のメリット)
4. 本番展開前にまだ不足している要素

# レビュー対象
<main.bicep と modules/*.bicep を添付 or ワークスペースを参照>
````

完全版は [`prompts/03-review.prompt.md`](../prompts/03-review.prompt.md) にあります。

---

## 6. 参考リンク

- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Best practices for Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Azure security baseline for App Service](https://learn.microsoft.com/security/benchmark/azure/baselines/app-service-security-baseline)
- [Azure SQL — Azure AD-only authentication](https://learn.microsoft.com/azure/azure-sql/database/authentication-azure-ad-only-authentication)
- [Use managed identities for Azure resources on a VM / App Service](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)
- [Bicep parameter files (.bicepparam)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameter-files)

---

## 🎉 おつかれさまでした

ここまで進めたあなたは、以下ができるようになっているはずです。

- 要件 → 設計 → 実装 → デプロイ → レビュー を **Copilot と一緒に一周** できる
- 生成された Bicep を **ベストプラクティスで検証** できる
- 本番運用に向けて **何を追加するか** を言語化できる

この一連のフローを、ぜひ実際のプロジェクトに持ち帰ってください。
