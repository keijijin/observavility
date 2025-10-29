#!/bin/bash

# Actuatorエンドポイント診断スクリプト
# OpenShift環境でactuator/prometheusが有効かチェック

echo "========================================="
echo "🔍 Actuator診断スクリプト"
echo "========================================="
echo ""

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Podの状態確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Podの状態を確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
POD_NAME=$(oc get pods -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}✗ Camel App Podが見つかりません${NC}"
    echo ""
    echo "Podを確認してください:"
    echo "  oc get pods"
    exit 1
fi

POD_STATUS=$(oc get pod $POD_NAME -o jsonpath='{.status.phase}')
echo -e "Pod名: ${BLUE}$POD_NAME${NC}"
echo -e "状態: ${GREEN}$POD_STATUS${NC}"
echo ""

# 2. ConfigMapの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  ConfigMapの存在確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if oc get configmap camel-app-config &>/dev/null; then
    echo -e "${GREEN}✓ ConfigMap 'camel-app-config' が存在します${NC}"
    
    # application.ymlの内容確認
    echo ""
    echo "application.ymlにactuator設定があるか確認:"
    if oc get configmap camel-app-config -o yaml | grep -q "prometheus"; then
        echo -e "${GREEN}✓ prometheus設定が見つかりました${NC}"
    else
        echo -e "${RED}✗ prometheus設定が見つかりません${NC}"
        echo ""
        echo "ConfigMapを確認してください:"
        echo "  oc get configmap camel-app-config -o yaml | grep -A 20 'management:'"
    fi
else
    echo -e "${RED}✗ ConfigMap 'camel-app-config' が見つかりません${NC}"
    echo ""
    echo "ConfigMapを作成してください:"
    echo "  oc create configmap camel-app-config --from-file=application.yml=./camel-app/src/main/resources/application.yml"
fi
echo ""

# 3. Pod内の設定ファイル確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Pod内の設定ファイルを確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if oc exec $POD_NAME -- test -f /config/application.yml 2>/dev/null; then
    echo -e "${GREEN}✓ /config/application.yml が存在します${NC}"
    
    # management設定の確認
    echo ""
    echo "management設定:"
    oc exec $POD_NAME -- grep -A 15 "^management:" /config/application.yml 2>/dev/null || \
        echo -e "${YELLOW}⚠ management設定が見つかりません${NC}"
else
    echo -e "${RED}✗ /config/application.yml が見つかりません${NC}"
    echo ""
    echo "ConfigMapがマウントされていない可能性があります。"
    echo "確認してください:"
    echo "  oc describe pod $POD_NAME | grep -A 10 'Mounts:'"
fi
echo ""

# 4. 環境変数の確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  環境変数を確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SPRING_CONFIG=$(oc exec $POD_NAME -- env 2>/dev/null | grep SPRING_CONFIG_LOCATION || echo "")
if [ -n "$SPRING_CONFIG" ]; then
    echo -e "${GREEN}✓ $SPRING_CONFIG${NC}"
else
    echo -e "${YELLOW}⚠ SPRING_CONFIG_LOCATION が設定されていません${NC}"
    echo "  デフォルトのapplication.ymlが使用されます"
fi
echo ""

# 5. Actuatorエンドポイントの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Actuatorエンドポイントを確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ヘルスチェック
echo -n "Health endpoint: "
if oc exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN}✓ OK (200)${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Actuatorルートエンドポイント
echo -n "Actuator endpoint: "
if oc exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN}✓ OK (200)${NC}"
    
    # 利用可能なエンドポイント一覧を取得
    echo ""
    echo "利用可能なエンドポイント:"
    ENDPOINTS=$(oc exec $POD_NAME -- curl -s http://localhost:8080/actuator 2>/dev/null | grep -o '"[^"]*":{"href"' | grep -o '"[^"]*"' | head -20)
    echo "$ENDPOINTS"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Prometheusエンドポイント
echo ""
echo -n "Prometheus endpoint: "
HTTP_CODE=$(oc exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/prometheus 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ OK (200)${NC}"
    
    # メトリクス数を確認
    METRICS_COUNT=$(oc exec $POD_NAME -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | wc -l)
    echo "  メトリクス行数: $METRICS_COUNT"
    
    # JVMメトリクスの存在確認
    echo ""
    echo "  JVMメトリクス確認:"
    if oc exec $POD_NAME -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -q "jvm_threads_live_threads"; then
        echo -e "    ${GREEN}✓ jvm_threads_live_threads${NC}"
    else
        echo -e "    ${RED}✗ jvm_threads_live_threads${NC}"
    fi
    
    if oc exec $POD_NAME -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -q "undertow_"; then
        echo -e "    ${GREEN}✓ undertow_*${NC}"
    else
        echo -e "    ${YELLOW}⚠ undertow_* (Undertowメトリクスなし)${NC}"
    fi
else
    echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo -e "${YELLOW}Prometheusエンドポイントが有効になっていません！${NC}"
    echo ""
    echo "修正方法:"
    echo "  1. ConfigMapを再作成:"
    echo "     oc delete configmap camel-app-config"
    echo "     oc create configmap camel-app-config \\"
    echo "       --from-file=application.yml=./camel-app/src/main/resources/application.yml"
    echo ""
    echo "  2. Deploymentを再起動:"
    echo "     oc rollout restart deployment/camel-app"
fi
echo ""

# 6. 外部アクセス確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  外部からのアクセスを確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -z "$CAMEL_URL" ]; then
    echo -e "${RED}✗ Route 'camel-app' が見つかりません${NC}"
    echo ""
    echo "Routeを作成してください:"
    echo "  oc create route edge camel-app --service=camel-app --port=8080-tcp"
else
    echo -e "Route URL: ${BLUE}https://$CAMEL_URL${NC}"
    echo ""
    
    echo -n "外部からのPrometheusエンドポイントアクセス: "
    EXT_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://${CAMEL_URL}/actuator/prometheus" 2>/dev/null)
    if [ "$EXT_HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ OK (200)${NC}"
    else
        echo -e "${RED}✗ Failed (HTTP $EXT_HTTP_CODE)${NC}"
    fi
fi
echo ""

# 7. まとめ
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 診断結果サマリー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Actuator/Prometheusエンドポイントは正常に動作しています${NC}"
    echo ""
    echo "thread_monitor.shを実行できます:"
    echo "  ./thread_monitor.sh 5"
else
    echo -e "${RED}❌ Actuator/Prometheusエンドポイントに問題があります${NC}"
    echo ""
    echo "修正が必要です。上記のエラーメッセージを確認してください。"
fi
echo ""

