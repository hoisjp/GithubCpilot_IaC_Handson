# Step 2: 設計図を貼り付けて一気に Bicep を生成する手順

01-design.md で作成した Mermaid / draw.io の設計図を Copilot に貼り付け、設計どおりに一気に `bicep` ファイル群を生成するための簡潔な手順です。

> 本ハンズオンの構成は **App Service + Blob Storage** のみ。両者の接続は **Managed Identity (System Assigned) + RBAC** によるパスワードレスを採用します。

---

## 🎯 このステップのゴール

- `docs/architecture.md` の Mermaid を Copilot に渡して、`demoBicep/` 以下に Bicep 一式を一気に生成する
- 生成物を `az bicep build` と `az deployment group what-if` ですぐ検証できる形にする

---

## 手順（最短ルート — 一気に生成）

1. `docs/architecture.md` を開き、Mermaid ブロックをコピーする。
2. GitHub Copilot Chat を **Agent モード** で開き、以下のプロンプトに Mermaid を差し込んで実行する。

プロンプト（そのまま貼って実行）:

````text
以下のアーキテクチャ図に沿って、Resource Group スコープの Bicep 一式を
`demoBicep/` フォルダに新規作成してください。

# 設計図
```mermaid
<docs/architecture.md からコピーした Mermaid を貼る>
```

# 方針
- 環境は `environmentName` (`dev` | `prod`) で切替 (dev=B1 / prod=P1v3)
- リージョンは `japaneast`
- App Service → Blob はパスワードレス (MI + RBAC)。接続文字列・アカウントキーは使わない
- Azure / Bicep のベストプラクティスに従う (セキュア既定値、@description、@allowed など)
- モジュール分割・命名・パラメータファイル構成は Copilot の判断に任せる
````

> 💡 **想定される生成物（参考）**
> Copilot は通常、以下のような構成で出力します（ファイル名や分割粒度は多少揺れます）。
>
> ```text
> demoBicep/
> ├── main.bicep                 # エントリポイント (リソースグループスコープ)
> ├── modules/
> │   ├── appService.bicep       # App Service Plan + App Service + System Assigned MI
> │   ├── storage.bicep          # Storage Account (+ Blob)
> │   ├── roleAssignment.bicep   # MI への Storage Blob Data Contributor 付与 (別出しの場合)
> │   └── monitoring.bicep       # Log Analytics / App Insights (Copilot の判断で追加されることあり)
> ├── main.dev.bicepparam        # dev 用パラメータ (B1)
> ├── main.prod.bicepparam       # prod 用パラメータ (P1v3)
> └── README.md                  # 使い方の説明 (Copilot が一緒に生成することが多い)
> ```
>
> - `roleAssignment.bicep` のように RBAC を別モジュールに切り出すのは良いプラクティス。`storage.bicep` 内に含まれていても OK。
> - `monitoring.bicep` は本ハンズオンの必須構成ではありません。不要なら Copilot に「モニタリングは外して」と伝えれば削除してくれます。
> - 構成が想定と大きく違う場合は、「`modules/` に分けて」「dev/prod の `.bicepparam` も作って」など会話で追加指示すれば OK。



3. **生成された Bicep の中身を Copilot に解説してもらう**（動かす前に「何が作られたか」を理解するステップ）。

   Copilot Chat (Ask / Agent どちらでも OK) を開き、ワークスペース全体を参照させるために `#codebase` を付けて以下のように聞く。

   ````text
   #codebase demoBicep/ 配下のファイル構成と、main.bicep から各モジュールがどう呼ばれているかを初心者向けに解説してください。
   特に次の観点でお願いします。

   - main.bicep の役割と、各 module 呼び出しの依存関係
   - App Service の System Assigned Managed Identity がどこで有効化され、どう Storage Account の RBAC に渡っているか
   - environmentName (`dev` / `prod`) によって何が切り替わるのか
   - main.dev.bicepparam / main.prod.bicepparam の違い
   - セキュリティ上重要な設定 (allowSharedKeyAccess, httpsOnly, minimumTlsVersion など)
   ````

   > 💡 個別ファイルだけ聞きたい場合は、エディタで `demoBicep/main.bicep` を開き「このファイルを解説して」でも OK。Agent モードなら自動で関連モジュールも読みに行きます。

   解説を読んで「なぜそう書かれているか」が腹落ちしてから、次の構文チェック・what-if に進むのがおすすめ。

4. Copilot が `demoBicep/` 以下にファイルを作成したら、そのまま構文チェックを実行する。

```powershell
az bicep build --file demoBicep/main.bicep
```

**想定される応答:**

