#!/bin/bash

# Deployment selector問題を修正するスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 Deployment Selector 修正"
echo "========================================="
echo ""

# 1. 現在の状態確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: 現在の状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Deployment状態:"
oc get deployment camel-app 2>/dev/null || echo -e "${YELLOW}⚠ Deploymentが見つかりません${NC}"
echo ""

echo "Pod状態:"
oc get pods -l app=camel-app 2>/dev/null || echo -e "${YELLOW}⚠ Podが見つかりません${NC}"
echo ""

echo "ReplicaSet状態:"
oc get replicaset -l app=camel-app 2>/dev/null || echo -e "${YELLOW}⚠ ReplicaSetが見つかりません${NC}"
echo ""

# 2. 問題の説明
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 問題の説明"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "既存のDeploymentには以下のselectorが設定されています:"
echo "  matchLabels:"
echo "    app: camel-app"
echo "    deployment: camel-app  ← これが問題"
echo ""
echo "新しいDeployment YAMLには以下のselectorしかありません:"
echo "  matchLabels:"
echo "    app: camel-app"
echo ""
echo "Kubernetesでは、Deploymentのselectorは作成後に変更できません（immutable）。"
echo "そのため、Deploymentを削除して再作成する必要があります。"
echo ""

read -p "Deploymentを削除して再作成しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作をキャンセルしました"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: Deploymentを削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if oc get deployment camel-app &> /dev/null; then
    echo "Deployment camel-app を削除中..."
    oc delete deployment camel-app
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deployment削除成功${NC}"
    else
        echo -e "${RED}✗ Deployment削除失敗${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Deploymentが既に存在しません${NC}"
fi
echo ""

# Podが完全に削除されるのを待つ
echo "Podの削除を待機中（最大30秒）..."
for i in {1..30}; do
    POD_COUNT=$(oc get pods -l app=camel-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$POD_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ すべてのPodが削除されました${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""
echo ""

# 3. 新しいDeploymentを作成
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: 新しいDeploymentを作成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_FILE="$SCRIPT_DIR/camel-app/camel-app-deployment.yaml"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo -e "${RED}✗ Deploymentファイルが見つかりません: $DEPLOYMENT_FILE${NC}"
    exit 1
fi

echo "Deploymentファイル: $DEPLOYMENT_FILE"
echo ""

echo "新しいDeploymentを作成中..."
oc apply -f "$DEPLOYMENT_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment作成成功${NC}"
else
    echo -e "${RED}✗ Deployment作成失敗${NC}"
    exit 1
fi
echo ""

# 4. Podの起動を待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: Podの起動を待機"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Podが作成されるのを待機中（最大180秒）..."
if oc wait --for=condition=ready pod -l app=camel-app --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}✓ Podが正常に起動しました${NC}"
else
    echo -e "${RED}✗ Podの起動に失敗したか、タイムアウトしました${NC}"
    echo ""
    echo "Pod状態:"
    oc get pods -l app=camel-app
    echo ""
    echo "詳細を確認:"
    echo "  oc describe pod -l app=camel-app"
    echo "  oc logs -l app=camel-app --tail=50"
    exit 1
fi
echo ""

# 5. Podの詳細確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$CAMEL_POD" ]; then
    echo -e "${RED}✗ Podが見つかりません${NC}"
    exit 1
fi

echo "新しいPod名: $CAMEL_POD"
echo ""

# 6. Undertowメトリクス確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: Undertowメトリクス確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "アプリケーションの起動を待機中（30秒）..."
sleep 30

echo "Undertowメトリクスを確認中..."
UNDERTOW_METRICS=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")

if [ -n "$UNDERTOW_METRICS" ]; then
    echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
    echo ""
    echo "メトリクスのサンプル:"
    echo "$UNDERTOW_METRICS"
    echo ""
else
    echo -e "${RED}✗ Undertowメトリクスが見つかりません${NC}"
    echo ""
    echo "トラブルシューティング:"
    echo "  1. Podのログを確認:"
    echo "     oc logs $CAMEL_POD --tail=100"
    echo ""
    echo "  2. ConfigMapが正しく反映されているか確認:"
    echo "     oc get configmap camel-app-config -o yaml | grep -A 5 'undertow'"
    echo ""
    echo "  3. Actuatorエンドポイントが応答するか確認:"
    echo "     oc exec $CAMEL_POD -- curl -s http://localhost:8080/actuator/health"
    echo ""
    exit 1
fi

# 7. Grafana確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ6: Grafana確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Prometheusがメトリクスをスクレイプするまで待機中（30秒）..."
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
    echo "  パスワード: admin123"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 期待される結果:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✅ Undertow Queue Size: 0（緑色）"
    echo "  ✅ Undertow Active Requests: グラフが表示される"
    echo "  ✅ Undertow Worker Usage: 数値が表示される"
    echo "  ✅ Undertow Thread Configuration: Workers: 200, I/O: 4"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    echo -e "${RED}✗ Grafana Routeが見つかりません${NC}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


