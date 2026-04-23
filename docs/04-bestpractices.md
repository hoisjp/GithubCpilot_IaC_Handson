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
| App Settings に Storage 接続文字列を直書き | System-assigned Managed Identity で Entra ID 認証 |
| Storage アカウントキーをコード/設定に保存 | `allowSharedKeyAccess: false` で **キー認証そのものを禁止** |
| アプリ側で接続文字列をパース | SDK が `DefaultAzureCredential` で MI トークンを自動取得 |

**根拠:**
- [Azure security baseline — Identity Management](https://learn.microsoft.com/azure/security/fundamentals/identity-management-best-practices)
- WAF セキュリティ柱 `SE:05 Identity and access management`
- シークレットを「持たない」ことが最強のシークレット管理

### 1-2. 最小権限の RBAC

App Service の Managed Identity に付与するのは、必要なロールだけに絞っています。

| 対象 | ロール | 用途 |
|---|---|---|
| Storage Account | `Storage Blob Data Contributor` | Blob の読み書き |

**避けたこと:**
- Contributor / Owner の付与
- サブスクリプションスコープでのロール付与 (Storage Account 単位に絞る)

### 1-3. ネットワーク (本ハンズオンではあえて簡易化)

ハンズオンでは Public Endpoint のままにしています。本番では以下を追加検討:

| リソース | 本番で推奨する強化 |
|---|---|
| App Service | VNet 統合 + Private Endpoint 受信 |
| Storage | Private Endpoint / `publicNetworkAccess: 'Disabled'` |

→ 本番運用時は **Hub-Spoke + Private DNS Zone** を前提に再設計してください。

### 1-4. 環境分離 (dev / prod)

- **同じ Bicep + 異なる `.bicepparam`** で切り替え
- 環境差分はパラメータに集約 (App Service Plan SKU など)
- 命名規則 `${workload}-${env}-${resourceType}` で一目で識別可能

**避けたこと:**
- 環境ごとに Bicep ファイルをコピペ (ドリフトの温床)

### 1-5. モジュール分割

- リソース種別で 1 ファイル = 1 責務 (`storage.bicep`, `appservice.bicep`)
- モジュール間連携は **出力値の受け渡し**、`existing` 参照は RBAC スコープのみ
- `main.bicep` はオーケストレーション役に徹する (ロジックを書かない)

---

## 2. Bicep のベストプラクティス (コード観点)

今回の Bicep で意識したポイント:

| カテゴリ | 具体例 |
|---|---|
| パラメータ | `@description`, `@allowed`, `@minLength` を必須レベルで付与 |
| 命名 | `${workloadName}-${environmentName}-${type}` + `uniqueString(resourceGroup().id)` でグローバル一意化 |
| タグ | `tags` を共通オブジェクトで定義し全モジュールに伝播 |
| API バージョン | Bicep linter が推奨する最新安定版を使用 |
| 出力 | 秘匿情報を含めない (接続文字列・キーは出力しない) |
| 依存関係 | `dependsOn` は原則書かず、参照の連鎖でビルド順を解決させる |
| RBAC の冪等性 | `guid(scope.id, principalId, roleDefinitionId)` で `name` を生成 |

詳細は Bicep 公式ベストプラクティスを参照してください: [Best practices for Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)

---

## 3. WAF 5 本柱でのセルフチェック

| 柱 | 本ハンズオンでの対応 | 本番追加検討 |
|---|---|---|
| 信頼性 (Reliability) | App Service の Always On (prod), Blob soft delete + versioning | ゾーン冗長 / ジオレプリケーション (GZRS) / バックアップ戦略 |
| セキュリティ (Security) | Managed Identity, RBAC, HTTPS only, minTlsVersion 1.2, shared key 無効 | Private Endpoint, WAF (Front Door / App Gateway), Defender for Cloud |
| コスト最適化 | dev は B1, prod は P1v3, Storage は Standard_LRS | 予算アラート, Reserved Instance, Autoscale |
| 運用 (Operational Excellence) | IaC 化, 環境分離, モジュール構造 | CI/CD, blue-green, 変更管理, 監視 (App Insights 追加) |
| パフォーマンス | SKU をパラメータ化, HTTP/2 有効化 | CDN, Cache (Redis), 自動スケール |

> 💡 監視は今回スコープ外ですが、本番では **Application Insights + Log Analytics Workspace** を追加し、`APPLICATIONINSIGHTS_CONNECTION_STRING` を App Settings に渡すのが定石です。

---

## 4. Copilot にレビューさせるプロンプト

仕上げに、作成した Bicep を Copilot 自身にレビューさせます。

````text
あなたは Azure の FTE (シニアクラウドアーキテクト) です。
以下の Bicep を Azure Well-Architected Framework の 5 本柱 (信頼性, セキュリティ, コスト, 運用, パフォーマンス) と
Bicep ベストプラクティスの観点でレビューしてください。

# 出力
1. 重大度 (High / Medium / Low) ごとの指摘一覧 (箇条書き)
2. 具体的な修正例 (diff または before/after)
3. 本番展開前にまだ不足している要素

# レビュー対象
<sample/main.bicep と sample/modules/*.bicep を添付 or ワークスペースを参照>
````

完全版は [`prompts/03-review.prompt.md`](../prompts/03-review.prompt.md) にあります。

---

## 5. 参考リンク

- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Best practices for Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Azure security baseline for App Service](https://learn.microsoft.com/security/benchmark/azure/baselines/app-service-security-baseline)
- [Authorize access to blobs using Microsoft Entra ID](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
- [Use managed identities for Azure resources on App Service](https://learn.microsoft.com/azure/app-service/overview-managed-identity)
- [Bicep parameter files (.bicepparam)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameter-files)

---

## 🎉 おつかれさまでした

ここまで進めたあなたは、以下ができるようになっているはずです。

- 要件 → 設計 → 実装 → デプロイ → レビュー を **Copilot と一緒に一周** できる
- 生成された Bicep を **ベストプラクティスで検証** できる
- 本番運用に向けて **何を追加するか** を言語化できる

この一連のフローを、ぜひ実際のプロジェクトに持ち帰ってください。

最後に、デプロイした App Service + Storage が **実際にパスワードレスで連携するか** を Step 5 で動作確認します。

---

👉 次へ: [Step 5: App Service に画像ビューアーをデプロイして動作確認する](05-WebAppDeploy.md)
