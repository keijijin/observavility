#!/bin/bash

###############################################################################
# OpenShift Camel App ストレステストスクリプト
# 
# 機能:
#   1. 並列リクエスト送信（configurable）
#   2. 継続時間の設定
#   3. リクエスト数の設定
#   4. レスポンスタイムの測定
#   5. エラー率の測定
#   6. リアルタイム進捗表示
#   7. 詳細な結果レポート
#
# 使い方:
#   ./stress_test.sh [オプション]
#
# オプション:
#   -c, --concurrent <num>    並列接続数（デフォルト: 10）
#   -d, --duration <seconds>  テスト継続時間（秒、デフォルト: 60）
#   -r, --requests <num>      総リクエスト数（デフォルト: 無制限、継続時間で制御）
#   -w, --warmup <seconds>    ウォームアップ時間（秒、デフォルト: 5）
#   -h, --help                ヘルプを表示
#
# 例:
#   ./stress_test.sh                              # デフォルト設定
#   ./stress_test.sh -c 20 -d 120                # 20並列、2分間
#   ./stress_test.sh -c 50 -r 1000               # 50並列、1000リクエスト
###############################################################################

# エラーが発生してもスクリプトを継続
set +e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# デフォルト設定
CONCURRENT=10
DURATION=60
MAX_REQUESTS=0  # 0 = 無制限（継続時間で制御）
WARMUP=5

# 結果格納用
TEMP_DIR="/tmp/camel-stress-test-$$"
RESULTS_FILE="$TEMP_DIR/results.txt"
TIMES_FILE="$TEMP_DIR/times.txt"
ERRORS_FILE="$TEMP_DIR/errors.txt"

# ヘルパー関数
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_progress() {
    echo -e "${MAGENTA}⏳ $1${NC}"
}

# ヘルプ表示
show_help() {
    cat << EOF
OpenShift Camel App ストレステストスクリプト

使い方:
  ./stress_test.sh [オプション]

オプション:
  -c, --concurrent <num>    並列接続数（デフォルト: 10）
  -d, --duration <seconds>  テスト継続時間（秒、デフォルト: 60）
  -r, --requests <num>      総リクエスト数（デフォルト: 0 = 無制限）
  -w, --warmup <seconds>    ウォームアップ時間（秒、デフォルト: 5）
  -h, --help                このヘルプを表示

例:
  ./stress_test.sh                              # デフォルト設定（10並列、60秒）
  ./stress_test.sh -c 20 -d 120                # 20並列、2分間
  ./stress_test.sh -c 50 -r 1000               # 50並列、1000リクエスト
  ./stress_test.sh -c 5 -d 300 -w 10           # 5並列、5分間、10秒ウォームアップ

推奨設定:
  軽負荷テスト:     -c 5 -d 60
  中負荷テスト:     -c 20 -d 120
  高負荷テスト:     -c 50 -d 180
  ストレステスト:   -c 100 -d 300

EOF
    exit 0
}

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--concurrent)
            CONCURRENT="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -r|--requests)
            MAX_REQUESTS="$2"
            shift 2
            ;;
        -w|--warmup)
            WARMUP="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# クリーンアップ関数
cleanup() {
    print_info "クリーンアップ中..."
    # バックグラウンドプロセスを終了
    jobs -p | xargs -r kill 2>/dev/null
    wait 2>/dev/null
    # 一時ファイルを削除
    rm -rf "$TEMP_DIR" 2>/dev/null
    exit
}

trap cleanup SIGINT SIGTERM

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
# 2. テスト対象の確認
###############################################################################
print_header "2. テスト対象の確認"

# camel-app Routeの確認
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -z "$CAMEL_URL" ]; then
    print_error "camel-app Routeが見つかりません。"
    exit 1
fi
print_success "Camel App URL: https://$CAMEL_URL"

# ヘルスチェック
HEALTH_CHECK=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$CAMEL_URL/actuator/health" 2>/dev/null || echo "000")
if [ "$HEALTH_CHECK" == "200" ]; then
    print_success "ヘルスチェック: OK (HTTP $HEALTH_CHECK)"
else
    print_error "ヘルスチェック失敗: HTTP $HEALTH_CHECK"
    exit 1
fi

###############################################################################
# 3. テスト設定の表示
###############################################################################
print_header "3. テスト設定"

echo -e "${CYAN}並列接続数:${NC}       $CONCURRENT"
echo -e "${CYAN}テスト継続時間:${NC}   $DURATION 秒"
if [ $MAX_REQUESTS -gt 0 ]; then
    echo -e "${CYAN}最大リクエスト数:${NC} $MAX_REQUESTS"
else
    echo -e "${CYAN}最大リクエスト数:${NC} 無制限（継続時間で制御）"
