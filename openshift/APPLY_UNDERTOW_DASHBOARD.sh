#!/bin/bash

# OpenShift Undertow Dashboard適用スクリプト

echo "========================================="
echo "🚀 OpenShift Undertow Dashboard 適用"
echo "========================================="
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# OpenShift接続確認
echo "1️⃣  OpenShift接続確認..."
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ OpenShiftにログインしていません${NC}"
    echo ""
    echo "ログインしてください:"
    echo "  oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>"
    exit 1
fi

CURRENT_USER=$(oc whoami)
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "なし")

echo -e "${GREEN}✓ ログイン済み${NC}"
echo "  ユーザー: $CURRENT_USER"
echo "  プロジェクト: $CURRENT_PROJECT"
echo ""

# プロジェクト確認
if [ "$CURRENT_PROJECT" = "なし" ] || [ "$CURRENT_PROJECT" != "camel-observability-demo" ]; then
    echo -e "${YELLOW}⚠ プロジェクトを camel-observability-demo に切り替えますか？${NC}"
    read -p "続行しますか? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc project camel-observability-demo 2>/dev/null || {
            echo -e "${YELLOW}プロジェクトが存在しません。作成しますか？${NC}"
            read -p "作成しますか? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                oc new-project camel-observability-demo
            else
                echo "キャンセルしました"
                exit 0
            fi
        }
    else
        echo "キャンセルしました"
        exit 0
    fi
fi

echo ""
echo "2️⃣  ConfigMapファイル確認..."
CONFIGMAP_FILE="grafana/grafana-dashboards-configmap.yaml"

if [ ! -f "$CONFIGMAP_FILE" ]; then
    echo -e "${RED}✗ ConfigMapファイルが見つかりません${NC}"
    echo "  パス: $CONFIGMAP_FILE"
    echo ""
    echo "現在のディレクトリ: $(pwd)"
    echo "このスクリプトは openshift/ ディレクトリから実行してください"
    exit 1
fi

echo -e "${GREEN}✓ ConfigMapファイル確認${NC}"
echo "  ファイル: $CONFIGMAP_FILE"
echo "  サイズ: $(ls -lh $CONFIGMAP_FILE | awk '{print $5}')"
echo ""

# Undertowダッシュボードの存在確認
UNDERTOW_COUNT=$(grep -c "undertow-monitoring-dashboard.json:" $CONFIGMAP_FILE)
echo "3️⃣  Undertowダッシュボード確認..."
if [ "$UNDERTOW_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ undertow-monitoring-dashboard.json が見つかりません${NC}"
    echo "  ConfigMapにUndertowダッシュボードが含まれていません"
    exit 1
else
    echo -e "${GREEN}✓ Undertowダッシュボード確認${NC}"
    echo "  undertow-monitoring-dashboard.json: 存在"
fi
echo ""

# 既存のConfigMap確認
echo "4️⃣  既存のConfigMap確認..."
if oc get configmap grafana-dashboards &> /dev/null; then
    echo -e "${YELLOW}⚠ 既存のConfigMapが存在します${NC}"
    echo ""
    echo "既存のConfigMapを更新します。"
    read -p "続行しますか? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました"
        exit 0
    fi
    ACTION="更新"
else
    echo -e "${GREEN}✓ 新規作成${NC}"
    ACTION="作成"
fi
echo ""

# ConfigMapを適用
echo "5️⃣  ConfigMapを${ACTION}中..."
if oc apply -f $CONFIGMAP_FILE; then
    echo -e "${GREEN}✓ ConfigMap ${ACTION}成功${NC}"
else
    echo -e "${RED}✗ ConfigMap ${ACTION}失敗${NC}"
    exit 1
fi
echo ""

# Grafana Podの再起動
echo "6️⃣  Grafana Podを再起動..."
echo "  ダッシュボードを再読み込みするためにGrafanaを再起動します"
echo ""

if ! oc get deployment grafana &> /dev/null; then
    echo -e "${YELLOW}⚠ Grafana Deploymentが見つかりません${NC}"
    echo "  Grafanaがデプロイされていない可能性があります"
    echo ""
    echo "Grafanaをデプロイしますか？"
    read -p "デプロイしますか? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "grafana/grafana-deployment.yaml" ]; then
            oc apply -f grafana/
            echo "  Grafanaデプロイメント完了"
        else
            echo -e "${RED}✗ Grafanaデプロイメントファイルが見つかりません${NC}"
            exit 1
        fi
    fi
else
    # Grafana Podを削除（自動的に再作成される）
    GRAFANA_POD=$(oc get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$GRAFANA_POD" ]; then
        echo "  現在のPod: $GRAFANA_POD"
        oc delete pod $GRAFANA_POD
        echo -e "${GREEN}✓ Grafana Pod削除${NC}"
        echo ""
        
        # 新しいPodの起動を待機
        echo "  新しいPodの起動を待機中..."
        oc wait --for=condition=ready pod -l app=grafana --timeout=120s
        
        if [ $? -eq 0 ]; then
            NEW_POD=$(oc get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
            echo -e "${GREEN}✓ 新しいPodが起動しました${NC}"
            echo "  新しいPod: $NEW_POD"
        else
            echo -e "${YELLOW}⚠ タイムアウト: Podの起動に時間がかかっています${NC}"
            echo "  手動で確認してください: oc get pods -l app=grafana"
        fi
    else
        echo -e "${YELLOW}⚠ Grafana Podが見つかりません${NC}"
    fi
fi

echo ""
echo "========================================="
echo "✅ Undertow Dashboard 適用完了"
echo "========================================="
echo ""

# Grafana Routeを取得
GRAFANA_ROUTE=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -n "$GRAFANA_ROUTE" ]; then
    echo "🎉 Grafanaにアクセスしてダッシュボードを確認してください"
    echo ""
    echo "Grafana URL:"
    echo "  https://$GRAFANA_ROUTE"
    echo ""
    echo "ログイン情報:"
    echo "  ユーザー名: admin"
    echo "  パスワード: admin123"
    echo ""
    echo "ダッシュボード:"
    echo "  左メニュー → Dashboards"
    echo "  → 'Undertow Monitoring Dashboard' を選択"
    echo ""
    echo "または、直接アクセス:"
    echo "  https://$GRAFANA_ROUTE/d/undertow-monitoring/"
else
    echo -e "${YELLOW}⚠ Grafana Routeが見つかりません${NC}"
    echo ""
    echo "Routeを作成してください:"
    echo "  oc expose svc/grafana"
    echo ""
    echo "または、Port Forwardingを使用:"
    echo "  oc port-forward svc/grafana 3000:3000"
    echo "  → http://localhost:3000"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 ダッシュボード確認方法:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Grafanaにログイン"
echo "2. 左メニュー → Dashboards"
echo "3. 以下のダッシュボードが表示されるはずです:"
echo "   - 🚨 アラート監視ダッシュボード"
echo "   - Camel Observability Dashboard"
echo "   - 47a6270d-3b6c-5c9b-afdb-5b8d09dd1b84"
echo "   - Undertow Monitoring Dashboard  ← 新規追加！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ConfigMap確認コマンドを表示
echo "📝 確認コマンド:"
echo ""
echo "  # ConfigMapの内容確認"
echo "  oc get configmap grafana-dashboards -o yaml | grep undertow"
echo ""
echo "  # Grafana Podのログ確認"
echo "  oc logs -l app=grafana | grep undertow"
echo ""
echo "  # Grafana Podの状態確認"
echo "  oc get pods -l app=grafana"
echo ""



