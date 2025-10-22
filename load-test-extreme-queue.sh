#!/bin/bash

# 極限負荷テスト - Undertowキューサイズを増加させる
# 目的: キューイングを発生させてメトリクスを確認する

echo "========================================="
echo "🚀 Undertowキューサイズ増加テスト"
echo "========================================="
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ENDPOINT="http://localhost:8080/camel/api/orders"
ACTUATOR="http://localhost:8080/actuator/prometheus"

# アプリケーションの接続確認
echo -n "アプリケーション接続確認中... "
# ヘルスチェックエンドポイントで確認（GETで確認可能）
if ! curl -s -f -m 3 "http://localhost:8080/actuator/health" > /dev/null 2>&1; then
    echo -e "${RED}✗ 失敗${NC}"
    echo ""
    echo "エラー: アプリケーションに接続できません"
    echo "以下を確認してください:"
    echo "  1. アプリケーションが起動しているか"
    echo "  2. ポート8080が使用可能か"
    echo "  3. ヘルスチェックURL: http://localhost:8080/actuator/health"
    exit 1
fi
echo -e "${GREEN}✓ 成功${NC}"
echo ""

# 現在のUndertow設定を確認
echo "📊 現在のUndertow設定:"
WORKER_THREADS=$(curl -s "$ACTUATOR" | grep "^undertow_worker_threads" | awk '{print $2}')
CURRENT_QUEUE=$(curl -s "$ACTUATOR" | grep "^undertow_request_queue_size" | awk '{print $2}')
CURRENT_ACTIVE=$(curl -s "$ACTUATOR" | grep "^undertow_active_requests" | awk '{print $2}')

echo "  ワーカースレッド数: ${WORKER_THREADS:-不明}"
echo "  現在のキューサイズ: ${CURRENT_QUEUE:-0}"
echo "  現在のアクティブリクエスト: ${CURRENT_ACTIVE:-0}"
echo ""

# ワーカースレッド数に応じた推奨並列数
if [[ -n "$WORKER_THREADS" ]]; then
    WORKER_INT=$(echo "$WORKER_THREADS" | cut -d. -f1)
    if (( WORKER_INT < 10 )); then
        RECOMMENDED_CONCURRENT=100
        echo -e "${GREEN}✓ ワーカースレッド数が少ない（${WORKER_INT}）ため、キューイングが発生しやすい環境です${NC}"
    elif (( WORKER_INT < 50 )); then
        RECOMMENDED_CONCURRENT=500
        echo -e "${YELLOW}⚠ ワーカースレッド数（${WORKER_INT}）に対して、高負荷が必要です${NC}"
    else
        RECOMMENDED_CONCURRENT=1000
        echo -e "${YELLOW}⚠ ワーカースレッド数が多い（${WORKER_INT}）ため、非常に高い負荷が必要です${NC}"
    fi
    echo "  推奨並列数: ${RECOMMENDED_CONCURRENT}"
else
    RECOMMENDED_CONCURRENT=500
fi
echo ""

# テスト設定
echo "📋 テスト設定:"
echo "  並列接続数: $RECOMMENDED_CONCURRENT"
echo "  継続時間: 30秒"
echo "  目的: Undertowキューサイズを増加させる"
echo ""

# 警告
if [[ -n "$WORKER_THREADS" && "$WORKER_INT" -gt 100 ]]; then
    echo -e "${YELLOW}⚠ 警告${NC}"
    echo "  現在のワーカースレッド数（${WORKER_INT}）では、キューサイズが増加しない可能性があります。"
    echo ""
    echo "  キューサイズを確実に増加させるには、以下を推奨します:"
    echo "  1. application.ymlでワーカースレッド数を5に減らす"
    echo "     server.undertow.threads.worker: 5"
    echo "  2. アプリケーションを再起動"
    echo "  3. このテストを再実行"
    echo ""
    echo "  詳細: QUEUE_SIZE_TESTING_GUIDE.md を参照"
    echo ""
fi