fi
echo -e "${CYAN}ウォームアップ:${NC}   $WARMUP 秒"
echo -e "${CYAN}テストURL:${NC}        https://$CAMEL_URL/camel/api/orders"

# 一時ディレクトリ作成
mkdir -p "$TEMP_DIR"

###############################################################################
# 4. Grafana監視の案内
###############################################################################
print_header "4. Grafana監視の準備"

GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_URL" ]; then
    echo -e "${CYAN}📊 Grafana URL:${NC}"
    echo "   https://$GRAFANA_URL"
    echo ""
    echo -e "${CYAN}推奨ダッシュボード:${NC}"
    echo "   - Camel Comprehensive Dashboard"
    echo ""
    echo -e "${CYAN}推奨パネル:${NC}"
    echo "   - HTTP Request Rate"
    echo "   - HTTP Response Time (95th percentile)"
    echo "   - HTTP Error Rate"
    echo "   - JVM Memory Usage"
    echo "   - Camel Exchanges Total"
    echo ""
    print_warning "ストレステスト開始前にGrafanaを開いてメトリクスを監視することを推奨します。"
    echo ""
    read -p "Grafanaの準備ができたらEnterキーを押してください..." -t 30
    echo ""
else
    print_warning "Grafana Routeが見つかりません。メトリクスの監視はできません。"
fi

###############################################################################
# 5. ウォームアップ
###############################################################################
if [ $WARMUP -gt 0 ]; then
    print_header "5. ウォームアップ ($WARMUP 秒)"
    
    print_progress "アプリケーションをウォームアップ中..."
    
    for i in $(seq 1 $WARMUP); do
        curl -k -s -o /dev/null -X POST \
            "https://$CAMEL_URL/camel/api/orders" \
            -H "Content-Type: application/json" \
            -d '{"id":"warmup-'$i'","product":"Warmup","quantity":1}' &
        sleep 1
    done
    
    wait
    print_success "ウォームアップ完了"
fi

###############################################################################
# 6. ストレステスト実行
###############################################################################
print_header "6. ストレステスト実行"

print_progress "テスト開始..."
echo ""

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
REQUEST_COUNTER=0
SUCCESS_COUNTER=0
ERROR_COUNTER=0

# リクエスト送信関数
send_request() {
    local request_id=$1
    # macOS互換: Pythonでミリ秒を取得
    local start=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000)))
    
    ORDER_JSON=$(cat <<EOF
{
  "id": "stress-${request_id}",
  "product": "StressTest Product",
  "quantity": $((RANDOM % 100 + 1))
}
EOF
)
    
    RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST \
        "https://$CAMEL_URL/camel/api/orders" \
        -H "Content-Type: application/json" \
        -d "$ORDER_JSON" 2>/dev/null || echo "000")
    
    local end=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000)))
    local elapsed=$((end - start))
    
    echo "$elapsed" >> "$TIMES_FILE"
    
    if [ "$RESPONSE" == "200" ]; then
        echo "SUCCESS" >> "$RESULTS_FILE"
    else
        echo "ERROR:$RESPONSE" >> "$RESULTS_FILE"
        echo "$RESPONSE" >> "$ERRORS_FILE"
    fi
}

# メインループ
print_info "テスト実行中... (Ctrl+C で中断)"
echo ""

while true; do
    CURRENT_TIME=$(date +%s)
    
    # 時間制限チェック
    if [ $CURRENT_TIME -ge $END_TIME ]; then
        break
    fi
    
    # リクエスト数制限チェック
    if [ $MAX_REQUESTS -gt 0 ] && [ $REQUEST_COUNTER -ge $MAX_REQUESTS ]; then
        break
    fi
    
    # 並列数チェック
    RUNNING_JOBS=$(jobs -r | wc -l)
    if [ $RUNNING_JOBS -lt $CONCURRENT ]; then
        REQUEST_COUNTER=$((REQUEST_COUNTER + 1))
        send_request $REQUEST_COUNTER &
    fi
    
    # 進捗表示（5秒ごと）
    if [ $((REQUEST_COUNTER % 50)) -eq 0 ]; then
        ELAPSED=$((CURRENT_TIME - START_TIME))
        REMAINING=$((END_TIME - CURRENT_TIME))
        if [ $REMAINING -lt 0 ]; then
            REMAINING=0
        fi
        echo -ne "\r${CYAN}進捗: ${NC}${REQUEST_COUNTER} リクエスト送信 | ${ELAPSED}秒経過 | 残り${REMAINING}秒   "
    fi
    
    sleep 0.1
done

# すべてのバックグラウンドジョブの完了を待つ
print_progress "残りのリクエストの完了を待機中..."
wait

ACTUAL_END_TIME=$(date +%s)
TOTAL_DURATION=$((ACTUAL_END_TIME - START_TIME))

echo ""
print_success "ストレステスト完了"

