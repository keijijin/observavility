#!/bin/bash

###############################################################################
# OpenShift アラート設定スクリプト（修正版）
# 
# 機能:
#   Prometheusアラートルールを自動的にOpenShiftに適用
#   アラートルールを prometheus-config ConfigMap に統合
#
# 使い方:
#   ./SETUP_ALERTS_FIXED.sh
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
print_header "2. アラートルールConfigMapの作成"

oc apply -f prometheus/alert-rules-configmap.yaml

if [ $? -eq 0 ]; then
    print_success "ConfigMapを適用しました"
else
    print_error "ConfigMapの適用に失敗しました"
    exit 1
fi

###############################################################################
# 3. 既存のPrometheus設定を取得
###############################################################################
print_header "3. Prometheus設定の更新"

print_info "現在のPrometheus設定を取得しています..."
oc get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}' > /tmp/prometheus.yml
oc get configmap prometheus-alert-rules -o jsonpath='{.data.alert_rules\.yml}' > /tmp/alert_rules.yml

if [ ! -f "/tmp/prometheus.yml" ] || [ ! -f "/tmp/alert_rules.yml" ]; then
    print_error "設定ファイルの取得に失敗しました"
    exit 1
fi
print_success "設定ファイルを取得しました"

###############################################################################
# 4. Prometheus ConfigMapを統合
###############################################################################
print_info "アラートルールをPrometheus ConfigMapに統合しています..."

# rule_files のパスを確認・修正
if grep -q '"/etc/prometheus/rules/alert_rules.yml"' /tmp/prometheus.yml; then
    sed -i.bak 's|"/etc/prometheus/rules/alert_rules.yml"|"alert_rules.yml"|' /tmp/prometheus.yml
    print_info "rule_files パスを修正しました"
elif grep -q 'alert_rules.yml' /tmp/prometheus.yml; then
    print_info "rule_files は既に正しい設定です"
else
    print_warning "rule_files が見つかりません。追加します。"
    # evaluation_interval の後に rule_files を追加
    sed -i.bak '/evaluation_interval:/a\
\
rule_files:\
  - "alert_rules.yml"
' /tmp/prometheus.yml
fi

# ConfigMapを更新
oc create configmap prometheus-config \
  --from-file=prometheus.yml=/tmp/prometheus.yml \
  --from-file=alert_rules.yml=/tmp/alert_rules.yml \
  --dry-run=client -o yaml | oc apply -f -

if [ $? -eq 0 ]; then
    print_success "Prometheus ConfigMapを更新しました"
else
    print_error "ConfigMapの更新に失敗しました"
    exit 1
fi

###############################################################################
# 5. 余分なボリュームマウントを削除
###############################################################################
print_header "5. Deployment設定のクリーンアップ"

print_info "余分なボリュームマウントを削除しています..."
oc set volume deployment/prometheus --remove --name=prometheus-alert-rules 2>/dev/null || true
print_success "Deploymentをクリーンアップしました"

###############################################################################
# 6. Prometheusを再起動
###############################################################################
print_header "6. Prometheusの再起動"

print_info "Prometheusを再起動しています..."

# 安全のため、まずスケールダウン
oc scale deployment/prometheus --replicas=0
sleep 5

# スケールアップ
oc scale deployment/prometheus --replicas=1
sleep 10

# Podの起動を待機
print_info "Podの起動を待機しています..."
if oc wait --for=condition=ready pod -l app=prometheus --timeout=120s; then
    print_success "Prometheus Podが起動しました"
else
    print_error "Prometheusの起動に失敗しました"
    exit 1
fi

###############################################################################
# 7. アラートルールの確認
###############################################################################
print_header "7. アラートルールの確認"

sleep 10

# Prometheus URLを取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -n "$PROMETHEUS_URL" ]; then
    print_success "Prometheus URL: https://$PROMETHEUS_URL"
    
    echo ""
    print_info "アラートルールの数を確認しています..."
    
    ALERT_COUNT=$(curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" 2>/dev/null | jq '.data.groups[].rules | length' 2>/dev/null | awk '{s+=$1} END {print s}')
    
    if [ -n "$ALERT_COUNT" ] && [ "$ALERT_COUNT" -gt 0 ]; then
        print_success "アラートルール数: $ALERT_COUNT"
        
        echo ""
        echo "📊 アラート一覧:"
        curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" 2>/dev/null | jq -r '.data.groups[].rules[] | "  - \(.alert): \(.state)"' | head -20
    else
        print_warning "アラートルールを取得できませんでした（起動直後の場合は正常です）"
    fi
else
    print_warning "Prometheus Routeが見つかりません"
fi

###############################################################################
# 8. 完了
###############################################################################
print_header "8. 完了"

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

# クリーンアップ
rm -f /tmp/prometheus.yml /tmp/prometheus.yml.bak /tmp/alert_rules.yml

exit 0


