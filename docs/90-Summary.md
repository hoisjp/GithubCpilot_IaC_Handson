# 90. ハンズオン総まとめ & 設計根拠

このドキュメントは、本ハンズオン (Step 1〜5 + Appendix) 全体を振り返り、**「何を学んだか」** と **「なぜそう作ったか (設計根拠)」** を 1 枚に凝縮した総括ページです。研修後の自社持ち帰り資料や、チーム内勉強会の読み物としてそのまま使えます。

---

## ✨ このハンズオンで体験した "すごさ" の正体

従来、Azure 上に Web アプリ基盤を立てるには、**要件整理 → 設計書作成 → IaC コード記述 → レビュー → デプロイ** と、それぞれ専門スキルを持つ人が分担して **数日〜数週間** かけるのが当たり前でした。

本ハンズオンでは、この一連の工程を **GitHub Copilot を対話相手にした一人の作業として、数時間で一気通貫** で通しました。しかも、出来上がったのは「動くだけの雑なコード」ではなく、**Managed Identity + RBAC によるパスワードレス・最小権限を満たす、本番設計に耐える Bicep** です。

### 何が画期的だったか

| 従来のやり方 | Copilot を使った今回 |
|---|---|
| 要件ヒアリング → Word/Excel で要件定義書 | **自然言語の要件をそのままプロンプトに** 構造化して投入 |
| アーキテクトが手で PowerPoint / draw.io で作図 | 要件プロンプトから **Mermaid 図が即座に生成** → `.drawio.svg` に清書まで自動 |
| IaC 技術者が Bicep リファレンスを引きながら数日かけて実装 | 設計図を貼るだけで **Bicep 一式 (main + modules + bicepparam) が一気に生成** |
| レビュー会議を開いてベストプラクティス照合 | Copilot に **「WAF 5 本柱でレビューして」** と頼むだけで指摘が出る |
| デプロイは別の運用担当へ引き継ぎ | **Agent モードから `az deployment` をそのまま実行** → 結果を要約してもらえる |
| エラーが出たら調査に半日 | エラーログを貼るだけで **原因候補と修正案が即提示** |

### この体験から持ち帰る本質

- **設計 → 実装 → デプロイの "間" にあった待ち時間・翻訳ロス・属人性** が一気に縮まる
- 人間は **「何を作るか」「なぜそうするか」を決める役割** に集中できる (コードの手書き作業から解放される)
- それでいて **成果物の品質は下がらない** — Copilot に「ベストプラクティスに従って」と指示すれば、人間が書くより漏れが少ないことすらある
- **"一人で設計から運用まで触れる"** ことで、分業で失われていた **全体感** が個人に戻ってくる

> 🎯 **Copilot は "コードを書く AI" ではなく "設計から運用まで並走してくれる相棒"**。
> この体験をチームに持ち帰れば、要件〜デプロイのリードタイムは劇的に短くなり、しかもセキュリティ原則を落とさずに済みます。

---

## 🗺️ 全体フロー (1 行サマリ)

> **要件 → 設計図 (Mermaid/drawio) → Bicep 生成 → what-if → デプロイ → アプリで動作確認 → ベストプラクティスで振り返り**
> を **GitHub Copilot (Chat / Agent モード) と対話しながら** 一気通貫で体験する。

| Step | やったこと | 主な成果物 | Copilot が担った役割 |
|---|---|---|---|
| Step 1 | 要件を構造化プロンプトに変換し、アーキテクチャ図を生成 | `docs/architecture.md`, `docs/architecture.drawio.svg` | アーキテクト |
| Step 2 | 設計図から Bicep 一式を生成 → `az bicep build` / `what-if` で検証 | `demoBicep/main.bicep`, `modules/*.bicep`, `*.bicepparam` | IaC エンジニア |
| Step 3 | Copilot Agent モードで対話的に Azure へデプロイ | Azure 上の RG `rg-iac-handson-dev` | リリース担当 |
| Step 4 | WAF 5 本柱 + Bicep ベストプラクティスで設計を振り返る | 設計根拠の言語化 | シニアレビュアー |
| Step 5 | 画像ビューアー Web アプリをデプロイし、**パスワードレス連携を実動作で検証** | `sample-web/` + App Service 上で稼働するアプリ | アプリ開発者 + トラブルシューター |
| Appendix | Bicep linter / PSRule / Copilot レビューで品質をセルフチェック | チェックリスト化された検証手順 | 品質保証 |

