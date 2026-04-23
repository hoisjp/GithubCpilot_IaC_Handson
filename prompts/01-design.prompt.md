# サンプルプロンプト: 設計図 (アーキテクチャ) 生成

そのまま GitHub Copilot Chat に貼り付けて使える、Step 1 用の完全版プロンプトです。

---

あなたは Azure ソリューションアーキテクトです。
以下の要件を満たす Web アプリケーション基盤の最小構成を設計してください。

## 要件

- 小規模な社内 Web アプリ (Node.js または .NET)
- データストアは Azure SQL Database (Serverless Gen5, 1 vCore)
- シークレットは Azure Key Vault で一元管理し、App Service からは Managed Identity で参照
- アプリのログ / メトリクスは Application Insights (workspace-based) と Log Analytics に集約
- ファイルアップロード用に Blob Storage を用意 (public access 無効)
- 本番 (prod) と開発 (dev) の 2 環境をパラメータで切り替えられるようにする
- リージョンは Japan East

## 非機能要件

- パスワードレス (Managed Identity + RBAC) を優先
- 最小権限の原則に従う (Contributor / Owner は付与しない)
- Azure Well-Architected Framework の信頼性・セキュリティ・運用性を意識
- 本番展開時の強化ポイント (Private Endpoint 等) も言及するが、初期構成には含めない

## 出力形式

1. **アーキテクチャ概要** (箇条書き 5 行以内)
2. **Mermaid 記法** のアーキテクチャ図 (`flowchart LR`)
3. **リソース一覧表** — 名前 / 役割 / 採用理由 / SKU
4. **ID とシークレットのフロー** — どこが Managed Identity で、どこが Key Vault 経由か
5. **想定リスクと対策** (3 点)
6. **本番化する際の追加検討事項** (3 点)

※ この段階では Bicep コードは書かないでください。設計のみに集中します。
