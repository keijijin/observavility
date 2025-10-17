#!/bin/bash

###############################################################################
# OpenShift Camel App テストスクリプト
# 
# 機能:
#   1. Pod状態確認
#   2. ヘルスチェック
#   3. REST API テスト（注文作成）
#   4. メトリクス確認
#   5. トレースID確認
#   6. ログ確認
#
# 使い方:
#   ./test_camel_app.sh
###############################################################################

# エラーが発生してもスクリプトを継続
set +e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 結果カウンター
PASSED=0
FAILED=0

# ヘルパー関数
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

###############################################################################
# 1. 前提条件の確認
###############################################################################
print_header "1. 前提条件の確認"

# ocコマンドの確認
if ! command -v oc &> /dev/null; then
    print_error "ocコマンドが見つかりません。OpenShift CLIをインストールしてください。"
    exit 1
fi
print_success "ocコマンド: 利用可能"

# curlコマンドの確認
if ! command -v curl &> /dev/null; then
    print_error "curlコマンドが見つかりません。"
    exit 1
fi
print_success "curlコマンド: 利用可能"

# jqコマンドの確認（オプション）
if command -v jq &> /dev/null; then
    HAS_JQ=true
    print_success "jqコマンド: 利用可能"
else
    HAS_JQ=false
    print_warning "jqコマンドがありません（JSON整形は省略されます）"
fi

# OpenShift接続確認
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
# 2. Pod状態の確認
###############################################################################
print_header "2. Pod状態の確認"

