#!/bin/bash

# skopeoを使ってローカルイメージをOpenShiftレジストリに直接コピー

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🚀 skopeoでOpenShiftにプッシュ"
echo "========================================="
echo ""

# 1. イメージの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: ローカルイメージ確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! podman image exists camel-app:undertow; then
    echo -e "${RED}✗ イメージcamel-app:undertowが見つかりません${NC}"
    exit 1
fi

echo -e "${GREEN}✓ イメージが存在します${NC}"
podman images | grep camel-app
echo ""

# 2. OpenShiftトークンを取得
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: OpenShift認証情報取得"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

OCP_TOKEN=$(oc whoami -t)
if [ -z "$OCP_TOKEN" ]; then
    echo -e "${RED}✗ OpenShiftトークンを取得できません${NC}"
    exit 1
fi

echo -e "${GREEN}✓ トークン取得成功${NC}"
echo "ユーザー: $(oc whoami)"
echo ""

# 3. Port Forwardを起動
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: Port Forward起動"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 既存のport-forwardプロセスを停止
pkill -f "oc port-forward.*image-registry" 2>/dev/null
sleep 2

echo "OpenShiftレジストリへのPort Forward起動中..."
oc port-forward -n openshift-image-registry service/image-registry 5000:5000 &
PF_PID=$!
echo "Port Forward PID: $PF_PID"
echo ""

# Port Forwardが確立されるまで待機
echo "接続確立を待機中（10秒）..."
sleep 10

# Port Forwardが動作しているか確認
if ! ps -p $PF_PID > /dev/null 2>&1; then
    echo -e "${RED}✗ Port Forwardの起動に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Port Forward起動成功${NC}"
echo ""

# 4. skopeoでイメージをコピー
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: skopeoでイメージをコピー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SOURCE_IMAGE="docker-daemon:camel-app:undertow"
DEST_IMAGE="docker://localhost:5000/camel-observability-demo/camel-app:latest"

echo "コピー元: $SOURCE_IMAGE"
echo "コピー先: $DEST_IMAGE"
echo ""
echo "コピー中（2-5分）..."
echo ""

skopeo copy \
  --dest-tls-verify=false \
  --dest-creds="admin:$OCP_TOKEN" \
  "$SOURCE_IMAGE" \
  "$DEST_IMAGE"

COPY_RESULT=$?

# 5. Port Forwardをクリーンアップ
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: クリーンアップ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Port Forwardを停止中..."
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null
echo -e "${GREEN}✓ Port Forward停止完了${NC}"
echo ""

if [ $COPY_RESULT -ne 0 ]; then
    echo -e "${RED}✗ イメージのコピーに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✅ イメージのコピーが成功しました！${NC}"
echo ""

# 6. ImageStreamを確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ6: ImageStream確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "ImageStreamを更新中..."
sleep 5
oc import-image camel-app:latest --insecure --confirm
echo ""

echo "ImageStream情報:"
oc describe imagestream camel-app | grep -A 5 "latest"
echo ""

# 7. Podを強制削除して再作成
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ7: Podを強制再作成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "古いPodを削除中..."
oc delete pod -l app=camel-app --force --grace-period=0
echo ""

echo "新しいPodが起動するまで待機中..."
oc rollout status deployment/camel-app --timeout=300s

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ ロールアウトがタイムアウトしました${NC}"
    echo ""
    echo "Pod状態を確認:"
    oc get pods -l app=camel-app
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ロールアウト完了${NC}"
echo ""

# 8. Undertowメトリクスを確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ8: Undertowメトリクス確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "新しいPod: $CAMEL_POD"
echo ""

echo "アプリケーション起動待機（60秒）..."
sleep 60
echo ""

echo "Undertowメトリクスを取得中..."
UNDERTOW_METRICS=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")

if [ -z "$UNDERTOW_METRICS" ]; then
    echo -e "${RED}✗ Undertowメトリクスが見つかりません${NC}"
    echo ""
    
    # Tomcatメトリクスを確認
    echo "Tomcatメトリクスを確認中..."
    TOMCAT_COUNT=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -c "^tomcat")
    if [ "$TOMCAT_COUNT" -gt 0 ]; then
        echo -e "${RED}✗ まだTomcatメトリクスが出力されています（$TOMCAT_COUNT個）${NC}"
        echo ""
        echo "ImageStreamを確認:"
        oc describe imagestream camel-app
        echo ""
        echo "Podのイメージを確認:"
        oc describe pod "$CAMEL_POD" | grep "Image:"
    else
        echo -e "${YELLOW}⚠ アプリケーションがまだ起動中の可能性があります${NC}"
        echo ""
        echo "ログを確認:"
        oc logs "$CAMEL_POD" | tail -50
    fi
    exit 1
fi

echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
echo ""
echo "Undertowメトリクス:"
echo "$UNDERTOW_METRICS"
echo ""

# 9. Grafana確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 成功！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)

echo "Prometheusがメトリクスをスクレイプするまで待機（30秒）..."
sleep 30

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
echo "  ✅ Undertow Thread Configuration: Workers: 200"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

