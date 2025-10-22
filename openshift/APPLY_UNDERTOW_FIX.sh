#!/bin/bash

# OpenShift版 Undertow Dashboard "No Data" 修正適用スクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 Undertow Dashboard No Data 修正適用"
echo "========================================="
echo ""

# 前提条件確認
echo -n "OpenShift接続確認... "
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ 失敗${NC}"
    echo "エラー: OpenShiftにログインしてください"
    exit 1
fi
echo -e "${GREEN}✓ OK${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 問題の原因"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "OpenShift版のcamel-app ConfigMapに以下の設定が欠けていました:"
echo ""
echo "  1. server.undertow.threads 設定"
echo "  2. management.metrics.enable.undertow: true"
echo ""
echo "Spring Boot 3.xではUndertowメトリクスがデフォルトで無効なため、"
echo "明示的に有効化する必要があります。"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 修正内容"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "以下の設定を camel-app-config ConfigMap に追加しました:"
echo ""
echo -e "${BLUE}1. Undertow サーバー設定:${NC}"
echo "   server:"
echo "     undertow:"
echo "       threads:"
echo "         io: 4"
echo "         worker: 200"
echo "       buffer-size: 1024"
echo "       direct-buffers: true"
echo ""
echo -e "${BLUE}2. Undertow メトリクス有効化:${NC}"
echo "   management:"
echo "     metrics:"
echo "       enable:"
echo "         undertow: true"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "修正を適用しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "適用をキャンセルしました"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: ConfigMapをバックアップ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

oc get configmap camel-app-config -o yaml > /tmp/camel-app-config-backup-$(date +%Y%m%d%H%M%S).yaml
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ バックアップ作成成功: /tmp/camel-app-config-backup-*.yaml${NC}"
else
    echo -e "${YELLOW}⚠ バックアップの作成に失敗しましたが、続行します${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: 修正済みConfigMapを適用"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/camel-app/camel-app-deployment.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ ConfigMapファイルが見つかりません: $CONFIG_FILE${NC}"
    exit 1
fi

echo "ConfigMapファイル: $CONFIG_FILE"
echo ""

# ConfigMapのみを抽出して適用
# YAMLファイルから最初のリソース（ConfigMap）だけを取得
echo "ConfigMapを抽出中..."
awk 'BEGIN {found=0} /^apiVersion:/ {if (found==1) exit; found=1} found==1' "$CONFIG_FILE" > /tmp/camel-app-configmap-only.yaml

# 抽出したConfigMapを確認
if [ ! -s /tmp/camel-app-configmap-only.yaml ]; then
    echo -e "${RED}✗ ConfigMapの抽出に失敗しました${NC}"
    exit 1
fi

echo "抽出したConfigMapのサイズ: $(wc -c < /tmp/camel-app-configmap-only.yaml) bytes"
echo ""

# ConfigMapを適用
oc apply -f /tmp/camel-app-configmap-only.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ConfigMap適用成功${NC}"
else
    echo -e "${RED}✗ ConfigMap適用失敗${NC}"
    echo ""
    echo "デバッグ情報:"
    echo "  抽出したConfigMap: /tmp/camel-app-configmap-only.yaml"
    echo "  確認: cat /tmp/camel-app-configmap-only.yaml | head -20"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: camel-app Podを再起動"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CAMEL_POD" ]; then
    echo "現在のcamel-app Pod: $CAMEL_POD"
    echo "Podを削除して再起動します..."
    oc delete pod -l app=camel-app
else
    echo -e "${YELLOW}⚠ 実行中のcamel-app Podが見つかりませんでした${NC}"
    echo "Deploymentをロールアウトします..."
    oc rollout restart deployment/camel-app
fi
echo ""

echo "新しいPodの起動を待機中（最大180秒）..."
if oc wait --for=condition=ready pod -l app=camel-app --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}✓ camel-app Podが起動しました${NC}"
else
    echo -e "${YELLOW}⚠ タイムアウトしました。Podの状態を確認してください${NC}"
    echo ""
    echo "Pod状態:"
    oc get pods -l app=camel-app
    echo ""
    echo "詳細を確認:"
    echo "  oc describe pod -l app=camel-app"
    echo "  oc logs -l app=camel-app --tail=50"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: Undertowメトリクスの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "camel-appの起動を待機中（30秒）..."
sleep 30

NEW_CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$NEW_CAMEL_POD" ]; then
    echo "新しいcamel-app Pod: $NEW_CAMEL_POD"
    echo ""
    echo "Undertowメトリクスを確認中..."
    UNDERTOW_METRICS=$(oc exec "$NEW_CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")
    
    if [ -n "$UNDERTOW_METRICS" ]; then
        echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
        echo ""
        echo "メトリクスのサンプル:"
        echo "$UNDERTOW_METRICS" | head -5
        echo ""
    else
        echo -e "${RED}✗ Undertowメトリクスが見つかりません${NC}"
        echo ""
        echo "トラブルシューティング:"
        echo "  1. Podのログを確認:"
        echo "     oc logs $NEW_CAMEL_POD --tail=100"
        echo ""
        echo "  2. ConfigMapが正しく反映されているか確認:"
        echo "     oc get configmap camel-app-config -o yaml | grep -A 5 'undertow'"
        echo ""
        echo "  3. Podを再度再起動:"
        echo "     oc delete pod -l app=camel-app"
        echo ""
        exit 1
    fi
else
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: Grafana確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Prometheusがメトリクスをスクレイプするまで少し待機します（30秒）..."
sleep 30

GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$GRAFANA_URL" ]; then
    echo "========================================="
    echo "✅ 修正完了！"
    echo "========================================="
    echo ""
    echo "Grafanaにアクセスしてダッシュボードを確認してください:"
    echo ""
    echo -e "  ${BLUE}Grafana URL:${NC} https://$GRAFANA_URL"
    echo -e "  ${BLUE}Undertow Dashboard:${NC} https://$GRAFANA_URL/d/undertow-monitoring/"
    echo ""
    echo "  ユーザー名: admin"
    echo "  パスワー: admin123"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 期待される結果:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✅ Undertow Queue Size: 0（緑色）"
    echo "  ✅ Undertow Active Requests: グラフが表示される"
    echo "  ✅ Undertow Worker Usage: 数値が表示される"
    echo "  ✅ Undertow Thread Configuration: Workers: 200"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "もし「No Data」が続く場合:"
    echo "  1. ブラウザのキャッシュをクリア"
    echo "  2. Grafana Dashboardの時間範囲を「Last 5 minutes」に変更"
    echo "  3. Prometheusでクエリを直接実行:"
    echo "     oc port-forward svc/prometheus 9090:9090 &"
    echo "     ブラウザで http://localhost:9090"
    echo "     クエリ: undertow_request_queue_size"
    echo ""
else
    echo -e "${RED}✗ Grafana Routeが見つかりません${NC}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

