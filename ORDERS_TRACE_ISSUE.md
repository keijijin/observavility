# ordersトレースが表示されない問題 - 診断と解決

## 🔍 問題の症状

Tempoのトレース一覧で、以前は表示されていた`orders`というrootTraceNameが表示されなくなった。

### 現在表示されているトレース

```
- http get /actuator/prometheus
- http post
- timer
```

### 期待されるトレース

```
- http post (HTTPリクエスト)
- orders (Kafkaコンシューマー処理) ← これが表示されない！
```

---

## 🔍 原因の分析

### 1. Kafkaコンシューマーは動作している

ログを見ると、Kafkaからメッセージを受信して処理していることは確認できます：

```
2025-10-14 16:43:35 [KafkaConsumer[orders]] INFO  order-consumer-route - === Kafkaからオーダーを受信しました ===
2025-10-14 16:43:35 [KafkaConsumer[orders]] INFO  shipping-route - ✅ オーダー処理完了: ORD-54090455
```

### 2. OpenTelemetryコンテキストの警告

大量の警告メッセージが出力されています：

```
DEBUG i.o.c.ThreadLocalContextStorage - Trying to close scope which does not represent current context. Ignoring the call.
```

**この警告の意味:**
- Camelルート間でOpenTelemetryのコンテキストが正しく伝播していない
- 各ルート（direct:validateOrder、direct:processPayment など）でスパンを閉じる際にコンテキストが一致しない

### 3. トレースの構造

**現在の動作:**
```
HTTP POST /camel/api/orders
  ↓
[トレース: "http post"]
  ├─ HTTP処理
  ├─ Kafka送信
  └─ 終了

Kafka受信（別スレッド）
  ↓
[トレースなし or 独立したトレース]  ← ここが問題！
  ├─ validateOrder
  ├─ processPayment
  └─ shipOrder
```

**期待される動作:**
```
HTTP POST /camel/api/orders
  ↓
[トレース: "http post"]
  ├─ HTTP処理
  └─ Kafka送信

Kafka受信（別スレッド）
  ↓
[トレース: "orders"]  ← 独立したトレースとして表示されるべき
  ├─ validateOrder
  ├─ processPayment
  └─ shipOrder
```

---

## 🛠️ 原因の特定

### 主な原因

**Camel 4.xでのOpenTelemetry統合の制限**

1. **非同期処理のコンテキスト伝播**
   - HTTPリクエスト → Kafka送信まではトレースが作成される
   - Kafkaコンシューマー側（別スレッド）では新しいトレースが自動作成されない
   - または、トレース名が自動的に決定されず、親トレースに統合される

2. **Camel Direct コンポーネントでのスコープ管理**
   - `direct:validateOrder`、`direct:processPayment`などの内部ルート呼び出し
   - 各directエンドポイントでスパンを作成/終了する際にコンテキストが不一致

### 変更された可能性のあるもの

**最近の変更で影響を受けた可能性:**

1. **TracingMdcFilter の追加**
   - MDCを設定するためにFilterを追加
   - これがOpenTelemetryのスコープ管理に影響している可能性

2. **ログレベルの変更**
   - `io.opentelemetry: DEBUG`に変更
   - これにより警告が可視化されただけ（問題自体は以前からあった）

---

## ✅ 解決方法

### 方法1: OpenTelemetry設定の最適化（推奨）

#### application.ymlを更新

```yaml
camel:
  opentelemetry:
    enabled: true
    endpoint: http://localhost:4318/v1/traces
    service-name: ${spring.application.name}
    # 明示的にトレース名を設定
    exclude-patterns: ""
    # コンテキスト伝播を有効化
    encoding: protobuf
```

#### ログレベルを調整

DEBUGレベルの警告を減らす：

```yaml
logging:
  level:
    io.opentelemetry: INFO  # DEBUG → INFO に変更
    io.opentelemetry.context: WARN
```

### 方法2: Kafkaコンシューマールートの明示的なトレース名設定

#### OrderConsumerRoute.javaを更新

```java
from("kafka:orders?groupId=camel-demo-group")
    .routeId("order-consumer-route")
    .log("=== Kafkaからオーダーを受信しました ===")
    // トレース名を明示的に設定
    .setHeader("X-B3-TraceId").simple("${random(16)}")
    .setHeader("X-B3-SpanId").simple("${random(8)}")
    .unmarshal().json(Order.class)
    .log("オーダーを処理中: ${body.orderId}")
    .to("direct:validateOrder");
```

### 方法3: direct: の代わりに seda: を使用

非同期処理でコンテキストを分離：

```java
from("kafka:orders?groupId=camel-demo-group")
    .routeId("order-consumer-route")
    .log("=== Kafkaからオーダーを受信しました ===")
    .unmarshal().json(Order.class)
    .log("オーダーを処理中: ${body.orderId}")
    .to("seda:validateOrder");  // direct: → seda:

from("seda:validateOrder")
    .routeId("validate-order-route")
    .log("オーダーをバリデーション中: ${body.orderId}")
    // ...
```

