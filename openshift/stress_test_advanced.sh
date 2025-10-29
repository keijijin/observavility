#!/bin/bash

###############################################################################
# OpenShift Camel App 高度なストレステストスクリプト
# 
# 機能:
#   1. 段階的負荷増加（ランプアップ）
#   2. 複数のコンカレント設定で連続テスト
#   3. プリセット設定の選択
#   4. 結果比較とレポート生成
#   5. CSV形式での結果出力
#
# 使い方:
#   ./stress_test_advanced.sh [オプション]
#
# オプション:
#   -m, --mode <mode>         テストモード（single|rampup|multi|preset）
#   -c, --concurrent <num>    並列接続数（single mode用）
#   -d, --duration <seconds>  各テストの継続時間（秒）
#   -s, --start <num>         開始並列数（rampup mode用）
#   -e, --end <num>           終了並列数（rampup mode用）
#   -i, --increment <num>     増加ステップ（rampup mode用）
#   -l, --list <nums>         テスト並列数リスト（multi mode用、カンマ区切り）
#   -p, --preset <name>       プリセット名（light|medium|heavy|extreme）
#   -o, --output <file>       結果をCSVファイルに出力
#   -h, --help                ヘルプを表示
#
# 例:
#   # 単一テスト（既存のstress_test.shと同じ）
#   ./stress_test_advanced.sh -m single -c 20 -d 60
#
#   # ランプアップテスト（5 → 50並列、5ずつ増加）
#   ./stress_test_advanced.sh -m rampup -s 5 -e 50 -i 5 -d 30
#
#   # 複数設定テスト（10, 20, 50並列で各60秒）
#   ./stress_test_advanced.sh -m multi -l "10,20,50" -d 60
#
#   # プリセットテスト
#   ./stress_test_advanced.sh -m preset -p medium
#
#   # 結果をCSVに出力
#   ./stress_test_advanced.sh -m multi -l "10,20,30" -d 60 -o results.csv
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
MODE="single"
CONCURRENT=10
DURATION=60
START_CONCURRENT=5
END_CONCURRENT=50
INCREMENT=5
PRESET="medium"
OUTPUT_FILE=""
WARMUP=5

# 結果格納用の配列
declare -a TEST_RESULTS

# 一時ディレクトリ
BASE_TEMP_DIR="/tmp/camel-stress-advanced-$$"
mkdir -p "$BASE_TEMP_DIR"

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
OpenShift Camel App 高度なストレステストスクリプト

使い方:
  ./stress_test_advanced.sh [オプション]

オプション:
  -m, --mode <mode>         テストモード
                            - single: 単一の並列数でテスト（デフォルト）
                            - rampup: 段階的に並列数を増加
                            - multi: 複数の並列数で連続テスト
                            - preset: プリセット設定を使用
  
  -c, --concurrent <num>    並列接続数（single mode用、デフォルト: 10）
  -d, --duration <seconds>  各テストの継続時間（秒、デフォルト: 60）
  
  -s, --start <num>         開始並列数（rampup mode用、デフォルト: 5）
  -e, --end <num>           終了並列数（rampup mode用、デフォルト: 50）
  -i, --increment <num>     増加ステップ（rampup mode用、デフォルト: 5）
  
  -l, --list <nums>         テスト並列数リスト（multi mode用、カンマ区切り）
                            例: "5,10,20,50"
  
  -p, --preset <name>       プリセット名（preset mode用）
                            - light: 軽負荷テスト
                            - medium: 中負荷テスト（デフォルト）
                            - heavy: 高負荷テスト
                            - extreme: 極限ストレステスト
  
  -o, --output <file>       結果をCSVファイルに出力
  -w, --warmup <seconds>    ウォームアップ時間（秒、デフォルト: 5）
  -h, --help                このヘルプを表示

テストモード詳細:

1. Single Mode（単一テスト）:
   ./stress_test_advanced.sh -m single -c 20 -d 60
   → 20並列で60秒間テスト

2. Rampup Mode（段階的負荷増加）:
   ./stress_test_advanced.sh -m rampup -s 5 -e 50 -i 5 -d 30
   → 5並列から開始し、5ずつ増やして50並列まで、各30秒テスト

3. Multi Mode（複数設定テスト）:
   ./stress_test_advanced.sh -m multi -l "10,20,50,100" -d 60
   → 10, 20, 50, 100並列で各60秒テスト

4. Preset Mode（プリセット設定）:
   ./stress_test_advanced.sh -m preset -p medium
   → 中負荷テストプリセットを実行

プリセット設定:
  - light:   5並列 → 20並列（5ずつ増加）、各30秒
  - medium:  10並列 → 50並列（10ずつ増加）、各60秒
  - heavy:   20並列 → 100並列（20ずつ増加）、各90秒
  - extreme: 50並列 → 200並列（50ずつ増加）、各120秒

