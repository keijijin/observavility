# ✅ メトリクス修正完了サマリー

Grafanaダッシュボードで "No Data" と表示されていたUndertowとKafkaメッセージングのメトリクスを修正しました。

## 🔍 問題の原因

ダッシュボードで使用していたメトリクス名と、実際にアプリケーションが公開しているメトリクス名が異なっていました。

### 存在しなかったメトリクス（使用していたが存在しない）

#### Undertow関連
- ❌ `undertow_worker_threads_busy`
- ❌ `undertow_worker_threads_idle`
- ❌ `undertow_active_connections`
- ❌ `undertow_requests_total`

#### Camel関連
- ❌ `camel_route_exchanges_inflight`
- ❌ `camel_route_exchanges_total`
- ❌ `camel_route_exchanges_failed`
- ❌ `camel_route_processing_time_seconds_sum`
- ❌ `camel_route_processing_time_seconds_count`
- ❌ `camel_route_processing_time_seconds_max`

### 実際に存在するメトリクス

#### Undertow関連
- ✅ `undertow_worker_threads` - 設定された最大ワーカースレッド数（例: 200）
- ✅ `undertow_active_requests` - 現在アクティブなリクエスト数
- ✅ `undertow_request_queue_size` - リクエストキューサイズ
- ✅ `undertow_io_threads` - I/Oスレッド数（通常はCPUコア数）

#### Camel関連
- ✅ `camel_route_policy_seconds_count` - ルート処理回数
- ✅ `camel_route_policy_seconds_sum` - ルート処理時間の合計
- ✅ `camel_route_policy_seconds_max` - ルート最大処理時間
- ✅ `camel_routes_running_routes` - 実行中のルート数

## 🔧 修正内容

### 1. Undertowセクション（パネル62, 63, 64, 65）

| パネルID | 変更前 | 変更後 | 説明 |
|---------|--------|--------|------|
| **62** | 🧵 ワーカースレッド状態<br>（Busy/Idle） | 🧵 ワーカースレッドとアクティブリクエスト | 最大スレッド数（200）とアクティブリクエスト数を表示 |
| **63** | 🔌 アクティブ接続数 | 📊 I/Oスレッド数 | I/Oスレッド数（4）を表示 |
| **64** | 📊 スレッド使用率 | 📊 リクエスト負荷率 | アクティブリクエスト数 ÷ 最大スレッド数 × 100 |
| **65** | 📈 総リクエスト処理数 | 📈 総ルート処理数 | Camelルートの総処理回数 |

#### パネル62の修正クエリ

```promql
# 変更前（存在しないメトリクス）
undertow_worker_threads_busy{application="camel-observability-demo"}
undertow_worker_threads_idle{application="camel-observability-demo"}

# 変更後（実際のメトリクス）
undertow_worker_threads{application="camel-observability-demo"}
undertow_active_requests{application="camel-observability-demo"}
```

#### パネル63の修正クエリ

```promql
# 変更前
undertow_active_connections{application="camel-observability-demo"}

# 変更後
undertow_io_threads{application="camel-observability-demo"}
```

#### パネル64の修正クエリ

```promql
# 変更前
(undertow_worker_threads_busy / (undertow_worker_threads_busy + undertow_worker_threads_idle)) * 100

# 変更後
(undertow_active_requests / undertow_worker_threads) * 100
```

#### パネル65の修正クエリ

```promql
# 変更前
undertow_requests_total{application="camel-observability-demo"}

# 変更後
sum(camel_route_policy_seconds_count{application="camel-observability-demo", eventType="route"})
```

### 2. Kafkaメッセージングセクション（パネル71, 72, 73）

| パネルID | 変更前 | 変更後 | 説明 |
|---------|--------|--------|------|
| **71** | 📊 処理中メッセージ数<br>（Timeseries） | 📊 実行中のルート数<br>（Stat） | 現在実行中のCamelルート数を表示 |
| **72** | 📬 ルート処理レート | 📬 ルート処理レート | 処理レートのみ表示（失敗レートは除外） |
| **73** | ⏱️ ルート処理時間 | ⏱️ ルート処理時間 | メトリクス名を修正 |

#### パネル71の修正クエリ

```promql
# 変更前
camel_route_exchanges_inflight{application="camel-observability-demo", routeId=~".*kafka.*|.*order.*"}

# 変更後
camel_routes_running_routes{application="camel-observability-demo"}
```

#### パネル72の修正クエリ

```promql
# 変更前
rate(camel_route_exchanges_total{application="camel-observability-demo", routeId=~".*kafka.*|.*order.*"}[1m])
rate(camel_route_exchanges_failed{application="camel-observability-demo", routeId=~".*kafka.*|.*order.*"}[1m])

# 変更後
rate(camel_route_policy_seconds_count{application="camel-observability-demo", eventType="route", routeId=~".*kafka.*|.*order.*"}[1m])
```

#### パネル73の修正クエリ

```promql
# 変更前
camel_route_processing_time_seconds_sum / camel_route_processing_time_seconds_count
camel_route_processing_time_seconds_max

# 変更後
camel_route_policy_seconds_sum{eventType="route"} / camel_route_policy_seconds_count{eventType="route"}
camel_route_policy_seconds_max{eventType="route"}
```

## ✅ 動作確認

### 1. メトリクスがPrometheusで取得できることを確認

