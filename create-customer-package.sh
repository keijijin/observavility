#!/bin/bash

###############################################################################
# お客様提供パッケージ作成スクリプト
#
# 3種類のパッケージを作成:
#   1. minimal    - 最小構成（動作に必要な最小限）
#   2. recommended - 推奨構成（本番環境向け）
#   3. enterprise - エンタープライズ構成（最高品質）
#
# 使い方:
#   ./create-customer-package.sh [minimal|recommended|enterprise|all]
###############################################################################

set -e

# 色付き出力
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}📦 $1${NC}"
}

###############################################################################
# 最小構成パッケージ
###############################################################################
create_minimal_package() {
    print_header "最小構成パッケージ作成"
    
    PACKAGE_NAME="camel-observability-minimal-$(date +%Y%m%d)"
    PACKAGE_DIR="packages/$PACKAGE_NAME"
    
    print_info "パッケージディレクトリ: $PACKAGE_DIR"
    
    # ディレクトリ作成
    mkdir -p "$PACKAGE_DIR"/{config/{grafana/{dashboards,datasources,provisioning},prometheus},docs}
    
    # Grafana設定
    cp docker/grafana/provisioning/dashboards/camel-comprehensive-dashboard.json \
       "$PACKAGE_DIR/config/grafana/dashboards/"
    print_success "Grafanaダッシュボード"
    
    cp docker/grafana/provisioning/datasources/datasources.yml \
       "$PACKAGE_DIR/config/grafana/datasources/"
    print_success "データソース設定"
    
    cp docker/grafana/provisioning/dashboards/dashboards.yml \
       "$PACKAGE_DIR/config/grafana/provisioning/"
    print_success "プロビジョニング設定"
    
    # Prometheus設定
    cp docker/prometheus/alert_rules.yml \
       "$PACKAGE_DIR/config/prometheus/"
    print_success "アラートルール"
    
    cp docker/prometheus/prometheus.yml \
       "$PACKAGE_DIR/config/prometheus/"
    print_success "Prometheus設定"
    
    # README作成
    cat > "$PACKAGE_DIR/README.md" << 'EOF'
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
EOF
    
    print_success "README作成"
    
    # パッケージ情報
    cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" << EOF
パッケージ名: Camel分散アプリケーション監視パッケージ（最小構成）
作成日時: $(date '+%Y-%m-%d %H:%M:%S')
構成: 最小構成（Minimal）

含まれるファイル:
- Grafanaダッシュボード: 1個
- Prometheusアラート: 18個
- 設定ファイル: 4個
- ドキュメント: 1個

対象環境:
- PoC/検証環境
- 開発環境
- 小規模デプロイ

次のステップ:
本番環境では推奨構成パッケージのご利用をお勧めします。
EOF
    
    # アーカイブ作成
    cd packages
    tar czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"
    print_success "アーカイブ作成: $PACKAGE_NAME.tar.gz"
    cd ..
    
    print_success "最小構成パッケージ完成: packages/$PACKAGE_NAME"
    echo ""
    echo "📦 ファイル数: $(find "$PACKAGE_DIR" -type f | wc -l)"
    echo "💾 サイズ: $(du -sh "$PACKAGE_DIR" | cut -f1)"
}