- ✅ **正常時 (エラー・警告なし)**: 標準出力に**何も表示されず**、プロンプトが戻ってくるのが成功。副作用として同じディレクトリに `demoBicep/main.json` (ARM テンプレート) が生成される。

   ```powershell
   PS> az bicep build --file demoBicep/main.bicep
   PS>
   PS> Test-Path demoBicep/main.json
   True
   ```

- ⚠️ **警告あり (ビルド成功)**: 終了コードは 0 で `main.json` も生成されるが、Bicep linter の警告が表示される。警告文をそのまま Copilot Chat に貼って「直して」と依頼するのが手早い。

   ```text
   demoBicep/modules/storage.bicep(15,7) : Warning no-hardcoded-location: A resource location should not use a hard-coded string or variable value. [https://aka.ms/bicep/linter/no-hardcoded-location]
   demoBicep/modules/appService.bicep(42,3) : Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. [https://aka.ms/bicep/linter/outputs-should-not-contain-secrets]
   ```

- ❌ **異常時 (ビルド失敗)**: 赤字でエラーが表示され、終了コードは 1。`main.json` は生成されない (または古いものが残る)。エラーメッセージを丸ごと Copilot Chat に貼って修正を依頼する。

   ```text
   demoBicep/main.bicep(23,15) : Error BCP057: The name "storageAcct" does not exist in the current context.
   demoBicep/modules/appService.bicep(18,9) : Error BCP036: The property "sku" expected a value of type "SkuDescription" but the provided value is of type "'B1' | 'P1v3'". [https://aka.ms/bicep/core-diagnostics#BCP036]
   ```

   よくあるエラーコード: `BCP057` (名前未定義), `BCP036` (型不一致), `BCP104` (モジュールのパスミス), `BCP062` (循環参照) など。

5. **what-if の前提準備** — Azure にサインインし、差分確認の対象となるリソースグループを作成しておく。

   ```powershell
   # 1) Azure にサインイン (対象テナントを明示)
   az login --tenant <your-tenant-id-or-domain>

   # 2) 対象のサブスクリプションを選択 (複数ある場合)
   az account list --output table
   az account set --subscription "<your-subscription-name-or-id>"

   # 3) リソースグループを作成 (japaneast)
   az group create --name rg-iac-handson-dev --location japaneast
   ```

   > 💡 **ポイント**
   > - `--tenant` にはテナント ID (GUID) または検証済みドメイン (`contoso.onmicrosoft.com` など) を指定する。ゲストユーザーや複数テナントに所属しているアカウントで**意図しないテナントにサインインするのを防ぐ**ため、明示しておくのがおすすめ。
   > - テナント ID が分からない場合は Azure Portal 右上のアカウント > ディレクトリ切替で確認、または `az account tenant list` で一覧表示できる。
   > - `az deployment group what-if` は**既存のリソースグループに対して**差分を計算するコマンドなので、RG は事前に作っておく必要があります (Bicep 側では作れない)。
   > - RG 名は何でも OK (以下のコマンドでは `rg-iac-handson-dev` を例として使用)。
   > - prod 用に別 RG を作る場合は `rg-iac-handson-prod` のように用意する。
   > - 現在のサインイン状況は `az account show` で確認できます。

6. `az deployment group what-if` で差分確認（`<your-rg>` は手順 5 で作成したリソースグループ名に置換）。

```powershell
az deployment group what-if -g <your-rg> --template-file demoBicep/main.bicep --parameters demoBicep/main.dev.bicepparam
```

**想定される応答 (正常時):**

- ✅ **初回実行 (リソースが 1 つも無い RG に対して)** — `+ Create` がリソース数だけ並び、末尾に `Resource changes: N to create.` と出れば成功。`<will-be-computed>` はデプロイ時に決まる値 (MI の principalId など) で正常。

   ```text
   Note: As What-If is currently in preview, the result may contain false positive predictions (noise).

   Resource and property changes are indicated with these symbols:
     + Create

   The deployment will update the following scope:

   Scope: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-iac-handson-dev

     + Microsoft.Web/serverfarms/asp-handson-dev [2023-12-01]
         location:                              "japaneast"
         sku.name:                              "B1"
         sku.tier:                              "Basic"

     + Microsoft.Web/sites/app-handson-dev-abc123 [2023-12-01]
         identity.type:                         "SystemAssigned"
         location:                              "japaneast"
         properties.httpsOnly:                  true
         properties.siteConfig.minTlsVersion:   "1.2"
         properties.siteConfig.ftpsState:       "Disabled"

     + Microsoft.Storage/storageAccounts/sthandsondevabc123 [2023-05-01]
         location:                              "japaneast"
         properties.allowBlobPublicAccess:      false
         properties.allowSharedKeyAccess:       false
         properties.minimumTlsVersion:          "TLS1_2"
         sku.name:                              "Standard_LRS"

     + Microsoft.Authorization/roleAssignments/<guid> [2022-04-01]
         properties.principalId:                "<will-be-computed>"
         properties.roleDefinitionId:           ".../ba92f5b4-2d11-453d-a403-e96b0029c9fe"  # Storage Blob Data Contributor
         properties.scope:                      ".../storageAccounts/sthandsondevabc123"

   Resource changes: 4 to create.
   ```

   **判断基準:**
   - 最後に `Resource changes: N to create.` と表示される (エラー行なし)
   - 終了コード `0` (`$LASTEXITCODE` で確認可能)
   - `+ Create` のリソース一覧がテンプレートで定義した内容と一致している

