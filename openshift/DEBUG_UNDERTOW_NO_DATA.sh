#!/bin/bash

# OpenShift版 Undertow Dashboard "No Data" 問題のデバッグスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔍 Undertow Dashboard No Data デバッグ"
echo "========================================="
echo ""

# 1. OpenShift接続確認
echo -n "1. OpenShift接続確認... "
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ ログインしていません${NC}"
    echo "エラー: OpenShiftにログインしてください"
    exit 1
fi
echo -e "${GREEN}✓ 接続OK${NC}"
echo ""

# 2. camel-app Pod確認
echo "2. camel-app Pod状態確認:"
if ! oc get pod -l app=camel-app -o wide; then
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    exit 1
fi
echo ""

# 3. camel-appからundertowメトリクス取得
echo "3. camel-appからundertowメトリクス取得:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
if [ -z "$CAMEL_POD" ]; then
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    exit 1
fi

echo "Pod名: $CAMEL_POD"
echo ""
echo "Undertowメトリクス:"
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_" || echo -e "${RED}✗ undertowメトリクスが見つかりません${NC}"
echo ""

# 4. Prometheus Serviceの確認
echo "4. Prometheus Service確認:"
if ! oc get svc prometheus; then
    echo -e "${RED}✗ Prometheus Serviceが見つかりません${NC}"
    exit 1
fi
echo ""

# 5. Prometheusでundertowメトリクスを確認
echo "5. Prometheusでundertowメトリクスを確認:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PROMETHEUS_POD=$(oc get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
if [ -z "$PROMETHEUS_POD" ]; then
    echo -e "${RED}✗ Prometheus Podが見つかりません${NC}"
    exit 1
fi

echo "Prometheus Pod: $PROMETHEUS_POD"
echo ""
echo "Prometheusに保存されているundertowメトリクス:"
oc exec "$PROMETHEUS_POD" -- wget -qO- "http://localhost:9090/api/v1/label/__name__/values" 2>/dev/null | grep undertow || echo -e "${YELLOW}⚠ undertowメトリクスがPrometheusに保存されていません${NC}"
echo ""

# 6. Prometheusでクエリを直接実行
echo "6. Prometheusでクエリを直接実行:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "クエリ: undertow_request_queue_size"
oc exec "$PROMETHEUS_POD" -- wget -qO- "http://localhost:9090/api/v1/query?query=undertow_request_queue_size" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo -e "${YELLOW}⚠ クエリ結果の取得に失敗${NC}"
echo ""

# 7. Grafana datasource設定確認
echo "7. Grafana datasource設定確認:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
GRAFANA_POD=$(oc get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
if [ -z "$GRAFANA_POD" ]; then
    echo -e "${RED}✗ Grafana Podが見つかりません${NC}"
    exit 1
fi

echo "Grafana Pod: $GRAFANA_POD"
echo ""
echo "Datasource設定ファイル:"
oc exec "$GRAFANA_POD" -- cat /etc/grafana/provisioning/datasources/datasources.yml 2>/dev/null || echo -e "${YELLOW}⚠ datasources.ymlが見つかりません${NC}"
echo ""

# 8. Grafana API経由でdatasource確認
echo "8. Grafana API経由でdatasource確認:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Grafana認証情報をシークレットから取得
GRAFANA_USER=$(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
GRAFANA_PASS=$(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || echo "admin")

if [ -z "$GRAFANA_USER" ] || [ -z "$GRAFANA_PASS" ]; then
    echo -e "${YELLOW}⚠ Grafana認証情報がシークレットから取得できません。デフォルト値を使用します。${NC}"
    GRAFANA_USER="admin"
    GRAFANA_PASS="admin"
fi

GRAFANA_AUTH=$(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)
oc exec "$GRAFANA_POD" -- wget -qO- --header="Authorization: Basic $GRAFANA_AUTH" "http://localhost:3000/api/datasources" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo -e "${YELLOW}⚠ API呼び出しに失敗${NC}"
echo ""

# 9. ConfigMap内のdashboard設定確認
echo "9. ConfigMap内のundertow dashboard設定確認:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ConfigMap内のdatasource設定（最初の3つ）:"
oc get configmap grafana-dashboards -o yaml | grep -o '"datasource":"[^"]*"' | head -3 || echo -e "${YELLOW}⚠ datasource設定が見つかりません${NC}"
echo ""

# 10. 診断まとめ
echo "========================================="
echo "📋 診断完了"
echo "========================================="
echo ""
echo "次のステップ:"
echo ""
echo "【確認事項】"
echo "  1. camel-appからundertowメトリクスが取得できているか？"
echo "     → 上記「3. camel-appからundertowメトリクス取得」を確認"
echo ""
echo "  2. Prometheusがundertowメトリクスをスクレイプしているか？"
echo "     → 上記「5. Prometheusでundertowメトリクスを確認」を確認"
echo ""
echo "  3. Grafanaのdatasource名は「Prometheus」か？"
echo "     → 上記「8. Grafana API経由でdatasource確認」のnameフィールドを確認"
echo ""
echo "【よくある原因と解決策】"
echo ""
echo "❌ 原因A: camel-appがundertowメトリクスを出力していない"
echo "   解決策: application.ymlにmanagement.metrics.enable.undertow: trueが設定されているか確認"
echo ""
echo "❌ 原因B: Prometheusがcamel-appをスクレイプしていない"
echo "   解決策: prometheus.ymlのscrape_configsにcamel-appが含まれているか確認"
echo ""
echo "❌ 原因C: Grafanaのdatasource名が「Prometheus」ではない"
echo "   解決策: datasources.ymlのnameフィールドを確認し、dashboard JSONを修正"
echo ""
echo "❌ 原因D: メトリクスのラベルが異なる"
echo "   解決策: 実際のメトリクスのラベルを確認し、dashboard JSONのPromQLクエリを修正"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "このスクリプトの出力結果を共有してください！"
echo ""