結果出力:
  -o オプションでCSVファイルに結果を保存できます。
  Excelやスプレッドシートでグラフ化して分析できます。

EOF
    exit 0
}

# 引数解析
CONCURRENT_LIST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -c|--concurrent)
            CONCURRENT="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -s|--start)
            START_CONCURRENT="$2"
            shift 2
            ;;
        -e|--end)
            END_CONCURRENT="$2"
            shift 2
            ;;
        -i|--increment)
            INCREMENT="$2"
            shift 2
            ;;
        -l|--list)
            CONCURRENT_LIST="$2"
            shift 2
            ;;
        -p|--preset)
            PRESET="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
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

# プリセット設定の適用
apply_preset() {
    case $PRESET in
        light)
            MODE="rampup"
            START_CONCURRENT=5
            END_CONCURRENT=20
            INCREMENT=5
            DURATION=30
            print_info "プリセット: 軽負荷テスト (5→20並列、各30秒)"
            ;;
        medium)
            MODE="rampup"
            START_CONCURRENT=10
            END_CONCURRENT=50
            INCREMENT=10
            DURATION=60
            print_info "プリセット: 中負荷テスト (10→50並列、各60秒)"
            ;;
        heavy)
            MODE="rampup"
            START_CONCURRENT=20
            END_CONCURRENT=100
            INCREMENT=20
            DURATION=90
            print_info "プリセット: 高負荷テスト (20→100並列、各90秒)"
            ;;
        extreme)
            MODE="rampup"
            START_CONCURRENT=50
            END_CONCURRENT=200
            INCREMENT=50
            DURATION=120
            print_info "プリセット: 極限ストレステスト (50→200並列、各120秒)"
            ;;
        *)
            print_error "不明なプリセット: $PRESET"
            exit 1
            ;;
    esac
}

# クリーンアップ関数
cleanup() {
    print_info "クリーンアップ中..."
    # バックグラウンドプロセスを終了
    jobs -p | xargs -r kill 2>/dev/null
    wait 2>/dev/null
    # 一時ファイルを削除
    rm -rf "$BASE_TEMP_DIR" 2>/dev/null
    exit
}

trap cleanup SIGINT SIGTERM

###############################################################################
# 前提条件の確認
###############################################################################
print_header "1. 前提条件の確認"

# ocコマンドの確認
if ! command -v oc &> /dev/null; then
    print_error "ocコマンドが見つかりません。"
    exit 1
fi
print_success "ocコマンド: 利用可能"

# curlコマンドの確認
if ! command -v curl &> /dev/null; then
    print_error "curlコマンドが見つかりません。"
    exit 1
fi
print_success "curlコマンド: 利用可能"

# bcコマンドの確認
if ! command -v bc &> /dev/null; then
    print_warning "bcコマンドがありません（計算精度が低下します）"
fi

# OpenShift接続確認
if ! oc whoami &> /dev/null; then
    print_error "OpenShiftに接続できません。"
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
# テスト対象の確認
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
    print_success "ヘルスチェック: OK"
else
    print_error "ヘルスチェック失敗: HTTP $HEALTH_CHECK"
    exit 1
fi

###############################################################################
# テスト設定の決定
###############################################################################
print_header "3. テスト設定"

# モードに応じた設定
case $MODE in
    preset)
        apply_preset
        ;;
    rampup)
        print_info "モード: ランプアップテスト"
        print_info "並列数: $START_CONCURRENT → $END_CONCURRENT (${INCREMENT}ずつ増加)"
        print_info "各テスト継続時間: $DURATION 秒"
        ;;
    multi)
        if [ -z "$CONCURRENT_LIST" ]; then
            print_error "multi modeでは -l オプションで並列数リストを指定してください"
            exit 1
        fi
        print_info "モード: 複数設定テスト"
        print_info "並列数リスト: $CONCURRENT_LIST"
        print_info "各テスト継続時間: $DURATION 秒"
        ;;
    single)
        print_info "モード: 単一テスト"
        print_info "並列数: $CONCURRENT"
        print_info "テスト継続時間: $DURATION 秒"
        ;;
    *)
        print_error "不明なモード: $MODE"
        exit 1
        ;;
esac

# Grafana監視の案内
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_URL" ]; then
    echo ""
    print_info "📊 Grafana: https://$GRAFANA_URL"
    print_warning "テスト開始前にGrafanaを開いてメトリクスを監視することを推奨します。"
    echo ""
    read -p "準備ができたらEnterキーを押してください..." -t 30
    echo ""
fi

