# Step 3: GitHub Copilot と対話的に Azure へデプロイする

完成した Bicep を、**GitHub Copilot (Agent モード)** を使って対話的にデプロイします。

---

## 🎯 このステップのゴール

- `az deployment` / `what-if` を Copilot 経由で実行できる
- エラーが出た時に **Copilot と一緒に原因特定** できる
- デプロイ後の検証 (Managed Identity と RBAC の確認) まで自動化の勘所を掴む

---

## 1. 準備

### 1-1. Copilot を Agent モードに切り替える

VS Code の Copilot Chat パネルで、モードを **Agent** に変更します。Agent モードでは、ツール (ファイル編集・ターミナル実行・Azure MCP) を Copilot が自律的に呼び出せます。

### 1-2. Azure CLI でログイン

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show -o table
```

### 1-3. リソースグループ

Step 2 の手順 5 で `rg-iac-handson-dev` を作成済みのため、このステップはスキップ。まだ作っていない場合は以下を実行:

```powershell
az group create --name rg-iac-handson-dev --location japaneast
```

---

## 2. 対話的デプロイの流れ

### 2-1. what-if (プレビュー) を依頼

Agent モードの Copilot Chat に以下を投げます。

````text
demoBicep/main.bicep を、リソースグループ rg-iac-handson-dev に対して
demoBicep/main.dev.bicepparam を使って what-if で差分を確認してください。
実行するコマンドを提案し、そのあと実行して結果を要約してください。
````

Copilot は以下のようなコマンドを提案 → 実行します。

```powershell
az deployment group what-if `
  --resource-group rg-iac-handson-dev `
  --template-file demoBicep/main.bicep `
  --parameters demoBicep/main.dev.bicepparam
```

### 2-2. 結果のレビュー

what-if の出力には `+ Create`, `~ Modify`, `- Delete` が色付きで表示されます。**意図しない `- Delete` や `~ Modify` がないか** を必ず目視確認します。

うまく読めなければ、そのまま Copilot に投げます。

````text
what-if の結果を、リソース種別ごとに 1 行ずつ要約してください。
想定外の変更があれば指摘してください。
````

### 2-3. 本デプロイを依頼

````text
内容に問題なさそうなので、同じパラメータで本デプロイを実行してください。
デプロイ名は dev-$(日付) としてください。
エラーが出たら、原因と想定される対処法を 3 つ挙げてください。
````

Copilot が実行するコマンド例:

```powershell
$deployName = "dev-$(Get-Date -Format 'yyyyMMdd-HHmm')"
az deployment group create `
  --name $deployName `
  --resource-group rg-iac-handson-dev `
  --template-file demoBicep/main.bicep `
  --parameters demoBicep/main.dev.bicepparam
```

### 2-4. Azure Portal でデプロイの実行状況を確認

CLI のログだけでなく、**Azure Portal のリソースグループ画面**からリアルタイムでデプロイ進捗を見られます。長めのデプロイ中や、どのリソースで止まっているかを視覚的に確認したいときに便利。

**手順:**

1. [Azure Portal](https://portal.azure.com/) にサインインする。
2. 上部検索バーで `rg-iac-handson-dev` を入力し、リソースグループを開く。
3. 左メニューの **「設定」→「デプロイ」** (英語 UI: **Settings → Deployments**) を選択。
4. デプロイ一覧から対象 (例: `dev-20260424-1530`) をクリック。
   - 状態: `実行中 (Running)` / `成功 (Succeeded)` / `失敗 (Failed)`
   - 所要時間・開始時刻・トリガー元 (CLI / Portal / Pipeline 等)
5. **「操作の詳細 (Operation details)」** タブで、リソース単位の進捗 (Created / Running / Failed) と所要時間が表形式で確認できる。
6. 失敗時は対象行の **「エラーの詳細 (Error details)」** を展開するとエラーコード・メッセージ・対象リソースが表示される。そのままコピーして Copilot Chat に貼れば修正案が得られる。

> 💡 **ポイント**
> - デプロイ履歴はリソースグループごとに最大 800 件まで保持される。過去のデプロイ内容 (使用した template / parameters) もここから JSON で確認・再利用可能。
> - **「テンプレート (Template)」** タブを開くと、実際にデプロイされた ARM テンプレート (Bicep のコンパイル結果) と入力パラメータを確認できる。`.bicepparam` の値が意図通りに渡っているかのデバッグに使える。
> - CLI 実行中でも Portal 側は自動更新される (明示的な再読み込み不要)。

---

## 3. よくあるエラーと Copilot の活用

### 3-1. `RoleAssignmentExists` / `AuthorizationFailed`

RBAC の `name` (GUID) が一意でなかったり、実行者の権限不足が原因です。

````text
以下のエラーが出ました。原因と修正方法を Bicep コードの該当箇所付きで教えてください。
<エラーメッセージを貼る>
````

> ヒント: ロール割り当ての `name` は `guid(scope.id, principalId, roleDefinitionId)` で冪等化しておくと、再デプロイ時の衝突を防げます。

### 3-2. `StorageAccountNameAlreadyTaken`

Storage Account 名はグローバル一意です。`uniqueString(resourceGroup().id)` でサフィックスを付与して再実行してください。

### 3-3. App Service の Managed Identity が有効化されない

`identity.type: 'SystemAssigned'` が抜けていると、後段の RBAC 付与で `principalId` が取れずエラーになります。Copilot に以下を依頼:

````text
appservice.bicep の Web App リソースで、System Assigned Managed Identity が有効になっているか確認し、
無効なら有効化してください。
````

---

## 4. デプロイ後の検証

Copilot に以下を依頼すると、一括で確認してくれます。

````text
rg-iac-handson-dev のリソースを以下の観点で検証してください。
1. App Service に System-assigned Managed Identity が有効か
2. App Service の Managed Identity に Storage Blob Data Contributor ロールが付与されているか
3. Storage の allowBlobPublicAccess が false / allowSharedKeyAccess が false か
4. App Service の httpsOnly が true / minTlsVersion が 1.2 か

確認した az コマンドも併記してください。
````

参考コマンド例:

```powershell
# Managed Identity
az webapp identity show -g rg-iac-handson-dev -n <appName>

# Role Assignments on Storage Account
$saId = az storage account show -g rg-iac-handson-dev -n <storageName> --query id -o tsv
az role assignment list --scope $saId -o table

# Storage public access / shared key
az storage account show -g rg-iac-handson-dev -n <storageName> `
  --query "{public:allowBlobPublicAccess, sharedKey:allowSharedKeyAccess, tls:minimumTlsVersion}" -o table

# App Service config
az webapp show -g rg-iac-handson-dev -n <appName> `
  --query "{httpsOnly:httpsOnly, tls:siteConfig.minTlsVersion}" -o table
```

---

## 5. 片付け (重要)

ハンズオン後は課金を止めるため削除します。

```powershell
az group delete -n rg-iac-handson-dev --yes --no-wait
```

---

## 6. まとめ

- **Copilot Agent + Azure CLI** の組み合わせで「提案 → 確認 → 実行 → 検証」を短サイクルで回せる
- 必ず **what-if で差分をレビュー** してから適用する
- エラーメッセージはそのまま Copilot に貼って質問 → 修正案を得るのが最速
- 本番環境では、このフローを **GitHub Actions / Azure DevOps Pipelines** に組み込み、人のレビューを挟む運用にする

👉 次へ: [Step 4: 設計ポイントとベストプラクティス](04-bestpractices.md)
