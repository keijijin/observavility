# ✅ Kafkaメトリクス修正完了

統合ダッシュボードの「📨 Kafka メッセージング」セクションで "No Data" と表示される問題を修正しました。

## 🔧 修正内容

### 1. ダッシュボードの修正

**変更前：** Kafka Client レベルのメトリクス（利用不可）
**変更後：** Camel Route レベルのメトリクス（利用可能）

### 2. セクション名の変更

- **変更前**: 📨 Kafka メッセージング
- **変更後**: 📨 Kafka & Camel ルート処理

### 3. パネルの修正

#### パネル71: 📊 処理中メッセージ数
- **変更前**: `kafka_consumer_fetch_manager_records_lag_max` (Kafka Consumer Lag)
- **変更後**: `camel_route_exchanges_inflight` (Camelルートの処理中メッセージ数)
- **説明**: 現在Camelルートで処理中のメッセージ数を表示

#### パネル72: 📬 ルート処理レート
- **変更前**: 
  - `kafka_producer_metrics_record_send_total` (Producer Send Rate)
  - `kafka_consumer_fetch_manager_records_consumed_total` (Consumer Consume Rate)
- **変更後**: 
  - `camel_route_exchanges_total` (ルート処理レート)
  - `camel_route_exchanges_failed` (ルート失敗レート)
- **説明**: Camelルートの処理レートと失敗レートを表示（messages/sec）

#### パネル73: ⏱️ ルート処理時間
- **変更前**: 
  - `kafka_producer_metrics_request_latency_avg` (Producer Request Latency)
  - `kafka_consumer_fetch_manager_fetch_latency_avg` (Consumer Fetch Latency)
- **変更後**: 
  - `camel_route_processing_time_seconds_sum / camel_route_processing_time_seconds_count` (平均処理時間)
  - `camel_route_processing_time_seconds_max` (最大処理時間)
- **説明**: Camelルートの処理時間を秒単位で表示
- **しきい値**: 
  - 🟢 緑: 0秒～
  - 🟡 黄: 0.05秒（50ms）～
  - 🟠 橙: 0.1秒（100ms）～
  - 🔴 赤: 0.2秒（200ms）～

## 📊 使用メトリクスの詳細

### Camelルートメトリクス

すべてのパネルで以下のラベルフィルターを使用：
```promql
routeId=~".*kafka.*|.*order.*"
```

これにより、KafkaまたはOrderを含むルート名のメトリクスのみを表示します。

### 利用可能なメトリクス

| メトリクス名 | 説明 | 型 |
|---|---|---|
| `camel_route_exchanges_inflight` | 現在処理中のメッセージ数 | Gauge |
| `camel_route_exchanges_total` | 総処理メッセージ数 | Counter |
| `camel_route_exchanges_failed` | 失敗したメッセージ数 | Counter |
| `camel_route_processing_time_seconds_sum` | 処理時間の合計 | Counter |
| `camel_route_processing_time_seconds_count` | 処理回数 | Counter |
| `camel_route_processing_time_seconds_max` | 最大処理時間 | Gauge |

## ✅ 適用方法

### ローカル版

```bash
cd demo
# 方法1: スクリプトを使用（推奨）
./stop-demo.sh && ./start-demo.sh

# 方法2: Grafanaのみ再起動
podman-compose restart grafana
# または
podman compose restart grafana
```

### OpenShift版

```bash
cd demo/openshift
./UPDATE_DASHBOARD.sh
```

## 🔍 動作確認

### 1. Camelルートの確認

アプリケーションにどのようなルートが存在するか確認：

```bash
curl http://localhost:8080/actuator/camel/routes | jq '.[] | .id'
```

### 2. メトリクスの確認

Prometheusエンドポイントでメトリクスを確認：

```bash
# 処理中メッセージ数
curl http://localhost:8080/actuator/prometheus | grep camel_route_exchanges_inflight

# 処理レート
curl http://localhost:8080/actuator/prometheus | grep camel_route_exchanges_total

# 処理時間
curl http://localhost:8080/actuator/prometheus | grep camel_route_processing_time
```

### 3. Prometheusで確認

Prometheus UI (`http://localhost:9090`) で以下のクエリを実行：

```promql
# 処理中メッセージ数
camel_route_exchanges_inflight{application="camel-observability-demo"}

# 処理レート（1分間の平均）
rate(camel_route_exchanges_total{application="camel-observability-demo"}[1m])

# 平均処理時間
camel_route_processing_time_seconds_sum / camel_route_processing_time_seconds_count
```

### 4. Grafanaダッシュボードで確認

1. Grafanaにアクセス (`http://localhost:3000`)
2. ログイン（admin/admin）
3. 「Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード」を開く
4. 「📨 Kafka & Camel ルート処理」セクションにスクロール
5. 3つのパネルにデータが表示されることを確認

## 📝 注意事項

### ルート名のパターン

現在のフィルター `routeId=~".*kafka.*|.*order.*"` は以下のルート名にマッチします：
- `kafka-consumer-route`
- `kafka-producer-route`
- `order-processor`
- `kafka-order-handler`
- など

独自のルート名を使用している場合は、ダッシュボードのクエリを調整してください。

### メトリクスが表示されない場合

1. **アプリケーションが起動しているか確認**
   ```bash
   curl http://localhost:8080/actuator/health
   ```

2. **Camelルートが動作しているか確認**
   ```bash
   curl http://localhost:8080/actuator/camel/routes
   ```

3. **メトリクスが公開されているか確認**
   ```bash
   curl http://localhost:8080/actuator/prometheus | grep camel
   ```

4. **Prometheusがメトリクスを収集しているか確認**
   ```bash
   curl http://localhost:9090/api/v1/query?query=camel_route_exchanges_total
   ```

## 🎯 メリット

修正後のメトリクスは以下のメリットがあります：

✅ **すぐに利用可能** - 追加の設定不要
✅ **アプリケーション視点** - Camelの観点から見たメトリクス
✅ **実用的** - 実際のビジネスロジックの処理状況を反映
✅ **包括的** - 成功・失敗・処理中の状態をすべて表示

## 📚 関連ドキュメント

- **詳細ガイド**: `KAFKA_METRICS_GUIDE.md`
- **ダッシュボードドキュメント**: `docker/grafana/provisioning/dashboards/DASHBOARD_README.md`
- **デプロイガイド**: `DASHBOARD_DEPLOYMENT_GUIDE.md`
- **Camel Micrometer**: https://camel.apache.org/components/latest/micrometer-component.html

## 🚀 次のステップ

1. ✅ `application.yml`を更新（完了）
2. ✅ ダッシュボードを修正（完了）
3. ⏳ アプリケーションを再起動
4. ⏳ Grafanaを再起動
5. ⏳ メトリクスが表示されることを確認

お疲れ様でした！ 🎉

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