# camel-app Podの確認
CAMEL_POD=$(oc get pods -l deployment=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$CAMEL_POD" ]; then
    print_error "camel-app Podが見つかりません。"
    exit 1
fi
print_success "camel-app Pod: $CAMEL_POD"

# Pod状態の確認
POD_STATUS=$(oc get pod "$CAMEL_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "$POD_STATUS" != "Running" ]; then
    print_error "Podのステータスが異常です: $POD_STATUS"
    oc get pod "$CAMEL_POD"
    exit 1
fi
print_success "Pod状態: $POD_STATUS"

# Ready状態の確認
POD_READY=$(oc get pod "$CAMEL_POD" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
if [ "$POD_READY" != "true" ]; then
    print_error "Podの準備ができていません"
    exit 1
fi
print_success "Pod Ready: $POD_READY"

# 起動時間の確認
POD_START_TIME=$(oc get pod "$CAMEL_POD" -o jsonpath='{.status.startTime}' 2>/dev/null || echo "Unknown")
print_info "起動時間: $POD_START_TIME"

###############################################################################
# 3. Routeの確認とURLの取得
###############################################################################
print_header "3. Routeの確認"

CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -z "$CAMEL_URL" ]; then
    print_error "camel-app Routeが見つかりません。"
    exit 1
fi
print_success "Camel App URL: https://$CAMEL_URL"

###############################################################################
# 4. ヘルスチェック
###############################################################################
print_header "4. ヘルスチェック"

HEALTH_RESPONSE=$(curl -k -s -w "\n%{http_code}" "https://$CAMEL_URL/actuator/health" 2>/dev/null || echo "")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    print_success "ヘルスチェック: HTTP $HTTP_CODE"
    
    # JSONレスポンスの確認
    if echo "$HEALTH_BODY" | grep -q '"status":"UP"'; then
        print_success "アプリケーションステータス: UP"
        
        if [ "$HAS_JQ" = true ]; then
            echo "$HEALTH_BODY" | jq '.' 2>/dev/null | head -20 || echo "$HEALTH_BODY"
        else
            echo "$HEALTH_BODY" | head -5
        fi
    else
        print_error "アプリケーションステータスが異常です"
        echo "$HEALTH_BODY"
    fi
else
    print_error "ヘルスチェック失敗: HTTP $HTTP_CODE"
    echo "$HEALTH_BODY"
fi

###############################################################################
# 5. アプリケーション情報の確認
###############################################################################
print_header "5. アプリケーション情報の確認"

INFO_RESPONSE=$(curl -k -s -w "\n%{http_code}" "https://$CAMEL_URL/actuator/info" 2>/dev/null || echo "")
HTTP_CODE=$(echo "$INFO_RESPONSE" | tail -n 1)
INFO_BODY=$(echo "$INFO_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    print_success "アプリケーション情報取得: HTTP $HTTP_CODE"
    
    if [ "$HAS_JQ" = true ]; then
        echo "$INFO_BODY" | jq '.' 2>/dev/null || echo "$INFO_BODY"
        
        # バージョン情報の抽出
        APP_VERSION=$(echo "$INFO_BODY" | jq -r '.app.version' 2>/dev/null || echo "N/A")
        CAMEL_VERSION=$(echo "$INFO_BODY" | jq -r '.camel.version' 2>/dev/null || echo "N/A")
        print_info "アプリバージョン: $APP_VERSION"
        print_info "Camelバージョン: $CAMEL_VERSION"
    else
        echo "$INFO_BODY"
    fi
else
    print_warning "アプリケーション情報取得失敗: HTTP $HTTP_CODE"
fi

###############################################################################
# 6. REST API テスト（注文作成）
###############################################################################
print_header "6. REST API テスト（注文作成）"

print_info "3件の注文を作成します..."

for i in {1..3}; do
    echo ""
    print_info "注文 #$i を作成中..."
    
    ORDER_ID="test-$(date +%s)-$i"
    ORDER_JSON=$(cat <<EOF
{
  "id": "$ORDER_ID",
  "product": "テスト商品$i",
  "quantity": $((i * 10))
}
EOF
)
    
    ORDER_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST \
        "https://$CAMEL_URL/camel/api/orders" \
        -H "Content-Type: application/json" \
        -d "$ORDER_JSON" 2>/dev/null || echo "")
    
    HTTP_CODE=$(echo "$ORDER_RESPONSE" | tail -n 1)
    ORDER_BODY=$(echo "$ORDER_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "200" ]; then
        print_success "注文 #$i 作成成功: HTTP $HTTP_CODE"
        print_info "レスポンス: $ORDER_BODY"
    else
        print_error "注文 #$i 作成失敗: HTTP $HTTP_CODE"
        echo "$ORDER_BODY"
    fi
    
    sleep 2
done

###############################################################################
# 7. メトリクス確認
###############################################################################
print_header "7. メトリクスエンドポイント確認"

METRICS_RESPONSE=$(curl -k -s -w "\n%{http_code}" "https://$CAMEL_URL/actuator/prometheus" 2>/dev/null || echo "")
HTTP_CODE=$(echo "$METRICS_RESPONSE" | tail -n 1)
METRICS_BODY=$(echo "$METRICS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    print_success "Prometheusメトリクス取得: HTTP $HTTP_CODE"
    
    # 主要メトリクスの確認
    METRIC_COUNT=$(echo "$METRICS_BODY" | grep -c "^[a-z]" || echo "0")
    print_info "メトリクス数: 約 $METRIC_COUNT 種類"
    
    echo ""
    print_info "主要メトリクス（サンプル）:"
    echo "$METRICS_BODY" | grep -E "(jvm_memory|http_server|camel_exchanges)" | head -10
else
    print_error "Prometheusメトリクス取得失敗: HTTP $HTTP_CODE"
fi

###############################################################################
# 8. トレースID確認（ログから）
###############################################################################
print_header "8. トレースID確認"

print_info "最新のログからTraceIDを検索します..."
RECENT_LOGS=$(oc logs "$CAMEL_POD" --tail=50 2>/dev/null || echo "")

if echo "$RECENT_LOGS" | grep -q "TraceId:"; then
    print_success "TraceIDが生成されています"
    echo ""
    print_info "最近のTraceID（サンプル）:"
    echo "$RECENT_LOGS" | grep "TraceId:" | tail -3
else
    print_warning "TraceIDが見つかりませんでした（注文を作成してから再度確認してください）"
fi

###############################################################################
# 9. エラーログ確認
###############################################################################
print_header "9. エラーログ確認"

ERROR_LOGS=$(echo "$RECENT_LOGS" | grep -iE "(error|exception|failed)" | grep -v "Request joining group" || echo "")

if [ -z "$ERROR_LOGS" ]; then
    print_success "エラーログなし"
else
    ERROR_COUNT=$(echo "$ERROR_LOGS" | wc -l)
    print_warning "エラーログが ${ERROR_COUNT} 件見つかりました:"
    echo ""
    echo "$ERROR_LOGS" | tail -5
fi

###############################################################################
# 10. Kafka接続確認
###############################################################################
print_header "10. Kafka接続確認"

if echo "$RECENT_LOGS" | grep -q "Kafkaにオーダーを送信しました"; then
    print_success "Kafka送信: 正常"
    KAFKA_SEND_COUNT=$(echo "$RECENT_LOGS" | grep -c "Kafkaにオーダーを送信しました" || echo "0")
    print_info "送信数（直近50行）: $KAFKA_SEND_COUNT 件"
else
    print_warning "Kafka送信ログが見つかりません"
fi

if echo "$RECENT_LOGS" | grep -q "Kafkaからオーダーを受信しました"; then
    print_success "Kafka受信: 正常"
    KAFKA_RECEIVE_COUNT=$(echo "$RECENT_LOGS" | grep -c "Kafkaからオーダーを受信しました" || echo "0")
    print_info "受信数（直近50行）: $KAFKA_RECEIVE_COUNT 件"
else
    print_warning "Kafka受信ログが見つかりません"
fi

###############################################################################
# 11. 処理完了確認
###############################################################################
print_header "11. 処理完了確認"

if echo "$RECENT_LOGS" | grep -q "オーダー処理完了"; then
    print_success "オーダー処理: 正常完了"
    COMPLETED_COUNT=$(echo "$RECENT_LOGS" | grep -c "オーダー処理完了" || echo "0")
    print_info "完了数（直近50行）: $COMPLETED_COUNT 件"
    
    # ステータスの確認
    echo ""
    print_info "最新の処理結果:"
    echo "$RECENT_LOGS" | grep "オーダー処理完了" | tail -3
else
    print_warning "オーダー処理完了ログが見つかりません"
fi

###############################################################################
# 12. リソース使用状況
###############################################################################
print_header "12. リソース使用状況"

print_info "Pod リソース使用状況:"
oc adm top pod "$CAMEL_POD" 2>/dev/null || print_warning "メトリクスサーバーが利用できません"

###############################################################################
# 結果サマリー
###############################################################################
print_header "テスト結果サマリー"

TOTAL=$((PASSED + FAILED))
echo ""
echo -e "合計テスト数: ${BLUE}$TOTAL${NC}"
echo -e "成功: ${GREEN}$PASSED${NC}"
echo -e "失敗: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 すべてのテストが成功しました！${NC}"
    echo ""
    echo -e "${BLUE}次のステップ:${NC}"
    echo "  1. Grafana でダッシュボードを確認"
    echo "     https://grafana-$CURRENT_PROJECT.apps.cluster-2mcrz.dynamic.redhatworkshops.io"
    echo ""
    echo "  2. Grafana Explore でトレースを確認"
    echo "     データソース: Tempo"
    echo ""
    echo "  3. Grafana Explore でログを確認"
    echo "     データソース: Loki"
    echo "     クエリ: {app=\"camel-observability-demo\"}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ いくつかのテストが失敗しました。${NC}"
    echo ""
    echo -e "${YELLOW}トラブルシューティング:${NC}"
    echo "  1. Podログを確認: oc logs $CAMEL_POD"
    echo "  2. Pod詳細を確認: oc describe pod $CAMEL_POD"
    echo "  3. イベントを確認: oc get events --sort-by='.lastTimestamp'"
    echo ""
    exit 1
fi

