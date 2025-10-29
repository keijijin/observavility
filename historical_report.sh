#!/bin/bash
# 過去24時間のシステムレポート生成スクリプト

echo "=========================================="
echo "  過去24時間のシステムレポート"
echo "=========================================="
echo ""
echo "生成時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# メモリ使用率の最大値
echo "📊 メモリ使用率:"
MAX_MEMORY=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=max_over_time((jvm_memory_used_bytes{application="camel-observability-demo",area="heap"}/jvm_memory_max_bytes{application="camel-observability-demo",area="heap"}*100)[24h:1m])' | \
  jq -r '.data.result[0].value[1]' 2>/dev/null)

if [ ! -z "$MAX_MEMORY" ] && [ "$MAX_MEMORY" != "null" ]; then
    printf "  最大値: %.2f%%\n" $MAX_MEMORY
else
    echo "  最大値: データなし"
fi

# 平均メモリ使用率
AVG_MEMORY=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((jvm_memory_used_bytes{application="camel-observability-demo",area="heap"}/jvm_memory_max_bytes{application="camel-observability-demo",area="heap"}*100)[24h:1m])' | \
  jq -r '.data.result[0].value[1]' 2>/dev/null)

if [ ! -z "$AVG_MEMORY" ] && [ "$AVG_MEMORY" != "null" ]; then
    printf "  平均値: %.2f%%\n" $AVG_MEMORY
else
    echo "  平均値: データなし"
fi

# エラー率
echo ""
echo "❌ エラー率:"
AVG_ERROR=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((rate(camel_exchanges_failed_total{application="camel-observability-demo"}[5m])/rate(camel_exchanges_total{application="camel-observability-demo"}[5m])*100)[24h:5m])' | \
  jq -r '.data.result[0].value[1]' 2>/dev/null)

if [ ! -z "$AVG_ERROR" ] && [ "$AVG_ERROR" != "null" ]; then
    printf "  平均: %.2f%%\n" $AVG_ERROR
else
    echo "  平均: データなし"
fi

# リクエスト総数
echo ""
echo "📈 HTTPリクエスト総数:"
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=increase(http_server_requests_seconds_count{application="camel-observability-demo"}[24h])' | \
  jq -r '.data.result[] | "  \(.metric.uri): \(.value[1] | tonumber | floor) requests"' 2>/dev/null || echo "  データなし"

# アクティブスレッド数
echo ""
echo "🧵 スレッド数:"
AVG_THREADS=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time(jvm_threads_live_threads{application="camel-observability-demo"}[24h])' | \
  jq -r '.data.result[0].value[1]' 2>/dev/null)

if [ ! -z "$AVG_THREADS" ] && [ "$AVG_THREADS" != "null" ]; then
    printf "  平均: %.0f threads\n" $AVG_THREADS
else
    echo "  平均: データなし"
fi

# GC実行回数
echo ""
echo "🗑️ ガベージコレクション:"
TOTAL_GC=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=increase(jvm_gc_pause_seconds_count{application="camel-observability-demo"}[24h])' | \
  jq -r '.data.result[0].value[1]' 2>/dev/null)

if [ ! -z "$TOTAL_GC" ] && [ "$TOTAL_GC" != "null" ]; then
    printf "  実行回数: %.0f 回\n" $TOTAL_GC
else
    echo "  実行回数: データなし"
fi

echo ""
echo "=========================================="
echo "  レポート生成完了"
echo "=========================================="