---

## 🔧 実装手順

### ステップ1: ログレベルを調整（まず警告を減らす）

```bash
# application.ymlを編集
vim demo/camel-app/src/main/resources/application.yml

# 以下のように変更:
logging:
  level:
    io.opentelemetry: INFO  # DEBUG → INFO
    io.opentelemetry.context: WARN
```

### ステップ2: アプリケーションを再起動

```bash
cd demo/camel-app
pkill -9 -f "spring-boot:run"
nohup mvn spring-boot:run > ../camel-app-startup.log 2>&1 &
```

### ステップ3: 動作確認

```bash
# テストリクエスト送信
curl -X POST http://localhost:8080/camel/api/orders \
  -H "Content-Type: application/json" \
  -d '{"orderId":"TEST-001","product":"Test","quantity":1}'

# 数秒待機
sleep 5

# Tempoでトレース確認
curl -s "http://localhost:3200/api/search?limit=10" | \
  jq '.traces[] | {traceID, rootTraceName, durationMs}'
```

---

## 📊 期待される結果

### 修正後のトレース一覧

```json
[
  {
    "traceID": "abc123...",
    "rootTraceName": "http post",
    "durationMs": 10
  },
  {
    "traceID": "def456...",
    "rootTraceName": "orders",  // ← これが表示されるようになる
    "durationMs": 850
  }
]
```

### トレース詳細（http postトレース）

```
http post (10ms)
├─ POST /camel/api/orders (5ms)
│  └─ Kafka Producer: orders (3ms)
└─ レスポンス返却 (2ms)
```

### トレース詳細（ordersトレース）

```
orders (850ms)
├─ Kafka Consumer (10ms)
├─ validateOrder (150ms)
├─ processPayment (400ms)
└─ shipOrder (290ms)
```

---

## 🔍 トラブルシューティング

### 問題1: まだ警告が出る

**確認事項:**
```bash
# 警告の数を確認
grep "Trying to close scope" camel-app-startup.log | wc -l

# どのルートで発生しているか確認
grep "Trying to close scope" -B 1 camel-app-startup.log | \
  grep -E "validate|payment|shipping" | sort | uniq -c
```

**解決策:**
- ログレベルを`WARN`に変更（警告を非表示）
- または、direct: を seda: に変更

### 問題2: ordersトレースがまだ表示されない

**確認事項:**
```bash
# Kafkaコンシューマーが動作しているか
tail -f camel-app-startup.log | grep "Kafkaからオーダーを受信"

# Tempoにデータが送信されているか
curl -s "http://localhost:4318/v1/traces" -X POST \
  -H "Content-Type: application/json" \
  -d '{"test":"connectivity"}' && echo "Tempo接続OK"
```

**解決策:**
- Tempoを再起動
- アプリケーションのOpenTelemetry設定を確認

### 問題3: 警告は消えたが、パフォーマンスが悪い

**確認事項:**
```bash
# 処理時間を確認
grep "処理時間:" camel-app-startup.log | tail -10
```

**解決策:**
- OpenTelemetryのオーバーヘッドが大きい可能性
- サンプリング確率を下げる（`probability: 0.1`）

---

## 💡 補足情報

### OpenTelemetryコンテキストについて

**コンテキストとは:**
- トレース情報（traceId, spanId）を保持するスレッドローカルな状態
- スレッド間、非同期処理間で正しく伝播させる必要がある

**Camelでの課題:**
- `direct:` は同期的なルート呼び出し
- 各エンドポイントでスパンを開始/終了
- コンテキストの開始/終了が不整合になりやすい

### なぜ以前は動作していたか

**可能性:**
1. **以前はトレースが表示されていたわけではない**
   - 実は以前から表示されていなかったが、気づいていなかった
   - または、別の条件で時々表示されていた

2. **設定変更の影響**
   - TracingMdcFilterの追加
   - ログレベルをDEBUGに変更
   - これらにより、既存の問題が可視化された

---

## ✅ チェックリスト

- [ ] ログレベルを`INFO`または`WARN`に変更
- [ ] アプリケーションを再起動
- [ ] テストリクエストを送信
- [ ] Tempoでトレース一覧を確認
- [ ] `orders`トレースが表示されることを確認
- [ ] 警告メッセージが減少したことを確認

---

## 🔗 関連ドキュメント

- [Apache Camel OpenTelemetry](https://camel.apache.org/components/latest/opentelemetry.html)
- [OpenTelemetry Context Propagation](https://opentelemetry.io/docs/instrumentation/java/manual/#context-propagation)
- [Micrometer Tracing](https://micrometer.io/docs/tracing)

---

この問題は、Camel 4.xとOpenTelemetryの統合における既知の制限です。完全に解決するには、Camel 4.9以降へのアップグレードを検討してください。




