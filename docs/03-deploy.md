# Step 3: GitHub Copilot と対話的に Azure へデプロイする

完成した Bicep を、**GitHub Copilot (Agent モード)** を使って対話的にデプロイします。

---

## 🎯 このステップのゴール

- `az deployment` / `what-if` を Copilot 経由で実行できる
- エラーが出た時に **Copilot と一緒に原因特定** できる
- デプロイ後の検証 (RBAC や App Service の起動確認) まで自動化の勘所を掴む

---

## 1. 準備

### 1-1. Copilot を Agent モードに切り替える

VS Code の Copilot Chat パネルで、モードを **Agent** に変更します。Agent モードでは、ツール (ファイル編集・ターミナル実行・Azure MCP) を Copilot が自律的に呼び出せます。

### 1-2. Azure CLI でログイン

```powershell
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --query "{subscription:name, tenant:tenantId}" -o table
```

### 1-3. リソースグループを作成

Copilot Chat に依頼してもよいですが、最初は自分で作ると流れが掴みやすいです。

```powershell
$rg  = "rg-web-dev-japaneast"
$loc = "japaneast"
az group create -n $rg -l $loc
```

---

## 2. 対話的デプロイの流れ

### 2-1. what-if (プレビュー) を依頼

Agent モードの Copilot Chat に以下を投げます。

````text
bicep/main.bicep を、リソースグループ rg-web-dev-japaneast に対して
main.dev.bicepparam を使って what-if で差分を確認してください。
実行するコマンドを提案し、そのあと実行して結果を要約してください。
````

Copilot は以下のようなコマンドを提案 → 実行します。

```powershell
az deployment group what-if `
  --resource-group rg-web-dev-japaneast `
  --template-file bicep/main.bicep `
  --parameters bicep/main.dev.bicepparam
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
  --resource-group rg-web-dev-japaneast `
  --template-file bicep/main.bicep `
  --parameters bicep/main.dev.bicepparam
```

---

## 3. よくあるエラーと Copilot の活用

### 3-1. `RoleAssignmentExists` / `AuthorizationFailed`

RBAC の ID が一意でなかったり、実行者の権限が不足していることが多いです。

````text
以下のエラーが出ました。原因と修正方法を Bicep コードの該当箇所付きで教えてください。
<エラーメッセージを貼る>
````

### 3-2. `InvalidTemplateDeployment` — SQL の Entra ID 管理者

`sqlAdminObjectId` が自分自身の objectId になっていない場合に多発します。

```powershell
az ad signed-in-user show --query id -o tsv
```

で取得した値を `.bicepparam` に反映し、再実行。

### 3-3. Key Vault の purge protection

同名の Key Vault が **論理削除状態で残っている** とデプロイに失敗します。ハンズオンのやり直しでよく踏みます。

```powershell
az keyvault list-deleted
az keyvault purge --name <kv-name> --location japaneast
```

---

## 4. デプロイ後の検証

Copilot に以下を依頼すると、一括で確認してくれます。

````text
rg-web-dev-japaneast のリソースを以下の観点で検証してください。
1. App Service に System-assigned Managed Identity が有効か
2. App Service の Managed Identity に Key Vault Secrets User ロールが付与されているか
3. Storage の allowBlobPublicAccess が false か
4. SQL Server が Entra ID 認証のみ (SQL 認証無効) になっているか

確認した az コマンドも併記してください。
````

参考コマンド例:

```powershell
# Managed Identity
az webapp identity show -g rg-web-dev-japaneast -n <appName>

# Role Assignments on Key Vault
$kvId = az keyvault show -g rg-web-dev-japaneast -n <kvName> --query id -o tsv
az role assignment list --scope $kvId -o table

# Storage public access
az storage account show -g rg-web-dev-japaneast -n <storageName> `
  --query "{public:allowBlobPublicAccess, tls:minimumTlsVersion}" -o table

# SQL auth
az sql server show -g rg-web-dev-japaneast -n <sqlServerName> `
  --query "{adOnly:administrators.administratorType, login:administrators.login}"
```

---

## 5. 片付け (重要)

ハンズオン後は課金を止めるため削除します。

```powershell
az group delete -n rg-web-dev-japaneast --yes --no-wait
```

Key Vault は purge protection を有効にしているので、同名で再作成したい場合は論理削除のパージも必要です (Step 3-3 参照)。

---

## 6. (オプション) AVM 版をデプロイして差分を見る

Step 2 で `sample/avm/main.bicep` を作成した場合、**別のリソースグループ** にデプロイして Track A との違いを確認できます。

```powershell
$avmRg = "rg-web-dev-avm-japaneast"
az group create -n $avmRg -l japaneast

# what-if
az deployment group what-if -g $avmRg `
  --template-file sample/avm/main.bicep `
  --parameters sample/avm/main.dev.bicepparam

# 本デプロイ
az deployment group create -n avm-dev-$(Get-Date -Format 'yyyyMMdd-HHmm') `
  -g $avmRg `
  --template-file sample/avm/main.bicep `
  --parameters sample/avm/main.dev.bicepparam
```

**Copilot に違いを説明させるプロンプト**:

````text
rg-web-dev-japaneast (Track A) と rg-web-dev-avm-japaneast (Track B: AVM) の
リソースを az resource list --resource-group で取得し、以下の観点で比較してください。

1. デプロイされたリソースの種類・数
2. 各リソースの diagnosticSettings の有無
3. Storage / Key Vault / SQL の securityProperty (publicNetworkAccess, TLS, etc.)
4. ロール割り当ての差分

AVM 版で "追加で有効化されている" セキュリティ機能があれば指摘してください。
````

後片付けも忘れずに:

```powershell
az group delete -n rg-web-dev-avm-japaneast --yes --no-wait
```

---

## 7. まとめ

- **Copilot Agent + Azure CLI** の組み合わせで「提案 → 確認 → 実行 → 検証」を短サイクルで回せる
- 必ず **what-if で差分をレビュー** してから適用する
- エラーメッセージはそのまま Copilot に貼って質問 → 修正案を得るのが最速
- 本番環境では、このフローを **GitHub Actions / Azure DevOps Pipelines** に組み込み、人のレビューを挟む運用にする

👉 次へ: [Step 4: 設計ポイントとベストプラクティス](04-bestpractices.md)
