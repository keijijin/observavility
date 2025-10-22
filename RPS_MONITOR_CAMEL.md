# rps_monitor.sh のURI問題と解決策

## 問題

```bash
http_server_requests_seconds_count{...,method="POST",uri="UNKNOWN",} 15309.0
```

`/camel/api/orders`にリクエストを送信しているのに、Spring BootのHTTPメトリクスでURIが`UNKNOWN`として記録されています。

---

## 原因

**Camel REST DSL**を使用しているため、Spring BootのHTTPメトリクスがURIパスを正しく認識できません。

Camelは内部的にServletを使用しており、Spring BootのHTTPメトリクス収集機構がCamelのルーティング情報を取得できていないためです。

---

## 解決策

### 方法1: URIを"UNKNOWN"として監視（簡単）

`rps_monitor.sh`を修正して、`uri="UNKNOWN"`のPOSTリクエストを監視します。

#### 修正版 rps_monitor.sh

```bash
#!/bin/bash

# ルート別RPSモニタリングスクリプト（Camel対応）
# 使い方: ./rps_monitor_camel.sh [interval_seconds]

INTERVAL=${1:-5}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== Camel ルート RPSモニタリング ==="
echo "監視対象: POST リクエスト（Camel REST API）"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# カウント取得（UNKNOWN URIのPOSTリクエスト）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "http_server_requests_seconds_count" | \
    grep 'method="POST"' | \
    grep 'uri="UNKNOWN"' | \
    grep 'status="200"' | \
    awk '{print $NF}' | \
    head -1
}

while true; do
    BEFORE=$(get_count)
    
    if [ -z "$BEFORE" ]; then
        echo "$(date '+%H:%M:%S') - ❌ メトリクスが見つかりません"
        echo "  確認: curl http://localhost:8080/actuator/health"
        sleep $INTERVAL
        continue
    fi
    
    sleep $INTERVAL
    
    AFTER=$(get_count)
    
    if [ -z "$AFTER" ]; then
        echo "$(date '+%H:%M:%S') - ❌ メトリクスが見つかりません"
        continue
    fi
    
    RPS=$(echo "scale=2; ($AFTER - $BEFORE) / $INTERVAL" | bc)
    TOTAL=$(printf "%.0f" "$AFTER")
    
    echo "$(date '+%H:%M:%S') - RPS: $RPS req/sec | 累積: $TOTAL requests (POST /camel/api/orders)"
done
```

#### 使い方

```bash
cd /Users/kjin/mobills/observability/demo

# 実行
./rps_monitor_camel.sh

# カスタム間隔
./rps_monitor_camel.sh 3
```

---

### 方法2: Camelメトリクスを使用（推奨✅）

Camelの`camel_exchanges_total`メトリクスを使用します。こちらの方が正確です。

#### Camelメトリクス版 rps_monitor.sh

```bash
#!/bin/bash

# Camelルート別RPSモニタリングスクリプト
# 使い方: ./rps_monitor_camel_route.sh [interval_seconds] [route_id]

INTERVAL=${1:-5}
ROUTE_ID=${2:-"create-order-route"}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== Camel ルート RPSモニタリング ==="
echo "ルート: $ROUTE_ID"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# Camelルート処理数を取得
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "camel_exchanges_total" | \
    grep "routeId=\"$ROUTE_ID\"" | \
    awk '{print $NF}' | \
    head -1
}

while true; do
    BEFORE=$(get_count)
    
    if [ -z "$BEFORE" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE_ID"
        echo ""
        echo "利用可能なルート:"
        curl -s "$ACTUATOR_URL" | grep "camel_exchanges_total" | grep -oP 'routeId="\K[^"]+' | sort -u | head -10
        sleep $INTERVAL
        continue
    fi
    
    sleep $INTERVAL
    
    AFTER=$(get_count)
    
    if [ -z "$AFTER" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE_ID"
        continue
    fi
    
    RPS=$(echo "scale=2; ($AFTER - $BEFORE) / $INTERVAL" | bc)
    TOTAL=$(printf "%.0f" "$AFTER")
    
    echo "$(date '+%H:%M:%S') - RPS: $RPS msg/sec | 累積: $TOTAL messages"
done
```

#### 使い方

```bash
# デフォルト（create-order-route）
./rps_monitor_camel_route.sh

# 別のルート（order-consumer-route）
./rps_monitor_camel_route.sh 5 "order-consumer-route"

# 支払い処理ルート
./rps_monitor_camel_route.sh 3 "payment-processing-route"
```

---

## 利用可能なCamelルート

```bash
# 利用可能なルート一覧を取得
curl -s http://localhost:8080/actuator/prometheus | \
  grep "camel_exchanges_total" | \
  grep -oP 'routeId="\K[^"]+' | \
  sort -u
```

**主要ルート**:
- `create-order-route` - オーダー作成
- `order-consumer-route` - Kafkaからのメッセージ受信
- `validate-order-route` - オーダーバリデーション
- `payment-processing-route` - 支払い処理
- `shipping-route` - 配送準備

---

## 比較

| 方法 | メトリクス | 正確性 | 使いやすさ |
|---|---|---|---|
| **方法1** | `http_server_requests_seconds_count{uri="UNKNOWN"}` | ⚠️ すべてのPOSTリクエストを含む | ✅ シンプル |
| **方法2** | `camel_exchanges_total{routeId="..."}` | ✅ ルート単位で正確 | ✅ ルートIDの指定が必要 |

---

## テスト方法

### 1. スクリプトを実行

```bash
cd /Users/kjin/mobills/observability/demo

# 方法1: UNKNOWN URI版
./rps_monitor_camel.sh

# 方法2: Camelルート版（推奨）
./rps_monitor_camel_route.sh
```

### 2. 別のターミナルで負荷をかける

```bash
# 10回リクエストを送信（1秒間隔）
for i in {1..10}; do 
  curl -X POST http://localhost:8080/camel/api/orders \
    -H 'Content-Type: application/json' \
    -d "{\"customerId\":\"TEST-$i\",\"productName\":\"Product-$i\",\"quantity\":1,\"price\":100}" \
    -s -o /dev/null -w "Request $i: %{http_code}\n"
  sleep 1
done
```

### 3. 出力例

```
=== Camel ルート RPSモニタリング ===
ルート: order-consumer-route
測定間隔: 5秒
Ctrl+C で終了

10:30:15 - RPS: 2.00 msg/sec | 累積: 52780 messages
10:30:20 - RPS: 1.60 msg/sec | 累積: 52788 messages
10:30:25 - RPS: 2.20 msg/sec | 累積: 52799 messages
```

---

## まとめ

| 問題 | 解決策 |
|---|---|
| `uri="UNKNOWN"`で記録される | ✅ 方法1または方法2を使用 |
| `/camel/api/orders`が見つからない | ✅ Camelメトリクスを使用（方法2推奨） |
| ルート単位で監視したい | ✅ `camel_exchanges_total`を使用 |

**推奨**: 方法2（Camelメトリクス版）を使用してください。ルート単位で正確な監視が可能です。

---

**作成日**: 2025-10-20  
**対象**: `rps_monitor.sh` のURI問題  
**理由**: Camel REST DSLを使用しているため、Spring BootのHTTPメトリクスでURIが正しく記録されない


