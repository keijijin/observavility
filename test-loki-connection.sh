#!/bin/bash

# Loki接続テストスクリプト

echo "================================"
echo "Loki 接続テスト"
echo "================================"
echo ""

# Lokiのヘルスチェック
echo "📋 Step 1: Lokiのヘルスチェック"
echo "-------------------------------------------"
LOKI_URL="http://localhost:3100"

if curl -s -f "$LOKI_URL/ready" > /dev/null 2>&1; then
    echo "✅ Loki is ready: $LOKI_URL/ready"
else
    echo "❌ Loki is not ready or not running"
    echo "   Please start Loki with: cd demo && podman-compose up -d loki"
    exit 1
fi
echo ""

# Lokiのバージョン確認
echo "📋 Step 2: Lokiのバージョン確認"
echo "-------------------------------------------"
VERSION=$(curl -s "$LOKI_URL/loki/api/v1/status/buildinfo" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
if [ -n "$VERSION" ]; then
    echo "✅ Loki version: $VERSION"
else
    echo "⚠️  バージョン情報を取得できませんでした"
fi
echo ""

# テストログを送信
echo "📋 Step 3: テストログの送信"
echo "-------------------------------------------"
TIMESTAMP=$(date +%s%N)
TEST_LOG_DATA=$(cat <<EOF
{
  "streams": [
    {
      "stream": {
        "app": "test-app",
        "level": "info",
        "host": "localhost"
      },
      "values": [
        ["$TIMESTAMP", "Test log entry from connection test script"]
      ]
    }
  ]
}
EOF
)

RESPONSE=$(curl -s -X POST "$LOKI_URL/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d "$TEST_LOG_DATA" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" == "204" ]; then
    echo "✅ テストログの送信成功 (HTTP $HTTP_CODE)"
else
    echo "❌ テストログの送信失敗 (HTTP $HTTP_CODE)"
    echo "   Response: $RESPONSE"
    exit 1
fi
echo ""

# ログクエリのテスト
echo "📋 Step 4: ログクエリのテスト"
echo "-------------------------------------------"
# 少し待機
sleep 2

QUERY_START=$(date -u -d '5 minutes ago' +%s%N 2>/dev/null || date -u -v-5M +%s%N 2>/dev/null)
QUERY_END=$(date -u +%s%N)

QUERY_RESPONSE=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
  --data-urlencode 'query={app="test-app"}' \
  --data-urlencode "start=$QUERY_START" \
  --data-urlencode "end=$QUERY_END" \
  --data-urlencode 'limit=10')

if echo "$QUERY_RESPONSE" | grep -q '"status":"success"'; then
    RESULT_COUNT=$(echo "$QUERY_RESPONSE" | grep -o '"values":\[\[' | wc -l)
    echo "✅ ログクエリ成功"
    echo "   検索結果: $RESULT_COUNT 件のログエントリが見つかりました"
else
    echo "⚠️  ログクエリは実行できましたが、結果が見つかりませんでした"
    echo "   これは正常です（ログがまだ送信されていない可能性があります）"
fi
echo ""

# ラベル一覧の取得
echo "📋 Step 5: 利用可能なラベルの確認"
echo "-------------------------------------------"
LABELS=$(curl -s "$LOKI_URL/loki/api/v1/labels" | grep -o '"data":\[[^]]*\]')
if [ -n "$LABELS" ]; then
    echo "✅ 利用可能なラベル:"
    echo "$LABELS" | sed 's/,/\n/g' | sed 's/"data":\[//g' | sed 's/\]//g' | sed 's/"//g' | while read label; do
        if [ -n "$label" ]; then
            echo "   - $label"
        fi
    done
else
    echo "⚠️  ラベルが見つかりませんでした（ログがまだ送信されていない可能性があります）"
fi
echo ""

# Camelアプリケーションのログを確認
echo "📋 Step 6: Camelアプリケーションのログ確認"
echo "-------------------------------------------"
CAMEL_QUERY=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"}' \
  --data-urlencode "start=$QUERY_START" \
  --data-urlencode "end=$QUERY_END" \
  --data-urlencode 'limit=5')

if echo "$CAMEL_QUERY" | grep -q '"status":"success"'; then
    CAMEL_COUNT=$(echo "$CAMEL_QUERY" | grep -o '"values":\[\[' | wc -l)
    if [ "$CAMEL_COUNT" -gt 0 ]; then
        echo "✅ Camelアプリケーションのログが見つかりました: $CAMEL_COUNT 件"
        echo ""
        echo "   最新のログエントリ（最大5件）:"
        echo "$CAMEL_QUERY" | grep -o '"values":\[\[.*\]\]' | sed 's/\]\],\[\[/\n/g' | head -5 | while read entry; do
            LOG_MSG=$(echo "$entry" | grep -o '","[^"]*"' | tail -1 | sed 's/","//g' | sed 's/"//g')
            if [ -n "$LOG_MSG" ]; then
                echo "   • $LOG_MSG"
            fi
        done
    else
        echo "⚠️  Camelアプリケーションのログが見つかりませんでした"
        echo ""
        echo "   考えられる原因："
        echo "   1. Camelアプリケーションがまだ起動していない"
        echo "   2. アプリケーションからLokiへのログ送信に失敗している"
        echo "   3. Lokiの設定に問題がある"
        echo ""
        echo "   確認方法："
        echo "   - Camelアプリケーションのログを確認: tail -f demo/camel-app/logs/application.log"
        echo "   - Loki4jのログを確認: grep 'loki4j' demo/camel-app/logs/application.log"
    fi
else
    echo "❌ クエリの実行に失敗しました"
fi
echo ""

# 結果サマリー
echo "================================"
echo "🎉 接続テスト完了"
echo "================================"
echo ""
echo "📊 Grafanaでログを確認:"
echo "   1. http://localhost:3000 にアクセス"
echo "   2. 左メニューから「Explore」を選択"
echo "   3. データソースで「Loki」を選択"
echo "   4. クエリ例: {app=\"camel-observability-demo\"}"
echo ""
echo "💡 よく使うクエリ:"
echo "   - すべてのログ: {app=\"camel-observability-demo\"}"
echo "   - エラーログのみ: {app=\"camel-observability-demo\"} |= \"ERROR\""
echo "   - 特定のトレースID: {app=\"camel-observability-demo\"} | json | trace_id=\"YOUR_TRACE_ID\""
echo ""

