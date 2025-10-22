# 🚀 Camel分散アプリケーション監視パッケージ（推奨構成）

本番環境向けの完全な監視ソリューションパッケージです。

## 📋 パッケージ内容

### 設定ファイル（config/）

#### Grafana
- `camel-comprehensive-dashboard.json` - メインダッシュボード
- `alerts-overview-dashboard.json` - アラート監視ダッシュボード
- `datasources.yml` - データソース設定
- `dashboards.yml` - プロビジョニング設定

#### Prometheus
- `alert_rules.yml` - 18個のアラートルール
- `prometheus.yml` - Prometheus設定

### ドキュメント（docs/）

#### セットアップ（setup/）
- `README.md` - 概要
- `QUICKSTART.md` - クイックスタート
- `ALERT_SETUP_PRODUCTION.md` - アラート設定詳細
- `DASHBOARD_DEPLOYMENT_GUIDE.md` - デプロイメントガイド

#### 運用（operation/）
- `ALERTING_GUIDE.md` - アラート運用ガイド
- `GRAFANA_HOWTO.md` - Grafana操作ガイド
- `DASHBOARD_README.md` - ダッシュボード詳細

#### リファレンス（reference/）
- `ALERT_PRODUCTION_SUMMARY.md` - アラート一覧
- `METRICS_FIX_SUMMARY.md` - メトリクス説明
- `DASHBOARD_CUSTOMER_EVALUATION.md` - 評価レポート
- `CUSTOMER_DELIVERY_PACKAGE.md` - パッケージ説明

### OpenShift版（openshift/）
- ConfigMapファイル
- セットアップスクリプト
- デプロイガイド

## 🚀 クイックスタート

### 1. ローカル環境（Docker/Podman）

```bash
# Grafana設定
cp config/grafana/datasources.yml /etc/grafana/provisioning/datasources/
cp config/grafana/*.json /etc/grafana/provisioning/dashboards/
cp config/grafana/dashboards.yml /etc/grafana/provisioning/dashboards/

# Prometheus設定
cp config/prometheus/*.yml /etc/prometheus/

# 再起動
systemctl restart grafana-server prometheus
```

### 2. OpenShift環境

```bash
cd openshift
./SETUP_ALERTS_FIXED.sh
```

詳細は `docs/setup/` のドキュメントを参照してください。

## 📊 ダッシュボード機能

### システム監視
- ✅ CPU使用率（閾値: 50% 警告、85% 危険）
- ✅ メモリ使用率（閾値: 60% 警告、90% 危険）
- ✅ JVMスレッド数
- ✅ アプリケーション稼働時間

### Camel監視
- ✅ メッセージ処理レート
- ✅ エラー率（閾値: 1% 警告、10% 危険）
- ✅ 平均処理時間
- ✅ 処理中メッセージ数

### HTTP監視
- ✅ リクエストレート（エンドポイント別）
- ✅ レスポンスタイム
- ✅ ステータスコード別分布

### JVM詳細
- ✅ ヒープメモリ推移
- ✅ ガベージコレクション
- ✅ メモリ割り当てレート
- ✅ GCオーバーヘッド（閾値: 5% 警告、20% 危険）

### Undertow Webサーバー
- ✅ リクエストキューサイズ（閾値: 50 警告、100 危険）
- ✅ ワーカースレッド使用状況
- ✅ アクティブリクエスト数
- ✅ リクエスト負荷率

### Kafka & Camel
- ✅ 実行中ルート数
- ✅ ルート処理レート
- ✅ ルート処理時間

## 🚨 アラート機能

### クリティカルアラート（6個） - 即座の対応が必要
1. HighMemoryUsage - ヒープメモリ > 90% (2分)
2. HighErrorRate - Camelエラー率 > 10% (2分)
3. HighHTTPErrorRate - HTTP 5xxエラー > 5% (2分)
4. HighGCOverhead - GCオーバーヘッド > 20% (5分)
5. ApplicationDown - アプリケーションダウン (1分)
6. UndertowRequestQueueFull - リクエストキュー > 100 (2分)

### 警告アラート（9個） - 注意が必要
- ModerateMemoryUsage、HighCPUUsage、SlowResponseTime
- HighRunningRoutes、HighThreadCount、ModerateGCOverhead
- UndertowHighRequestLoad、UndertowModerateQueueSize
- SlowCamelRouteProcessing

### 情報アラート（3個） - 参考情報
- FrequentGarbageCollection、ApplicationRestarted
- HighMemoryAllocationRate

詳細は `docs/reference/ALERT_PRODUCTION_SUMMARY.md` を参照。

## 📚 ドキュメント構成

### 初めての方
1. `README.md`（このファイル） - 概要
2. `docs/setup/QUICKSTART.md` - クイックスタート
3. `docs/operation/DASHBOARD_README.md` - ダッシュボード使い方

### セットアップ担当者
1. `docs/setup/ALERT_SETUP_PRODUCTION.md` - アラート詳細設定
2. `docs/setup/DASHBOARD_DEPLOYMENT_GUIDE.md` - デプロイガイド

### 運用担当者
1. `docs/operation/ALERTING_GUIDE.md` - アラート対応マニュアル
2. `docs/operation/GRAFANA_HOWTO.md` - Grafana操作ガイド

### 技術担当者
1. `docs/reference/METRICS_FIX_SUMMARY.md` - メトリクス詳細
2. `docs/reference/DASHBOARD_CUSTOMER_EVALUATION.md` - 技術評価

## 🔧 カスタマイズ

### データソース設定変更

`config/grafana/datasources.yml` を環境に合わせて編集:

```yaml
datasources:
  - name: Prometheus
    url: http://your-prometheus:9090  # ← 変更
```

### アラート閾値変更

`config/prometheus/alert_rules.yml` の閾値を編集:

```yaml
- alert: HighMemoryUsage
  expr: ... > 0.9  # ← 90% を変更
```

## 🎯 ベストプラクティス

1. **定期的な監視**: ダッシュボードを常時表示
2. **アラート設定**: Alertmanagerで通知先を設定
3. **閾値調整**: 環境に合わせてアラート閾値を調整
4. **ログ保管**: Lokiで長期保管設定
5. **定期レビュー**: 月1回のメトリクスレビュー

## 📞 サポート

各ドキュメントの「トラブルシューティング」セクションを参照してください。

---

**パッケージバージョン**: 1.0  
**作成日**: 2025-10-22  
**対象環境**: 本番環境、ステージング環境
