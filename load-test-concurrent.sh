#!/bin/bash

# 並行負荷テストスクリプト
# 複数の同時接続でCamel Observability Demoに負荷をかける

echo "================================"
echo "並行負荷テスト"
echo "================================"
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト設定
ENDPOINT="http://localhost:8080/camel/api/orders"
TOTAL_REQUESTS=100
CONCURRENT=10
DURATION=30

# 引数の処理
while getopts "r:c:d:h" opt; do
  case $opt in
    r) TOTAL_REQUESTS=$OPTARG ;;
    c) CONCURRENT=$OPTARG ;;
    d) DURATION=$OPTARG ;;
    h)
      echo "使用方法: $0 [-r REQUESTS] [-c CONCURRENT] [-d DURATION]"
      echo ""
      echo "オプション:"
      echo "  -r REQUESTS   総リクエスト数（デフォルト: 100）"
      echo "  -c CONCURRENT 同時接続数（デフォルト: 10）"
      echo "  -d DURATION   テスト継続時間（秒、デフォルト: 30）"
      echo "  -h            このヘルプを表示"
      echo ""
      echo "例:"
      echo "  $0 -r 500 -c 20 -d 60    # 20並列で500リクエスト、最大60秒"
      echo "  $0 -r 1000 -c 50 -d 120  # 50並列で1000リクエスト、最大120秒"
      exit 0
      ;;
    \?) echo "無効なオプション: -$OPTARG" >&2; exit 1 ;;
  esac
done

echo "設定:"
echo "  エンドポイント: $ENDPOINT"
echo "  総リクエスト数: $TOTAL_REQUESTS"
echo "  同時接続数: $CONCURRENT"
echo "  最大継続時間: ${DURATION}秒"
echo ""

# 一時ファイル
TEMP_DIR=$(mktemp -d)
RESULT_FILE="$TEMP_DIR/results.txt"
trap "rm -rf $TEMP_DIR" EXIT

echo "テスト開始..."
echo ""

START_TIME=$(date +%s)

# 並行リクエスト関数
send_request() {
  local id=$1
  local result_file=$2
  
  RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST $ENDPOINT 2>&1)
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 2 | head -n 1)
  TIME_TOTAL=$(echo "$RESPONSE" | tail -n 1)
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "SUCCESS $TIME_TOTAL" >> $result_file
  else
    echo "FAILED $HTTP_CODE" >> $result_file
  fi
}

# プログレスバー関数
show_progress() {
  local current=$1
  local total=$2
  local width=50
  local percentage=$((current * 100 / total))
  local completed=$((width * current / total))
  local remaining=$((width - completed))
  
  printf "\r${BLUE}進行状況:${NC} ["
  printf "%${completed}s" | tr ' ' '='
  printf "%${remaining}s" | tr ' ' ' '
  printf "] %3d%% (%d/%d)" $percentage $current $total
}

# 並行実行
REQUESTS_SENT=0
ACTIVE_JOBS=0

while [ $REQUESTS_SENT -lt $TOTAL_REQUESTS ]; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  
  # タイムアウトチェック
  if [ $ELAPSED -ge $DURATION ]; then
    echo ""
    echo -e "${YELLOW}⚠ 最大継続時間に達しました${NC}"
    break
  fi
  
  # 同時接続数の制御
  while [ $ACTIVE_JOBS -ge $CONCURRENT ]; do
    wait -n 2>/dev/null
    ACTIVE_JOBS=$((ACTIVE_JOBS - 1))
  done
  
  # リクエスト送信
  send_request $REQUESTS_SENT $RESULT_FILE &
  REQUESTS_SENT=$((REQUESTS_SENT + 1))
  ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
  
  show_progress $REQUESTS_SENT $TOTAL_REQUESTS
done

# 残りのジョブを待機
wait

echo ""
echo ""
echo "分析中..."
sleep 1

# 結果の集計
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

SUCCESS_COUNT=$(grep -c "SUCCESS" $RESULT_FILE 2>/dev/null || echo 0)
FAILED_COUNT=$(grep -c "FAILED" $RESULT_FILE 2>/dev/null || echo 0)
TOTAL_COUNT=$((SUCCESS_COUNT + FAILED_COUNT))

# レスポンスタイムの統計
if [ $SUCCESS_COUNT -gt 0 ]; then
  RESPONSE_TIMES=$(grep "SUCCESS" $RESULT_FILE | awk '{print $2}')
  AVG_TIME=$(echo "$RESPONSE_TIMES" | awk '{sum+=$1; count++} END {printf "%.3f", sum/count}')
  MIN_TIME=$(echo "$RESPONSE_TIMES" | sort -n | head -n 1)
  MAX_TIME=$(echo "$RESPONSE_TIMES" | sort -n | tail -n 1)
else
  AVG_TIME="N/A"
  MIN_TIME="N/A"
  MAX_TIME="N/A"
fi

# 結果表示
echo ""
echo "================================"
echo "テスト結果"
echo "================================"
echo "総リクエスト数: $TOTAL_COUNT"
echo -e "${GREEN}成功: $SUCCESS_COUNT${NC}"
echo -e "${RED}失敗: $FAILED_COUNT${NC}"
echo ""
echo "所要時間: ${TOTAL_DURATION}秒"
echo "平均レート: $(echo "scale=2; $TOTAL_COUNT / $TOTAL_DURATION" | bc) req/s"
echo ""
echo "レスポンスタイム統計:"
echo "  平均: ${AVG_TIME}秒"
echo "  最小: ${MIN_TIME}秒"
echo "  最大: ${MAX_TIME}秒"
echo ""
echo "================================"
echo "次のステップ"
echo "================================"
echo ""
echo "📊 Grafanaでメトリクスを確認:"
echo "   http://localhost:3000"
echo ""
echo "🔍 Prometheusでクエリを実行:"
echo "   http://localhost:9090"
echo "   例: rate(http_server_requests_seconds_count[1m])"
echo ""
echo "📝 アプリケーションログを確認:"
echo "   tail -f demo/camel-app/app.log"
echo ""
echo "🗺️ Tempoでトレースを確認:"
echo "   Grafana → Explore → Tempo"
echo ""



