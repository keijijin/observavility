#!/bin/bash

# Camel Observability Demo - 停止スクリプト
echo "================================"
echo "Camel Observability Demo - 停止"
echo "================================"
echo ""

# Compose コマンドの検出
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif podman compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="podman compose"
else
    echo "❌ podman-compose または podman compose が見つかりません"
    exit 1
fi

echo "📋 インフラストラクチャを停止しています..."
$COMPOSE_CMD down

if [ $? -eq 0 ]; then
    echo "✅ インフラストラクチャを停止しました"
else
    echo "❌ 停止中にエラーが発生しました"
    exit 1
fi

echo ""
echo "💡 データも含めてすべて削除する場合は、以下を実行してください："
echo "   $COMPOSE_CMD down -v"
echo ""