###############################################################################
# 推奨構成パッケージ
###############################################################################
create_recommended_package() {
    print_header "推奨構成パッケージ作成"
    
    PACKAGE_NAME="camel-observability-recommended-$(date +%Y%m%d)"
    PACKAGE_DIR="packages/$PACKAGE_NAME"
    
    print_info "パッケージディレクトリ: $PACKAGE_DIR"
    
    # ディレクトリ作成
    mkdir -p "$PACKAGE_DIR"/{config/{grafana,prometheus},docs/{setup,operation,reference},openshift}
    
    # Grafana設定
    cp docker/grafana/provisioning/dashboards/camel-comprehensive-dashboard.json \
       "$PACKAGE_DIR/config/grafana/"
    cp docker/grafana/provisioning/dashboards/alerts-overview-dashboard.json \
       "$PACKAGE_DIR/config/grafana/" 2>/dev/null || true
    cp docker/grafana/provisioning/datasources/datasources.yml \
       "$PACKAGE_DIR/config/grafana/"
    cp docker/grafana/provisioning/dashboards/dashboards.yml \
       "$PACKAGE_DIR/config/grafana/"
    print_success "Grafana設定（4ファイル）"
    
    # Prometheus設定
    cp docker/prometheus/alert_rules.yml \
       "$PACKAGE_DIR/config/prometheus/"
    cp docker/prometheus/prometheus.yml \
       "$PACKAGE_DIR/config/prometheus/"
    print_success "Prometheus設定（2ファイル）"
    
    # セットアップドキュメント
    cp README.md "$PACKAGE_DIR/docs/setup/" 2>/dev/null || true
    cp QUICKSTART.md "$PACKAGE_DIR/docs/setup/" 2>/dev/null || true
    cp ALERT_SETUP_PRODUCTION.md "$PACKAGE_DIR/docs/setup/"
    cp DASHBOARD_DEPLOYMENT_GUIDE.md "$PACKAGE_DIR/docs/setup/" 2>/dev/null || true
    print_success "セットアップドキュメント"
    
    # 運用ドキュメント
    cp ALERTING_GUIDE.md "$PACKAGE_DIR/docs/operation/"
    cp GRAFANA_HOWTO.md "$PACKAGE_DIR/docs/operation/" 2>/dev/null || true
    cp docker/grafana/provisioning/dashboards/DASHBOARD_README.md \
       "$PACKAGE_DIR/docs/operation/" 2>/dev/null || true
    print_success "運用ドキュメント"
    
    # リファレンスドキュメント
    cp ALERT_PRODUCTION_SUMMARY.md "$PACKAGE_DIR/docs/reference/"
    cp METRICS_FIX_SUMMARY.md "$PACKAGE_DIR/docs/reference/" 2>/dev/null || true
    cp DASHBOARD_CUSTOMER_EVALUATION.md "$PACKAGE_DIR/docs/reference/" 2>/dev/null || true
    cp CUSTOMER_DELIVERY_PACKAGE.md "$PACKAGE_DIR/docs/reference/"
    print_success "リファレンスドキュメント"
    
    # OpenShift版（オプション）
    cp openshift/prometheus/alert-rules-configmap.yaml \
       "$PACKAGE_DIR/openshift/" 2>/dev/null || true
    cp openshift/SETUP_ALERTS_FIXED.sh \
       "$PACKAGE_DIR/openshift/" 2>/dev/null || true
    cp openshift/ALERT_SETUP_SUCCESS.md \
       "$PACKAGE_DIR/openshift/" 2>/dev/null || true
    print_success "OpenShift版"
    
    # 統合README作成
    cat > "$PACKAGE_DIR/README.md" << 'EOF'
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
EOF
    
    print_success "統合README作成"
    
    # パッケージ情報
    cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" << EOF
パッケージ名: Camel分散アプリケーション監視パッケージ（推奨構成）
作成日時: $(date '+%Y-%m-%d %H:%M:%S')
構成: 推奨構成（Recommended）

含まれるファイル:
- Grafanaダッシュボード: 2個
- Prometheusアラート: 18個
- 設定ファイル: 6個
- ドキュメント: 11+個
- OpenShift版: 3+個

対象環境:
- 本番環境
- ステージング環境
- エンタープライズ環境

特徴:
✅ 完全なドキュメント
✅ 運用ガイド完備
✅ OpenShift対応
✅ 即デプロイ可能
EOF
    
    # アーカイブ作成
    cd packages
    tar czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"
    print_success "アーカイブ作成: $PACKAGE_NAME.tar.gz"
    cd ..
    
    print_success "推奨構成パッケージ完成: packages/$PACKAGE_NAME"
    echo ""
    echo "📦 ファイル数: $(find "$PACKAGE_DIR" -type f | wc -l)"
    echo "💾 サイズ: $(du -sh "$PACKAGE_DIR" | cut -f1)"
}

###############################################################################
# メイン処理
###############################################################################
main() {
    print_header "お客様提供パッケージ作成"
    
    # packagesディレクトリ作成
    mkdir -p packages
    
    PACKAGE_TYPE="${1:-recommended}"
    
    case "$PACKAGE_TYPE" in
        minimal)
            create_minimal_package
            ;;
        recommended)
            create_recommended_package
            ;;
        all)
            create_minimal_package
            create_recommended_package
            ;;
        *)
            echo "使い方: $0 [minimal|recommended|all]"
            echo ""
            echo "  minimal     - 最小構成（5ファイル）"
            echo "  recommended - 推奨構成（12+ファイル）- デフォルト"
            echo "  all         - すべてのパッケージを作成"
            exit 1
            ;;
    esac
    
    print_header "完了"
    echo ""
    echo "作成されたパッケージ:"
    ls -lh packages/*.tar.gz 2>/dev/null || echo "（アーカイブなし）"
    echo ""
    echo "パッケージディレクトリ:"
    ls -d packages/*/ 2>/dev/null || echo "（ディレクトリなし）"
}

main "$@"

