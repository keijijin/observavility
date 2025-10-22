#!/bin/bash

# PodがConfigMapの最新内容を使用しているか確認するスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔍 ConfigMap適用状況の確認"
echo "========================================="
echo ""

# 1. ConfigMapの更新日時を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. ConfigMapの更新日時"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CONFIGMAP_VERSION=$(oc get configmap camel-app-config -o jsonpath='{.metadata.resourceVersion}')
CONFIGMAP_TIMESTAMP=$(oc get configmap camel-app-config -o jsonpath='{.metadata.creationTimestamp}')
echo "ConfigMap resourceVersion: $CONFIGMAP_VERSION"
echo "ConfigMap作成日時: $CONFIGMAP_TIMESTAMP"
echo ""

# ConfigMapにUndertow設定が含まれているか確認
echo "ConfigMapのUndertow設定:"
oc get configmap camel-app-config -o yaml | grep -A 8 "server:" | head -9
echo ""

echo "ConfigMapのメトリクス設定:"
oc get configmap camel-app-config -o yaml | grep -A 3 "enable:" | head -4
echo ""

# 2. Podの起動日時を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Podの状態と起動日時"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

POD_COUNT=$(oc get pods -l app=camel-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$POD_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    echo ""
    echo "Podを起動する必要があります:"
    echo "  ./FIX_IMAGE_ISSUE.sh"
    exit 1
fi

CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
POD_STATUS=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].status.phase}')
POD_START_TIME=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].status.startTime}')

echo "Pod名: $CAMEL_POD"
echo "Pod状態: $POD_STATUS"
echo "Pod起動日時: $POD_START_TIME"
echo ""

if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${RED}✗ Podが Running 状態ではありません${NC}"
    echo ""
    echo "Pod詳細:"
    oc describe pod "$CAMEL_POD" | tail -20
    echo ""
    echo "Podを修正する必要があります:"
    echo "  ./FIX_IMAGE_ISSUE.sh"
    exit 1
fi

# 3. ConfigMapとPodの時系列を比較
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. ConfigMapとPodの時系列比較"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 注意: ConfigMapのcreationTimestampは最初の作成日時なので、
# resourceVersionで更新を追跡する必要がある
echo "ConfigMapのresourceVersion: $CONFIGMAP_VERSION"
echo ""

# Podが参照しているConfigMapのバージョンを確認
POD_CONFIGMAP_VERSION=$(oc get pod "$CAMEL_POD" -o jsonpath='{.spec.volumes[?(@.name=="camel-app-config")].configMap.name}')
echo "PodがマウントしているConfigMap: $POD_CONFIGMAP_VERSION"
echo ""

if [ "$POD_CONFIGMAP_VERSION" != "camel-app-config" ]; then
    echo -e "${RED}✗ Podが正しいConfigMapをマウントしていません${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Podは正しいConfigMapをマウントしています${NC}"
fi
echo ""

# 4. Pod内のConfigMap内容を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Pod内のapplication.yml確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Pod内のUndertow設定:"
oc exec "$CAMEL_POD" -- cat /config/application.yml 2>/dev/null | grep -A 8 "server:" | head -9
echo ""

echo "Pod内のメトリクス設定:"
oc exec "$CAMEL_POD" -- cat /config/application.yml 2>/dev/null | grep -A 3 "enable:" | head -4
echo ""

# Undertow設定が含まれているか確認
HAS_UNDERTOW=$(oc exec "$CAMEL_POD" -- cat /config/application.yml 2>/dev/null | grep -c "undertow:")

if [ "$HAS_UNDERTOW" -eq 0 ]; then
    echo -e "${RED}✗ Pod内のConfigMapにUndertow設定が含まれていません${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠ 問題: Podが古いConfigMapを使用しています"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "ConfigMapは更新されていますが、Podがまだ古い内容を使用しています。"
    echo ""
    echo "解決策: Podを再起動して新しいConfigMapを読み込む"
    echo ""
    echo "  oc delete pod -l app=camel-app"
    echo "  oc wait --for=condition=ready pod -l app=camel-app --timeout=180s"
    echo ""
else
    echo -e "${GREEN}✓ Pod内のConfigMapにUndertow設定が含まれています${NC}"
fi
echo ""

# 5. Undertowメトリクスの出力確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Undertowメトリクスの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "アプリケーションの応答を確認中..."
HEALTH_CHECK=$(oc exec "$CAMEL_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null)

if [ "$HEALTH_CHECK" != "200" ]; then
    echo -e "${YELLOW}⚠ アプリケーションがまだ起動中の可能性があります（HTTP $HEALTH_CHECK）${NC}"
    echo "30秒待機してから再試行します..."
    sleep 30
fi

echo ""
echo "Undertowメトリクスを取得中..."
UNDERTOW_METRICS=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")

if [ -z "$UNDERTOW_METRICS" ]; then
    echo -e "${RED}✗ Undertowメトリクスが出力されていません${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠ 問題: Undertowメトリクスが有効化されていません"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "考えられる原因:"
    echo "  1. アプリケーションがまだ起動中"
    echo "  2. ConfigMapの設定が反映されていない"
    echo "  3. Podが古いイメージを使用している"
    echo ""
    echo "解決策:"
    echo ""
    echo "  1. もう少し待ってから再確認:"
    echo "     sleep 60"
    echo "     oc exec $CAMEL_POD -- curl -s http://localhost:8080/actuator/prometheus | grep undertow"
    echo ""
    echo "  2. Podを再起動:"
    echo "     oc delete pod -l app=camel-app"
    echo ""
    echo "  3. イメージを再ビルド（最終手段）:"
    echo "     oc start-build camel-app --follow"
    echo ""
else
    echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
    echo ""
    echo "メトリクス:"
    echo "$UNDERTOW_METRICS"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ すべて正常です！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Prometheusがメトリクスをスクレイプするまで待機（30-60秒）してから、"
    echo "Grafana Dashboardを確認してください。"
    echo ""
    
    GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$GRAFANA_URL" ]; then
        echo "Grafana URL: https://$GRAFANA_URL/d/undertow-monitoring/"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


