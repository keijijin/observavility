#!/bin/bash

# Camelルート別RPSモニタリングスクリプト
# 使い方: ./rps_monitor_camel_route.sh [interval_seconds] [route_id]

INTERVAL=${1:-5}
ROUTE_ID=${2:-"order-consumer-route"}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== Camel ルート RPSモニタリング ==="
echo "ルート: $ROUTE_ID"
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# Camelルート処理数を取得（macOS互換）
get_count() {
    curl -s "$ACTUATOR_URL" | \
    grep "camel_exchanges_total" | \
    grep "routeId=\"$ROUTE_ID\"" | \
    awk '{print $NF}' | \
    head -1
}

while true; do
    BEFORE=$(get_count)
    
    if [ -z "$BEFORE" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE_ID"
        echo ""
        echo "利用可能なルート:"
        curl -s "$ACTUATOR_URL" | grep "camel_exchanges_total" | awk -F'routeId="' '{print $2}' | awk -F'"' '{print $1}' | sort -u | head -10
        sleep $INTERVAL
        continue
    fi
    
    sleep $INTERVAL
    
    AFTER=$(get_count)
    
    if [ -z "$AFTER" ]; then
        echo "$(date '+%H:%M:%S') - ❌ ルートが見つかりません: $ROUTE_ID"
        continue
    fi
    
    RPS=$(echo "scale=2; ($AFTER - $BEFORE) / $INTERVAL" | bc)
    TOTAL=$(printf "%.0f" "$AFTER")
    
    echo "$(date '+%H:%M:%S') - RPS: $RPS msg/sec | 累積: $TOTAL messages"
done


