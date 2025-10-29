#!/bin/bash

###############################################################################
# OpenShift アラート設定スクリプト
# 
# 機能:
#   Prometheusアラートルールを自動的にOpenShiftに適用
#
# 使い方:
#   ./SETUP_ALERTS.sh
###############################################################################

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

###############################################################################
# 1. 前提条件の確認
###############################################################################
print_header "1. 前提条件の確認"

# OpenShift接続確認
if ! command -v oc &> /dev/null; then
    print_error "ocコマンドが見つかりません。"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    print_error "OpenShiftに接続できません。oc loginを実行してください。"
    exit 1
fi
print_success "OpenShift接続: $(oc whoami)"

# プロジェクト確認
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    print_error "プロジェクトが選択されていません。"
    exit 1
fi
print_success "現在のプロジェクト: $CURRENT_PROJECT"

# スクリプトディレクトリ
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
print_success "スクリプトディレクトリ: $SCRIPT_DIR"

# アラートルールファイル確認
if [ ! -f "prometheus/alert-rules-configmap.yaml" ]; then
    print_error "アラートルールファイルが見つかりません: prometheus/alert-rules-configmap.yaml"
    exit 1
fi
print_success "アラートルールファイル: prometheus/alert-rules-configmap.yaml"

###############################################################################
# 2. ConfigMapの適用
###############################################################################
print_header "2. ConfigMapの適用"

oc apply -f prometheus/alert-rules-configmap.yaml

if [ $? -eq 0 ]; then
    print_success "ConfigMapを適用しました"
else
    print_error "ConfigMapの適用に失敗しました"
    exit 1
fi

# ConfigMap確認
if oc get configmap prometheus-alert-rules &> /dev/null; then
    print_success "ConfigMap確認: prometheus-alert-rules が存在します"
else
    print_error "ConfigMapが見つかりません"
    exit 1
fi

###############################################################################
# 3. Prometheus Deploymentの確認
###############################################################################
print_header "3. Prometheus Deploymentの確認"

if oc get deployment prometheus &> /dev/null; then
    print_success "Prometheus Deployment が存在します"
else
    print_error "Prometheus Deploymentが見つかりません"
    exit 1
fi

# ボリュームマウント確認
print_info "Prometheus DeploymentでConfigMapがマウントされているか確認します..."

VOLUME_MOUNTED=$(oc get deployment prometheus -o jsonpath='{.spec.template.spec.volumes[?(@.name=="prometheus-alert-rules")].name}' 2>/dev/null || echo "")

if [ -z "$VOLUME_MOUNTED" ]; then
    print_warning "ConfigMapがまだマウントされていません"
    print_info "以下のコマンドを実行してマウントしてください:"
    echo ""
    echo "  oc set volume deployment/prometheus \\"
    echo "    --add --name=prometheus-alert-rules \\"
    echo "    --type=configmap \\"
    echo "    --configmap-name=prometheus-alert-rules \\"
    echo "    --mount-path=/etc/prometheus/alert_rules.yml \\"
    echo "    --sub-path=alert_rules.yml"
    echo ""
    NEEDS_MOUNT=true
else
    print_success "ConfigMapは既にマウントされています"
    NEEDS_MOUNT=false
fi

###############################################################################
# 4. 自動マウント（オプション）
###############################################################################
if [ "$NEEDS_MOUNT" = true ]; then
    print_header "4. ConfigMapの自動マウント"
    
    read -p "ConfigMapを自動的にマウントしますか? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "ConfigMapをマウントしています..."
        
        oc set volume deployment/prometheus \
          --add --name=prometheus-alert-rules \
          --type=configmap \
          --configmap-name=prometheus-alert-rules \
          --mount-path=/etc/prometheus/alert_rules.yml \
          --sub-path=alert_rules.yml
        
        if [ $? -eq 0 ]; then
            print_success "ConfigMapをマウントしました"
            
            # Prometheusを再起動
            print_info "Prometheusを再起動しています..."
            oc rollout restart deployment/prometheus
            oc rollout status deployment/prometheus --timeout=2m
            print_success "Prometheus再起動完了"
        else
            print_error "ConfigMapのマウントに失敗しました"
            exit 1
        fi
    else
        print_info "手動でマウントしてください"
    fi
fi

###############################################################################
# 5. アラートルールの確認
###############################################################################
print_header "5. アラートルールの確認"

# Prometheus URLを取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -n "$PROMETHEUS_URL" ]; then
    print_success "Prometheus URL: https://$PROMETHEUS_URL"
    
    echo ""
    print_info "アラートルールを確認するには、以下のURLにアクセスしてください:"
    echo "  https://$PROMETHEUS_URL/alerts"
    echo ""
    
    # APIでアラート数を確認
    print_info "アラートルールの数を確認しています..."
    sleep 5
    
    ALERT_COUNT=$(curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" 2>/dev/null | jq '.data.groups[].rules | length' 2>/dev/null | awk '{s+=$1} END {print s}')
    
    if [ -n "$ALERT_COUNT" ] && [ "$ALERT_COUNT" -gt 0 ]; then
        print_success "アラートルール数: $ALERT_COUNT"
    else
        print_warning "アラートルールを取得できませんでした（Prometheusの起動を待っています）"
    fi
else
    print_warning "Prometheus Routeが見つかりません"
fi

###############################################################################
# 6. 完了
###############################################################################
print_header "6. 完了"

echo ""
print_success "アラート設定のセットアップが完了しました！"
echo ""

echo "📋 セットアップされたアラート:"
echo "  🔴 クリティカル: 6個"
echo "  🟡 警告: 9個"
echo "  ℹ️  情報: 3個"
echo ""

if [ -n "$PROMETHEUS_URL" ]; then
    echo "📊 確認方法:"
    echo "  1. ブラウザでPrometheusにアクセス:"
    echo "     https://$PROMETHEUS_URL/alerts"
    echo ""
    echo "  2. Grafanaでアラート監視ダッシュボードを確認:"
    GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "$GRAFANA_URL" ]; then
        echo "     https://$GRAFANA_URL"
        echo "     → Dashboards → 「アラート監視ダッシュボード」"
    fi
    echo ""
fi

echo "📚 詳細なドキュメント:"
echo "  - ALERT_SETUP_PRODUCTION.md - 本番環境向けアラート設定ガイド"
echo "  - ALERTING_GUIDE.md - アラート設定ガイド"
echo ""

print_info "アラートのテストを実行する場合:"
echo "  ./stress_test_advanced.sh --preset extreme"
echo ""

exit 0


