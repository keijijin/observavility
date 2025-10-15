# ordersトレースの表示 - 完全ガイド

## 🎯 結論

**`orders`は正しく記録されています！** ただし、独立したトレースではなく、`http post`トレースの**子スパン**として含まれています。

---

## 📊 トレース構造の理解

### 現在の動作（正しい動作）

```
トレース: "http post" (rootTraceName)
├─ Span: "http post" (HTTPリクエスト受信)
│  └─ Span: "/api/orders" (Camel REST エンドポイント)
│     └─ Span: "orders" (Kafka プロデューサー) ← これ！
│        └─ Span: "kafka send" (メッセージ送信)
```

### 誤解されやすいポイント

❌ **誤解:** `orders`という**トレース**が表示されるはず  
✅ **実際:** `orders`は**スパン**として`http post`トレースに含まれる

---

## 🔍 Grafanaでの確認方法

### ステップ1: Tempoでトレースを開く

1. Grafana → **Explore**
2. データソース: **Tempo**
3. **Search** タブ → **Run query**
4. トレース一覧が表示される

### ステップ2: http postトレースを選択

- `rootTraceName: "http post"`のトレースをクリック
- スパン階層が表示される

### ステップ3: ordersスパンを確認

トレース詳細画面で以下のスパン階層が表示されます：

```
▼ http post (10ms)
  ▼ /api/orders (8ms)
    ▼ orders (5ms)  ← ここに表示される！
      └─ kafka send (2ms)
```

### スパンの詳細情報

`orders`スパンをクリックすると、以下の情報が表示されます：

- **Span Name:** `orders`
- **Span Kind:** `PRODUCER` (Kafkaプロデューサー)
- **Duration:** 約5ms
- **Attributes:**
  - `messaging.destination`: `orders`
  - `messaging.system`: `kafka`
  - `messaging.operation`: `send`

---

## 🤔 なぜKafkaコンシューマーのトレースが独立していないのか

### アーキテクチャ

```
[HTTPリクエスト] → [Camelルート] → [Kafka送信]
                                      ↓
                                   [Kafkaトピック]
                                      ↓
[別スレッド] ← [Kafkaコンシューマー] ←┘
```

### トレースの範囲

**HTTPリクエストのトレース:**
```
開始: HTTPリクエスト受信
終了: HTTPレスポンス返却
含まれるスパン:
  - HTTP処理
  - Camel REST処理
  - Kafka送信（orders スパン）
```

**Kafkaコンシューマーのトレース:**
```
開始: Kafkaメッセージ受信
終了: メッセージ処理完了
含まれるスパン:
  - validateOrder
  - processPayment
  - shipOrder
```

### なぜ分離されているか

1. **非同期処理**
   - HTTPリクエストとKafka処理は異なるスレッド
   - Kafkaは非同期メッセージング（疎結合）

2. **トレースコンテキストの伝播**
   - HTTPリクエスト内で完結するトレース
   - Kafkaコンシューマーは新しいトレースを開始するべき
   - **しかし、現在は自動的に開始されない**

---

## ✅ 期待される動作 vs 実際の動作

### 理想的な動作

```
トレース1: "http post" (10ms)
├─ HTTP処理 (5ms)
└─ Kafka送信: orders (2ms)
   traceID: ABC123

トレース2: "orders" または "kafka consumer" (800ms)
├─ Kafka受信 (10ms)
├─ validateOrder (150ms)
├─ processPayment (400ms)
└─ shipOrder (240ms)
   traceID: DEF456
   parentTraceID: ABC123  ← リンク
```

### 実際の動作

```
トレース1: "http post" (10ms)
├─ HTTP処理 (5ms)
└─ Kafka送信: orders (2ms)
   traceID: ABC123

トレース2: なし（ログには記録されているが、独立したトレースとして表示されない）
または
トレース2: 親トレースなし（孤立したトレース）
```

---

## 🛠️ Kafkaコンシューマートレースを表示させる方法

### 現状の制限

**Camel 4.8 + OpenTelemetryの制限:**
- Kafkaコンシューマールートで自動的にトレースが開始されない
- または、トレース名が正しく設定されない
- コンテキスト伝播の問題

### 解決策

#### 方法1: Camel 4.9以降にアップグレード（推奨）

Camel 4.9+では、Kafkaコンシューマーのトレーシングが改善されています。

```xml
<!-- pom.xml -->
<properties>
    <camel.version>4.9.0</camel.version>  <!-- 4.8.0 → 4.9.0 -->
</properties>
```

