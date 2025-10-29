# トレースIDでログを絞り込む - 完全ガイド

## 🎯 この資料について

Grafanaでトレースからログへ、またはログからトレースへ移動する方法を**実践的に**説明します。

---

## 📊 前提：ログの構造

Lokiに保存されているログはJSON形式です：

```json
{
  "level": "INFO",
  "class": "c.e.demo.route.OrderProducerRoute",
  "thread": "http-nio-8080-exec-4",
  "message": "オーダーを生成しました: Order(orderId=ORD-abc123...)",
  "trace_id": "f5c79311bdc18e5c3b0024ceb11e3e8e",
  "span_id": "f2ad3df234aa72be"
}
```

---

## 🔍 方法1: Grafana UI（推奨）

### TempoからLokiへ（トレース → ログ）

#### **ステップ1: Tempoでトレースを開く**

1. Grafanaにアクセス: http://localhost:3000
2. 左メニューから**「Explore」**をクリック
3. データソースで**「Tempo」**を選択
4. **「Search」**タブをクリック
5. **「Run query」**をクリック
6. トレース一覧が表示される

#### **ステップ2: トレース詳細を開く**

- 任意のトレースをクリック
- スパン階層が表示される

#### **ステップ3: ログへ移動**

**方法A: 自動リンク（設定済みの場合）**
- スパン詳細の右側に**「Logs for this span」**ボタンが表示される
- クリックすると、そのスパンに関連するログが自動的にLokiで開く

**方法B: トレースIDを手動でコピー**
1. トレースIDをコピー（画面上部に表示されている）
2. 新しいタブでExploreを開く
3. データソースで**「Loki」**を選択
4. 以下のクエリを実行（`<TraceID>`を実際の値に置き換え）:

```logql
{app="camel-observability-demo"} | json | trace_id="<TraceID>"
```

**例:**
```logql
{app="camel-observability-demo"} | json | trace_id="f5c79311bdc18e5c3b0024ceb11e3e8e"
```

---

### LokiからTempoへ（ログ → トレース）

#### **ステップ1: Lokiでログを検索**

1. Grafanaにアクセス: http://localhost:3000
2. 左メニューから**「Explore」**をクリック
3. データソースで**「Loki」**を選択
4. クエリを実行:

```logql
{app="camel-observability-demo"} | json
```

または特定のメッセージで絞り込み:
```logql
{app="camel-observability-demo"} | json | message =~ "オーダー"
```

#### **ステップ2: ログ詳細を展開**

- ログ一覧から任意のログをクリック
- ログの詳細が展開される

#### **ステップ3: trace_idフィールドを確認**

- `trace_id`フィールドがあることを確認
- その値をクリック

#### **ステップ4: Tempoへ自動遷移**

- **自動的にTempoのExploreが開く**
- そのtrace_idに対応するトレース詳細が表示される

---

## 🖥️ 方法2: コマンドライン

### トレースIDでログを検索

```bash
# 1. Tempoからトレース一覧を取得
curl -s "http://localhost:3200/api/search?limit=5" | jq '.traces[] | {traceID, rootServiceName}'

# 出力例:
# {
#   "traceID": "f5c79311bdc18e5c3b0024ceb11e3e8e",
#   "rootServiceName": "camel-observability-demo"
# }

# 2. トレースIDをコピー（例: f5c79311bdc18e5c3b0024ceb11e3e8e）

# 3. そのトレースIDに関連するログを検索
TRACE_ID="f5c79311bdc18e5c3b0024ceb11e3e8e"  # ← 実際の値に置き換え

curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={app=\"camel-observability-demo\"} | json | trace_id=\"$TRACE_ID\"" \
  --data-urlencode "start=$(date -u -v-10M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=50" | jq '.'

# 4. ログの内容を見やすく表示
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={app=\"camel-observability-demo\"} | json | trace_id=\"$TRACE_ID\"" \
  --data-urlencode "start=$(date -u -v-10M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=50" | \
  jq '.data.result[0].values[] | (.[1] | fromjson | {level, message: (.message[0:80]), trace_id})'
```

---

## 📝 正しいクエリ形式

### ❌ 間違った形式

```logql
# これは動作しません
{app="camel-observability-demo"} |= "trace_id=<ID>"
```

**理由:**
- `|=`は文字列検索（生のログテキストから検索）
- しかし、trace_idはJSON内のフィールドなので見つからない

### ✅ 正しい形式

