# サンプルプロンプト: 設計図 (アーキテクチャ) 生成

そのまま GitHub Copilot Chat に貼り付けて使える、Step 1 用の完全版プロンプトです。

---

あなたは Azure ソリューションアーキテクトです。
以下の要件を満たす Web アプリケーション基盤の最小構成を設計してください。

## 要件

- 小規模な社内 Web アプリ (Node.js または .NET)
- ファイル保存用に Blob Storage を用意 (public access 無効)
- App Service から Blob Storage へは **Managed Identity (System Assigned) + RBAC** で接続 (パスワードレス、接続文字列・アカウントキー不使用)
- 本番 (prod) と開発 (dev) の 2 環境をパラメータで切り替えられるようにする
- リージョンは Japan East

## 非機能要件

- パスワードレス (Managed Identity + RBAC) を優先
- 最小権限の原則に従う (Contributor / Owner は付与せず、`Storage Blob Data Contributor` のみ)
- Azure Well-Architected Framework の信頼性・セキュリティ・運用性を意識
- 本番展開時の強化ポイント (Private Endpoint、Application Insights 等) も言及するが、初期構成には含めない

## 出力形式

1. **アーキテクチャ概要** (箇条書き 5 行以内)
2. **Mermaid 記法** のアーキテクチャ図 (`flowchart LR`)
3. **リソース一覧表** — 名前 / 役割 / 採用理由 / SKU
4. **ID とアクセス制御のフロー** — どこが Managed Identity で、どの RBAC ロールを付与するか
5. **想定リスクと対策** (3 点)
6. **本番化する際の追加検討事項** (3 点)

## 成果物

上記 1〜6 を 1 つの Markdown としてまとめ、`docs/architecture.md` に保存してください。
(ファイルが存在しない場合は新規作成、存在する場合は上書きしてください)

※ この段階では Bicep コードは書かないでください。設計のみに集中します。