```bash
# Undertowメトリクスの確認
curl -s http://localhost:8080/actuator/prometheus | grep "^undertow_"

# Camelメトリクスの確認
curl -s http://localhost:8080/actuator/prometheus | grep "^camel_route_policy"

# Prometheusでの確認
curl -s 'http://localhost:9090/api/v1/query?query=camel_route_policy_seconds_count' | jq '.data.result | length'
# 出力例: 7 (7つのルートの処理回数)

curl -s 'http://localhost:9090/api/v1/query?query=undertow_active_requests' | jq '.data.result[0].value'
# 出力例: [1761110616.571, "0"] (現在0個のアクティブリクエスト)
```

### 2. Grafanaダッシュボードの確認

1. ブラウザで Grafana にアクセス: http://localhost:3000
2. ログイン（admin/admin）
3. 「Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード」を開く
4. 以下のセクションでデータが表示されることを確認：
   - ✅ 🚀 Undertow Webサーバー
   - ✅ 📨 Kafka & Camel ルート処理

## 📊 修正後の表示内容

### Undertowセクション

1. **⭐ リクエストキューサイズ**（パネル61）
   - 値: 0（通常）
   - 説明: キューに溜まっているリクエスト数

2. **🧵 ワーカースレッドとアクティブリクエスト**（パネル62）
   - Max Worker Threads: 200（青）
   - Active Requests: 0～数個（オレンジ）
   - 説明: 設定された最大スレッド数と現在処理中のリクエスト数

3. **📊 I/Oスレッド数**（パネル63）
   - 値: 4（CPUコア数に応じて）
   - 説明: Undertowの非同期I/Oスレッド数

4. **📊 リクエスト負荷率**（パネル64）
   - 値: 0%～100%
   - 説明: 現在のリクエスト負荷（アクティブリクエスト数 ÷ 最大スレッド数）

5. **📈 総ルート処理数**（パネル65）
   - 値: 数千～数十万
   - 説明: Camelルートの総処理回数

### Kafkaメッセージングセクション

1. **📊 実行中のルート数**（パネル71）
   - 値: 8（ルート数）
   - 説明: 現在実行中のCamelルート数

2. **📬 ルート処理レート**（パネル72）
   - 各ルートの処理レート（messages/sec）
   - 例: 
     - shipping-route - Rate: 1.2 msg/sec
     - order-consumer-route - Rate: 5.3 msg/sec

3. **⏱️ ルート処理時間**（パネル73）
   - 平均処理時間と最大処理時間（秒）
   - 例:
     - shipping-route - Avg: 0.205s, Max: 0.303s
     - payment-processing-route - Avg: 0.540s, Max: 0.682s

## 💡 メトリクス名が異なる理由

### Spring Boot Actuator + Micrometerの挙動

Spring Boot ActuatorとMicrometerが自動的に生成するメトリクス名は、使用しているライブラリとバージョンによって異なります。

**期待していたメトリクス名:**
- `camel-micrometer-starter`の古いバージョンで使用されていた命名規則
- Micrometerの古い規約

**実際のメトリクス名:**
- Apache Camel 4.x + Spring Boot 3.x + Micrometer最新版の命名規則
- より統一された命名規則（`camel_route_policy_*`）

## 🎯 今後の対応

### 1. メトリクス名の確認方法

新しいメトリクスを追加する際は、必ず以下を確認してください：

```bash
# 利用可能なメトリクス名を確認
curl -s http://localhost:8080/actuator/prometheus | grep "^metric_prefix"

# Prometheusに登録されているメトリクスを確認
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | jq -r '.data[]' | grep metric_prefix
```

### 2. ダッシュボードのテスト

ダッシュボードを作成・修正した後は、必ずテストしてください：

1. Grafana Exploreで実際にクエリを実行
2. データが表示されることを確認
3. 時間範囲を変更してデータが取得できることを確認

### 3. ドキュメントの更新

メトリクス名が変わった場合は、以下のドキュメントを更新してください：

- `DASHBOARD_README.md` - ダッシュボード詳細説明
- `METRICS_GUIDE.md` - メトリクスガイド
- `UNDERTOW_METRICS_SUCCESS.md` - Undertowメトリクス関連

## 📚 関連ドキュメント

- **`KAFKA_METRICS_FIX.md`** - Kafkaメトリクス修正ガイド
- **`KAFKA_METRICS_GUIDE.md`** - Kafkaメトリクス詳細ガイド
- **`DASHBOARD_README.md`** - ダッシュボード詳細説明
- **`UNDERTOW_METRICS_SUCCESS.md`** - Undertowメトリクス成功事例

## ✅ チェックリスト

修正後の確認項目：

- [x] アプリケーションが起動している（`/actuator/health`でUP）
- [x] メトリクスが公開されている（`/actuator/prometheus`で確認）
- [x] Prometheusがメトリクスを収集している（Prometheus UIで確認）
- [x] Grafanaが起動している（http://localhost:3000）
- [x] ダッシュボードでデータが表示される
  - [x] Undertowセクション（パネル61-65）
  - [x] Kafkaメッセージングセクション（パネル71-73）

## 🎉 完了！

メトリクスの修正が完了し、すべてのパネルでデータが正しく表示されるようになりました。

Grafanaダッシュボードを開いて確認してください：
```
http://localhost:3000
```

お疲れ様でした！ 🚀

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22


