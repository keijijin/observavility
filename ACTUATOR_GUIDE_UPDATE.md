# ACTUATOR_METRICS_GUIDE.md 更新完了

## 修正内容

### 1. macOS互換性の修正

すべての`grep -oP`（GNU grep専用）を`awk '{print $NF}'`（macOS/Linux両対応）に置き換えました。

**修正箇所: 13箇所 → 0箇所**

| 旧 | 新 |
|---|---|
| `grep -oP '\d+\.\d+$'` | `awk '{print $NF}'` |

---

### 2. thread_monitor.sh サンプルコードの更新

Tomcat/Undertow固有メトリクスはデフォルトで無効のため、**JVM + Executorメトリクス**を使用するバージョンに更新。

#### 変更前
```bash
# Tomcat固有メトリクス（デフォルトで無効）
tomcat_threads_current_threads
tomcat_threads_busy_threads
```

#### 変更後
```bash
# JVMスレッドメトリクス（常に有効）
jvm_threads_live_threads
jvm_threads_daemon_threads
jvm_threads_peak_threads

# Executorメトリクス（常に有効）
executor_active_threads
executor_pool_size_threads
executor_pool_max_threads
```

---

### 3. 追加した説明

#### rps_monitor.sh
```bash
# 初回測定（macOS互換）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "http_server_requests_seconds_count" | \
    grep "uri=\"$ROUTE\"" | \
    awk '{print $NF}' | \  # ← macOS対応
    head -1
}
```

#### thread_monitor.sh
```bash
> **注意**: Tomcat/Undertow固有のメトリクスはデフォルトで無効です。
> 代わりに**JVMスレッド + Executorメトリクス**を使用します。
```

---

### 4. 修正箇所の詳細

| セクション | 行番号 | 修正内容 |
|---|---|---|
| RPS計算（手動） | 53 | `awk '{print $NF}'` に変更 |
| rps_monitor.sh | 253 | `awk '{print $NF}'` に変更 |
| thread_monitor.sh | 298-384 | JVM + Executor版に全面書き換え |
| integrated_monitor.sh | 433, 441, 453-454, 459-460 | `awk '{print $NF}'` に変更 |

---

## 検証結果

### 修正前
```bash
$ grep -c 'grep -oP' ACTUATOR_METRICS_GUIDE.md
13
```

### 修正後
```bash
$ grep -c 'grep -oP' ACTUATOR_METRICS_GUIDE.md
0

$ grep -c "awk '{print \$NF}'" ACTUATOR_METRICS_GUIDE.md
16
```

---

## 利用可能なメトリクス

### ✅ 常に有効（デフォルト）

| メトリクス | 説明 |
|---|---|
| `jvm_threads_live_threads` | 稼働中のスレッド総数 |
| `jvm_threads_daemon_threads` | デーモンスレッド数 |
| `jvm_threads_peak_threads` | ピークスレッド数 |
| `executor_active_threads` | HTTPリクエスト処理中のスレッド |
| `executor_pool_size_threads` | 現在のプールサイズ |
| `executor_pool_max_threads` | 最大スレッド数 |

### ❌ デフォルトで無効

| メトリクス | 有効化方法 |
|---|---|
| `tomcat_threads_*` | 追加設定が必要（Spring Boot 3.x） |
| `undertow_*` | Undertowへの切り替えが必要 |

---

## 追加の修正: Camel REST DSL対応

### 5. rps_monitor.sh の URI="UNKNOWN" 問題

**問題**: Camel REST DSLを使用しているため、Spring BootのHTTPメトリクスでURIが`UNKNOWN`として記録される。

```bash
http_server_requests_seconds_count{...,method="POST",uri="UNKNOWN",} 15309.0
```

**原因**: Camelは内部的にServletを使用しており、Spring BootのHTTPメトリクス収集機構がCamelの動的ルーティング情報を取得できない。

**解決策**: Camelの`camel_exchanges_total`メトリクスを使用する新しいスクリプトを作成。

#### 新規作成: rps_monitor_camel_route.sh

