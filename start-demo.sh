#!/bin/bash

# Camel Observability Demo - 起動スクリプト
echo "================================"
echo "Camel Observability Demo"
echo "================================"
echo ""

# 1. Podman環境のチェック
echo "📋 Step 1: Podman環境をチェックしています..."
if ! command -v podman &> /dev/null; then
    echo "❌ Podmanがインストールされていません。"
    echo "   Podmanをインストールしてください: https://podman.io/getting-started/installation"
    exit 1
fi

if ! podman info &> /dev/null; then
    echo "❌ Podmanが正しく動作していません。"
    echo "   Podman Machineを起動してください（Mac/Windows）: podman machine start"
    exit 1
fi

if ! command -v podman-compose &> /dev/null; then
    echo "⚠️  podman-composeが見つかりません。"
    echo "   インストールしてください: pip3 install podman-compose"
    echo "   または podman compose プラグインを使用します。"
    # podman compose (プラグイン) があるかチェック
    if ! podman compose version &> /dev/null; then
        echo "❌ podman-compose または podman compose が必要です。"
        exit 1
    fi
    COMPOSE_CMD="podman compose"
else
    COMPOSE_CMD="podman-compose"
fi

echo "✅ Podman環境: OK"
echo ""

# 2. インフラストラクチャの起動
echo "📋 Step 2: インフラストラクチャを起動しています..."
echo "   (Kafka, Prometheus, Grafana, Tempo, Loki)"
$COMPOSE_CMD up -d

if [ $? -ne 0 ]; then
    echo "❌ Podman Composeの起動に失敗しました。"
    exit 1
fi

echo "✅ インフラストラクチャ起動: OK"
echo ""

# 3. サービスの起動待機
echo "📋 Step 3: サービスの起動を待機しています..."
echo "   これには30秒ほどかかる場合があります..."
sleep 30

echo "✅ 待機完了"
echo ""

# 4. サービスの状態確認
echo "📋 Step 4: サービスの状態を確認しています..."
$COMPOSE_CMD ps
echo ""

# 5. アプリケーションの起動確認
echo "📋 Step 5: Camelアプリケーションを起動してください"
echo ""
echo "別のターミナルで以下のコマンドを実行してください："
echo "-------------------------------------------"
echo "cd camel-app"
echo "mvn clean install"
echo "mvn spring-boot:run"
echo "-------------------------------------------"
echo ""

# 6. アクセス情報の表示
echo "================================"
echo "🎉 デモ環境の準備が整いました！"
echo "================================"
echo ""
echo "📊 アクセス情報："
echo "-------------------------------------------"
echo "Grafana:     http://localhost:3000"
echo "  ユーザー名: admin"
echo "  パスワード: admin"
echo ""
echo "Prometheus:  http://localhost:9090"
echo "Tempo:       http://localhost:3200 (Grafana経由)"
echo "Loki:        http://localhost:3100 (Grafana経由)"
echo "-------------------------------------------"
echo ""
echo "Camelアプリケーション起動後："
echo "  ヘルスチェック: http://localhost:8080/api/health"
echo "  メトリクス:     http://localhost:8080/actuator/prometheus"
echo "  オーダー作成:   curl -X POST http://localhost:8080/api/orders"
echo ""
echo "📖 詳細な手順は README.md をご覧ください"
echo ""

