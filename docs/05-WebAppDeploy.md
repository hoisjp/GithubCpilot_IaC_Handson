# Step 5: App Service に画像ビューアーをデプロイして動作確認する

Step 3 でデプロイ済みの **App Service + Blob Storage (コンテナ `app-data`)** を使い、「Blob に保存された画像一覧を表示するだけ」の最小 Web アプリを作成して App Service にデプロイします。App → Storage のアクセスは **Managed Identity + RBAC** (パスワードレス) を維持。

---

## 🎯 このステップのゴール

- 自分自身に対して Storage Account への `Storage Blob Data Contributor` ロールを付与し、画像を手動アップロードできる状態を作る
- `sample-web/` フォルダに Node.js (Express) の画像一覧アプリを Copilot と一緒に作成する
- App Service にデプロイし、ブラウザでアップロード済み画像が一覧表示されることを確認する

---

## 前提

- Step 3 までが完了し、以下が作成済みであること
  - App Service (例: `app-handson-dev-abc123`)
  - Storage Account (例: `sthandsondevabc123`) + Blob コンテナ `app-data`
  - App Service の System Assigned MI に `Storage Blob Data Contributor` ロール付与済み
- ローカルに **Node.js 20 LTS** と **Azure CLI** がインストール済み
- App Service の `linuxFxVersion` が `NODE|20-lts` (または同等) になっていること

> 確認: `az webapp show -g rg-iac-handson-dev -n <appName> --query siteConfig.linuxFxVersion -o tsv`

---

## 手順 1. 自分自身に `Storage Blob Data Contributor` を付与 (Azure Portal)

Portal からアップロードするには、**自分 (開発者) の Entra ID アカウント**にも同ロールが必要です (アプリの MI とは別)。ここでは Azure Portal の GUI から付与します。

### 1-1. Storage Account を開く

