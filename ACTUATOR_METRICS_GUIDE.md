# Actuator メトリクス取得ガイド 📊

## 目次

1. [ルート毎の秒間リクエスト数（RPS）](#1-ルート毎の秒間リクエスト数rps)
2. [Undertow スレッド数とキューサイズ](#2-undertow-スレッド数とキューサイズ)
3. [CLI スクリプト](#3-cli-スクリプト)

---

## 1. ルート毎の秒間リクエスト数（RPS）

### 📊 Actuator エンドポイント

#### 基本メトリクス

```bash
# すべてのメトリクス名を取得
curl -s http://localhost:8080/actuator/metrics | jq '.names[] | select(contains("http"))'

# HTTPリクエストカウント（累積）
curl -s http://localhost:8080/actuator/metrics/http.server.requests | jq .
```

#### ルート別リクエスト数（累積）

```bash
# すべてのルートのリクエスト数
curl -s http://localhost:8080/actuator/prometheus | grep "http_server_requests_seconds_count"

# 特定のルートのみ
curl -s http://localhost:8080/actuator/prometheus | grep "http_server_requests_seconds_count" | grep "uri=\"/camel/api/orders\""
```

#### 出力例

```
# TYPE http_server_requests_seconds_count counter
http_server_requests_seconds_count{application="camel-observability-demo",error="none",exception="none",method="POST",outcome="SUCCESS",status="200",uri="/camel/api/orders",} 1234.0
http_server_requests_seconds_count{application="camel-observability-demo",error="none",exception="none",method="GET",outcome="SUCCESS",status="200",uri="/actuator/health",} 567.0
```

---

### 🔄 秒間リクエスト数（RPS）の計算

Prometheusメトリクスは**累積カウント**のため、RPSを計算するには2回測定して差分を取ります。

#### 方法1: 手動計算

```bash
# 1回目の測定（macOS互換: awkを使用）
BEFORE=$(curl -s http://localhost:8080/actuator/prometheus | grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | awk '{print $NF}')
echo "Before: $BEFORE"

# 5秒待機
sleep 5

# 2回目の測定
AFTER=$(curl -s http://localhost:8080/actuator/prometheus | grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | awk '{print $NF}')
echo "After: $AFTER"

# RPSを計算
RPS=$(echo "scale=2; ($AFTER - $BEFORE) / 5" | bc)
echo "RPS: $RPS req/sec"
```

#### 方法2: Camel ルートメトリクス

Camelルートの処理数も確認できます：

```bash
# Camelルートの処理数（累積）
curl -s http://localhost:8080/actuator/prometheus | grep "camel_exchanges_total"

# 特定のルート
curl -s http://localhost:8080/actuator/prometheus | grep "camel_exchanges_total" | grep "routeId=\"create-order-route\""
```

---

### 📈 Grafana でのRPS確認（推奨）

PrometheusとGrafanaを使用すると、リアルタイムでRPSを確認できます。

#### PromQL クエリ

```promql
# ルート別のRPS（直近1分間の平均）
rate(http_server_requests_seconds_count{uri="/camel/api/orders"}[1m])

# ルート別のRPS（直近5分間の平均）
rate(http_server_requests_seconds_count{uri="/camel/api/orders"}[5m])

# すべてのルートのRPS合計
sum(rate(http_server_requests_seconds_count[1m])) by (uri)

# メソッド別RPS
sum(rate(http_server_requests_seconds_count[1m])) by (method, uri)
```

#### Grafana での確認手順

1. Grafana を開く: http://localhost:3000
2. **Explore** に移動
3. データソース: **Prometheus** を選択
4. クエリを入力:
   ```promql
   rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
   ```
5. **Run query** をクリック

---

## 2. Undertow スレッド数とキューサイズ

> **注意**: このデモアプリケーションは**組み込みTomcat**を使用しています。Undertowを使用する場合は、依存関係を変更する必要があります。

### 🔧 Undertow への切り替え（オプション）

#### pom.xml の変更

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <!-- Tomcatを除外 -->
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<!-- Undertowを追加 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-undertow</artifactId>
</dependency>
```

#### application.yml の設定

```yaml
server:
  undertow:
    threads:
      io: 4                    # I/Oスレッド数（通常はCPUコア数）
      worker: 200              # ワーカースレッド数（最大）
    buffer-size: 1024          # バッファサイズ（バイト）
    direct-buffers: true       # ダイレクトバッファを使用
```

---

### 📊 Undertow メトリクスの取得

#### Actuator エンドポイント

```bash
# Undertow関連のメトリクス名を取得
curl -s http://localhost:8080/actuator/metrics | jq '.names[] | select(contains("undertow"))'

# ワーカースレッド数
curl -s http://localhost:8080/actuator/metrics/undertow.worker.threads | jq .

# アクティブなリクエスト数
curl -s http://localhost:8080/actuator/metrics/undertow.active.requests | jq .

# キュー数
curl -s http://localhost:8080/actuator/metrics/undertow.request.queue.size | jq .
```

#### Prometheus形式で取得

```bash
# Undertowメトリクス
curl -s http://localhost:8080/actuator/prometheus | grep "undertow"

# スレッド数
curl -s http://localhost:8080/actuator/prometheus | grep "undertow_worker_threads"

# アクティブリクエスト
curl -s http://localhost:8080/actuator/prometheus | grep "undertow_active_requests"
```

---

### 🔍 現在使用中のサーバー（Tomcat）のメトリクス

Tomcatを使用している場合のメトリクス：

```bash
# Tomcat関連のメトリクス名を取得
curl -s http://localhost:8080/actuator/metrics | jq '.names[] | select(contains("tomcat"))'

# Tomcatスレッド数
curl -s http://localhost:8080/actuator/metrics/tomcat.threads.current | jq .

# Tomcat最大スレッド数
curl -s http://localhost:8080/actuator/metrics/tomcat.threads.config.max | jq .

# ビジースレッド数
curl -s http://localhost:8080/actuator/metrics/tomcat.threads.busy | jq .
```

#### Prometheus形式

```bash
# すべてのTomcatメトリクス
curl -s http://localhost:8080/actuator/prometheus | grep "tomcat_threads"

# 現在のスレッド数
curl -s http://localhost:8080/actuator/prometheus | grep "tomcat_threads_current_threads"

# 最大スレッド数
curl -s http://localhost:8080/actuator/prometheus | grep "tomcat_threads_config_max_threads"

# ビジースレッド数
curl -s http://localhost:8080/actuator/prometheus | grep "tomcat_threads_busy_threads"
```

---

## 3. CLI スクリプト

### 📜 ルート別RPSモニタリングスクリプト

> **⚠️ Camel REST DSLの制限**: Camel REST DSLを使用している場合、Spring BootのHTTPメトリクスでURIが`UNKNOWN`として記録されます。詳細は「Camel対応版」セクションを参照してください。

#### rps_monitor.sh（従来版）

> **注意**: このスクリプトは**Spring MVC**や**Actuatorエンドポイント**の監視に適しています。Camel REST API（`/camel/api/*`）の監視には`rps_monitor_camel_route.sh`を使用してください。

```bash
#!/bin/bash

# ルート別RPSモニタリングスクリプト
# 使い方: ./rps_monitor.sh [interval_seconds] [route_uri]

INTERVAL=${1:-5}
ROUTE=${2:-"/actuator/health"}  # デフォルトをActuatorに変更
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== ルート別RPSモニタリング ==="
echo "ルート: $ROUTE"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# 初回測定（macOS互換）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "http_server_requests_seconds_count" | \
    grep "uri=\"$ROUTE\"" | \
    awk '{print $NF}' | \
    head -1
}

while true; do
    BEFORE=$(get_count)
    
    if [ -z "$BEFORE" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE"
        echo ""
        echo "原因:"
        echo "  - アプリケーションが起動していない"
        echo "  - ルートにリクエストがまだ来ていない（累積カウント=0）"
        echo ""
        echo "確認: curl http://localhost:8080/actuator/health"
        sleep $INTERVAL
        continue
    fi
    
    sleep $INTERVAL
    
    AFTER=$(get_count)
    
    if [ -z "$AFTER" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE"
        continue
    fi
    
    RPS=$(echo "scale=2; ($AFTER - $BEFORE) / $INTERVAL" | bc)
    TOTAL=$(printf "%.0f" "$AFTER")
    
    echo "$(date '+%H:%M:%S') - RPS: $RPS req/sec | 累積: $TOTAL requests"
done
```

#### 使い方

```bash
# デフォルト（/actuator/health、5秒間隔）
./rps_monitor.sh

# カスタム間隔とルート
./rps_monitor.sh 10 "/actuator/info"
```

---

### 📜 Camel対応版RPSモニタリングスクリプト ✅ 推奨

#### rps_monitor_camel_route.sh

**Camel REST DSL**を使用している場合、このスクリプトを使用してください。Camelの`camel_exchanges_total`メトリクスを使用してルート単位で正確に監視します。

```bash
#!/bin/bash

# Camelルート別RPSモニタリングスクリプト
# 使い方: ./rps_monitor_camel_route.sh [interval_seconds] [route_id]

INTERVAL=${1:-5}
ROUTE_ID=${2:-"order-consumer-route"}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== Camel ルート RPSモニタリング ==="
echo "ルート: $ROUTE_ID"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# Camelルート処理数を取得（macOS互換）
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
        curl -s "$ACTUATOR_URL" | grep "camel_exchanges_total" | awk -F'routeId="' '{print $2}' | awk -F'"' '{print "  - " $1}' | sort -u | head -10
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
# デフォルト（order-consumer-route、5秒間隔）
./rps_monitor_camel_route.sh

# 別のルート（オーダー作成）
./rps_monitor_camel_route.sh 5 "create-order-route"

# 支払い処理ルート（3秒間隔）
./rps_monitor_camel_route.sh 3 "payment-processing-route"
```

#### 利用可能なCamelルート

| ルートID | 説明 |
|---|---|
| `create-order-route` | オーダー作成（REST API） |
| `order-consumer-route` | Kafkaからのメッセージ受信 |
| `validate-order-route` | オーダーバリデーション |
| `payment-processing-route` | 支払い処理 |
| `shipping-route` | 配送準備 |
| `auto-order-generator` | 自動オーダー生成タイマー |

#### Camelルート一覧を取得

```bash
# 利用可能なすべてのCamelルートを表示
curl -s http://localhost:8080/actuator/prometheus | \
  grep "camel_exchanges_total" | \
  awk -F'routeId="' '{print $2}' | \
  awk -F'"' '{print $1}' | \
  sort -u
```

---

### 🔍 HTTPメトリクス vs Camelメトリクス

| メトリクス | 対象 | Camel REST DSL | 正確性 | 使用推奨 |
|---|---|---|---|---|
| `http_server_requests_seconds_count{uri="/path"}` | Spring MVC | ❌ uri="UNKNOWN" | ⚠️ 不正確 | Spring MVC |
| `camel_exchanges_total{routeId="..."}` | Camel Routes | ✅ ルート単位 | ✅ 正確 | **Camel（推奨）** |

**Camel REST DSLの問題**:
```bash
# /camel/api/orders にリクエストを送信しても...
http_server_requests_seconds_count{...,method="POST",uri="UNKNOWN",} 15309.0

# URIが "UNKNOWN" として記録される
```

**解決策**: Camelメトリクスを使用
```bash
# Camelルート単位で正確に監視できる
camel_exchanges_total{routeId="create-order-route"} 52768.0
```

---

### 📜 サーバースレッド監視スクリプト

#### thread_monitor.sh

> **注意**: Tomcat/Undertow固有のメトリクスはデフォルトで無効です。代わりに**JVMスレッド + Executorメトリクス**を使用します。

```bash
#!/bin/bash

# スレッド監視スクリプト（JVM + Executor）
# 使い方: ./thread_monitor.sh [interval_seconds]

INTERVAL=${1:-5}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== JVM & Executor スレッド監視 ==="
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# アプリケーションが起動しているか確認
check_app() {
    if ! curl -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL" 2>/dev/null | grep -q "200"; then
        echo "❌ エラー: アプリケーションにアクセスできません"
        echo ""
        echo "確認方法:"
        echo "  curl http://localhost:8080/actuator/health"
        echo ""
        echo "起動方法:"
        echo "  1. ローカル環境: podman-compose up -d"
        echo "  2. スタンドアロン: mvn spring-boot:run"
        exit 1
    fi
}

check_app

echo "✅ アプリケーション接続成功"
echo ""
echo "監視項目:"
echo "  - JVMスレッド（全体）"
echo "  - Executor（Tomcat/Undertowのワーカースレッドプール）"
echo ""

while true; do
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # JVMスレッドメトリクス（macOS互換）
    LIVE=$(curl -s "$ACTUATOR_URL" | grep "^jvm_threads_live_threads{" | awk '{print $NF}' | head -1)
    DAEMON=$(curl -s "$ACTUATOR_URL" | grep "^jvm_threads_daemon_threads{" | awk '{print $NF}' | head -1)
    PEAK=$(curl -s "$ACTUATOR_URL" | grep "^jvm_threads_peak_threads{" | awk '{print $NF}' | head -1)
    
    # Executorメトリクス（Tomcat/Undertowのワーカープール）
    EXECUTOR_ACTIVE=$(curl -s "$ACTUATOR_URL" | grep "^executor_active_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_SIZE=$(curl -s "$ACTUATOR_URL" | grep "^executor_pool_size_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_MAX=$(curl -s "$ACTUATOR_URL" | grep "^executor_pool_max_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_CORE=$(curl -s "$ACTUATOR_URL" | grep "^executor_pool_core_threads{" | awk '{print $NF}' | head -1)
    
    # 整数変換
    LIVE_INT=$(printf "%.0f" "$LIVE" 2>/dev/null || echo "0")
    DAEMON_INT=$(printf "%.0f" "$DAEMON" 2>/dev/null || echo "0")
    PEAK_INT=$(printf "%.0f" "$PEAK" 2>/dev/null || echo "0")
    EXECUTOR_ACTIVE_INT=$(printf "%.0f" "$EXECUTOR_ACTIVE" 2>/dev/null || echo "0")
    EXECUTOR_POOL_SIZE_INT=$(printf "%.0f" "$EXECUTOR_POOL_SIZE" 2>/dev/null || echo "0")
    EXECUTOR_POOL_MAX_INT=$(printf "%.0f" "$EXECUTOR_POOL_MAX" 2>/dev/null || echo "0")
    EXECUTOR_POOL_CORE_INT=$(printf "%.0f" "$EXECUTOR_POOL_CORE" 2>/dev/null || echo "0")
    
    # 非デーモンスレッド
    NON_DAEMON=$((LIVE_INT - DAEMON_INT))
    
    # Executor使用率
    if [ "$EXECUTOR_POOL_MAX_INT" -gt 0 ]; then
        EXECUTOR_USAGE=$(echo "scale=1; ($EXECUTOR_ACTIVE_INT / $EXECUTOR_POOL_MAX_INT) * 100" | bc 2>/dev/null || echo "0")
    else
        EXECUTOR_USAGE="N/A"
    fi
    
    echo "[$TIMESTAMP]"
    echo "  JVMスレッド:"
    echo "    Live: $LIVE_INT | Daemon: $DAEMON_INT | Non-Daemon: $NON_DAEMON | Peak: $PEAK_INT"
    echo "  Executor（Webサーバーワーカープール）:"
    if [ "$EXECUTOR_POOL_MAX_INT" -gt 0 ]; then
        echo "    Active: $EXECUTOR_ACTIVE_INT | Pool Size: $EXECUTOR_POOL_SIZE_INT | Max: $EXECUTOR_POOL_MAX_INT | Core: $EXECUTOR_POOL_CORE_INT | Usage: ${EXECUTOR_USAGE}%"
    else
        echo "    ⚠️  Executorメトリクス取得不可（Webサーバー起動直後またはメトリクス未対応）"
    fi
    echo ""
    
    sleep $INTERVAL
done
```

#### 使い方

```bash
# デフォルト（5秒間隔）
./thread_monitor.sh

# カスタム間隔
./thread_monitor.sh 10
```

---

### 📜 統合監視スクリプト

#### integrated_monitor.sh

```bash
#!/bin/bash

# 統合監視スクリプト（RPS + スレッド）
# 使い方: ./integrated_monitor.sh [interval_seconds]

INTERVAL=${1:-5}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"
ROUTE="/camel/api/orders"

echo "=== 統合監視ダッシュボード ==="
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# サーバータイプを検出
if curl -s "$ACTUATOR_URL" | grep -q "tomcat_threads"; then
    SERVER_TYPE="tomcat"
elif curl -s "$ACTUATOR_URL" | grep -q "undertow_worker_threads"; then
    SERVER_TYPE="undertow"
else
    echo "エラー: サーバータイプを検出できませんでした"
    exit 1
fi

echo "サーバータイプ: $SERVER_TYPE"
echo ""
printf "%-8s | %-15s | %-30s\n" "Time" "RPS" "Threads"
printf "%-8s-+-%-15s-+-%-30s\n" "--------" "---------------" "------------------------------"

# 初回測定（macOS互換）
BEFORE_COUNT=$(curl -s "$ACTUATOR_URL" | grep "http_server_requests_seconds_count" | grep "uri=\"$ROUTE\"" | awk '{print $NF}' | head -1)

while true; do
    sleep $INTERVAL
    
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # RPS計算（macOS互換）
    AFTER_COUNT=$(curl -s "$ACTUATOR_URL" | grep "http_server_requests_seconds_count" | grep "uri=\"$ROUTE\"" | awk '{print $NF}' | head -1)
    
    if [ -n "$BEFORE_COUNT" ] && [ -n "$AFTER_COUNT" ]; then
        RPS=$(echo "scale=2; ($AFTER_COUNT - $BEFORE_COUNT) / $INTERVAL" | bc)
    else
        RPS="N/A"
    fi
    
    BEFORE_COUNT=$AFTER_COUNT
    
    # スレッド情報（macOS互換）
    if [ "$SERVER_TYPE" == "tomcat" ]; then
        BUSY=$(curl -s "$ACTUATOR_URL" | grep "tomcat_threads_busy_threads" | awk '{print $NF}' | head -1)
        MAX=$(curl -s "$ACTUATOR_URL" | grep "tomcat_threads_config_max_threads" | awk '{print $NF}' | head -1)
        BUSY_INT=$(printf "%.0f" "$BUSY")
        MAX_INT=$(printf "%.0f" "$MAX")
        THREAD_INFO="Busy: $BUSY_INT/$MAX_INT"
    else
        ACTIVE=$(curl -s "$ACTUATOR_URL" | grep "undertow_active_requests" | awk '{print $NF}' | head -1)
        WORKER=$(curl -s "$ACTUATOR_URL" | grep "undertow_worker_threads" | awk '{print $NF}' | head -1)
        ACTIVE_INT=$(printf "%.0f" "$ACTIVE")
        WORKER_INT=$(printf "%.0f" "$WORKER")
        THREAD_INFO="Active: $ACTIVE_INT/$WORKER_INT"
    fi
    
    printf "%-8s | %-15s | %-30s\n" "$TIMESTAMP" "$RPS req/sec" "$THREAD_INFO"
done
```

---

## 4. OpenShift での使用

### Pod内でメトリクスを取得

```bash
# Podにログイン
oc exec -it deployment/camel-app -- bash

# Actuatorエンドポイントにアクセス
curl http://localhost:8080/actuator/prometheus | grep "http_server_requests_seconds_count"

# Tomcatスレッド情報
curl http://localhost:8080/actuator/prometheus | grep "tomcat_threads"
```

### 外部から取得（Route経由）

```bash
# RouteのURLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# メトリクスを取得
curl -k "https://$CAMEL_URL/actuator/prometheus" | grep "http_server_requests_seconds_count"

# Tomcatスレッド情報
curl -k "https://$CAMEL_URL/actuator/prometheus" | grep "tomcat_threads"
```

---

## 5. まとめ

### ルート別RPS

| 方法 | コマンド | 対象 | 特徴 |
|---|---|---|---|
| Actuator（累積） | `curl /actuator/prometheus \| grep http_server_requests_seconds_count` | Spring MVC | 累積値のみ |
| 手動計算 | 2回測定して差分を計算 | すべて | 簡単だが手間 |
| CLIスクリプト（従来版） | `./rps_monitor.sh` | Spring MVC | 自動的に継続監視 |
| **CLIスクリプト（Camel版）** | `./rps_monitor_camel_route.sh` | **Camel REST DSL** | **✅ Camel推奨** |
| Grafana | `rate(http_server_requests_seconds_count[1m])` | Spring MVC | リアルタイム、グラフ表示 |
| **Grafana（Camel）** | `rate(camel_exchanges_total[1m])` | **Camel Routes** | **✅ Camel推奨** |

### Tomcat/Undertow スレッド

| メトリクス | Tomcat | Undertow | JVM（常に有効） |
|---|---|---|---|
| 現在のスレッド数 | `tomcat.threads.current` | `undertow.worker.threads` | `jvm_threads_live_threads` |
| 最大スレッド数 | `tomcat.threads.config.max` | application.yml設定 | `executor_pool_max_threads` |
| ビジー/アクティブ | `tomcat.threads.busy` | `undertow.active.requests` | `executor_active_threads` |
| キューサイズ | N/A | `undertow.request.queue.size` | N/A |

> **注意**: Tomcat/Undertow固有メトリクスはデフォルトで無効です。JVM + Executorメトリクスの使用を推奨します。

### スクリプト選択ガイド

| アプリケーション種別 | 推奨スクリプト | 理由 |
|---|---|---|
| **Camel REST DSL** | `rps_monitor_camel_route.sh` | HTTPメトリクスでuri="UNKNOWN"になる |
| **Spring MVC** | `rps_monitor.sh` | HTTPメトリクスで正確なURIが記録される |
| **Actuatorエンドポイント** | `rps_monitor.sh` | HTTPメトリクスで正確なURIが記録される |
| **スレッド監視** | `thread_monitor.sh` | JVM + Executorメトリクスを使用 |

---

## 📚 参考リンク

- Spring Boot Actuator: https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html
- Micrometer Metrics: https://micrometer.io/docs
- Prometheus Querying: https://prometheus.io/docs/prometheus/latest/querying/basics/

---

お疲れ様でした！ 🚀