###############################################################################
# 単一ストレステスト実行関数
###############################################################################
run_single_test() {
    local concurrent=$1
    local duration=$2
    local test_name=$3
    
    print_header "テスト: $test_name (並列数: $concurrent)"
    
    # テスト用一時ディレクトリ
    local temp_dir="$BASE_TEMP_DIR/test-$concurrent"
    mkdir -p "$temp_dir"
    
    local results_file="$temp_dir/results.txt"
    local times_file="$temp_dir/times.txt"
    local errors_file="$temp_dir/errors.txt"
    
    # リクエスト送信関数
    send_request() {
        local request_id=$1
        local start=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000)))
        
        local response=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST \
            "https://$CAMEL_URL/camel/api/orders" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"test-${concurrent}-${request_id}\",\"product\":\"StressTest\",\"quantity\":$((RANDOM % 100 + 1))}" \
            2>/dev/null || echo "000")
        
        local end=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000)))
        local elapsed=$((end - start))
        
        echo "$elapsed" >> "$times_file"
        
        if [ "$response" == "200" ]; then
            echo "SUCCESS" >> "$results_file"
        else
            echo "ERROR:$response" >> "$results_file"
            echo "$response" >> "$errors_file"
        fi
    }
    
    # テスト実行
    print_progress "テスト実行中..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_counter=0
    
    while true; do
        local current_time=$(date +%s)
        
        # 時間制限チェック
        if [ $current_time -ge $end_time ]; then
            break
        fi
        
        # 並列数チェック
        local running_jobs=$(jobs -r | wc -l)
        if [ $running_jobs -lt $concurrent ]; then
            request_counter=$((request_counter + 1))
            send_request $request_counter &
        fi
        
        # 進捗表示
        if [ $((request_counter % 50)) -eq 0 ]; then
            local elapsed=$((current_time - start_time))
            local remaining=$((end_time - current_time))
            echo -ne "\r${CYAN}進捗: ${NC}${request_counter} リクエスト | ${elapsed}秒経過 | 残り${remaining}秒   "
        fi
        
        sleep 0.1
    done
    
    # 完了待機
    wait
    echo ""
    
    local actual_end_time=$(date +%s)
    local total_duration=$((actual_end_time - start_time))
    
    # 結果集計
    local total_requests=$(wc -l < "$results_file" 2>/dev/null || echo "0")
    local success_count=$(grep -c "SUCCESS" "$results_file" 2>/dev/null || echo "0")
    local error_count=$(grep -c "ERROR" "$results_file" 2>/dev/null || echo "0")
    
    # レスポンスタイム計算
    local avg_time=0
    local min_time=0
    local max_time=0
    local p95=0
    local p99=0
    
    if [ -f "$times_file" ] && [ -s "$times_file" ]; then
        avg_time=$(awk '{ total += $1; count++ } END { print (count > 0) ? total/count : 0 }' "$times_file")
        min_time=$(sort -n "$times_file" | head -1)
        max_time=$(sort -n "$times_file" | tail -1)
        p95=$(sort -n "$times_file" | awk 'BEGIN{c=0} {total[c]=$1; c++} END{print total[int(c*0.95-0.5)]}')
        p99=$(sort -n "$times_file" | awk 'BEGIN{c=0} {total[c]=$1; c++} END{print total[int(c*0.99-0.5)]}')
    fi
    
    # スループット計算
    local throughput=$(echo "scale=2; $total_requests / $total_duration" | bc 2>/dev/null || echo "0")
    
    # エラー率計算
    local error_rate=0
    if [ $total_requests -gt 0 ]; then
        error_rate=$(echo "scale=2; ($error_count * 100) / $total_requests" | bc 2>/dev/null || echo "0")
    fi
    
    # 結果表示
    echo ""
    echo -e "${GREEN}=== テスト結果 ===${NC}"
    echo -e "${CYAN}並列数:${NC}             $concurrent"
    echo -e "${CYAN}継続時間:${NC}           $total_duration 秒"
    echo -e "${CYAN}総リクエスト数:${NC}     $total_requests"
    echo -e "${CYAN}成功:${NC}               ${GREEN}$success_count${NC}"
    echo -e "${CYAN}失敗:${NC}               ${RED}$error_count${NC}"
    echo -e "${CYAN}エラー率:${NC}           ${error_rate}%"
    echo -e "${CYAN}スループット:${NC}       ${throughput} req/sec"
    echo -e "${CYAN}平均レスポンス:${NC}     $(printf "%.2f" $avg_time) ms"
    echo -e "${CYAN}最小レスポンス:${NC}     $min_time ms"
    echo -e "${CYAN}最大レスポンス:${NC}     $max_time ms"
    echo -e "${CYAN}95パーセンタイル:${NC}  $p95 ms"
    echo -e "${CYAN}99パーセンタイル:${NC}  $p99 ms"
    
    # 結果を配列に保存
    TEST_RESULTS+=("$concurrent,$total_duration,$total_requests,$success_count,$error_count,$error_rate,$throughput,$avg_time,$min_time,$max_time,$p95,$p99")
    
    print_success "テスト完了"
    
    # テスト間の待機時間
    if [ "$MODE" != "single" ]; then
        print_info "次のテストまで10秒待機..."
        sleep 10
    fi
}

