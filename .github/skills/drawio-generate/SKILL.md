---
name: drawio-generate
description: 'Generate draw.io (.drawio) architecture diagrams and flowcharts in XML format. WHEN: create diagram, draw architecture, generate drawio, create flowchart, visualize infrastructure, network diagram, system diagram, draw.io, drawio file, architecture diagram, sequence diagram, ER diagram, class diagram, create .drawio file.'
argument-hint: 'Describe the diagram you want to generate'
---

# draw.io Diagram Generator

## When to Use

- アーキテクチャ図、フローチャート、ネットワーク図、ER 図、クラス図などを `.drawio` 形式で生成する
- 既存の `.drawio` ファイルを編集・更新する
- インフラ構成やシステム設計を図として可視化する

## Procedure

1. ユーザーの要件からダイアグラムの種類・内容を把握する
2. 下記の XML テンプレートとスタイルガイドに従い、draw.io XML を生成する
3. `.drawio` 拡張子でファイルを保存する

## draw.io XML 基本構造

```xml
<mxfile host="app.diagrams.net" agent="GitHub Copilot">
  <diagram id="DIAGRAM_ID" name="Page-1">
    <mxGraphModel dx="1422" dy="762" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <!-- ここにセル（図形・矢印）を配置 -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### 重要ルール

- `id="0"` と `id="1"` のセルは必須（ルート要素）
- すべての図形は `parent="1"` を指定する
- 矢印（エッジ）は `source` と `target` で接続先セルの ID を指定する
- ID は一意の整数または文字列を使用する
- `vertex="1"` は図形、`edge="1"` は矢印

## 図形（Vertex）の書き方

```xml
<!-- 矩形 -->
<mxCell id="2" value="Web App" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
  <mxGeometry x="200" y="100" width="160" height="60" as="geometry" />
</mxCell>

<!-- 円形 -->
<mxCell id="3" value="Start" style="ellipse;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="80" height="80" as="geometry" />
</mxCell>

<!-- データベース -->
<mxCell id="4" value="SQL Database" style="shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
  <mxGeometry x="400" y="80" width="100" height="80" as="geometry" />
</mxCell>
```

## 矢印（Edge）の書き方

```xml
<!-- 実線矢印 -->
<mxCell id="10" value="" style="endArrow=classic;html=1;" edge="1" source="2" target="4" parent="1">
  <mxGeometry relative="1" as="geometry" />
</mxCell>

<!-- ラベル付き矢印 -->
<mxCell id="11" value="HTTPS" style="endArrow=classic;html=1;" edge="1" source="2" target="3" parent="1">
  <mxGeometry relative="1" as="geometry" />
</mxCell>

<!-- 点線矢印 -->
<mxCell id="12" value="" style="endArrow=classic;dashed=1;html=1;" edge="1" source="3" target="4" parent="1">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

## グループ（コンテナ）の書き方

```xml
<!-- グループ枠 -->
<mxCell id="20" value="Azure Resource Group" style="rounded=1;whiteSpace=wrap;html=1;verticalAlign=top;fontStyle=1;fillColor=#f5f5f5;strokeColor=#666666;dashed=1;dashPattern=5 5;fontSize=14;" vertex="1" parent="1">
  <mxGeometry x="50" y="50" width="500" height="300" as="geometry" />
</mxCell>

<!-- グループ内の要素は parent にグループの ID を指定 -->
<mxCell id="21" value="App Service" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="20">
  <mxGeometry x="30" y="60" width="160" height="60" as="geometry" />
</mxCell>
```

## よく使うスタイル一覧

### Azure アイコン（azure2 ライブラリ）

Azure リソースには必ず draw.io 組み込みの **`img/lib/azure2`** SVG アイコンを使用する。
参照： https://github.com/jgraph/drawio/tree/dev/src/main/webapp/img/lib/azure2

#### パス規則

```
img/lib/azure2/<category>/<resource_name>.svg
```

- `<category>` — Azure のサービスカテゴリ（`compute`, `databases`, `networking`, `storage`, `security`, `identity`, `integration`, `analytics`, `devops`, `management_governance`, `general` など）
- `<resource_name>` — リソース名をスネークケースで指定（例: `app_services`, `sql_database`, `key_vaults`）

#### スタイルテンプレート

```
image=img/lib/azure2/<category>/<resource_name>.svg;aspect=fixed;
```

#### 使用例

```xml
<mxCell id="2" value="App Service" style="image=img/lib/azure2/compute/app_services.svg;aspect=fixed;" vertex="1" parent="1">
  <mxGeometry x="200" y="100" width="50" height="50" as="geometry" />
</mxCell>

<mxCell id="3" value="SQL DB" style="image=img/lib/azure2/databases/sql_database.svg;aspect=fixed;" vertex="1" parent="1">
  <mxGeometry x="400" y="100" width="50" height="50" as="geometry" />
</mxCell>
```

## レイアウトのベストプラクティス

1. **左から右**または**上から下**の流れでレイアウトする
2. 要素間の間隔は **40〜80px** を目安にする
3. 関連する要素はグループ（コンテナ）でまとめる
4. 矢印にはラベルを付けて通信プロトコルやデータの流れを明示する
5. グリッドサイズ 10px に合わせて座標を 10 の倍数にする

## 出力ファイル

- 拡張子: `.drawio`
- エンコーディング: UTF-8