→ **これだけの役割を、一人 × Copilot の対話だけで回せる** のが本ハンズオンの核心です。

---

## ⭐ 重要ポイント (これだけは覚えて帰る)

### 1. Copilot を「設計パートナー」として使う

- いきなり Bicep を書かせない。**先に Mermaid 図を作って人間が合意** → その図を貼って Bicep 生成、の 2 段構え
- プロンプトには **役割 / コンテキスト / 要件 / 出力形式** の 4 要素を必ず入れる
- Agent モードを使うとファイル作成・CLI 実行まで Copilot が自律的に行う

### 2. パスワードレス (Managed Identity + RBAC) を徹底する

- App Service → Blob Storage は **System Assigned MI + `Storage Blob Data Contributor`** のみで接続
- `allowSharedKeyAccess: false` で **キー認証そのものを禁止** (=「持たない」ことが最強のシークレット管理)
- アプリ側は `DefaultAzureCredential` + **User Delegation SAS** で画像 URL を発行 (キー不要)

### 3. 環境差分はパラメータに集約する

- 同一 Bicep + `main.dev.bicepparam` / `main.prod.bicepparam` で dev/prod 切替
- SKU (`B1` / `P1v3`) などの差分だけをパラメータに出し、本体はコピペしない

### 4. 検証は多層で行う

| レイヤー | ツール | 検出対象 |
|---|---|---|
| 構文 | `az bicep build` | 型エラー・構文エラー |
| 静的 (Bicep) | Bicep linter | API バージョン / セキュア既定値 / 命名 |
| 静的 (Azure) | PSRule for Azure | WAF ルール (数百件) |
| 動的 (差分) | `az deployment group what-if` | 実デプロイ前の差分・失敗要因 |
| 観点 | Copilot レビュー | 設計意図 / 本番化で不足しているもの |
| 実動作 | Step 5 の画像ビューアー | パスワードレス連携が **本当に動くか** |

### 5. デプロイ時のハマりどころ (Step 5 で実際に踏んだ落とし穴)

| 症状 | 根本原因 | 解決策 |
|---|---|---|
| `Cannot find module 'express'` | Oryx のリモートビルドが走っていない | `SCM_DO_BUILD_DURING_DEPLOYMENT=true` + **`ENABLE_ORYX_BUILD=true`** を両方設定 |
| Oryx マニフェストが生成されない | `az webapp deploy --type zip` (OneDeploy) はリモートビルドをスキップ | **`az webapp deployment source config-zip`** (Kudu ZipDeploy) を使う |
| ビルド設定を入れても動かない | `WEBSITE_RUN_FROM_PACKAGE=1` が zip を読み取り専用マウントし Oryx を上書き | この設定を **削除** してから再デプロイ |
| 何度デプロイしても同じエラー | `Compress-Archive` が `package-lock.json` 欠如で **Exit 1 で無言失敗**、古い zip が使われ続ける | zip 作成前に `npm install` + zip 中身を `Expand-Archive` で必ず検証 |

> 💡 **教訓**: 「同じエラーが繰り返される」ときは zip・設定・デプロイ方式の **3 点セットを疑う**。1 つ直しても他の 2 つで上書きされる。

---

## 🧠 設計根拠 (なぜこう作ったか)

### A. なぜ「App Service + Blob Storage」の最小 2 リソースにしたか

| 判断 | 理由 |
|---|---|
| SQL / Key Vault を **入れない** | 依存が増えると Copilot との対話サイクルが長くなり、学習の本筋 (IaC × AI) がボケる |
| VNet / Private Endpoint を **入れない** | パスワードレス化の本質 (MI + RBAC) の学習を優先。NW 強化は「本番時の追加項目」として Step 4 で別途明示 |
| Front Door / WAF を **入れない** | 同上。最小構成で一周することを最優先 |
| ただし MI + RBAC は **妥協しない** | これを落とすと「結局キー認証じゃん」になり、本ハンズオンの価値が消える |

→ **「学習スコープは絞るが、セキュリティ原則は絞らない」** という線引き。

### B. なぜ System Assigned MI にしたか (User Assigned ではなく)

| 観点 | System Assigned (採用) | User Assigned |
|---|---|---|
| ライフサイクル | App Service と一体で自動管理 | 独立管理 (別リソースとして削除漏れリスク) |
| 学習コスト | 低い (`identity.type: 'SystemAssigned'` の 1 行) | やや高い (ID リソース + 紐付け) |
| 複数アプリ間共有 | 不可 | 可 |

