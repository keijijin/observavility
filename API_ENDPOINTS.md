# API エンドポイント一覧

## Camel REST API

### ヘルスチェック
```bash
curl http://localhost:8080/camel/api/health
```

**レスポンス:**
```json
{"status":"UP","service":"camel-observability-demo"}
```

### メトリクス情報
```bash
curl http://localhost:8080/camel/api/metrics
```

**レスポンス:**
```json
{"message":"メトリクスは /actuator/prometheus で確認できます"}
```

### オーダー作成
```bash
curl -X POST http://localhost:8080/camel/api/orders
```

**レスポンス:**
```
Order created successfully
```

**処理フロー:**
1. オーダーが生成される（ランダムな商品、顧客、数量、価格）
2. Kafkaの `orders` トピックに送信
3. Camelコンシューマーが受信
4. バリデーション → 支払い → 配送の3ステップで処理

## Spring Boot Actuator API

### Prometheusメトリクス
```bash
curl http://localhost:8080/actuator/prometheus
```

**確認できるメトリクス:**
- `jvm_*` - JVM関連メトリクス
- `process_*` - プロセス情報
- `camel_*` - Camelルートのメトリクス（現在設定中）
- `http_server_requests_*` - HTTPリクエスト統計

### ヘルスチェック（Actuator）
```bash
curl http://localhost:8080/actuator/health
```

### アプリケーション情報
```bash
curl http://localhost:8080/actuator/info
```

### 利用可能なエンドポイント一覧
```bash
curl http://localhost:8080/actuator
```

## エンドポイント構造

```
http://localhost:8080
├── /camel/*                      # Camel REST API
│   └── /api
│       ├── /health               # Camelアプリのヘルスチェック
│       ├── /metrics              # メトリクス情報
│       └── /orders               # オーダー作成（POST）
│
└── /actuator/*                   # Spring Boot Actuator
    ├── /health                   # Actuatorヘルスチェック
    ├── /info                     # アプリケーション情報
    ├── /prometheus               # Prometheusメトリクス
    └── /metrics                  # Micrometerメトリクス
```

## Kafkaトピック

### orders トピック
- **プロデューサー**: OrderProducerRoute
- **コンシューマー**: OrderConsumerRoute
- **メッセージフォーマット**: JSON

**サンプルメッセージ:**
```json
{
  "orderId": "ORD-db623e82",
  "customerId": "CUST-004",
  "productName": "Monitor",
  "quantity": 5,
  "price": 372.15826602696905,
  "status": "CREATED",
  "timestamp": 1760416220555
}
```

### Kafkaメッセージの確認
```bash
podman exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:29092 \
  --topic orders \
  --from-beginning
```

## テストシナリオ

### 1. 基本的な動作確認
```bash
# ヘルスチェック
curl http://localhost:8080/camel/api/health

# オーダーを5件作成
for i in {1..5}; do
  curl -X POST http://localhost:8080/camel/api/orders
  echo ""
  sleep 1
done
```

### 2. メトリクスの確認
```bash
# Prometheusメトリクスを取得
curl http://localhost:8080/actuator/prometheus | grep camel

# JVMメモリ使用量
curl http://localhost:8080/actuator/prometheus | grep jvm_memory_used_bytes
```

### 3. 継続的な負荷生成
```bash
# 無限ループでオーダーを生成（Ctrl+Cで停止）
while true; do
  curl -X POST http://localhost:8080/camel/api/orders
  echo " - Order created at $(date)"
  sleep 2
done
```

## トラブルシューティング

### エンドポイントが404を返す

**症状:**
```bash
curl http://localhost:8080/api/health
# => 404 Not Found
```

**解決方法:**
正しいエンドポイントを使用：
```bash
curl http://localhost:8080/camel/api/health
```

### アプリケーションが起動しない

**確認方法:**
```bash
# アプリケーションのログを確認
tail -f camel-app/app.log

# プロセスの確認
ps aux | grep spring-boot:run
```

### Kafkaに接続できない

**確認方法:**
```bash
# Kafkaコンテナの状態確認
podman ps | grep kafka

# Kafkaのログ確認
podman logs kafka
```

## 参考リンク

- [Apache Camel REST DSL](https://camel.apache.org/components/latest/rest-dsl.html)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Micrometer Prometheus](https://micrometer.io/docs/registry/prometheus)



