# SpringBoot + Camel + Kafka 分散アプリケーション メトリクスガイド

## 📊 観測すべきメトリクスの全体像

分散アプリケーションの健全性とパフォーマンスを監視するために、以下の6つのカテゴリに分けてメトリクスを整理します。

---

## 1️⃣ Camelルート メトリクス

### 🎯 目的
- ルートの処理状況を把握
- ボトルネックとエラーを検知
- スループットを監視

### 📈 主要メトリクス

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `camel_exchanges_total` | 総メッセージ処理数 | ⭐⭐⭐ |
| `camel_exchanges_succeeded_total` | 成功したメッセージ数 | ⭐⭐⭐ |
| `camel_exchanges_failed_total` | 失敗したメッセージ数 | ⭐⭐⭐ |
| `camel_exchanges_inflight` | 処理中のメッセージ数 | ⭐⭐⭐ |
| `camel_routes_running_routes` | 実行中のルート数 | ⭐⭐ |
| `camel_route_policy_seconds_sum` | ルート処理時間（合計） | ⭐⭐⭐ |
| `camel_route_policy_seconds_count` | ルート処理回数 | ⭐⭐ |
| `camel_route_policy_seconds_max` | ルート最大処理時間 | ⭐⭐⭐ |

### 🔍 推奨クエリ

```promql
# メッセージ処理レート（req/sec）
rate(camel_exchanges_total[1m])

# エラー率（%）
(rate(camel_exchanges_failed_total[1m]) / rate(camel_exchanges_total[1m])) * 100

# 平均処理時間（秒）
rate(camel_route_policy_seconds_sum[1m]) / rate(camel_route_policy_seconds_count[1m])

# 成功率（%）
(rate(camel_exchanges_succeeded_total[1m]) / rate(camel_exchanges_total[1m])) * 100
```

---

## 2️⃣ Kafka メトリクス

### 🎯 目的
- Kafkaプロデューサー/コンシューマーのパフォーマンス監視
- メッセージの遅延とスループットを把握
- コネクション状態を監視

### 📈 主要メトリクス

Spring Kafkaが提供するメトリクス：

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `kafka_consumer_fetch_manager_records_consumed_total` | 消費したレコード総数 | ⭐⭐⭐ |
| `kafka_consumer_fetch_manager_records_lag` | コンシューマーラグ | ⭐⭐⭐ |
| `kafka_consumer_coordinator_commit_latency_avg` | コミットレイテンシ平均 | ⭐⭐ |
| `kafka_producer_topic_record_send_total` | 送信したレコード総数 | ⭐⭐⭐ |
| `kafka_producer_record_error_total` | プロデューサーエラー数 | ⭐⭐⭐ |
| `kafka_producer_compression_rate_avg` | 圧縮率平均 | ⭐ |

### 🔍 推奨クエリ

```promql
# Kafka消費レート（msg/sec）
rate(kafka_consumer_fetch_manager_records_consumed_total[1m])

# Kafkaプロデューサー送信レート（msg/sec）
rate(kafka_producer_topic_record_send_total[1m])

# コンシューマーラグ（メッセージ数）
kafka_consumer_fetch_manager_records_lag

# プロデューサーエラー率（%）
(rate(kafka_producer_record_error_total[1m]) / rate(kafka_producer_topic_record_send_total[1m])) * 100
```

**注意:** 本デモ環境では、Kafkaメトリクスを有効にするために追加の依存関係が必要です。

---

## 3️⃣ JVMメモリ メトリクス

### 🎯 目的
- メモリリークの検知
- ガベージコレクションの監視
- OOMエラーの予防

### 📈 主要メトリクス

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `jvm_memory_used_bytes` | 使用中メモリ量 | ⭐⭐⭐ |
| `jvm_memory_max_bytes` | 最大メモリ量 | ⭐⭐ |
| `jvm_memory_committed_bytes` | コミット済みメモリ量 | ⭐⭐ |
| `jvm_gc_pause_seconds_count` | GC実行回数 | ⭐⭐⭐ |
| `jvm_gc_pause_seconds_sum` | GC累積時間 | ⭐⭐⭐ |
| `jvm_gc_overhead_percent` | GCオーバーヘッド率 | ⭐⭐⭐ |
| `jvm_gc_memory_allocated_bytes_total` | 割り当てられたメモリ総量 | ⭐⭐ |

### 🔍 推奨クエリ

```promql
# ヒープメモリ使用率（%）
(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) * 100

# GC実行頻度（回/分）
rate(jvm_gc_pause_seconds_count[1m]) * 60

# GC平均時間（秒）
rate(jvm_gc_pause_seconds_sum[1m]) / rate(jvm_gc_pause_seconds_count[1m])

# メモリ割り当てレート（bytes/sec）
rate(jvm_gc_memory_allocated_bytes_total[1m])
```

---

## 4️⃣ JVMスレッド メトリクス

### 🎯 目的
- スレッドリークの検知
- デッドロックの監視
- スレッドプールの最適化

### 📈 主要メトリクス

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `jvm_threads_live_threads` | アクティブスレッド数 | ⭐⭐⭐ |
| `jvm_threads_daemon_threads` | デーモンスレッド数 | ⭐⭐ |
| `jvm_threads_peak_threads` | ピークスレッド数 | ⭐⭐ |
| `jvm_threads_states_threads` | スレッド状態別数 | ⭐⭐ |

### 🔍 推奨クエリ

```promql
# アクティブスレッド数
jvm_threads_live_threads

# デッドロック検知（BLOCKED状態のスレッド）
jvm_threads_states_threads{state="blocked"}

# スレッド増加率（threads/sec）
rate(jvm_threads_started_threads_total[1m])
```