###############################################################################
# ウォームアップ
###############################################################################
if [ $WARMUP -gt 0 ]; then
    print_header "4. ウォームアップ ($WARMUP 秒)"
    
    print_progress "アプリケーションをウォームアップ中..."
    
    for i in $(seq 1 $WARMUP); do
        curl -k -s -o /dev/null -X POST \
            "https://$CAMEL_URL/camel/api/orders" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"warmup-$i\",\"product\":\"Warmup\",\"quantity\":1}" &
        sleep 1
    done
    
    wait
    print_success "ウォームアップ完了"
fi

###############################################################################
# メインテスト実行
###############################################################################
print_header "5. ストレステスト実行"

case $MODE in
    single)
        run_single_test $CONCURRENT $DURATION "単一テスト"
        ;;
    
    rampup)
        test_num=1
        for concurrent in $(seq $START_CONCURRENT $INCREMENT $END_CONCURRENT); do
            run_single_test $concurrent $DURATION "ランプアップテスト #$test_num"
            test_num=$((test_num + 1))
        done
        ;;
    
    multi)
        test_num=1
        IFS=',' read -ra CONCURRENT_ARRAY <<< "$CONCURRENT_LIST"
        for concurrent in "${CONCURRENT_ARRAY[@]}"; do
            run_single_test $concurrent $DURATION "マルチテスト #$test_num"
            test_num=$((test_num + 1))
        done
        ;;
esac

###############################################################################
# 結果サマリーと比較
###############################################################################
print_header "6. 結果サマリー"

echo ""
echo -e "${GREEN}=== すべてのテスト結果 ===${NC}"
echo ""
printf "${CYAN}%-12s %-12s %-12s %-12s %-12s %-12s${NC}\n" \
    "並列数" "リクエスト" "成功率" "エラー率" "RPS" "平均応答時間"
echo "--------------------------------------------------------------------------------"

for result in "${TEST_RESULTS[@]}"; do
    IFS=',' read -r concurrent duration total success errors error_rate throughput avg_time min_time max_time p95 p99 <<< "$result"
    
    success_rate=$(echo "scale=2; 100 - $error_rate" | bc 2>/dev/null || echo "0")
    
    printf "%-12s %-12s %-12s %-12s %-12s %-12s\n" \
        "$concurrent" "$total" "${success_rate}%" "${error_rate}%" \
        "$throughput" "$(printf "%.2f" $avg_time)ms"
done

echo ""

###############################################################################
# CSV出力
###############################################################################
if [ -n "$OUTPUT_FILE" ]; then
    print_header "7. CSV出力"
    
    echo "Concurrent,Duration,TotalRequests,Success,Errors,ErrorRate,Throughput,AvgTime,MinTime,MaxTime,P95,P99" > "$OUTPUT_FILE"
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result" >> "$OUTPUT_FILE"
    done
    
    print_success "結果を保存しました: $OUTPUT_FILE"
fi

###############################################################################
# 推奨事項
###############################################################################
print_header "8. 分析と推奨事項"

echo ""

# 最適な並列数を見つける
if [ ${#TEST_RESULTS[@]} -gt 1 ]; then
    print_info "パフォーマンス分析:"
    echo ""
    
    best_throughput=0
    best_concurrent=0
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS=',' read -r concurrent duration total success errors error_rate throughput avg_time min_time max_time p95 p99 <<< "$result"
        
        # エラー率が5%未満の場合のみ考慮
        if (( $(echo "$error_rate < 5" | bc -l 2>/dev/null || echo "0") )); then
            if (( $(echo "$throughput > $best_throughput" | bc -l 2>/dev/null || echo "0") )); then
                best_throughput=$throughput
                best_concurrent=$concurrent
            fi
        fi
    done
    
    if [ $best_concurrent -gt 0 ]; then
        print_success "最適な並列数: $best_concurrent (スループット: $best_throughput req/sec)"
    else
        print_warning "すべてのテストでエラー率が5%を超えています。"
    fi
fi

echo ""
print_info "Grafanaで詳細を確認:"
if [ -n "$GRAFANA_URL" ]; then
    echo "  https://$GRAFANA_URL"
fi

###############################################################################
# クリーンアップ
###############################################################################
print_header "9. クリーンアップ"

rm -rf "$BASE_TEMP_DIR"
print_success "一時ファイルを削除しました"

echo ""
print_success "すべてのテストが完了しました！"
echo ""

exit 0


