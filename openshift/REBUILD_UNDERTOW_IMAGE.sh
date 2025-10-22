#!/bin/bash

# OpenShift用Undertowイメージ再ビルドスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 Undertowイメージ再ビルド"
echo "========================================="
echo ""

# 1. 現在の状況を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: 現在のイメージ確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$CAMEL_POD" ]; then
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    echo ""
    echo "Podを起動してから再実行してください。"
    exit 1
fi

echo "現在のPod: $CAMEL_POD"
echo ""

# Tomcatメトリクスが出力されるか確認
echo "Tomcatメトリクスの確認中..."
TOMCAT_COUNT=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -c "^tomcat")

echo "Tomcatメトリクス数: $TOMCAT_COUNT"
echo ""

if [ "$TOMCAT_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ 現在のイメージはTomcatを使用しています${NC}"
    echo ""
    echo "Tomcatメトリクスの例:"
    oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^tomcat" | head -3
    echo ""
    echo "Undertowイメージへの再ビルドが必要です。"
else
    echo "Undertowメトリクスの確認中..."
    UNDERTOW_COUNT=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -c "^undertow")
    
    if [ "$UNDERTOW_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ 既にUndertowイメージを使用しています！${NC}"
        echo ""
        echo "Undertowメトリクス:"
        oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow"
        echo ""
        echo "再ビルドは不要です。"
        echo ""
        echo "Grafana Dashboardを確認してください:"
        GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)
        echo "  https://$GRAFANA_URL/d/undertow-monitoring/"
        exit 0
    else
        echo -e "${YELLOW}⚠ TomcatもUndertowもメトリクスが見つかりません${NC}"
        echo ""
        echo "アプリケーションがまだ起動中の可能性があります。"
        echo "60秒待ってから再試行します..."
        sleep 60
        
        UNDERTOW_COUNT=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -c "^undertow")
        if [ "$UNDERTOW_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✓ Undertowメトリクスが出力されました！${NC}"
            oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow"
            exit 0
        fi
        
        echo -e "${YELLOW}⚠ まだメトリクスが出力されません。再ビルドを続行します。${NC}"
    fi
fi

echo ""
read -p "イメージを再ビルドしますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "再ビルドをキャンセルしました"
    exit 0
fi

# 2. BuildConfigの確認
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: BuildConfig確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! oc get buildconfig camel-app &> /dev/null; then
    echo -e "${RED}✗ BuildConfig camel-app が見つかりません${NC}"
    echo ""
    echo "BuildConfigを作成してから再実行してください。"
    echo "詳細: OPENSHIFT_DEPLOYMENT_GUIDE.md を参照"
    exit 1
fi

echo "✓ BuildConfig camel-app が存在します"
oc get buildconfig camel-app
echo ""

# 過去のビルド履歴を確認
echo "過去のビルド履歴:"
oc get builds -l app=camel-app --sort-by=.metadata.creationTimestamp | tail -5
echo ""

# 3. 新しいビルドを開始
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: 新しいビルドを開始"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "新しいビルドを開始します..."
echo "（ビルド完了まで5-10分かかる場合があります）"
echo ""

oc start-build camel-app --follow

BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ ビルドが失敗しました${NC}"
    echo ""
    echo "ビルドログを確認してください:"
    echo "  oc logs -f bc/camel-app"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ビルドが成功しました！${NC}"
echo ""

# 4. ImageStreamの更新を確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: ImageStream更新確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "ImageStream最新タグ:"
oc get imagestream camel-app
echo ""

LATEST_TAG=$(oc get is camel-app -o jsonpath='{.status.tags[0].tag}' 2>/dev/null)
echo "最新のタグ: $LATEST_TAG"
echo ""

# 5. Deploymentのロールアウトを待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: Deploymentロールアウト待機"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "新しいイメージでPodが起動するまで待機中..."
oc rollout status deployment/camel-app --timeout=300s

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ ロールアウトがタイムアウトしました${NC}"
    echo ""
    echo "Pod状態を確認:"
    oc get pods -l app=camel-app
    echo ""
    echo "詳細:"
    echo "  oc describe pod -l app=camel-app"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ロールアウトが完了しました！${NC}"
echo ""

# 6. 新しいPodの確認
NEW_CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "新しいPod: $NEW_CAMEL_POD"
echo ""

# 7. アプリケーション起動を待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ6: アプリケーション起動待機"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "アプリケーションが完全に起動するまで待機中（60秒）..."
for i in {1..60}; do
    HEALTH_STATUS=$(oc exec "$NEW_CAMEL_POD" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null)
    if [ "$HEALTH_STATUS" = "200" ]; then
        echo ""
        echo -e "${GREEN}✓ アプリケーションが起動しました！${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""
echo ""

# 8. Undertowメトリクスの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ7: Undertowメトリクス確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Undertowメトリクスを取得中..."
UNDERTOW_METRICS=$(oc exec "$NEW_CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")

if [ -z "$UNDERTOW_METRICS" ]; then
    echo -e "${RED}✗ Undertowメトリクスが見つかりません${NC}"
    echo ""
    echo "Tomcatメトリクスが出力されているか確認:"
    TOMCAT_METRICS=$(oc exec "$NEW_CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^tomcat_")
    
    if [ -n "$TOMCAT_METRICS" ]; then
        echo -e "${RED}✗ まだTomcatメトリクスが出力されています${NC}"
        echo ""
        echo "ビルドが正しく実行されなかった可能性があります。"
        echo ""
        echo "ビルドログを確認してください:"
        echo "  oc logs -f bc/camel-app"
        echo ""
        echo "pom.xmlにUndertow依存関係が含まれているか確認してください。"
    else
        echo -e "${YELLOW}⚠ メトリクスが出力されていません${NC}"
        echo ""
        echo "もう少し待ってから再確認してください:"
        echo "  sleep 60"
        echo "  oc exec $NEW_CAMEL_POD -- curl -s http://localhost:8080/actuator/prometheus | grep undertow"
    fi
    exit 1
else
    echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
    echo ""
    echo "Undertowメトリクス:"
    echo "$UNDERTOW_METRICS"
    echo ""
fi

# 9. Grafana確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ8: Grafana Dashboard確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Prometheusがメトリクスをスクレイプするまで待機中（30秒）..."
sleep 30

GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)

echo "========================================="
echo "✅ Undertowイメージへの移行完了！"
echo "========================================="
echo ""
echo "Grafana Dashboardを確認してください:"
echo ""
echo -e "  ${BLUE}Grafana URL:${NC} https://$GRAFANA_URL"
echo -e "  ${BLUE}Undertow Dashboard:${NC} https://$GRAFANA_URL/d/undertow-monitoring/"
echo ""
echo "  ユーザー名: admin"
echo "  パスワード: admin123"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 期待される表示:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✅ Undertow Queue Size: 0（緑色）"
echo "  ✅ Undertow Active Requests: グラフ表示"
echo "  ✅ Undertow Worker Usage: 数値表示"
echo "  ✅ Undertow Thread Configuration: Workers: 200, I/O: 4"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


