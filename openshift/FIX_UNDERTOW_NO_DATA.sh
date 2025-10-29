#!/bin/bash

# OpenShift版 Undertow Dashboard "No Data" 自動修正スクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 Undertow Dashboard No Data 自動修正"
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

# 1. Grafana Datasource名を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: Grafana Datasource名を確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GRAFANA_POD=$(oc get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$GRAFANA_POD" ]; then
    echo -e "${RED}✗ Grafana Podが見つかりません${NC}"
    exit 1
fi

echo "Grafana Pod: $GRAFANA_POD"
echo ""

# Grafana API経由でdatasource名を取得（Base64エンコードされたadmin:admin123）
DATASOURCE_INFO=$(oc exec "$GRAFANA_POD" -- wget -qO- --header="Authorization: Basic YWRtaW46YWRtaW4xMjM=" "http://localhost:3000/api/datasources" 2>/dev/null)

if [ -z "$DATASOURCE_INFO" ]; then
    echo -e "${RED}✗ Datasource情報の取得に失敗しました${NC}"
    echo ""
    echo "手動で確認してください:"
    echo "  oc exec $GRAFANA_POD -- cat /etc/grafana/provisioning/datasources/datasources.yml"
    exit 1
fi

echo "Grafanaに登録されているDatasource:"
echo "$DATASOURCE_INFO" | python3 -c "import sys, json; [print(f\"  - {ds['name']} (type: {ds['type']}, uid: {ds.get('uid', 'N/A')})\") for ds in json.load(sys.stdin)]" 2>/dev/null || echo "$DATASOURCE_INFO"
echo ""

# Prometheus datasourceの名前を抽出
PROMETHEUS_DATASOURCE_NAME=$(echo "$DATASOURCE_INFO" | python3 -c "import sys, json; ds = [d for d in json.load(sys.stdin) if d['type'] == 'prometheus']; print(ds[0]['name'] if ds else '')" 2>/dev/null)

if [ -z "$PROMETHEUS_DATASOURCE_NAME" ]; then
    echo -e "${RED}✗ Prometheus Datasourceが見つかりません${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prometheus Datasource名: ${BLUE}$PROMETHEUS_DATASOURCE_NAME${NC}"
echo ""

# 2. ダッシュボードのdatasource設定確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: ダッシュボードのdatasource設定確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DASHBOARD_DATASOURCE=$(oc get configmap grafana-dashboards -o yaml 2>/dev/null | grep -o '"datasource":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DASHBOARD_DATASOURCE" ]; then
    echo -e "${RED}✗ ダッシュボードのdatasource設定が見つかりません${NC}"
    exit 1
fi

echo "ダッシュボードが参照しているDatasource名: $DASHBOARD_DATASOURCE"
echo ""