**判断**: 学習ハンズオンでは **一体管理が直感的** な System Assigned を採用。本番で複数アプリが同じ ID を共有するなら User Assigned に切替、と Step 4 で言及。

### C. なぜ `allowSharedKeyAccess: false` を既定にしたか

- Azure Storage では RBAC ロールがあっても **キー認証経路が開いていると "抜け道"** になる
- コード側で `DefaultAzureCredential` を使っていても、別ツール (Storage Explorer, azcopy の古いオプション等) でキーを使われたら台無し
- **`false` にすることで「キーでは絶対に触れない」状態を IaC レベルで保証** できる
- 副作用: Portal からの GUI アップロードに **ユーザー自身にも RBAC が必要** → これを Step 5 の手順 1 で明示

### D. なぜ User Delegation SAS を使ったか (Blob URL をそのまま返さない)

| 選択肢 | 採否と理由 |
|---|---|
| Blob の直 URL を返す | ❌ 非公開コンテナなのでブラウザから見えない |
| `allowBlobPublicAccess: true` + 匿名公開 | ❌ セキュリティ原則に反する |
| アカウントキー SAS | ❌ `allowSharedKeyAccess: false` と矛盾する (そもそも発行できない) |
| **User Delegation SAS** (採用) | ✅ Entra ID トークンから発行される SAS。キー不要。TTL 短く (1時間) できる |

→ **「`allowSharedKeyAccess: false` を貫くための必然の選択」** が User Delegation SAS。

### E. なぜ `what-if` を本デプロイ前に必ず挟むか

- `az bicep build` は **構文** しか見ない (名前重複・RBAC 不足・ポリシー違反は検知できない)
- `what-if` は **実環境に対しての差分計算** を行うため、「デプロイして初めて落ちる系」のエラーを事前に炙り出せる
- `+ Create` / `~ Modify` / `- Delete` の記号で、**意図しない破壊変更** を目視確認できる

→ Step 2 と Step 3 の両方で `what-if` を必ず通すのはこのため。

### F. なぜモジュール分割を「リソース種別 1 ファイル」にしたか

- `main.bicep` にロジックを書くと再利用できない → **`main` はオーケストレーションに徹する**
- `storage.bicep`, `appservice.bicep`, `roleAssignment.bicep` のように分けると、**1 モジュールの差し替え** が効く (例: Storage を Cosmos DB に置換)
- モジュール間の連携は **出力値の受け渡し** で行い、`dependsOn` は極力書かない (ビルド順はグラフから自動解決される)

### G. なぜ `docs/04-bestpractices.md` を Step 5 の **前** に置いたか

- 先に「なぜこの作りか」を理解してから動作確認すると、Step 5 で観察するもの (MI, SAS, キーなし) の意味が腹落ちする
- 逆順にすると「とりあえず動いた」で終わり、**根拠の言語化** が抜ける

---

## 📌 本ハンズオンを "現場で再現" するためのチェックリスト

- [ ] 要件を 4 要素 (役割 / コンテキスト / 要件 / 出力形式) でプロンプト化する習慣を持つ
- [ ] Bicep を書く前に必ず **Mermaid で合意** するフェーズを挟む
- [ ] `az bicep build` → `what-if` → 本デプロイ の 3 段階を CI でも同じ順序にする
- [ ] すべての Storage / DB 接続を **Managed Identity + RBAC** で設計する (接続文字列を書いたら負け)
- [ ] `allowSharedKeyAccess: false` を **既定** にし、例外時のみ議論する
- [ ] 環境差分は `*.bicepparam` に集約し、Bicep 本体はコピペしない
- [ ] PSRule for Azure を **PR チェック** に組み込み、WAF 準拠を自動化する
- [ ] デプロイ後は **実際のアプリ動作** まで確認する (IaC が通っても、アプリは動かないことがある)

---

## 🔗 本編リンク

- [README](../README.md)
- [Step 1: 設計図を作る](01-design.md)
- [Step 2: Bicep を生成する](02-bicep.md)
- [Step 3: 対話的にデプロイ](03-deploy.md)
- [Step 4: ベストプラクティス解説](04-bestpractices.md)
- [Step 5: Web アプリで動作確認](05-WebAppDeploy.md)
- [Appendix: Bicep 品質セルフチェック](99-appendix.md)

---

👈 戻る: [Step 5: App Service に画像ビューアーをデプロイして動作確認する](05-WebAppDeploy.md)
