#!/bin/bash

# ルート別RPSモニタリングスクリプト
# 使い方: ./rps_monitor.sh [interval_seconds] [route_uri]

INTERVAL=${1:-5}
ROUTE=${2:-"/camel/api/orders"}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== ルート別RPSモニタリング ==="
echo "ルート: $ROUTE"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# 初回測定（macOS互換）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "http_server_requests_seconds_count" | \
    grep "uri=\"$ROUTE\"" | \
    awk '{print $NF}' | \
    head -1
}

while true; do
    BEFORE=$(get_count)
    
    if [ -z "$BEFORE" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE"
        echo ""
        echo "原因:"
        echo "  - アプリケーションが起動していない"
        echo "  - ルートにリクエストがまだ来ていない（累積カウント=0）"
        echo ""
        echo "確認: curl http://localhost:8080/actuator/health"
        sleep $INTERVAL
        continue
    fi
    
    sleep $INTERVAL
    
    AFTER=$(get_count)
    
    if [ -z "$AFTER" ]; then
        echo "$(date '+%H:%M:%S') - ルートが見つかりません: $ROUTE"
        continue
    fi
    
    RPS=$(echo "scale=2; ($AFTER - $BEFORE) / $INTERVAL" | bc)
    TOTAL=$(printf "%.0f" "$AFTER")
    
    echo "$(date '+%H:%M:%S') - RPS: $RPS req/sec | 累積: $TOTAL requests"
done
