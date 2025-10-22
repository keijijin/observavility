# 📨 Kafka メトリクス設定ガイド

統合ダッシュボードのKafkaメッセージングセクションでメトリクスを表示するための設定ガイドです。

## ❌ 問題：Kafkaメトリクスが表示されない

統合ダッシュボードの「📨 Kafka メッセージング」セクションで "No Data" と表示される場合の対処方法を説明します。

## 🔍 原因

Apache Camelで`camel-kafka`コンポーネントを使用する場合、以下の2つのレベルのメトリクスがあります：

### 1. Camelルートレベルのメトリクス ✅ 利用可能
- Camel自身が提供するルート処理のメトリクス
- `camel-micrometer-starter`で自動的に収集される
- メトリクス名の例：
  - `camel_route_exchanges_total`
  - `camel_route_processing_time_seconds`

### 2. Kafka Clientレベルのメトリクス ❌ デフォルトでは利用不可
- Kafka Producer/Consumerが提供する低レベルメトリクス
- JMX経由で公開される
- メトリクス名の例：
  - `kafka_producer_metrics_record_send_total`
  - `kafka_consumer_fetch_manager_records_lag_max`

**現在のダッシュボードはKafka Clientレベルのメトリクスを使用しており、追加設定が必要です。**

## ✅ 解決策

以下の3つの解決策から選択してください：

### 解決策1: JMX Exporterを使用（推奨）

Kafka ClientsのJMXメトリクスをPrometheusフォーマットで公開します。

#### 1.1 JMX Exporterの追加

`pom.xml`に依存関係を追加：

```xml
<!-- JMX Prometheus Exporter -->
<dependency>
    <groupId>io.prometheus.jmx</groupId>
    <artifactId>jmx_prometheus_javaagent</artifactId>
    <version>0.20.0</version>
</dependency>
```

#### 1.2 JMX設定ファイルの作成

`camel-app/src/main/resources/jmx-exporter-config.yml`:

```yaml
---
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - kafka.producer:*
  - kafka.consumer:*
  - kafka.admin.client:*
rules:
  # Producer メトリクス
  - pattern: kafka.producer<type=producer-metrics, client-id=(.+)><>(.+)
    name: kafka_producer_metrics_$2
    labels:
      client_id: "$1"
  - pattern: kafka.producer<type=producer-topic-metrics, client-id=(.+), topic=(.+)><>(.+)
    name: kafka_producer_topic_metrics_$3
    labels:
      client_id: "$1"
      topic: "$2"
  
  # Consumer メトリクス
  - pattern: kafka.consumer<type=consumer-fetch-manager-metrics, client-id=(.+)><>(.+)
    name: kafka_consumer_fetch_manager_$2
    labels:
      client_id: "$1"
  - pattern: kafka.consumer<type=consumer-fetch-manager-metrics, client-id=(.+), topic=(.+), partition=(.+)><>(.+)
    name: kafka_consumer_fetch_manager_$4
    labels:
      client_id: "$1"
      topic: "$2"
      partition: "$3"
  - pattern: kafka.consumer<type=consumer-coordinator-metrics, client-id=(.+)><>(.+)
    name: kafka_consumer_coordinator_$2
    labels:
      client_id: "$1"
```

#### 1.3 アプリケーション起動時にJavaAgentを追加

**ローカル版** (`run-local.sh` を更新):

```bash
#!/bin/bash

# ログディレクトリの作成
mkdir -p logs

# 環境変数の設定
export LOG_PATH="$(pwd)/logs"
export LOKI_URL="http://localhost:3100/loki/api/v1/push"

# JMX Exporterを使用してアプリケーションを起動
mvn clean spring-boot:run \
  -Dspring-boot.run.jvmArguments="-javaagent:target/lib/jmx_prometheus_javaagent-0.20.0.jar=9999:src/main/resources/jmx-exporter-config.yml"
```

**OpenShift版** (Deployment YAMLを更新):

```yaml
env:
  - name: JAVA_OPTS
    value: "-javaagent:/app/lib/jmx_prometheus_javaagent.jar=9999:/app/config/jmx-exporter-config.yml"
```

### 解決策2: Camelルートメトリクスを使用（簡単）

ダッシュボードを修正して、Camelルートレベルのメトリクスを使用します。

#### 2.1 ダッシュボードのクエリを変更

`camel-comprehensive-dashboard.json`の以下のパネルを修正：

**パネル71: Kafka Consumer Lag → Camel Route処理中メッセージ数**

```json
{
  "expr": "camel_route_exchanges_inflight{application=\"camel-observability-demo\", routeId=~\".*kafka.*\"}",
  "legendFormat": "{{routeId}} - Inflight"
}
```

**パネル72: Kafka メッセージレート → Camelルート処理レート**

```json
{
  "expr": "rate(camel_route_exchanges_total{application=\"camel-observability-demo\", routeId=~\".*kafka.*\"}[1m])",
  "legendFormat": "{{routeId}} - Rate"
}
```