---

## 5️⃣ HTTPリクエスト メトリクス

### 🎯 目的
- APIエンドポイントのパフォーマンス監視
- エラー率の監視
- レイテンシの追跡

### 📈 主要メトリクス

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `http_server_requests_seconds_count` | リクエスト総数 | ⭐⭐⭐ |
| `http_server_requests_seconds_sum` | リクエスト処理時間合計 | ⭐⭐⭐ |
| `http_server_requests_seconds_max` | 最大処理時間 | ⭐⭐⭐ |
| `http_server_requests_active_seconds_*` | アクティブリクエスト | ⭐⭐ |

### 🔍 推奨クエリ

```promql
# リクエストレート（req/sec）
rate(http_server_requests_seconds_count[1m])

# 平均レスポンスタイム（秒）
rate(http_server_requests_seconds_sum[1m]) / rate(http_server_requests_seconds_count[1m])

# エラー率（4xx + 5xx）（%）
(rate(http_server_requests_seconds_count{status=~"[45].."}[1m]) / rate(http_server_requests_seconds_count[1m])) * 100

# P95レイテンシ（秒）
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[1m]))

# エンドポイント別リクエスト数
sum by (uri) (rate(http_server_requests_seconds_count[1m]))
```

---

## 6️⃣ システム/プロセス メトリクス

### 🎯 目的
- アプリケーションの可用性監視
- システムリソース使用状況の把握
- 異常終了の検知

### 📈 主要メトリクス

| メトリクス名 | 説明 | 重要度 |
|------------|------|--------|
| `process_uptime_seconds` | アプリケーション稼働時間 | ⭐⭐⭐ |
| `process_cpu_usage` | CPU使用率 | ⭐⭐⭐ |
| `system_cpu_usage` | システムCPU使用率 | ⭐⭐ |
| `system_load_average_1m` | システム負荷（1分平均） | ⭐⭐ |
| `jvm_classes_loaded_classes` | ロードされたクラス数 | ⭐ |

### 🔍 推奨クエリ

```promql
# アプリケーション稼働時間（時間）
process_uptime_seconds / 3600

# CPU使用率（%）
process_cpu_usage * 100

# システム負荷平均
system_load_average_1m
```

---

## 🚨 アラート推奨閾値

### クリティカルアラート（即座の対応が必要）

```promql
# メモリ使用率が90%超
(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.9

# エラー率が10%超
(rate(camel_exchanges_failed_total[5m]) / rate(camel_exchanges_total[5m])) > 0.1

# HTTPエラー率が5%超
(rate(http_server_requests_seconds_count{status=~"5.."}[5m]) / rate(http_server_requests_seconds_count[5m])) > 0.05

# コンシューマーラグが1000メッセージ超
kafka_consumer_fetch_manager_records_lag > 1000
```

### 警告アラート（注意が必要）

```promql
# メモリ使用率が70%超
(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.7

# GCオーバーヘッドが10%超
jvm_gc_overhead_percent > 10

# 平均レスポンスタイムが1秒超
(rate(http_server_requests_seconds_sum[5m]) / rate(http_server_requests_seconds_count[5m])) > 1

# 処理中メッセージが100超
camel_exchanges_inflight > 100
```

---

## 📊 ダッシュボード構成推奨

### レイアウト案

```
┌─────────────────────────────────────────────────────────────┐
│ Row 1: システム概要（4パネル）                                    │
│  [稼働時間] [CPU使用率] [メモリ使用率] [アクティブスレッド]          │
├─────────────────────────────────────────────────────────────┤
│ Row 2: Camelルートパフォーマンス（3パネル）                        │
│  [メッセージ処理レート] [エラー率] [平均処理時間]                   │
├─────────────────────────────────────────────────────────────┤
│ Row 3: Kafka（3パネル）                                        │
│  [消費レート] [プロデューサー送信レート] [コンシューマーラグ]         │
├─────────────────────────────────────────────────────────────┤
│ Row 4: HTTPエンドポイント（2パネル）                              │
│  [リクエストレート（エンドポイント別）] [レスポンスタイム分布]        │
├─────────────────────────────────────────────────────────────┤
│ Row 5: JVMメモリ詳細（2パネル）                                  │
│  [ヒープメモリ使用量推移] [GC実行頻度と時間]                       │
├─────────────────────────────────────────────────────────────┤
│ Row 6: 処理フロー（1パネル）                                     │
│  [メッセージフロー全体図]                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 メトリクス優先度マトリックス

| カテゴリ | 本番環境必須 | 開発環境推奨 | トラブルシューティング |
|---------|------------|------------|---------------------|
| Camelルート | ✅ | ✅ | ✅ |
| Kafka | ✅ | ✅ | ✅ |
| JVMメモリ | ✅ | ✅ | ✅ |
| JVMスレッド | ✅ | ⚠️ | ✅ |
| HTTPリクエスト | ✅ | ✅ | ✅ |
| システム/プロセス | ✅ | ⚠️ | ✅ |

---

## 📚 参考資料

- [Micrometer Documentation](https://micrometer.io/docs)
- [Spring Boot Actuator Metrics](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.metrics)
- [Apache Camel Metrics](https://camel.apache.org/components/latest/micrometer-component.html)
- [Kafka Monitoring](https://kafka.apache.org/documentation/#monitoring)

---

このガイドに基づいて、包括的なGrafanaダッシュボードを作成しました：
👉 **[camel-comprehensive-dashboard.json](docker/grafana/provisioning/dashboards/camel-comprehensive-dashboard.json)**