# 3. 名前が一致するか確認
if [ "$PROMETHEUS_DATASOURCE_NAME" == "$DASHBOARD_DATASOURCE" ]; then
    echo -e "${GREEN}✓ Datasource名は一致しています！${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "別の原因を調査します..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # メトリクス確認
    echo "ステップ3: camel-appのメトリクス確認"
    CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$CAMEL_POD" ]; then
        echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
        exit 1
    fi
    
    echo "camel-app Pod: $CAMEL_POD"
    echo ""
    echo "Undertowメトリクスの確認:"
    UNDERTOW_METRICS=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")
    
    if [ -z "$UNDERTOW_METRICS" ]; then
        echo -e "${RED}✗ undertowメトリクスが見つかりません！${NC}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ 原因: camel-appがundertowメトリクスを出力していません"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "解決策:"
        echo "  1. camel-app Deploymentのapplication.ymlを確認"
        echo "     oc get deployment camel-app -o yaml | grep -A 5 'application.yml'"
        echo ""
        echo "  2. 以下の設定が含まれているか確認:"
        echo "     management.metrics.enable.undertow: true"
        echo ""
        echo "  3. 設定がない場合、ConfigMapを更新してcamel-appを再起動"
        echo "     oc edit configmap camel-app-config"
        echo "     oc rollout restart deployment/camel-app"
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ undertowメトリクスが出力されています${NC}"
        echo ""
        echo "メトリクスのサンプル:"
        echo "$UNDERTOW_METRICS" | head -5
        echo ""
        
        # メトリクスのラベルを確認
        echo "メトリクスのラベル確認:"
        METRIC_LABELS=$(echo "$UNDERTOW_METRICS" | grep "undertow_request_queue_size" | grep -o '{[^}]*}' | head -1)
        echo "実際のラベル: $METRIC_LABELS"
        echo "期待されるラベル: {application=\"camel-observability-demo\"}"
        echo ""
        
        if [[ "$METRIC_LABELS" != *"application=\"camel-observability-demo\""* ]]; then
            echo -e "${YELLOW}⚠ ラベルが一致しません！${NC}"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "❌ 原因: メトリクスのラベルが異なります"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "解決策:"
            echo "  ダッシュボードのPromQLクエリを実際のラベルに合わせて修正する必要があります。"
            echo ""
            echo "  現在のクエリ:"
            echo "    undertow_request_queue_size{application=\"camel-observability-demo\"}"
            echo ""
            echo "  修正後のクエリ（ラベルなし）:"
            echo "    undertow_request_queue_size"
            echo ""
            echo "  または、実際のラベルに合わせる:"
            echo "    undertow_request_queue_size$METRIC_LABELS"
            echo ""
            echo "  詳細なデバッグには以下を実行:"
            echo "    ./DEBUG_UNDERTOW_NO_DATA.sh"
            echo ""
        else
            echo -e "${GREEN}✓ ラベルも一致しています${NC}"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Prometheusのターゲット確認を推奨"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Prometheusがcamel-appをスクレイプしているか確認してください:"
            echo ""
            echo "  1. Port Forwardを実行:"
            echo "     oc port-forward svc/prometheus 9090:9090 &"
            echo ""
            echo "  2. ブラウザで以下にアクセス:"
            echo "     http://localhost:9090/targets"
            echo ""
            echo "  3. camel-appのターゲットが「UP」であることを確認"
            echo ""
            echo "  4. Prometheusでクエリを直接実行:"
            echo "     http://localhost:9090/graph"
            echo "     クエリ: undertow_request_queue_size"
            echo ""
        fi
    fi
    
else
    echo -e "${YELLOW}⚠ Datasource名が一致しません！${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 原因: Datasource名の不一致"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Grafanaのdatasource名: $PROMETHEUS_DATASOURCE_NAME"
    echo "  ダッシュボードの設定名: $DASHBOARD_DATASOURCE"
    echo ""
    
    read -p "ダッシュボードを自動修正しますか？ (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "修正をキャンセルしました"
        exit 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ステップ3: ConfigMapを修正"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # ConfigMapをバックアップ
    echo "ConfigMapをバックアップ中..."
    oc get configmap grafana-dashboards -o yaml > /tmp/grafana-dashboards-backup.yaml
    echo -e "${GREEN}✓ バックアップ作成: /tmp/grafana-dashboards-backup.yaml${NC}"
    echo ""
    
    # ConfigMapを修正（\"datasource\":\"現在の名前\" を \"datasource\":\"Grafana上の名前\" に置換）
    echo "ConfigMapを修正中..."
    oc get configmap grafana-dashboards -o yaml | \
        sed "s/\"datasource\":\"$DASHBOARD_DATASOURCE\"/\"datasource\":\"$PROMETHEUS_DATASOURCE_NAME\"/g" | \
        oc replace -f -
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ConfigMapを修正しました${NC}"
    else
        echo -e "${RED}✗ ConfigMapの修正に失敗しました${NC}"
        exit 1
    fi
    echo ""
    
    # Grafana Podを再起動
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ステップ4: Grafana Podを再起動"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    oc delete pod -l app=grafana
    echo "Grafana Podの起動を待機中..."
    oc wait --for=condition=ready pod -l app=grafana --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Grafana Podが起動しました${NC}"
    else
        echo -e "${RED}✗ Grafana Podの起動に失敗しました${NC}"
        exit 1
    fi
    echo ""
    
    echo "========================================="
    echo "✅ 修正完了！"
    echo "========================================="
    echo ""
    GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)
    echo "Grafanaにアクセスしてダッシュボードを確認してください:"
    echo ""
    echo "  Grafana URL: https://$GRAFANA_URL"
    echo "  Undertow Dashboard: https://$GRAFANA_URL/d/undertow-monitoring/"
    echo ""
    echo "  ユーザー名: admin"
    echo "  パスワード: admin123"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""