1. [Azure Portal](https://portal.azure.com/) にサインイン
2. 上部検索バーで作成済みの Storage Account 名 (例: `sthandsondevabc123`) を入力して開く

### 1-2. アクセス制御 (IAM) からロールを追加

1. 左メニュー **「アクセス制御 (IAM)」** (英語: **Access control (IAM)**) をクリック
2. 上部の **「+ 追加」** → **「ロールの割り当ての追加」** を選択
3. **「ロール」** タブで検索ボックスに `Storage Blob Data Contributor` と入力 → 一覧から選択 → **「次へ」**
4. **「メンバー」** タブで:
   - アクセスの割り当て先: **「ユーザー、グループ、またはサービス プリンシパル」**
   - **「+ メンバーの選択」** をクリック → 自分のユーザー名 (サインイン中のアカウント) を検索して選択 → **「選択」**
5. **「確認と割り当て」** タブで内容を確認 → **「確認と割り当て」** ボタンをクリック
6. 画面右上に **「ロールの割り当てを追加しました」** の通知が出れば完了

### 1-3. 割り当ての確認

1. 同じ **「アクセス制御 (IAM)」** 画面の **「ロールの割り当て」** タブを開く
2. スコープを **「このリソース」** に絞り、自分のユーザー名と `Storage Blob Data Contributor` の行があることを確認

> 💡 反映まで最大 5 分ほどかかることがあります。直後にアップロードを試して `AuthorizationPermissionMismatch` が出たら少し待って再試行してください。
>
> CLI で同じ操作をしたい場合は `az role assignment create --assignee <your-upn> --role "Storage Blob Data Contributor" --scope <storage-account-id>` でも可能です (自動化向け)。

---

## 手順 2. 画像を `app-data` コンテナへアップロード

### 2-1. Azure Portal から (GUI)

1. Portal で Storage Account (`sthandsondevabc123`) を開く
2. 左メニュー **「データストレージ」→「コンテナー」** → `app-data` をクリック
3. 上部 **「アップロード」** → 任意の画像 (`.jpg` / `.png` など 3〜5 枚) を選択 → **「アップロード」**
4. 認証方法の選択が出たら **「Azure AD ユーザーアカウント」** を選ぶ (アクセスキーではなく)

### 2-2. CLI から (代替)

```powershell
az storage blob upload-batch `
  --account-name $saName `
  --destination app-data `
  --source ./images `
  --auth-mode login
```

> 💡 `--auth-mode login` を付けると共有キーではなく Entra ID 認証が使われます (前手順のロール付与が効く)。

---

## 手順 3. `sample-web/` に画像一覧アプリを生成

Copilot Chat (Agent モード) を開き、以下のプロンプトを実行します。

````text
リポジトリ直下に `sample-web/` フォルダを新規作成し、以下の仕様で
Node.js (Express) の最小アプリを生成してください。

# 仕様
- Storage Account 名と コンテナ名は環境変数で受け取る
  - `STORAGE_ACCOUNT_NAME`
  - `BLOB_CONTAINER_NAME` (デフォルト "app-data")
- 認証は `@azure/identity` の `DefaultAzureCredential` を使用 (Managed Identity 前提、ローカルでは `az login` 資格情報を流用)
- `GET /` で `app-data` コンテナ内の Blob 一覧を取得し、画像を `<img>` で一覧表示する HTML を返す
- Blob URL は SAS ではなく、User Delegation SAS を 1 時間有効で発行して埋め込む (キー認証は使わない)
- `npm start` で起動 (ポートは `process.env.PORT` または 3000)
- `package.json` / `server.js` / `README.md` を生成
- 接続文字列・アカウントキーは絶対に使わない
````

> 生成後、`sample-web/` 配下に `package.json`, `server.js`, `README.md` が出来ていることを確認。Copilot が書いたコードを **`#codebase sample-web/ の実装を解説して`** で読み解いてから次に進むのがおすすめ。

### 3-1. 依存関係をインストール

```powershell
cd sample-web
npm install
```

---

## 手順 4. ローカルで動作確認 (任意)

`DefaultAzureCredential` は `az login` 済みの資格情報を拾ってくれるため、ローカルでも MI と同じコードで動作します。

```powershell
$env:STORAGE_ACCOUNT_NAME = "<storageName>"
$env:BLOB_CONTAINER_NAME  = "app-data"
npm start
```

ブラウザで http://localhost:3000 を開き、アップロードした画像が一覧表示されれば OK。

> ⚠️ `AuthorizationPermissionMismatch` が出る場合は手順 1 のロール付与が反映されていない (数分待って再試行) か、ログインが別テナントの可能性。`az account show` を確認。

---

## 手順 5. App Service にデプロイ

> 💡 以降のコマンドで使う変数を先にまとめて定義しておきます (新しい PowerShell セッションで始めた場合は必ず実行)。
>
> ```powershell
> $rg     = "rg-iac-handson-dev"   # リソースグループ名
> $saName = "<storageName>"        # ストレージアカウント名 (例: sthandsondevabc123)
> $app    = "<appName>"            # App Service 名 (例: app-handson-dev-abc123)
> ```

### 5-1. zip を作成

`node_modules` を含めずに zip 化 (App Service 側で `npm install` させる)。

```powershell
# sample-web 直下で実行
# 先に npm install を済ませて package-lock.json を生成しておく (未生成だと Compress-Archive が失敗する)
if (-not (Test-Path package-lock.json)) { npm install }

Remove-Item ../sample-web.zip -ErrorAction SilentlyContinue
Compress-Archive -Path package.json, server.js, package-lock.json -DestinationPath ../sample-web.zip

# zip の中身確認 (3 ファイルが直下に並んでいること)
Expand-Archive -Path ../sample-web.zip -DestinationPath ../zip-check -Force
Get-ChildItem ../zip-check | Select-Object Name
Remove-Item ../zip-check -Recurse -Force
```

> ⚠️ `package-lock.json` が無いと `Compress-Archive` がエラーで止まり、zip が更新されません (古い zip のままデプロイしてしまう原因)。先に `npm install` を実行してロックファイルを作ってから zip 化してください。
>
> 💡 アプリ構成が増えた場合は `Compress-Archive -Path *` に変更 (ただし `node_modules` / `.env` は除外)。

### 5-2. App Service に環境変数とビルドフラグを設定

```powershell
az webapp config appsettings set `
  -g $rg -n $app `
  --settings `
    STORAGE_ACCOUNT_NAME=$saName `
    BLOB_CONTAINER_NAME=app-data `
    SCM_DO_BUILD_DURING_DEPLOYMENT=true `
    ENABLE_ORYX_BUILD=true `
    WEBSITE_NODE_DEFAULT_VERSION=~20
```

> ⚠️ **`SCM_DO_BUILD_DURING_DEPLOYMENT=true` と `ENABLE_ORYX_BUILD=true` はセットで必須**。どちらか欠けると App Service 側で `npm install` が走らず、起動時に `Error: Cannot find module 'express'` で落ちます。

#### `WEBSITE_RUN_FROM_PACKAGE` を削除する

過去のデプロイや Bicep で `WEBSITE_RUN_FROM_PACKAGE=1` が設定されていると、App Service は zip を読み取り専用でマウントするため **Oryx ビルドが走らず** `npm install` もスキップされます。今回は Oryx でビルドさせたいので、この設定は削除します。

```powershell
# 現在の値を確認 (1 になっていたら削除が必要)
az webapp config appsettings list -g $rg -n $app `
  --query "[?name=='WEBSITE_RUN_FROM_PACKAGE'].{name:name,value:value}" -o table

# 削除
az webapp config appsettings delete -g $rg -n $app `
  --setting-names WEBSITE_RUN_FROM_PACKAGE

# App Service を再起動して反映
az webapp restart -g $rg -n $app
```

> 💡 `WEBSITE_RUN_FROM_PACKAGE=1` は「事前にビルド済みの成果物を zip で配る」運用向け。本手順のようにサーバー側で `npm install` させたい場合は無効化しておく必要があります。

```powershell
az webapp deployment source config-zip `
  -g $rg -n $app `
  --src ../sample-web.zip
```

> ⚠️ **`az webapp deploy --type zip` (OneDeploy) ではなく、`az webapp deployment source config-zip` (Kudu ZipDeploy) を使う**のがポイント。前者は仕様上リモートビルドをスキップするため、`npm install` が走らず `Error: Cannot find module 'express'` で落ちます。後者は手順 5-2 で設定した `SCM_DO_BUILD_DURING_DEPLOYMENT=true` + `ENABLE_ORYX_BUILD=true` を honor して Oryx ビルドを走らせます。

デプロイ完了まで 1〜3 分。Portal のリソースグループ → 対象 App Service → **デプロイセンター** → **ログ** で進捗を確認できます。

**想定される応答:**

- ✅ **正常時 (デプロイ成功)** — CLI が zip をアップロードし、Kudu (SCM) 側で `npm install` → 成功ステータスで終了。最後に JSON が表示されれば OK。

   ```text
   Initiating deployment
   Deploying from local source "../sample-web.zip" ...
   [##################################################]  100%
   Polling SCM for build/deploy status: InProgress (elapsed time: 30s)
   Polling SCM for build/deploy status: InProgress (elapsed time: 60s)
   Polling SCM for build/deploy status: Success (elapsed time: 90s)
   Deployment has completed successfully
   You can visit your app at: http://app-handson-dev-abc123.azurewebsites.net
   ```

   ```json
   {
     "active": true,
     "complete": true,
     "deployer": "OneDeploy",
     "id": "xxxxxxxxxxxxxxxxxxxx",
     "provisioningState": "Succeeded",
     "status": 4,
     "status_text": "",
     "message": "Created via a push deployment"
   }
   ```

   **判断基準:**
   - 標準出力に `Deployment has completed successfully` が出ている
   - JSON の `"complete": true` かつ `"provisioningState": "Succeeded"` (または `"status": 4`)
   - 終了コード `0` (`$LASTEXITCODE` で確認)

- ⚠️ **ビルド成功だが警告あり** — `npm install` の警告 (非推奨パッケージなど) は表示されるが、最終的に `Success` で終われば問題なし。

   ```text
   npm warn deprecated xxxxx@1.0.0: This package is deprecated
   ...
   Polling SCM for build/deploy status: Success
   Deployment has completed successfully
   ```

- ❌ **デプロイ失敗** — `provisioningState` が `Failed` になる、または `Polling SCM for build/deploy status: Failed` が出る。Kudu のビルドログを確認:

   ```powershell
   az webapp log deployment show -g $rg -n $app
   ```

   よくある原因: `package.json` の `start` スクリプト不正、Node バージョン不一致、依存パッケージのインストールエラー。**エラーログを Copilot Chat に貼れば原因と修正案を提示してくれます。**

   ```text
   Polling SCM for build/deploy status: Failed (elapsed time: 120s)
   Deployment failed. response code = 500. Check logs for more details.
   ```

> 💡 Portal の **デプロイセンター → ログ** タブからも同じログが GUI で見えます (タイムスタンプ付き)。

### 5-4. ブラウザで確認

```powershell
az webapp show -g $rg -n $app --query defaultHostName -o tsv
```

出力された URL (例: `https://app-handson-dev-abc123.azurewebsites.net`) をブラウザで開き、アップロードした画像が一覧表示されれば完成。

---

## 手順 6. ログで挙動確認 (トラブル時)

```powershell
az webapp log tail -g $rg -n $app
```

よくあるエラー:

| 症状 | 原因 | 対処 |
| ---- | ---- | ---- |
| `Error: Cannot find module 'express'` (起動直後にクラッシュ) | App Service 上で `npm install` が走っていない (Oryx ビルド未実行)。ログに `Could not find build manifest file at '/home/site/wwwroot/oryx-manifest.toml'` が出ていればこれ。 | ① `WEBSITE_RUN_FROM_PACKAGE` が設定されていたら削除 (手順 5-2 参照) ② `az webapp deploy --type zip` ではなく `az webapp deployment source config-zip` を使う ③ app settings に `SCM_DO_BUILD_DURING_DEPLOYMENT=true` と `ENABLE_ORYX_BUILD=true` の両方が入っているか確認 |
| `ManagedIdentityCredential authentication failed` | App Service の System Assigned MI が無効 | `az webapp identity show -g $rg -n $app` で確認。空なら Bicep に `identity.type: 'SystemAssigned'` を追加し再デプロイ |
| `AuthorizationPermissionMismatch` | MI に `Storage Blob Data Contributor` が未付与 | Step 2 の `roleAssignment.bicep` が適用されているか確認 |
| `Application Error` / 502 | `npm start` 失敗 or ポート未バインド | `process.env.PORT` を使っているか確認。`az webapp log tail` でスタックトレースを貼って Copilot に修正依頼 |
| 画像が表示されない (一覧は出る) | SAS 生成失敗・CORS・Content-Type 未設定 | ログを Copilot に貼って原因調査依頼 |

> 💡 どの症状もエラーログをそのまま Copilot Chat に貼るのが最速です。

---

## 片付け

App Service / Storage ごと削除する場合は Step 3 と同じコマンド:

```powershell
az group delete -n rg-iac-handson-dev --yes --no-wait
```

自分に付与した `Storage Blob Data Contributor` ロールだけ外したい場合:

```powershell
az role assignment delete `
  --assignee $myId `
  --role "Storage Blob Data Contributor" `
  --scope $saId
```

---

## まとめ

- 自分 (User) とアプリ (MI) の **両方に** RBAC を付与することで、パスワードレスで Blob を読み書きできる
- アプリ側は `DefaultAzureCredential` + User Delegation SAS の組み合わせでキー不要の画像表示を実現
- `sample-web/` の生成・修正・デプロイトラブル対応はすべて Copilot Chat に丸投げ可能

---

## 🎉 おつかれさまでした！

これでハンズオンは全て完了です。ここまでやり切ったあなたは、

- **要件 → 設計 → Bicep 生成 → デプロイ → アプリ動作確認** までを Copilot と一緒に一周できた
- **Managed Identity + RBAC によるパスワードレス連携** を IaC とアプリの両面で実装できた
- デプロイトラブル (Oryx / `WEBSITE_RUN_FROM_PACKAGE` / zip 構造など) を **ログから切り分けて解決** できた

という、現場でそのまま使える経験を一式持ち帰れる状態になっています。

ぜひ自分の業務プロジェクトでも、**Copilot を設計パートナーとして巻き込みながら** IaC とアプリを育てていってください。お疲れさまでした!  ☕

最後に、ここまでの学びと **「なぜこう作ったか」の設計根拠** を 1 枚にまとめた総まとめページで振り返りましょう。

---

👉 次へ: [総まとめ & 設計根拠](90-Summary.md)