###############################################################################
# 7. 結果の集計
###############################################################################
print_header "7. テスト結果の集計"

# 結果ファイルの確認
if [ ! -f "$RESULTS_FILE" ]; then
    print_error "結果ファイルが見つかりません"
    cleanup
    exit 1
fi

# 成功・失敗のカウント
TOTAL_REQUESTS=$(wc -l < "$RESULTS_FILE" 2>/dev/null || echo "0")
SUCCESS_COUNT=$(grep -c "SUCCESS" "$RESULTS_FILE" 2>/dev/null || echo "0")
ERROR_COUNT=$(grep -c "ERROR" "$RESULTS_FILE" 2>/dev/null || echo "0")

# レスポンスタイムの計算
if [ -f "$TIMES_FILE" ]; then
    # 平均レスポンスタイム
    AVG_TIME=$(awk '{ total += $1; count++ } END { print total/count }' "$TIMES_FILE" 2>/dev/null || echo "0")
    
    # 最小・最大レスポンスタイム
    MIN_TIME=$(sort -n "$TIMES_FILE" | head -1 2>/dev/null || echo "0")
    MAX_TIME=$(sort -n "$TIMES_FILE" | tail -1 2>/dev/null || echo "0")
    
    # 95パーセンタイル
    PERCENTILE_95=$(sort -n "$TIMES_FILE" | awk 'BEGIN{c=0} {total[c]=$1; c++} END{print total[int(c*0.95-0.5)]}' 2>/dev/null || echo "0")
    
    # 99パーセンタイル
    PERCENTILE_99=$(sort -n "$TIMES_FILE" | awk 'BEGIN{c=0} {total[c]=$1; c++} END{print total[int(c*0.99-0.5)]}' 2>/dev/null || echo "0")
else
    AVG_TIME=0
    MIN_TIME=0
    MAX_TIME=0
    PERCENTILE_95=0
    PERCENTILE_99=0
fi

# スループット計算
THROUGHPUT=$(echo "scale=2; $TOTAL_REQUESTS / $TOTAL_DURATION" | bc 2>/dev/null || echo "0")

# エラー率計算
if [ $TOTAL_REQUESTS -gt 0 ]; then
    ERROR_RATE=$(echo "scale=2; ($ERROR_COUNT * 100) / $TOTAL_REQUESTS" | bc 2>/dev/null || echo "0")
else
    ERROR_RATE=0
fi

###############################################################################
# 8. 結果レポート
###############################################################################
print_header "8. 詳細レポート"

echo ""
echo -e "${GREEN}=== テスト概要 ===${NC}"
echo -e "${CYAN}テスト継続時間:${NC}     $TOTAL_DURATION 秒"
echo -e "${CYAN}並列接続数:${NC}         $CONCURRENT"
echo ""

echo -e "${GREEN}=== リクエスト統計 ===${NC}"
echo -e "${CYAN}総リクエスト数:${NC}     $TOTAL_REQUESTS"
echo -e "${CYAN}成功:${NC}               ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "${CYAN}失敗:${NC}               ${RED}$ERROR_COUNT${NC}"
echo -e "${CYAN}成功率:${NC}             $(echo "scale=2; 100 - $ERROR_RATE" | bc)%"
echo -e "${CYAN}エラー率:${NC}           ${ERROR_RATE}%"
echo -e "${CYAN}スループット:${NC}       ${THROUGHPUT} req/sec"
echo ""

echo -e "${GREEN}=== レスポンスタイム (ms) ===${NC}"
echo -e "${CYAN}平均:${NC}               $(printf "%.2f" $AVG_TIME) ms"
echo -e "${CYAN}最小:${NC}               $MIN_TIME ms"
echo -e "${CYAN}最大:${NC}               $MAX_TIME ms"
echo -e "${CYAN}95パーセンタイル:${NC}  $PERCENTILE_95 ms"
echo -e "${CYAN}99パーセンタイル:${NC}  $PERCENTILE_99 ms"
echo ""

# エラー詳細
if [ $ERROR_COUNT -gt 0 ] && [ -f "$ERRORS_FILE" ]; then
    echo -e "${RED}=== エラー詳細 ===${NC}"
    echo -e "${CYAN}HTTPステータスコード別エラー数:${NC}"
    sort "$ERRORS_FILE" | uniq -c | while read count code; do
        echo "  HTTP $code: $count 件"
    done
    echo ""
fi

###############################################################################
# 9. パフォーマンス評価
###############################################################################
print_header "9. パフォーマンス評価"

echo ""

# エラー率の評価
if (( $(echo "$ERROR_RATE < 1" | bc -l) )); then
    print_success "エラー率: 優秀 (${ERROR_RATE}% < 1%)"
