#!/bin/bash

# Camel アプリケーション ローカル実行スクリプト

echo "================================"
echo "Camel アプリケーション起動"
echo "================================"
echo ""

# カレントディレクトリの確認
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📂 作業ディレクトリ: $(pwd)"
echo ""

# ログディレクトリの作成
LOG_DIR="$SCRIPT_DIR/logs"
if [ ! -d "$LOG_DIR" ]; then
    echo "📁 ログディレクトリを作成しています: $LOG_DIR"
    mkdir -p "$LOG_DIR"
fi

echo "✅ ログディレクトリ: $LOG_DIR"
echo ""

# 環境変数の設定
export LOG_PATH="$LOG_DIR"
export LOKI_URL="http://localhost:3100/loki/api/v1/push"

echo "🔧 環境変数:"
echo "   LOG_PATH=$LOG_PATH"
echo "   LOKI_URL=$LOKI_URL"
echo ""

# ビルドとアプリケーション起動
echo "📋 アプリケーションをビルドして起動しています..."
echo ""

# Maven実行
mvn clean spring-boot:run

echo ""
echo "================================"
echo "アプリケーションが停止しました"
echo "================================"
echo ""
echo "📊 ログファイルの確認:"
echo "   テキスト形式: $LOG_DIR/application.log"
echo "   JSON形式:     $LOG_DIR/application.json"
echo ""