read -p "続行しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "テストをキャンセルしました"
    exit 0
fi

echo ""
echo -e "${BLUE}テスト開始...${NC}"
echo ""

# 結果ファイル
RESULT_FILE=$(mktemp)
trap "rm -f $RESULT_FILE" EXIT

# バックグラウンドでリクエストを送信する関数
send_request() {
    local id=$1
    START=$(date +%s.%N)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{"id": "ORD-EXT-'$id'", "product": "ExtremeTest", "quantity": 1, "price": 100}' 2>&1)
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo "$HTTP_CODE $ELAPSED" >> "$RESULT_FILE"
}

# テスト実行
START_TIME=$(date +%s)
DURATION=30
END_TIME=$((START_TIME + DURATION))

echo "📤 $RECOMMENDED_CONCURRENT 並列でリクエストを送信中..."
echo ""

# 並列でリクエストを送信
PIDS=()
for i in $(seq 1 $RECOMMENDED_CONCURRENT); do
    send_request $i &
    PIDS+=($!)
    
    # 進捗表示（100件ごと）
    if (( i % 100 == 0 )); then
        printf "\r  送信済み: %d / %d" $i $RECOMMENDED_CONCURRENT
    fi
done

printf "\r  送信済み: %d / %d\n" $RECOMMENDED_CONCURRENT $RECOMMENDED_CONCURRENT
echo ""
echo "⏳ リクエスト処理を待機中..."

# リアルタイムメトリクス表示
echo ""
echo "📊 リアルタイムメトリクス（5秒間隔）:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in {1..6}; do
    sleep 5
    
    # メトリクスを取得
    QUEUE_SIZE=$(curl -s "$ACTUATOR" 2>/dev/null | grep "^undertow_request_queue_size" | awk '{print $2}')
    ACTIVE_REQ=$(curl -s "$ACTUATOR" 2>/dev/null | grep "^undertow_active_requests" | awk '{print $2}')
    WORKER_USAGE=$(echo "scale=1; ($ACTIVE_REQ / $WORKER_THREADS) * 100" | bc 2>/dev/null)
    
    # 完了したプロセス数をカウント
    COMPLETED=0
    for pid in "${PIDS[@]}"; do
        if ! kill -0 $pid 2>/dev/null; then
            ((COMPLETED++))
        fi
    done
    
    ELAPSED=$(($(date +%s) - START_TIME))
    
    # 色付き表示
    if (( $(echo "$QUEUE_SIZE > 0" | bc -l 2>/dev/null || echo 0) )); then
        QUEUE_COLOR=$GREEN
    else
        QUEUE_COLOR=$YELLOW
    fi
    
    echo -e "[${ELAPSED}秒] ${CYAN}Queue:${QUEUE_COLOR} ${QUEUE_SIZE:-0}${NC} | ${CYAN}Active:${NC} ${ACTIVE_REQ:-0} | ${CYAN}Worker Usage:${NC} ${WORKER_USAGE:-0}% | ${CYAN}完了:${NC} $COMPLETED/${RECOMMENDED_CONCURRENT}"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# すべてのプロセスの完了を待機
echo "⏳ すべてのリクエストの完了を待機中..."
wait

# 結果集計
echo ""
echo "========================================="
echo "📊 テスト結果"
echo "========================================="

TOTAL=$(wc -l < "$RESULT_FILE")
SUCCESS=$(grep -c "^200" "$RESULT_FILE" 2>/dev/null || echo 0)
FAILED=$((TOTAL - SUCCESS))

