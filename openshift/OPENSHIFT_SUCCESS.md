# OpenShift オブザーバビリティ環境 構築成功！ 🎉

## 📋 構築完了サマリー

**日時**: 2025年10月16日  
**環境**: Red Hat OpenShift Container Platform  
**プロジェクト**: camel-observability-demo

---

## ✅ デプロイ済みコンポーネント

| コンポーネント | ステータス | URL |
|---|---|---|
| Camel App | ✅ Running | https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io |
| Grafana | ✅ Running | https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io |
| Prometheus | ✅ Running | https://prometheus-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io |
| Tempo | ✅ Running | (Internal Service) |
| Loki | ✅ Running | (Internal Service) |
| Kafka | ✅ Running | (Internal Service) |
| Zookeeper | ✅ Running | (Internal Service) |

**認証情報**: `admin` / `admin`

---

## 🎯 オブザーバビリティの三本柱

### 1. メトリクス（Prometheus + Grafana）

**Grafana ダッシュボード**:
- ✅ Camel Observability Dashboard
- ✅ Camel Comprehensive Dashboard (17パネル)
- ✅ Alerts Overview Dashboard

**主要メトリクス**:
- JVMメモリ使用率
- HTTP リクエスト数・レスポンスタイム
- Camel ルート処理数・エラー率
- Kafka メッセージ送受信数
- GC時間・頻度
- スレッド数

### 2. トレース（OpenTelemetry + Tempo）

**トレースの確認方法**:
1. Grafana > Explore > Tempo
2. Search > Run query
3. トレース一覧から選択
4. スパン詳細を確認

**確認できるスパン**:
- `http post` - HTTPリクエスト受信
- `/api/orders` - REST API処理
- `orders` - Kafka プロデューサー
- `create-order-route` - Camel ルート処理
- `validate-order-route` - バリデーション
- `payment-processing-route` - 支払い処理
- `shipping-route` - 配送処理

### 3. ログ（Logback + Loki）

**ログの確認方法**:
1. Grafana > Explore > Loki
2. LogQLクエリを実行:
   ```logql
   {app="camel-observability-demo"}
   ```
3. JSONフィールドでフィルタ:
   ```logql
   {app="camel-observability-demo"} | json | level="ERROR"
   ```
4. trace_idでフィルタ（トレースと連携）:
   ```logql
   {app="camel-observability-demo"} | json | trace_id="<TraceID>"
   ```

---

## 🚀 REST API エンドポイント

### ヘルスチェック
```bash
curl -k "https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/actuator/health"
```

### 注文作成
```bash
curl -k -X POST \
  "https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-123","product":"商品名","quantity":10}'
```

### Prometheusメトリクス
```bash
curl -k "https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/actuator/prometheus"
```

---

## 🐛 トラブルシューティング記録

### 問題1: Kafka CrashLoopBackOff
**原因**: OpenShiftの `restricted-v2` SCC とConfluentイメージの互換性問題  
**解決**: Strimzi Kafkaイメージに変更 + `lost+found`ディレクトリ削除

### 問題2: Grafana ダッシュボード未取り込み
**原因**: ConfigMap未マウント  
**解決**: `grafana-dashboards` と `grafana-dashboard-provider` ConfigMapを作成・マウント

### 問題3: camel-app ルート接続不可
**原因**: Service selector不一致（`app: camel-app` ラベル不足）  
**解決**: Service削除・再作成

### 問題4: OpenTelemetry localhost接続エラー
**原因**: `application.yml`の設定が環境変数で上書きされていない  
**解決**: `OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4318` 環境変数を設定

### 問題5: camel-app Kafka接続エラー
**原因**: `application.yml` ConfigMapがマウントされていない  
**解決**: `/deployments/config` にConfigMapをマウント + `SPRING_CONFIG_LOCATION`環境変数設定

---

## 📚 参考ドキュメント

- `openshift/OPENSHIFT_DEPLOYMENT_GUIDE.md` - 詳細なデプロイ手順
- `openshift/QUICKTEST.md` - 5分クイックテスト
- `openshift/TEST_GUIDE.md` - 詳細なテスト手順
- `openshift/KAFKA_SIMPLE.md` - Kafka設定の詳細
- `openshift/DASHBOARD_SETUP_COMPLETE.md` - ダッシュボード設定完了
- `OBSERVABILITY_EXPERIENCE.md` - オブザーバビリティ体験ガイド

---

## 🎯 次のステップ

### 1. Grafanaでダッシュボードを確認
1. https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io にアクセス
2. `admin` / `admin` でログイン
3. Dashboards > Camel Comprehensive Dashboard を開く

### 2. 注文を作成してメトリクスを観察
```bash
# 10件の注文を作成
for i in {1..10}; do
  curl -k -X POST \
    "https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"order-${i}\",\"product\":\"商品${i}\",\"quantity\":$((i*10))}"
  sleep 2
done
```

### 3. Tempoでトレースを確認
1. Grafana > Explore
2. データソース: Tempo
3. Search > Run query
4. 任意のトレースをクリック
5. スパン階層を確認

### 4. Lokiでログを確認
1. Grafana > Explore
2. データソース: Loki
3. クエリ: `{app="camel-observability-demo"}`
4. JSONフィルタ: `| json`

### 5. trace_idでトレースとログを連携
1. Tempo でトレースを開く
2. TraceID をコピー
3. Loki で検索:
   ```logql
   {app="camel-observability-demo"} | json | trace_id="<TraceID>"
   ```

---

## 🎉 完成！

**OpenShiftオブザーバビリティ環境が完全に動作しています！**

- ✅ メトリクス収集・可視化
- ✅ 分散トレーシング
- ✅ ログ集約・検索
- ✅ 三本柱の相互連携
- ✅ アラート設定

お疲れ様でした！🚀