```logql
# 方法1: 完全一致（推奨）
{app="camel-observability-demo"} | json | trace_id="f5c79311bdc18e5c3b0024ceb11e3e8e"

# 方法2: 部分一致
{app="camel-observability-demo"} | json | trace_id =~ "f5c79311.*"

# 方法3: trace_idが空でないものすべて
{app="camel-observability-demo"} | json | trace_id != ""
```

---

## 🎓 LogQLクエリの詳細

### 基本構造

```
{ラベルセレクタ} | パーサー | フィルタ
```

### ラベルセレクタ

```logql
{app="camel-observability-demo"}
{app="camel-observability-demo", level="ERROR"}
{app="camel-observability-demo", level=~"ERROR|WARN"}
```

### JSONパーサー

```logql
| json
```

これにより、JSON内のすべてのフィールドが抽出される：
- `level`
- `class`
- `message`
- `trace_id`
- `span_id`

### フィルタ

```logql
# 完全一致
| trace_id="f5c79311bdc18e5c3b0024ceb11e3e8e"

# 正規表現マッチ
| trace_id =~ "f5c79311.*"

# 否定
| trace_id != ""

# 複数条件（AND）
| trace_id="..." | level="ERROR"

# メッセージ検索
| message =~ "オーダー"
```

---

## 🔧 実践例

### 例1: エラーログのトレースを追跡

**シナリオ:** エラーログを見つけて、その全体の流れを追跡したい

#### **ステップ1: エラーログを検索**

```logql
{app="camel-observability-demo"} | json | level="ERROR"
```

#### **ステップ2: trace_idを確認**

- ログを展開
- `trace_id`フィールドの値をコピー
- 例: `f5c79311bdc18e5c3b0024ceb11e3e8e`

#### **ステップ3: そのトレース全体を確認**

新しいタブでTempoを開き、以下のように検索:
- Search query: `traceID=f5c79311bdc18e5c3b0024ceb11e3e8e`

または、ログの`trace_id`をクリックして自動遷移

#### **ステップ4: 関連する全ログを確認**

```logql
{app="camel-observability-demo"} | json | trace_id="f5c79311bdc18e5c3b0024ceb11e3e8e"
```

これで、そのリクエストに関するすべてのログが時系列で表示される

---

### 例2: 遅いリクエストの調査

**シナリオ:** レスポンスが遅いリクエストを調査したい

#### **ステップ1: Tempoで遅いトレースを探す**

1. Tempo Exploreで「Search」
2. 「Duration」でソート（降順）
3. 一番遅いトレースをクリック

#### **ステップ2: どのスパンが遅いか確認**

- スパン階層を見る
- 時間がかかっているスパン（赤色または長い）を特定
- 例: `payment-processing-route`が500ms

#### **ステップ3: そのスパンの詳細ログを確認**

- スパンをクリック
- 「Logs for this span」をクリック
- または、トレースIDをコピーしてLokiで検索

#### **ステップ4: 原因を特定**

```logql
{app="camel-observability-demo"} | json | trace_id="<ID>" | message =~ "payment|支払い"
```

支払い処理に関するログだけを抽出

---

### 例3: 特定のオーダーIDの追跡

**シナリオ:** `ORD-abc123`というオーダーIDの全処理を追跡したい

#### **ステップ1: オーダーIDでログ検索**

```logql
{app="camel-observability-demo"} | json | message =~ "ORD-abc123"
```

#### **ステップ2: trace_idを確認**

- 最初のログ（オーダー作成）のtrace_idをコピー

#### **ステップ3: そのトレース全体を確認**

Tempoで確認:
- トレース全体のタイムライン
- 各ステップの処理時間
- 並列処理の様子

Lokiで詳細ログ:
```logql
{app="camel-observability-demo"} | json | trace_id="<コピーしたID>"
```

---

## 🎯 Grafanaでの高度な使い方

### ダッシュボードでの連携

#### **パネル1: エラーログ数（Loki）**

```logql
sum(count_over_time({app="camel-observability-demo"} | json | level="ERROR" [1m]))
```

#### **パネル2: トレース数（Tempo）**

Prometheusメトリクスを使用:
```promql
rate(traces_service_graph_request_total[1m])
```

#### **パネル3: トレースとログのリンク**

- パネルの設定で「Data links」を追加
- URLテンプレート:
```
/explore?left=["now-1h","now","Loki",{"expr":"{app=\"camel-observability-demo\"} | json | trace_id=\"${__data.fields.traceID}\""}]
```

---