if [ $TOTAL -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=2; $SUCCESS * 100 / $TOTAL" | bc)
    FAILURE_RATE=$(echo "scale=2; $FAILED * 100 / $TOTAL" | bc)
else
    SUCCESS_RATE=0
    FAILURE_RATE=0
fi

# 応答時間統計
if [ $SUCCESS -gt 0 ]; then
    AVG_TIME=$(grep "^200" "$RESULT_FILE" | awk '{sum+=$2; count++} END {printf "%.3f", sum/count}')
    MIN_TIME=$(grep "^200" "$RESULT_FILE" | awk '{print $2}' | sort -n | head -1)
    MAX_TIME=$(grep "^200" "$RESULT_FILE" | awk '{print $2}' | sort -n | tail -1)
else
    AVG_TIME="N/A"
    MIN_TIME="N/A"
    MAX_TIME="N/A"
fi

echo ""
echo "リクエスト統計:"
echo "  総リクエスト数: $TOTAL"
echo -e "  ${GREEN}成功: $SUCCESS ($SUCCESS_RATE%)${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}失敗: $FAILED ($FAILURE_RATE%)${NC}"
else
    echo -e "  ${GREEN}失敗: $FAILED ($FAILURE_RATE%)${NC}"
fi
echo ""

echo "応答時間:"
echo "  平均: ${AVG_TIME}秒"
echo "  最小: ${MIN_TIME}秒"
echo "  最大: ${MAX_TIME}秒"
echo ""

# 最終メトリクス
echo "最終Undertowメトリクス:"
FINAL_QUEUE=$(curl -s "$ACTUATOR" | grep "^undertow_request_queue_size" | awk '{print $2}')
FINAL_ACTIVE=$(curl -s "$ACTUATOR" | grep "^undertow_active_requests" | awk '{print $2}')
FINAL_USAGE=$(echo "scale=1; ($FINAL_ACTIVE / $WORKER_THREADS) * 100" | bc 2>/dev/null)

echo "  ワーカースレッド数: ${WORKER_THREADS:-不明}"
echo "  キューサイズ: ${FINAL_QUEUE:-0}"
echo "  アクティブリクエスト: ${FINAL_ACTIVE:-0}"
echo "  ワーカー使用率: ${FINAL_USAGE:-0}%"
echo ""

# 評価
echo "========================================="
echo "🎯 評価"
echo "========================================="
echo ""

QUEUE_INT=$(echo "$FINAL_QUEUE" | cut -d. -f1)
if [[ -n "$QUEUE_INT" && $QUEUE_INT -gt 0 ]]; then
    echo -e "${GREEN}✓ キューサイズが増加しました！${NC}"
    echo "  テスト成功: Undertowキューイングが発生しました"
    echo "  最大キューサイズ: $FINAL_QUEUE"
else
    echo -e "${YELLOW}⚠ キューサイズは増加しませんでした${NC}"
    echo ""
    echo "考えられる理由:"
    echo "  1. ワーカースレッド数が多すぎる（${WORKER_INT:-不明}スレッド）"
    echo "  2. リクエスト処理が高速すぎる"
    echo "  3. 並列数が不十分（${RECOMMENDED_CONCURRENT}並列）"
    echo ""
    echo "推奨アクション:"
    echo "  1. application.ymlでワーカースレッド数を5に減らす:"
    echo "     server:"
    echo "       undertow:"
    echo "         threads:"
    echo "           worker: 5"
    echo ""
    echo "  2. アプリケーションを再起動"
    echo ""
    echo "  3. このテストを再実行"
    echo ""
    echo "詳細: QUEUE_SIZE_TESTING_GUIDE.md を参照"
fi

echo ""
echo "========================================="
echo "🔍 確認方法"
echo "========================================="
echo ""
echo "1. Grafana Undertow Dashboard:"
echo "   http://localhost:3000"
echo "   → 'Undertow Monitoring Dashboard' を開く"
echo "   → 'Queue Size' パネルを確認"
echo ""
echo "2. Prometheus直接確認:"
echo "   curl -s http://localhost:8080/actuator/prometheus | grep undertow"
echo ""
echo "3. リアルタイム監視:"
echo "   watch -n 1 'curl -s http://localhost:8080/actuator/prometheus | grep undertow'"
echo ""
echo "4. スレッド監視:"
echo "   ./thread_monitor.sh"
echo ""

echo "========================================="
echo "✅ テスト完了"
echo "========================================="
echo ""