```bash
#!/bin/bash

# Camelルート別RPSモニタリングスクリプト
# Camelメトリクスを使用してルート単位で正確に監視

INTERVAL=${1:-5}
ROUTE_ID=${2:-"order-consumer-route"}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

# Camelルート処理数を取得（macOS互換）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "camel_exchanges_total" | \
    grep "routeId=\"$ROUTE_ID\"" | \
    awk '{print $NF}' | \
    head -1
}
```

---

## テスト方法

### 1. RPSモニタリング（Camel対応・推奨✅）

```bash
cd /Users/kjin/mobills/observability/demo

# Camelルート監視（推奨）
./rps_monitor_camel_route.sh

# 別のルート
./rps_monitor_camel_route.sh 5 "payment-processing-route"

# オーダー作成ルート
./rps_monitor_camel_route.sh 3 "create-order-route"
```

**利用可能なCamelルート**:
- `create-order-route` - オーダー作成（REST API）
- `order-consumer-route` - Kafkaメッセージ受信
- `validate-order-route` - オーダーバリデーション
- `payment-processing-route` - 支払い処理
- `shipping-route` - 配送準備

### 2. RPSモニタリング（従来版）

```bash
# Actuatorエンドポイント監視（Camel以外）
./rps_monitor.sh 3 "/actuator/health"
```

> **注意**: `/camel/api/orders` は `uri="UNKNOWN"` として記録されるため、従来の `rps_monitor.sh` では正確に監視できません。Camelルート版（`rps_monitor_camel_route.sh`）を使用してください。

### 3. スレッド監視

```bash
# デフォルト（5秒間隔）
./thread_monitor.sh

# カスタム間隔
./thread_monitor.sh 3
```

### 4. ガイドのサンプルコードをコピー＆実行

```bash
# ACTUATOR_METRICS_GUIDE.md からコピーして実行
# すべてmacOS/Linux両対応
```

### 5. 負荷テスト

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

---

## 作成したスクリプト

| ファイル | サイズ | 説明 | 推奨度 |
|---|---|---|---|
| `rps_monitor.sh` | 1.1K | 従来版（Actuatorエンドポイント監視） | ⚠️ Camel以外 |
| `rps_monitor_camel_route.sh` | 1.4K | Camel対応版（ルート単位監視） | ✅ 推奨 |
| `thread_monitor.sh` | 2.4K | JVM + Executorスレッド監視 | ✅ 推奨 |

---

## メトリクス比較

### HTTPメトリクス vs Camelメトリクス

| メトリクス | 対象 | Camel REST DSL | 正確性 |
|---|---|---|---|
| `http_server_requests_seconds_count{uri="/path"}` | Spring MVC | ❌ uri="UNKNOWN" | ⚠️ 不正確 |
| `camel_exchanges_total{routeId="..."}` | Camel Routes | ✅ ルート単位 | ✅ 正確 |

**結論**: Camelアプリケーションでは`camel_exchanges_total`を使用してください。

---

## まとめ

| 項目 | 状態 |
|---|---|
| **macOS互換性** | ✅ 完全対応 |
| **grep -oP** | ❌ 0箇所（全削除） |
| **awk '{print $NF}'** | ✅ 16箇所（推奨） |
| **thread_monitor.sh** | ✅ JVM + Executor版に更新 |
| **rps_monitor_camel_route.sh** | ✅ 新規作成（Camel対応） |
| **URI="UNKNOWN" 問題** | ✅ 解決（Camelメトリクス使用） |
| **サンプルコード** | ✅ すべて実行可能 |

---

## 関連ドキュメント

- **RPS_MONITOR_CAMEL.md** (6.5K) - Camel REST DSL問題の詳細解説
- **THREAD_MONITOR_FIX.md** (4.9K) - thread_monitor.sh修正詳細
- **MACOS_GREP_FIX.md** (5.6K) - grep互換性問題の詳細

---

**作成日**: 2025-10-20  
**最終更新**: 2025-10-20  
**対象**: `ACTUATOR_METRICS_GUIDE.md`、`rps_monitor_camel_route.sh`  
**修正理由**: macOS互換性の確保、Tomcat/Undertowメトリクスの有効性、Camel REST DSL対応