## 🛠️ トラブルシューティング

### 問題1: trace_idでフィルタしても何も表示されない

**確認事項:**
```bash
# 1. そのtrace_idがLokiに存在するか確認
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"} | json | trace_id != ""' \
  --data-urlencode "limit=10" | jq '.data.result[0].values[] | (.[1] | fromjson | .trace_id)' | head -5

# 2. トレースIDが正しいか確認（32桁の16進数）
echo "f5c79311bdc18e5c3b0024ceb11e3e8e" | wc -c  # 33が返る（改行含む）= 32文字
```

**解決策:**
- トレースIDを正確にコピー（前後に空白がないか確認）
- 時間範囲を広げる（Last 15 minutes → Last 1 hour）
- クエリ構文を確認

### 問題2: ログからトレースへのリンクが動作しない

**原因:**
- Grafanaのデータソース設定が不完全

**解決策:**
1. **Settings → Data sources → Loki**を開く
2. **Derived fields**セクションを確認:
   ```yaml
   Name: TraceID
   Regex: "trace_id":"(\w+)"
   Query: ${__value.raw}
   Internal link: Tempo
   ```
3. **「Save & test」**をクリック

### 問題3: トレースからログへのリンクが動作しない

**原因:**
- Tempoのデータソース設定が不完全

**解決策:**
1. **Settings → Data sources → Tempo**を開く
2. **Trace to logs**セクションを確認:
   ```yaml
   Data source: Loki
   Tags: trace_id
   ```
3. **「Save & test」**をクリック

---

## 📚 よく使うクエリ集

### トレースID関連

```logql
# 特定のトレースIDのすべてのログ
{app="camel-observability-demo"} | json | trace_id="<ID>"

# トレースIDが存在するすべてのログ
{app="camel-observability-demo"} | json | trace_id != ""

# 複数のトレースIDで検索
{app="camel-observability-demo"} | json | trace_id =~ "f5c79311.*|e14bdad0.*"
```

### レベル別

```logql
# エラーログのみ（trace_id付き）
{app="camel-observability-demo"} | json | level="ERROR" | trace_id != ""

# 警告以上（ERROR or WARN）
{app="camel-observability-demo"} | json | level=~"ERROR|WARN"
```

### メッセージ検索

```logql
# 特定のキーワードを含むログ（trace_id付き）
{app="camel-observability-demo"} | json | message =~ "オーダー" | trace_id != ""

# 処理時間が長いログ
{app="camel-observability-demo"} | json | message =~ "処理時間: [5-9][0-9]{2}ms"
```

### 統計情報

```logql
# trace_idが含まれるログの数
count_over_time({app="camel-observability-demo"} | json | trace_id != "" [1m])

# エラーログの数（trace_id別）
sum by (trace_id) (count_over_time({app="camel-observability-demo"} | json | level="ERROR" [5m]))
```

---

## ✅ チェックリスト

### Grafana UI使用時

- [ ] Tempoでトレースを開いた
- [ ] トレースIDが表示されている
- [ ] Lokiで`| json | trace_id="<ID>"`クエリを使用
- [ ] 時間範囲が適切（トレース発生時を含む）
- [ ] ログが表示される

### コマンドライン使用時

- [ ] トレースIDを正確にコピー
- [ ] `curl`コマンドで正しいエンドポイント（`localhost:3100`）を使用
- [ ] クエリ構文が正しい（`| json | trace_id="<ID>"`）
- [ ] `jq`でJSONをパース
- [ ] 結果が表示される

---

## 🎉 成功の確認

以下ができれば成功です：

1. ✅ Tempoでトレースを開く
2. ✅ トレースIDをコピー
3. ✅ Lokiで`{app="..."} | json | trace_id="<ID>"`を実行
4. ✅ そのトレースに関するすべてのログが表示される
5. ✅ ログの`trace_id`をクリックしてTempoに戻れる

---

## 🔗 関連ドキュメント

- [TRACE_ID_FIX.md](TRACE_ID_FIX.md) - trace_id設定のトラブルシューティング
- [LOKI_TROUBLESHOOTING.md](LOKI_TROUBLESHOOTING.md) - Loki全般のトラブルシューティング
- [GRAFANA_HOWTO.md](GRAFANA_HOWTO.md) - Grafana基本操作
- [LogQL公式ドキュメント](https://grafana.com/docs/loki/latest/logql/)

---

これで、トレースとログを完全に連携させて、問題の根本原因を素早く特定できます！🚀