**パネル73: Kafka レイテンシ → Camelルート処理時間**

```json
{
  "expr": "camel_route_processing_time_seconds_sum{application=\"camel-observability-demo\", routeId=~\".*kafka.*\"} / camel_route_processing_time_seconds_count{application=\"camel-observability-demo\", routeId=~\".*kafka.*\"}",
  "legendFormat": "{{routeId}} - Avg Processing Time"
}
```

### 解決策3: Spring Kafkaに移行（高度）

Apache CamelのKafkaコンポーネントの代わりにSpring Kafkaを使用します。

#### 3.1 依存関係の追加

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

#### 3.2 Kafkaメトリクスの有効化

`application.yml`に既に追加済み：

```yaml
management:
  metrics:
    enable:
      kafka.consumer: true
      kafka.producer: true
```

#### 3.3 Camel RouteをSpring Kafka Listenerに置き換え

詳細は省略しますが、大規模な変更が必要です。

## 🎯 推奨アプローチ

現在のプロジェクト状態に基づいて、**解決策2（Camelルートメトリクスを使用）** を推奨します。

### 理由

- ✅ 追加の依存関係が不要
- ✅ 既存のコードを変更する必要がない
- ✅ すぐに動作する
- ✅ Camelの観点から見たメトリクスの方が実用的

### 実装手順

1. 修正されたダッシュボードを適用（下記参照）
2. Grafanaを再起動
3. メトリクスの確認

## 🔧 修正済みダッシュボード設定

以下のパッチを適用済みのダッシュボードを用意しました。

### 変更内容

**📨 Kafkaメッセージング** セクションのタイトルを変更：
- 新タイトル: **📨 Kafka & Camel ルート処理**

**パネルのクエリを更新：**

1. **Consumer Lag → 処理中メッセージ数**
2. **メッセージレート → ルート処理レート**
3. **レイテンシ → 処理時間**

## 📊 利用可能なCamelメトリクス

以下のメトリクスが自動的に収集されます：

| メトリクス名 | 説明 | 型 |
|---|---|---|
| `camel_route_exchanges_total` | 総処理数 | Counter |
| `camel_route_exchanges_failed` | 失敗数 | Counter |
| `camel_route_exchanges_inflight` | 処理中 | Gauge |
| `camel_route_processing_time_seconds_sum` | 処理時間合計 | Counter |
| `camel_route_processing_time_seconds_count` | 処理回数 | Counter |
| `camel_route_processing_time_seconds_max` | 最大処理時間 | Gauge |

すべてのメトリクスには以下のラベルが付きます：
- `application`: アプリケーション名
- `routeId`: CamelルートID
- `camelContext`: Camelコンテキスト名

## 🧪 動作確認

### 1. メトリクスの確認

```bash
# Actuatorエンドポイントで確認
curl http://localhost:8080/actuator/metrics | jq '.names[] | select(. | contains("camel"))'

# Prometheusエンドポイントで確認
curl http://localhost:8080/actuator/prometheus | grep camel_route
```

### 2. Prometheusで確認

```bash
# Prometheus UIで以下を実行
http://localhost:9090

# クエリ例
camel_route_exchanges_total{application="camel-observability-demo"}
```

### 3. Grafanaで確認

1. ダッシュボードを開く
2. 「📨 Kafka & Camel ルート処理」セクションを確認
3. データが表示されることを確認

## 🔍 トラブルシューティング

### メトリクスが全く表示されない

```bash
# 1. アプリケーションが起動しているか確認
curl http://localhost:8080/actuator/health

# 2. Prometheusエンドポイントが有効か確認
curl http://localhost:8080/actuator/prometheus

# 3. Camelルートが動作しているか確認
curl http://localhost:8080/actuator/metrics/camel.routes

# 4. Prometheusがメトリクスを収集しているか確認
curl http://localhost:9090/api/v1/query?query=camel_route_exchanges_total
```

### 特定のルートのメトリクスだけが表示されない

```bash
# ルート一覧を確認
curl http://localhost:8080/actuator/camel/routes | jq '.[] | .id'

# 特定のルートのメトリクスを確認
curl http://localhost:8080/actuator/prometheus | grep 'routeId="your-route-id"'
```

### Prometheusが古いメトリクスを表示している

```bash
# Prometheusの設定を確認
curl http://localhost:9090/api/v1/status/config

# scrape_intervalが適切か確認（デフォルト: 15s）
```

## 📝 次のステップ

1. ✅ `application.yml`を更新（既に完了）
2. ✅ ダッシュボードを修正（次のセクションで実施）
3. ⏳ アプリケーションを再起動
4. ⏳ Grafanaでメトリクスを確認

## 📚 関連ドキュメント

- **Apache Camel Metrics**: https://camel.apache.org/components/latest/micrometer-component.html
- **Micrometer Kafka**: https://micrometer.io/docs/registry/prometheus
- **JMX Exporter**: https://github.com/prometheus/jmx_exporter
- **Spring Boot Actuator**: https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

