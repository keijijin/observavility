# 🚀 Camel分散アプリケーション監視パッケージ（最小構成）

## 📋 含まれるもの

### 設定ファイル
- **Grafanaダッシュボード**: `camel-comprehensive-dashboard.json`
  - システム概要、Camelルート、HTTP、JVM、Undertow、Kafka監視
- **Prometheusアラート**: `alert_rules.yml`
  - 18個のアラートルール（クリティカル6、警告9、情報3）
- **データソース設定**: `datasources.yml`
  - Prometheus、Tempo、Loki連携
- **Prometheus設定**: `prometheus.yml`
  - メトリクス収集設定

## 🚀 クイックスタート

### 1. Grafana設定

```bash
# datasources.ymlを配置
cp config/grafana/datasources/datasources.yml /etc/grafana/provisioning/datasources/

# ダッシュボードを配置
cp config/grafana/dashboards/* /etc/grafana/provisioning/dashboards/
cp config/grafana/provisioning/dashboards.yml /etc/grafana/provisioning/dashboards/

# Grafana再起動
systemctl restart grafana-server
```

### 2. Prometheus設定

```bash
# 設定ファイルを配置
cp config/prometheus/prometheus.yml /etc/prometheus/
cp config/prometheus/alert_rules.yml /etc/prometheus/

# Prometheus再起動
systemctl restart prometheus
```

### 3. アクセス

- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **アラート**: http://localhost:9090/alerts

## 📊 ダッシュボード概要

### セクション
1. 📊 システム概要 - 稼働時間、CPU、メモリ、スレッド
2. 🐫 Camelルート - 処理レート、エラー率、処理時間
3. 🌐 HTTPエンドポイント - リクエストレート、レスポンスタイム
4. 🧠 JVMメモリ - ヒープ、GC、メモリ割り当て
5. 🚀 Undertow - リクエストキュー、スレッド、負荷率
6. 📨 Kafka - ルート処理、処理レート、処理時間

## 🚨 アラート一覧

### クリティカル（6個）
- HighMemoryUsage（メモリ > 90%）
- HighErrorRate（エラー率 > 10%）
- HighHTTPErrorRate（5xxエラー > 5%）
- HighGCOverhead（GC > 20%）
- ApplicationDown（ダウン検出）
- UndertowRequestQueueFull（キュー > 100）

### 警告（9個）
- ModerateMemoryUsage、HighCPUUsage、SlowResponseTime
- HighRunningRoutes、HighThreadCount、ModerateGCOverhead
- UndertowHighRequestLoad、UndertowModerateQueueSize
- SlowCamelRouteProcessing

### 情報（3個）
- FrequentGarbageCollection、ApplicationRestarted
- HighMemoryAllocationRate

## 🔧 環境別設定

### Docker/Podman

datasources.ymlのURLを以下に変更:
```yaml
url: http://prometheus:9090
url: http://tempo:3200
url: http://loki:3100
```

prometheus.ymlのターゲットを以下に変更:
```yaml
targets: ['camel-app:8080']
```

### Kubernetes/OpenShift

Service名に合わせてURLを変更してください。

## 📞 サポート

詳細なドキュメントは推奨パッケージ版をご利用ください。

---

**バージョン**: 1.0  
**作成日**: 2025-10-22