elif (( $(echo "$ERROR_RATE < 5" | bc -l) )); then
    print_warning "エラー率: 許容範囲 (${ERROR_RATE}% < 5%)"
else
    print_error "エラー率: 高い (${ERROR_RATE}% >= 5%)"
fi

# レスポンスタイムの評価
if (( $(echo "$AVG_TIME < 100" | bc -l) )); then
    print_success "平均レスポンスタイム: 優秀 (${AVG_TIME}ms < 100ms)"
elif (( $(echo "$AVG_TIME < 500" | bc -l) )); then
    print_warning "平均レスポンスタイム: 許容範囲 (${AVG_TIME}ms < 500ms)"
else
    print_error "平均レスポンスタイム: 遅い (${AVG_TIME}ms >= 500ms)"
fi

# 95パーセンタイルの評価
if (( $(echo "$PERCENTILE_95 < 200" | bc -l) )); then
    print_success "95パーセンタイル: 優秀 (${PERCENTILE_95}ms < 200ms)"
elif (( $(echo "$PERCENTILE_95 < 1000" | bc -l) )); then
    print_warning "95パーセンタイル: 許容範囲 (${PERCENTILE_95}ms < 1000ms)"
else
    print_error "95パーセンタイル: 遅い (${PERCENTILE_95}ms >= 1000ms)"
fi

# スループットの評価
if (( $(echo "$THROUGHPUT > 10" | bc -l) )); then
    print_success "スループット: 優秀 (${THROUGHPUT} req/sec > 10)"
elif (( $(echo "$THROUGHPUT > 5" | bc -l) )); then
    print_warning "スループット: 許容範囲 (${THROUGHPUT} req/sec > 5)"
else
    print_error "スループット: 低い (${THROUGHPUT} req/sec <= 5)"
fi

###############################################################################
# 10. Grafana確認の案内
###############################################################################
print_header "10. Grafana で結果を確認"

if [ -n "$GRAFANA_URL" ]; then
    echo ""
    echo -e "${CYAN}📊 Grafanaで以下を確認してください:${NC}"
    echo "   https://$GRAFANA_URL"
    echo ""
    echo -e "${CYAN}確認すべきメトリクス:${NC}"
    echo "   1. HTTP Request Rate - リクエスト率のピーク"
    echo "   2. HTTP Response Time (95th) - レスポンスタイムの変化"
    echo "   3. HTTP Error Rate - エラー率の推移"
    echo "   4. JVM Memory Usage - メモリ使用量の推移"
    echo "   5. GC Pause Time - ガベージコレクションの影響"
    echo "   6. Camel Exchanges Total - Camelルートの処理数"
    echo ""
    echo -e "${CYAN}確認すべきログ (Loki):${NC}"
    echo "   - クエリ: {app=\"camel-observability-demo\"} | json | level=\"ERROR\""
    echo "   - テスト期間中のエラーログを確認"
    echo ""
    echo -e "${CYAN}確認すべきトレース (Tempo):${NC}"
    echo "   - Search > Time Range を設定してトレースを確認"
    echo "   - レスポンスが遅いトレースを特定"
    echo ""
fi

###############################################################################
# 11. 推奨事項
###############################################################################
print_header "11. 推奨事項"

echo ""
if [ $ERROR_COUNT -gt 0 ]; then
    print_warning "エラーが発生しました。以下を確認してください:"
    echo "  1. Podログを確認: oc logs -l deployment=camel-app --tail=100"
    echo "  2. Podリソースを確認: oc adm top pod -l deployment=camel-app"
    echo "  3. Podを再起動: oc rollout restart deployment/camel-app"
    echo ""
fi

if (( $(echo "$AVG_TIME > 500" | bc -l) )); then
    print_warning "レスポンスタイムが遅いです。以下を検討してください:"
    echo "  1. レプリカ数を増やす: oc scale deployment/camel-app --replicas=3"
    echo "  2. リソース制限を緩和: CPU/メモリのlimitsを増やす"
    echo "  3. データベース接続プールを調整"
    echo "  4. Kafkaパーティション数を増やす"
    echo ""
fi

if (( $(echo "$THROUGHPUT < 5" | bc -l) )); then
    print_warning "スループットが低いです。以下を検討してください:"
    echo "  1. 水平スケーリング: レプリカ数を増やす"
    echo "  2. 垂直スケーリング: CPU/メモリを増やす"
    echo "  3. アプリケーションのボトルネックを特定（Tempoでトレース分析）"
    echo ""
fi

print_info "さらに詳しいチューニングについては、PERFORMANCE_TUNING_GUIDE.md を参照してください。"

###############################################################################
# クリーンアップ
###############################################################################
print_header "クリーンアップ"

rm -rf "$TEMP_DIR"
print_success "一時ファイルを削除しました"

echo ""
print_success "ストレステスト完了！"
echo ""

exit 0


