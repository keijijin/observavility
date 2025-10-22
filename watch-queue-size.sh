#!/bin/bash

# Undertowキューサイズをリアルタイム監視

echo "========================================="
echo "📊 Undertowメトリクス リアルタイム監視"
echo "========================================="
echo ""
echo "Ctrl+C で終了"
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ACTUATOR="http://localhost:8080/actuator/prometheus"

# 接続確認
if ! curl -s -f -m 3 "$ACTUATOR" > /dev/null 2>&1; then
    echo -e "${RED}✗ アプリケーションに接続できません${NC}"
    echo "  URL: $ACTUATOR"
    exit 1
fi

# ヘッダー表示
printf "${BOLD}%-10s | %-12s | %-12s | %-12s | %-12s${NC}\n" "時刻" "Queue Size" "Active Req" "Workers" "Usage %"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while true; do
    # メトリクスを取得
    METRICS=$(curl -s "$ACTUATOR" 2>/dev/null)
    
    QUEUE_SIZE=$(echo "$METRICS" | grep "^undertow_request_queue_size" | awk '{print $2}')
    ACTIVE_REQ=$(echo "$METRICS" | grep "^undertow_active_requests" | awk '{print $2}')
    WORKERS=$(echo "$METRICS" | grep "^undertow_worker_threads" | awk '{print $2}')
    
    # 使用率を計算
    if [[ -n "$ACTIVE_REQ" && -n "$WORKERS" ]]; then
        USAGE=$(echo "scale=1; ($ACTIVE_REQ / $WORKERS) * 100" | bc 2>/dev/null)
    else
        USAGE="N/A"
    fi
    
    # 時刻
    TIMESTAMP=$(date +%H:%M:%S)
    
    # 色付け
    QUEUE_INT=$(echo "$QUEUE_SIZE" | cut -d. -f1)
    if [[ -n "$QUEUE_INT" && $QUEUE_INT -gt 0 ]]; then
        QUEUE_COLOR=$GREEN
    else
        QUEUE_COLOR=$NC
    fi
    
    # 使用率による色付け
    if [[ "$USAGE" != "N/A" ]]; then
        USAGE_INT=$(echo "$USAGE" | cut -d. -f1)
        if [ "$USAGE_INT" -ge 90 ]; then
            USAGE_COLOR=$RED
        elif [ "$USAGE_INT" -ge 70 ]; then
            USAGE_COLOR=$YELLOW
        else
            USAGE_COLOR=$GREEN
        fi
    else
        USAGE_COLOR=$NC
    fi
    
    # 表示
    printf "${CYAN}%s${NC} | ${QUEUE_COLOR}%-12s${NC} | %-12s | %-12s | ${USAGE_COLOR}%-12s${NC}\n" \
        "$TIMESTAMP" \
        "${QUEUE_SIZE:-0}" \
        "${ACTIVE_REQ:-0}" \
        "${WORKERS:-N/A}" \
        "${USAGE:-N/A}"
    
    sleep 1
done


