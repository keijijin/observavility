#!/bin/bash

# ストレステストスクリプト
# 段階的に負荷を増やしてシステムの限界を探る

echo "================================"
echo "ストレステスト"
echo "================================"
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENDPOINT="http://localhost:8080/camel/api/orders"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "このテストは段階的に負荷を増やします"
echo ""
echo "段階:"
echo "  1. ウォームアップ (5並列、10秒)"
echo "  2. 低負荷 (10並列、15秒)"
echo "  3. 中負荷 (20並列、15秒)"
echo "  4. 高負荷 (50並列、15秒)"
echo "  5. ストレス (100並列、20秒)"
echo ""
read -p "続行しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "テストをキャンセルしました"
    exit 0
fi

echo ""
echo "テスト開始..."
echo ""

# テスト関数
run_stage() {
  local stage_name=$1
  local concurrent=$2
  local duration=$3
  local result_file="$TEMP_DIR/stage_$stage_name.txt"
  
  echo "================================"
  echo "段階: $stage_name"
  echo "同時接続数: $concurrent"
  echo "継続時間: ${duration}秒"
  echo "================================"
  
  local start_time=$(date +%s)
  local end_time=$((start_time + duration))
  local count=0
  local pids=()
  
  # バックグラウンドでリクエストを送信
  send_continuous_requests() {
    local result_file=$1
    while true; do
      RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST $ENDPOINT 2>&1)
      HTTP_CODE=$(echo "$RESPONSE" | tail -n 2 | head -n 1)
      TIME_TOTAL=$(echo "$RESPONSE" | tail -n 1)
      
      if [ "$HTTP_CODE" = "200" ]; then
        echo "SUCCESS $TIME_TOTAL" >> $result_file
      else
        echo "FAILED $HTTP_CODE" >> $result_file
      fi
    done
  }
  
  # 並行プロセスを起動
  for i in $(seq 1 $concurrent); do
    send_continuous_requests "$result_file" &
    pids+=($!)
  done
  
  # 進行状況表示
  while [ $(date +%s) -lt $end_time ]; do
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local remaining=$((duration - elapsed))
    printf "\r${BLUE}経過時間:${NC} %d秒 / %d秒 (残り: %d秒)" $elapsed $duration $remaining
    sleep 1
  done
  
  # プロセスを停止
  for pid in "${pids[@]}"; do
    kill $pid 2>/dev/null
  done
  wait 2>/dev/null
  
  echo ""
  
  # 結果集計
  local success=$(grep -c "SUCCESS" $result_file 2>/dev/null || echo 0)
  local failed=$(grep -c "FAILED" $result_file 2>/dev/null || echo 0)
  local total=$((success + failed))
  local rate=$(echo "scale=2; $total / $duration" | bc)
  
  if [ $success -gt 0 ]; then
    local avg_time=$(grep "SUCCESS" $result_file | awk '{print $2}' | awk '{sum+=$1; count++} END {printf "%.3f", sum/count}')
  else
    local avg_time="N/A"
  fi
  
  echo ""
  echo "結果:"
  echo "  総リクエスト: $total"
  echo -e "  ${GREEN}成功: $success${NC}"
  echo -e "  ${RED}失敗: $failed${NC}"
  echo "  レート: ${rate} req/s"
  echo "  平均応答時間: ${avg_time}秒"
  
  # 失敗率が高い場合は警告
  if [ $total -gt 0 ]; then
    local failure_rate=$(echo "scale=2; $failed * 100 / $total" | bc)
    if (( $(echo "$failure_rate > 10" | bc -l) )); then
      echo -e "  ${RED}⚠ 警告: 失敗率が高い (${failure_rate}%)${NC}"
    fi
  fi
  
  echo ""
  sleep 3
}

# 各段階を実行
run_stage "ウォームアップ" 5 10
run_stage "低負荷" 10 15
run_stage "中負荷" 20 15
run_stage "高負荷" 50 15
run_stage "ストレス" 100 20

echo "================================"
echo "ストレステスト完了"
echo "================================"
echo ""
echo "📊 オブザーバビリティツールで結果を確認:"
echo ""
echo "1. Grafana (http://localhost:3000)"
echo "   - メトリクスダッシュボードで負荷の変化を確認"
echo "   - JVMメモリ使用量の推移"
echo "   - HTTPリクエストレートのスパイク"
echo ""
echo "2. Prometheus (http://localhost:9090)"
echo "   - クエリ例:"
echo "     rate(http_server_requests_seconds_count[1m])"
echo "     jvm_memory_used_bytes"
echo ""
echo "3. Tempoでトレースを確認"
echo "   - Grafana → Explore → Tempo"
echo "   - 処理時間が長いトレースを探す"
echo ""
echo "4. アプリケーションログ"
echo "   - tail -f demo/camel-app/app.log"
echo "   - エラーログやボトルネックを確認"
echo ""