- ✅ **2 回目以降 (差分なし)** — 同じ RG に同じテンプレートを再実行した場合。このまま Step 3 のデプロイに進んで OK。

   ```text
   Scope: /subscriptions/.../resourceGroups/rg-iac-handson-dev

   The deployment will update the following scope, but no changes are predicted.

   Resource changes: no change.
   ```

- ⚠️ **プロパティ変更 (`~ Modify`)** — dev → prod にパラメータを切り替えたときなど、変更前後が `=>` で表示される。これも正常動作。

   ```text
     ~ Microsoft.Web/serverfarms/asp-handson-dev [2023-12-01]
       - sku.name:     "B1"     => "P1v3"
       - sku.tier:     "Basic"  => "PremiumV3"

   Resource changes: 1 to modify.
   ```

**想定される応答 (異常時):**

   ```text
   (ResourceGroupNotFound) Resource group 'rg-iac-handson-dev' could not be found.
   ```
   → 手順 5 の `az group create` を実行。

   ```text
   (InvalidTemplate) Deployment template validation failed: 'The value for the
   template parameter 'environmentName' ... is not provided.'
   ```
   → `.bicepparam` の不足パラメータを追加、または `main.bicep` の `param` にデフォルト値を設定。

   ```text
   (InvalidResourceName) Resource name 'st-handson-dev' is invalid. The storage
   account name must be between 3 and 24 characters and use numbers and lower-case letters only.
   ```
   → 命名規則違反。`uniqueString()` / `toLower()` / ハイフン除去を Copilot に依頼。

   ```text
   (AuthorizationFailed) ... does not have authorization to perform action
   'Microsoft.Authorization/roleAssignments/write' ...
   ```
   → RBAC 作成には `User Access Administrator` または `Owner` が必要。権限が無ければ管理者に依頼。

   ```text
   (SubscriptionIsOverQuotaForSku) This region has quota of 0 instances for your
   subscription. Try selecting different region or SKU.
   ```
   → 対象リージョンの App Service クォータが不足。別リージョン / 別 SKU で試すか、クォータ増加を申請する。**この書き換え自体も Copilot に丸投げ可能** — 例: 「上記エラーで `location` を `japanwest` に変更して、`main.bicep` と `main.dev.bicepparam` を両方更新して」と指示すれば自動で書き換えてくれる。

   > 💡 エラーメッセージを丸ごと Copilot Chat に貼って「直して」と依頼すれば、大抵そのまま修正案が返ってきます。

7. What-if のエラーや Bicep linter 警告が出たら、そのまま Copilot Chat に貼り付けて修正を依頼する。




---



## 早期に確認すべきポイント（自動生成後）

- App Service が `identity.type = 'SystemAssigned'` になっているか
- Storage Account の `allowSharedKeyAccess` が `false` になっているか（パスワードレスを担保）
- RoleAssignment が **Storage Account をスコープ** に、**App Service の `identity.principalId`** に対して `Storage Blob Data Contributor` を付与しているか
- App Settings に接続文字列やキーが含まれていないか（含まれていたら Copilot に削除を依頼）
- `publicNetworkAccess` はハンズオンでは `Enabled` で OK だが、本番は Private Endpoint を推奨する旨のコメントが残っているか

---

## よくあるトラブルと対処法

- Bicep linter の警告: 警告文をそのまま Copilot に入力し、修正パッチを生成してもらう
- 依存の循環参照: `resource existing` を使って参照を切る（Copilot にそのまま指示する）
- 接続文字列ベースの実装が出た場合: `listKeys()` を避け、Managed Identity + RBAC に書き換えるよう指示する

---

## 補足: 一気に生成するメリットとリスク

- メリット: 作業時間が短縮され、設計→コードのトレーサビリティが保てる
- リスク: 自動生成は細部のセキュリティ設定や命名制約を見落とす可能性があるため、生成直後に `what-if` とレビューを必ず行うこと

---

👉 次へ: [Step 3: Azure にデプロイする](03-deploy.md)