#### 方法2: 手動でトレースを開始（現在の設定）

現在の制限を理解して使い続ける：

**利点:**
- HTTPリクエストのトレースは完全に動作
- Kafkaプロデューサー（orders）も記録される
- ログにはすべての処理が記録される

**制限:**
- Kafkaコンシューマーの処理が独立したトレースとして表示されない
- Grafanaで視覚的に全体の流れを追跡しにくい

**対処法:**
- ログとトレースを組み合わせて使用
- trace_idでログを検索してKafka処理を確認

---

## 📖 実践: ordersスパンの確認

### コマンドライン

```bash
# 1. http postトレースを探す
TRACE_ID=$(curl -s "http://localhost:3200/api/search?limit=10" | \
  jq -r '.traces[] | select(.rootTraceName == "http post") | .traceID' | head -1)

echo "トレースID: $TRACE_ID"

# 2. そのトレースの全スパンを確認
curl -s "http://localhost:3200/api/traces/$TRACE_ID" | \
  jq '.batches[0].scopeSpans[0].spans[] | {name, kind, durationNs: (.endTimeUnixNano - .startTimeUnixNano)}'

# 出力例:
# {
#   "name": "http post",
#   "kind": "SPAN_KIND_SERVER",
#   "durationNs": 10000000
# }
# {
#   "name": "/api/orders",
#   "kind": "SPAN_KIND_SERVER",
#   "durationNs": 8000000
# }
# {
#   "name": "orders",          ← これ！
#   "kind": "SPAN_KIND_PRODUCER",
#   "durationNs": 5000000
# }
```

### Grafana UI

1. **Explore → Tempo**
2. **Search** → 最新の`http post`トレースをクリック
3. **スパン階層を展開**:
   ```
   ▼ http post
     ▼ /api/orders
       ▶ orders  ← ここをクリック
   ```
4. **ordersスパンの詳細**:
   - Operation: `send`
   - Destination: `orders`
   - Duration: ~5ms
   - Kind: `PRODUCER`

---

## 🔗 ログとトレースの連携

### Kafkaコンシューマー処理を追跡する方法

#### ステップ1: HTTPリクエストのトレースIDを取得

```bash
# Tempoから取得
TRACE_ID="abc123..."

# または、Grafanaで確認
```

#### ステップ2: Lokiでそのトレース IDのログを検索

```logql
{app="camel-observability-demo"} | json | trace_id="abc123..."
```

#### ステップ3: Kafkaコンシューマーのログを確認

ログには以下が含まれます：
```
- Kafkaからオーダーを受信しました
- オーダーを処理中: ORD-xxx
- バリデーション成功
- 支払い処理完了 (処理時間: 400ms)
- 配送完了
- オーダー処理完了
```

**これで、HTTPリクエストからKafka処理までの全体の流れが追跡できます！**

---

## 📊 まとめ

### ✅ 正しく動作しているもの

| 項目 | 状態 | 確認方法 |
|------|------|----------|
| HTTPリクエストトレース | ✅ 正常 | Tempo: `http post` |
| Kafkaプロデューサースパン | ✅ 正常 | Tempo: `orders`スパン |
| トレースID伝播 | ✅ 正常 | Loki: trace_idでログ検索 |
| ログ記録 | ✅ 正常 | Loki: すべての処理が記録 |

### ⚠️ 制限事項

| 項目 | 状態 | 回避策 |
|------|------|--------|
| Kafkaコンシューマートレース | ⚠️ 独立表示されない | ログで確認 |
| 非同期処理の可視化 | ⚠️ 限定的 | Camel 4.9+ にアップグレード |

### 🎯 結論

**`orders`は正しく記録されています！**

- Tempoの`http post`トレースを開く
- スパン階層で`orders`を確認
- Kafkaコンシューマー処理はログで追跡

完全なトレーシングを実現するには、Camel 4.9+へのアップグレードを検討してください。

---

## 🔗 関連ドキュメント

- [TRACE_ID_SEARCH_GUIDE.md](TRACE_ID_SEARCH_GUIDE.md) - トレースIDでログを検索
- [TEMPO_TROUBLESHOOTING.md](TEMPO_TROUBLESHOOTING.md) - Tempoトラブルシューティング
- [Apache Camel 4.9 Release Notes](https://camel.apache.org/blog/2024/03/camel49-whatsnew/)

---

これで、`orders`がどこに表示されているかが明確になりました！🎉

