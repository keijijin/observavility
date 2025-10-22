#!/bin/bash

###############################################################################
# Grafanaダッシュボード更新スクリプト
# 
# 機能:
#   ローカル版のダッシュボードをOpenShift ConfigMapに反映
#
# 使い方:
#   ./UPDATE_DASHBOARD.sh
###############################################################################

# エラーで停止
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
    echo -e "${CYAN}ℹ️  $1${NC}"
}

###############################################################################
# 1. 前提条件の確認
###############################################################################
print_header "1. 前提条件の確認"

# スクリプトの実行場所を確認
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_success "スクリプトディレクトリ: $SCRIPT_DIR"

# ダッシュボードファイルの確認
DASHBOARD_SOURCE="../docker/grafana/provisioning/dashboards/camel-comprehensive-dashboard.json"
if [ ! -f "$DASHBOARD_SOURCE" ]; then
    print_error "ダッシュボードファイルが見つかりません: $DASHBOARD_SOURCE"
    exit 1
fi
print_success "ダッシュボードファイル: $(basename $DASHBOARD_SOURCE)"

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

###############################################################################
# 2. ConfigMapの作成/更新
###############################################################################
print_header "2. ConfigMapの作成/更新"

# ConfigMapが存在するか確認
if oc get configmap grafana-dashboards &> /dev/null; then
    print_info "既存のConfigMapを更新します..."
    ACTION="更新"
else
    print_info "新しいConfigMapを作成します..."
    ACTION="作成"
fi

# ConfigMapを作成/更新
oc create configmap grafana-dashboards \
    --from-file=camel-comprehensive-dashboard.json="$DASHBOARD_SOURCE" \
    --dry-run=client -o yaml | oc apply -f -

if [ $? -eq 0 ]; then
    print_success "ConfigMap ${ACTION}成功"
else
    print_error "ConfigMap ${ACTION}失敗"
    exit 1
fi

###############################################################################
# 3. Grafana Podの再起動
###############################################################################
print_header "3. Grafana Podの再起動"

print_info "Grafana Podを再起動して設定を反映します..."

# Grafana Deploymentをロールアウト
oc rollout restart deployment/grafana

if [ $? -eq 0 ]; then
    print_success "Grafana再起動を開始しました"
else
    print_error "Grafana再起動に失敗しました"
    exit 1
fi

# 再起動の完了を待機
print_info "再起動の完了を待機中..."
oc rollout status deployment/grafana --timeout=2m

if [ $? -eq 0 ]; then
    print_success "Grafana再起動完了"
else
    print_error "Grafana再起動がタイムアウトしました"
    exit 1
fi

###############################################################################
# 4. 確認
###############################################################################
print_header "4. 確認"

# Grafana URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_URL" ]; then
    print_success "Grafana URL: https://$GRAFANA_URL"
    echo ""
    echo "ダッシュボードにアクセスして確認してください:"
    echo "  https://$GRAFANA_URL/dashboards"
    echo ""
    echo "ダッシュボード名:"
    echo "  Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード"
else
    print_error "Grafana Routeが見つかりません"
fi

echo ""
print_success "ダッシュボードの更新が完了しました！"
echo ""

exit 0

