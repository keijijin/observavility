# Lokiクエリのよくある間違いと修正方法

## 🔍 問題のクエリ

```logql
{app="camel-observability-demo"} | json | trace_id = `a191c67769012c1dcf1dc63ffb70db7`
```

### ❌ 3つの問題点

1. **バッククォート (`) を使用している**
   - LogQLでは文字列にダブルクォート (`"`) を使用
   - バッククォート (`) は使えない

2. **等号の周りにスペースがある**
   - `trace_id = "..."` ← スペースあり
   - 正しくは `trace_id="..."` ← スペースなし

3. **トレースIDが31文字**
   - 正しいトレースIDは**32文字**（16進数）
   - 提供されたID: `a191c67769012c1dcf1dc63ffb70db7` = 31文字
   - 1文字不足している

---

## ✅ 正しいクエリ

### 基本形式

```logql
{app="camel-observability-demo"} | json | trace_id="<32文字のトレースID>"
```

### 実際の例

```logql
{app="camel-observability-demo"} | json | trace_id="a191c67769012c1dcf1dc63ffb70db7a"
```

**注意:** 最後に`a`を追加して32文字にしました（例）

---

## 🎯 正しいトレースIDの取得方法

### 方法1: Grafana Tempoから取得

#### ステップ1: Tempoでトレースを開く
1. Grafana → Explore → **Tempo**
2. **Search** → **Run query**
3. トレース一覧が表示される

#### ステップ2: トレースIDをコピー
1. 任意のトレースをクリック
2. **画面上部のトレースID全体をコピー**
3. 32文字の16進数であることを確認

例:
```
c02efc99e65dce72bd88168c79edb8ad  ← 32文字
```

#### ステップ3: Lokiで検索
1. Explore → **Loki**
2. 以下のクエリを実行:
```logql
{app="camel-observability-demo"} | json | trace_id="c02efc99e65dce72bd88168c79edb8ad"
```

### 方法2: コマンドラインから取得

```bash
# 最新のトレースIDを取得
TRACE_ID=$(curl -s "http://localhost:3200/api/search?limit=1" | \
  jq -r '.traces[0].traceID')

echo "トレースID: $TRACE_ID"
echo "文字数: $(echo -n $TRACE_ID | wc -c)"

# そのトレースIDでLokiを検索
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={app=\"camel-observability-demo\"} | json | trace_id=\"$TRACE_ID\"" \
  --data-urlencode "start=$(date -u -v-10M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=10" | jq '.'
```

---

## 🚫 よくある間違い

### 間違い1: バッククォートを使用

```logql
❌ trace_id = `abc123...`
✅ trace_id="abc123..."
```

### 間違い2: シングルクォートを使用

```logql
❌ trace_id='abc123...'
✅ trace_id="abc123..."
```

### 間違い3: スペースを入れる

```logql
❌ trace_id = "abc123..."
✅ trace_id="abc123..."
```

### 間違い4: パイプの前後にスペースなし

```logql
❌ {app="..."}|json|trace_id="..."
✅ {app="..."} | json | trace_id="..."
```

スペースはあってもなくても動作しますが、可読性のため推奨。

### 間違い5: トレースIDが不完全

```logql
❌ trace_id="a191c67769012c1dcf1dc63ffb70db7"   ← 31文字
✅ trace_id="a191c67769012c1dcf1dc63ffb70db7a"  ← 32文字
```

### 間違い6: ラベルセレクタの引用符

```logql
❌ {app='camel-observability-demo'}
✅ {app="camel-observability-demo"}
```

---

## 📝 LogQL構文のまとめ

### 完全なクエリ構造

```logql
{ラベルセレクタ} | パーサー | フィルタ | 追加フィルタ
```

### 例1: 基本的なトレースID検索

```logql
{app="camel-observability-demo"} | json | trace_id="abc123def456..."
```

**説明:**
- `{app="camel-observability-demo"}` - ラベルでフィルタ
- `| json` - JSONをパース
- `| trace_id="..."` - trace_idフィールドでフィルタ

### 例2: 複数条件

```logql
{app="camel-observability-demo"} | json | trace_id="abc123..." | level="ERROR"
```

### 例3: 正規表現マッチ

```logql
{app="camel-observability-demo"} | json | trace_id =~ "abc123.*"
```

### 例4: 否定

```logql
{app="camel-observability-demo"} | json | trace_id!="abc123..."
```

---

## 🎓 トレースIDの形式

### 正しい形式

- **長さ**: 32文字
- **文字種**: 16進数（0-9, a-f）
- **大文字小文字**: 通常は小文字だが、大文字でも可

### 例

```
✅ c02efc99e65dce72bd88168c79edb8ad  (32文字)
✅ C02EFC99E65DCE72BD88168C79EDB8AD  (大文字も可)
✅ f5c79311bdc18e5c3b0024ceb11e3e8e  (32文字)

❌ a191c67769012c1dcf1dc63ffb70db7   (31文字 - 不完全)
❌ c02efc99e65dce72bd88168c79edb8ad9 (33文字 - 長すぎ)
❌ c02efc99-e65d-ce72-bd88-168c79edb8ad (ハイフン付き - 形式が違う)
```

### トレースIDのバリデーション

```bash
# Bashで検証
TRACE_ID="c02efc99e65dce72bd88168c79edb8ad"

# 文字数確認
if [ ${#TRACE_ID} -eq 32 ]; then
    echo "✅ 長さOK (32文字)"
else
    echo "❌ 長さNG (${#TRACE_ID}文字)"
fi

# 16進数確認
if [[ $TRACE_ID =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "✅ 形式OK (16進数)"
else
    echo "❌ 形式NG"
fi
```

---

## 🔧 トラブルシューティング

### 問題1: "No data" が表示される

**チェックリスト:**
```logql
# 1. トレースIDが存在するか確認
{app="camel-observability-demo"} | json | trace_id != ""

# 2. 時間範囲を確認
# Grafanaの右上で「Last 15 minutes」などを選択

# 3. トレースIDをコピペしてみる
# 手入力ではなくコピー&ペーストを使用
```

### 問題2: "parse error" が表示される

**原因と解決:**
```logql
# エラー例: parse error at line 1, col 45: syntax error
# 原因: クエリ構文が間違っている

# チェック項目:
1. ダブルクォートを使用しているか？
2. スペルミス（trace_id のスペル）
3. パイプ記号 | は正しく使っているか？
```

### 問題3: トレースIDがわからない

**解決策:**
```bash
# コマンドラインで最新のトレースIDを取得
curl -s "http://localhost:3200/api/search?limit=10" | \
  jq -r '.traces[] | "\(.traceID) - \(.rootTraceName)"'

# 出力例:
# c02efc99e65dce72bd88168c79edb8ad - http post
# f5c79311bdc18e5c3b0024ceb11e3e8e - http post
# ...
```

---

## ✅ 正しいワークフロー

### ステップ1: Tempoでトレースを探す

1. Grafana → Explore → **Tempo**
2. 興味のあるトレースを見つける
3. トレースIDをコピー

### ステップ2: トレースIDを検証

```bash
# ターミナルで
TRACE_ID="<コピーしたID>"
echo "文字数: $(echo -n $TRACE_ID | wc -c)"
# 出力: 文字数: 32 ← これならOK
```

### ステップ3: Lokiで検索

```logql
{app="camel-observability-demo"} | json | trace_id="<コピーしたID>"
```

### ステップ4: 結果を確認

- ログが表示される
- trace_idフィールドが一致していることを確認
- 関連する他のフィールド（level, message など）も確認

---

## 📚 実践例

### 例1: エラーログのトレースを追跡

```logql
# ステップ1: エラーログを探す
{app="camel-observability-demo"} | json | level="ERROR"

# ステップ2: エラーログのtrace_idを確認
# （ログを展開してtrace_idをコピー）

# ステップ3: そのトレースの全ログを表示
{app="camel-observability-demo"} | json | trace_id="<コピーしたID>"
```

### 例2: 特定の時間範囲で検索

```logql
# 1時間前から現在まで
{app="camel-observability-demo"} | json | trace_id="abc123..."

# Grafana UIで時間範囲を調整:
# 右上: "Last 1 hour" を選択
```

### 例3: メッセージ内容も確認

```logql
# trace_idが一致し、かつ特定のキーワードを含む
{app="camel-observability-demo"} | json | trace_id="abc123..." | message =~ "オーダー"
```

---

## 🎯 クイックリファレンス

### 基本テンプレート

```logql
{app="camel-observability-demo"} | json | trace_id="<32文字の16進数>"
```

### コマンドラインヘルパー

```bash
# 最新トレースで検索
TRACE_ID=$(curl -s "http://localhost:3200/api/search?limit=1" | jq -r '.traces[0].traceID')
echo "{app=\"camel-observability-demo\"} | json | trace_id=\"$TRACE_ID\""

# Grafanaでこのクエリを実行すればOK
```

### 検証スクリプト

```bash
#!/bin/bash
TRACE_ID="$1"

# 検証
if [ ${#TRACE_ID} -ne 32 ]; then
    echo "❌ エラー: トレースIDは32文字である必要があります（現在: ${#TRACE_ID}文字）"
    exit 1
fi

if [[ ! $TRACE_ID =~ ^[0-9a-fA-F]+$ ]]; then
    echo "❌ エラー: トレースIDは16進数である必要があります"
    exit 1
fi

echo "✅ トレースID形式: OK"
echo "Lokiクエリ:"
echo "{app=\"camel-observability-demo\"} | json | trace_id=\"$TRACE_ID\""
```

使い方:
```bash
./validate_trace_id.sh c02efc99e65dce72bd88168c79edb8ad
```

---

## 🔗 関連ドキュメント

- [TRACE_ID_SEARCH_GUIDE.md](TRACE_ID_SEARCH_GUIDE.md) - トレースID検索の完全ガイド
- [GRAFANA_HOWTO.md](GRAFANA_HOWTO.md) - Grafana基本操作
- [LogQL公式ドキュメント](https://grafana.com/docs/loki/latest/logql/)

---

これで、Lokiクエリのよくある間違いとその修正方法が理解できました！🚀

