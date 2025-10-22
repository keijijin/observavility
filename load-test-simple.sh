#!/bin/bash

# シンプルな負荷テストスクリプト
# Camel Observability Demo用

echo "================================"
echo "シンプル負荷テスト"
echo "================================"
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# デフォルト設定
ENDPOINT="http://localhost:8080/camel/api/orders"
COUNT=10
INTERVAL=1

# 引数の処理
while getopts "c:i:h" opt; do
  case $opt in
    c) COUNT=$OPTARG ;;
    i) INTERVAL=$OPTARG ;;
    h)
      echo "使用方法: $0 [-c COUNT] [-i INTERVAL]"
      echo ""
      echo "オプション:"
      echo "  -c COUNT     リクエスト数（デフォルト: 10）"
      echo "  -i INTERVAL  リクエスト間隔（秒、デフォルト: 1）"
      echo "  -h           このヘルプを表示"
      echo ""
      echo "例:"
      echo "  $0 -c 50 -i 0.5    # 50リクエストを0.5秒間隔で送信"
      echo "  $0 -c 100 -i 0.1   # 100リクエストを0.1秒間隔で送信"
      exit 0
      ;;
    \?) echo "無効なオプション: -$OPTARG" >&2; exit 1 ;;
  esac
done

echo "設定:"
echo "  エンドポイント: $ENDPOINT"
echo "  リクエスト数: $COUNT"
echo "  間隔: ${INTERVAL}秒"
echo ""
echo "テスト開始..."
echo ""

SUCCESS=0
FAILED=0
START_TIME=$(date +%s)

for i in $(seq 1 $COUNT); do
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $ENDPOINT 2>&1)
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓${NC} リクエスト $i/$COUNT - ステータス: $HTTP_CODE"
    SUCCESS=$((SUCCESS + 1))
  else
    echo -e "${RED}✗${NC} リクエスト $i/$COUNT - ステータス: $HTTP_CODE"
    FAILED=$((FAILED + 1))
  fi
  
  if [ $i -lt $COUNT ]; then
    sleep $INTERVAL
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "================================"
echo "テスト結果"
echo "================================"
echo "総リクエスト数: $COUNT"
echo -e "${GREEN}成功: $SUCCESS${NC}"
echo -e "${RED}失敗: $FAILED${NC}"
echo "所要時間: ${DURATION}秒"
echo "平均レート: $(echo "scale=2; $COUNT / $DURATION" | bc) req/s"
echo ""
echo "💡 次のステップ:"
echo "  1. Grafana (http://localhost:3000) でメトリクスを確認"
echo "  2. Prometheus (http://localhost:9090) でクエリを実行"
echo "  3. Camelアプリのログを確認: tail -f camel-app/app.log"
echo ""



