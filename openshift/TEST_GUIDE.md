# 🧪 OpenShift オブザーバビリティデモ テストガイド

## 📋 目次

1. [環境確認](#環境確認)
2. [基本動作テスト](#基本動作テスト)
3. [メトリクステスト](#メトリクステスト)
4. [トレーステスト](#トレーステスト)
5. [ログテスト](#ログテスト)
6. [ダッシュボード確認](#ダッシュボード確認)
7. [アラートテスト](#アラートテスト)
8. [負荷テスト](#負荷テスト)

---

## 環境確認

### 1. すべてのPodが起動しているか確認

```bash
oc get pods

# 期待される出力:
# NAME                          READY   STATUS    RESTARTS   AGE
# camel-app-xxx                 1/1     Running   0          Xm
# kafka-xxx                     1/1     Running   0          Xm
# grafana-xxx                   1/1     Running   0          Xm
# loki-xxx                      1/1     Running   0          Xm
# prometheus-xxx                1/1     Running   0          Xm
# tempo-xxx                     1/1     Running   0          Xm
```

### 2. サービスが正常に動作しているか確認

```bash
oc get svc

# 期待される出力:
# NAME         TYPE        CLUSTER-IP       PORT(S)
# camel-app    ClusterIP   172.31.x.x       8080/TCP
# kafka        ClusterIP   172.31.x.x       9092/TCP
# grafana      ClusterIP   172.31.x.x       3000/TCP
# prometheus   ClusterIP   172.31.x.x       9090/TCP
# tempo        ClusterIP   172.31.x.x       3200/TCP,4318/TCP
# loki         ClusterIP   172.31.x.x       3100/TCP
```

### 3. Routes（外部アクセス）を確認

```bash
oc get routes

# URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

echo "Grafana: https://${GRAFANA_URL}"
echo "Camel App: https://${CAMEL_URL}"
echo "Prometheus: https://${PROMETHEUS_URL}"
```

---

## 基本動作テスト

### 1. Camel App ヘルスチェック

```bash
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"

# 期待される出力:
# {"status":"UP"}
```

### 2. Actuatorエンドポイント一覧

```bash
# 利用可能なエンドポイント一覧
curl -k "https://${CAMEL_URL}/actuator"

# メトリクスエンドポイント
curl -k "https://${CAMEL_URL}/actuator/prometheus" | head -50

# アプリ情報
curl -k "https://${CAMEL_URL}/actuator/info"
```

### 3. REST APIエンドポイント

```bash
# ヘルスチェックAPI
curl -k "https://${CAMEL_URL}/camel/api/health"

# 期待される出力:
# {"status":"UP","timestamp":"..."}
```

---

## メトリクステスト

### 1. Prometheusでメトリクスを確認

```bash
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

# Prometheus UI にアクセス
open "https://${PROMETHEUS_URL}"

# または、APIで確認
curl -k "https://${PROMETHEUS_URL}/api/v1/query?query=up"
```

### 2. Camel Appのメトリクスを確認

Prometheus UI で以下のクエリを実行：

```promql
# アプリケーションが起動しているか
up{job="camel-app"}

# JVMヒープメモリ使用率
(jvm_memory_used_bytes{application="camel-observability-demo",area="heap"} / jvm_memory_max_bytes{application="camel-observability-demo",area="heap"}) * 100

# HTTPリクエスト数
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# Camel Exchange数
rate(camel_exchanges_total{application="camel-observability-demo"}[1m])
```

### 3. Kafkaメトリクスを確認

```bash
# Kafkaコンテナに入る
oc exec -it deployment/kafka -- bash

# トピック一覧
kafka-topics.sh --bootstrap-server localhost:9092 --list

# トピックの詳細
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders
```

---

## トレーステスト

### 1. トレース生成：注文を作成

```bash
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 注文を1件作成
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "order-001",
    "product": "商品A",
    "quantity": 10
  }'

# 期待される出力:
# {"orderId":"order-001","status":"accepted","message":"Order received"}
```

### 2. 複数の注文を作成（トレース増加）

```bash
# 5件の注文を作成
for i in {1..5}; do
  curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{
      \"id\": \"order-00${i}\",
      \"product\": \"商品${i}\",
      \"quantity\": $((i * 10))
    }"
  echo ""
  sleep 2
done
```

### 3. Grafana Tempoでトレースを確認

```bash
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"
```

1. Grafanaにアクセス（admin / admin）
2. **左メニュー > Explore** をクリック
3. データソースで **Tempo** を選択
4. **Search** タブで以下を選択：
   - Service Name: `camel-observability-demo`
   - Span Name: `http post` または `orders`
5. **Run query** をクリック
6. トレース一覧が表示されるので、1つクリック

**期待される結果**:
- `http post` トレースの階層構造:
  ```
  http post
  └─ /api/orders (POST)
     └─ orders (Kafka producer)
  ```

---

## ログテスト

### 1. Grafana Lokiでログを確認

Grafana（Explore > Loki）で以下のクエリを実行：

```logql
# すべてのログ
{app="camel-observability-demo"}

# ERRORレベルのみ
{app="camel-observability-demo"} | json | level="ERROR"

# WARNレベル以上
{app="camel-observability-demo"} | json | level=~"WARN|ERROR"

# Camel関連のログ
{app="camel-observability-demo"} | json | logger_name=~"org.apache.camel.*"

# 注文処理のログ
{app="camel-observability-demo"} |= "order"
```

### 2. trace_idでログを検索

1. Tempoでトレースを表示
2. トレースIDをコピー（例: `a191c67769012c1dcf1dc63ffb70db7c`）
3. Lokiで以下のクエリを実行：

```logql
{app="camel-observability-demo"} | json | trace_id="a191c67769012c1dcf1dc63ffb70db7c"
```

**期待される結果**: そのトレースに関連するログのみが表示される

### 3. Podログを直接確認

```bash
# Camel Appのログ
oc logs -f deployment/camel-app

# Kafkaのログ
oc logs -f deployment/kafka

# Grafanaのログ
oc logs -f deployment/grafana
```

---

## ダッシュボード確認

### 1. Grafanaダッシュボードにアクセス

```bash
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"
```

1. ブラウザでGrafanaを開く
2. **admin / admin** でログイン
3. **左メニュー > Dashboards** をクリック

### 2. 利用可能なダッシュボード

| ダッシュボード名 | 説明 |
|----------------|------|
| **Camel Observability Dashboard** | 基本的なシステム概要 |
| **Camel Comprehensive Dashboard** | 詳細なメトリクス（17パネル） |
| **Alerts Overview Dashboard** | Prometheusアラートの監視 |

### 3. Comprehensive Dashboardの確認項目

各パネルで以下を確認：

#### システム概要
- ✅ Uptime（稼働時間）
- ✅ Heap Memory Usage（メモリ使用率）
- ✅ Active Threads（スレッド数）
- ✅ GC Pause Time（GC停止時間）

#### Camel Route Performance
- ✅ Exchange Rate（メッセージ処理速度）
- ✅ Processing Time（処理時間）
- ✅ Error Rate（エラー率）

#### HTTP Endpoints
- ✅ Request Rate（リクエスト数）
- ✅ Response Time（レスポンス時間）
- ✅ Error Rate（HTTPエラー率）

---

## アラートテスト

### 1. Prometheusでアラートルールを確認

```bash
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

# ブラウザでPrometheusを開く
open "https://${PROMETHEUS_URL}"

# Status > Rules でアラートルール一覧を確認
```

### 2. アラートの種類

| アラート名 | 重大度 | 条件 |
|-----------|--------|------|
| **HighMemoryUsage** | Critical | メモリ使用率 > 90% （2分間） |
| **HighErrorRate** | Critical | エラー率 > 10% （2分間） |
| **ApplicationDown** | Critical | アプリダウン（1分間） |
| **ModerateMemoryUsage** | Warning | メモリ使用率 > 70% （5分間） |
| **SlowResponseTime** | Warning | 99%ile > 1秒 （3分間） |

### 3. Grafanaでアラートを確認

1. Grafanaにアクセス
2. **Dashboards > Alerts Overview Dashboard** を開く
3. 以下のパネルを確認：
   - **Firing/Pending Alerts Count** - 現在のアラート数
   - **Critical Alerts** - 重大なアラート一覧
   - **Warning Alerts** - 警告アラート一覧

### 4. アラートテスト（意図的にメモリを消費）

```bash
# 注意: これはテスト目的です
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 大量のリクエストを送信してメモリを消費
for i in {1..100}; do
  curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"order-${i}\",\"product\":\"商品${i}\",\"quantity\":${i}}" &
done

# 2-3分後、Prometheusでアラートを確認
```

---

## 負荷テスト

### 1. シンプルな負荷テスト

```bash
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 10秒間、並列5リクエスト
for i in {1..50}; do
  (curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"order-${i}\",\"product\":\"商品${i}\",\"quantity\":${i}}" &)
  sleep 0.2
done
```

### 2. 継続的な負荷テスト

```bash
# 5分間、継続的にリクエストを送信
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
END_TIME=$((SECONDS + 300))

while [ $SECONDS -lt $END_TIME ]; do
  curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"order-${RANDOM}\",\"product\":\"商品\",\"quantity\":10}" &
  sleep 0.5
done
```

### 3. 負荷テスト中の確認項目

負荷テスト実行中に以下を確認：

#### Grafanaで確認
- **Comprehensive Dashboard** を開く
- Request Rate が増加
- Response Time の変化
- Memory Usage の変化
- GC Pause Time の増加

#### Prometheusで確認
```promql
# リクエスト数の推移
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# レスポンスタイム（99%ile）
histogram_quantile(0.99, sum by (le) (rate(http_server_requests_seconds_bucket{application="camel-observability-demo"}[1m])))
```

#### Tempoで確認
- トレース数が増加
- 各リクエストの処理時間を確認

#### Lokiで確認
```logql
# ログ量の確認
count_over_time({app="camel-observability-demo"}[1m])
```

---

## 🎯 テスト成功の判定基準

| テスト項目 | 成功基準 |
|-----------|---------|
| **環境確認** | すべてのPodが `Running` |
| **ヘルスチェック** | `/actuator/health` が `{"status":"UP"}` を返す |
| **メトリクス** | Prometheusでメトリクスが取得できる |
| **トレース** | Tempoでトレースが表示される |
| **ログ** | Lokiでログが表示される |
| **ダッシュボード** | 3つのダッシュボードがGrafanaに表示される |
| **アラート** | Prometheusでアラートルールが表示される |
| **trace_id連携** | Tempoのtrace_idでLokiのログが検索できる |
| **負荷テスト** | 負荷時もエラーなく処理される |

---

## 🐛 トラブルシューティング

### Podが起動しない

```bash
# Podの詳細を確認
oc describe pod <POD_NAME>

# ログを確認
oc logs <POD_NAME>

# 前回のログを確認（クラッシュした場合）
oc logs <POD_NAME> --previous
```

### ダッシュボードが表示されない

```bash
# ConfigMapが作成されているか確認
oc get configmap grafana-dashboards
oc get configmap grafana-dashboard-provider

# Grafana Podを再起動
oc rollout restart deployment/grafana

# ログでダッシュボード読み込みを確認
oc logs deployment/grafana | grep -i dashboard
```

### メトリクスが表示されない

```bash
# Prometheusのターゲットを確認
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
curl -k "https://${PROMETHEUS_URL}/api/v1/targets"

# Camel Appのメトリクスエンドポイントを確認
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
curl -k "https://${CAMEL_URL}/actuator/prometheus" | head -20
```

### トレースが表示されない

```bash
# Tempoのログを確認
oc logs deployment/tempo

# Camel Appの環境変数を確認
oc get deployment camel-app -o yaml | grep -A 10 "env:"

# OpenTelemetry設定を確認
oc logs deployment/camel-app | grep -i "otel\|telemetry"
```

### ログが表示されない

```bash
# Lokiのログを確認
oc logs deployment/loki

# Camel Appがログを出力しているか確認
oc logs deployment/camel-app | tail -50

# Loki APIで直接確認
LOKI_URL="http://loki:3100"
oc exec -it deployment/camel-app -- curl "${LOKI_URL}/loki/api/v1/labels"
```

---

## 📚 参考コマンド集

```bash
# すべてのリソースを確認
oc get all

# ConfigMap一覧
oc get configmap

# PVC（永続ボリューム）
oc get pvc

# Routes（外部アクセス）
oc get routes

# Pod詳細
oc describe pod <POD_NAME>

# Podのシェルに入る
oc exec -it deployment/<DEPLOYMENT_NAME> -- bash

# リソース使用量
oc top pods

# イベント一覧
oc get events --sort-by='.lastTimestamp'

# ログのストリーミング
oc logs -f deployment/<DEPLOYMENT_NAME>

# デプロイメントの再起動
oc rollout restart deployment/<DEPLOYMENT_NAME>

# スケールアウト
oc scale deployment/<DEPLOYMENT_NAME> --replicas=3
```

---

**テストを楽しんでください！** 🎉


