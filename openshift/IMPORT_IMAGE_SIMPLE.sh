#!/bin/bash

# ローカルPodmanイメージをOpenShiftに直接インポートするシンプルなスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "📦 OpenShiftへのイメージインポート"
echo "========================================="
echo ""

# 1. イメージの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: ローカルイメージ確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! podman image exists camel-app:undertow; then
    echo -e "${RED}✗ イメージcamel-app:undertowが見つかりません${NC}"
    echo ""
    echo "まずイメージをビルドしてください:"
    echo "  cd ../camel-app"
    echo "  podman build --platform linux/amd64 -t camel-app:undertow -f Dockerfile.prebuilt ."
    exit 1
fi

echo -e "${GREEN}✓ イメージが存在します${NC}"
podman images | grep camel-app
echo ""

# 2. イメージをtarファイルにエクスポート
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: イメージをエクスポート"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TAR_FILE="/tmp/camel-app-undertow.tar"
echo "エクスポート先: $TAR_FILE"
echo "（1-2分かかります）"
echo ""

podman save -o "$TAR_FILE" camel-app:undertow

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ イメージのエクスポートに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ エクスポート完了${NC}"
ls -lh "$TAR_FILE"
echo ""

# 3. OpenShiftにインポート
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: OpenShiftにインポート"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "ImageStreamが存在するか確認..."
if ! oc get imagestream camel-app &>/dev/null; then
    echo "ImageStreamを作成中..."
    oc create imagestream camel-app
fi
echo ""

echo "tarファイルからImageStreamにインポート中..."
echo "（2-5分かかります）"
echo ""

oc import-image camel-app:latest \
  --from="$TAR_FILE" \
  --confirm \
  --insecure

IMPORT_RESULT=$?

# tarファイルを削除
echo ""
echo "一時ファイルをクリーンアップ中..."
rm -f "$TAR_FILE"
echo -e "${GREEN}✓ クリーンアップ完了${NC}"
echo ""

if [ $IMPORT_RESULT -ne 0 ]; then
    echo -e "${RED}✗ インポートに失敗しました${NC}"
    echo ""
    echo "代替方法を試します..."
    echo ""
    
    # 代替方法: Podman経由で直接タグを付けてプッシュ
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "代替方法: oc image toolsを使用"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # OpenShift CRCの場合、crc-adminでログイン
    echo "OpenShift環境を確認中..."
    oc whoami
    
    echo ""
    echo "ImageStreamを最新のローカルイメージで更新します..."
    
    # ImageStreamTagを直接作成
    cat <<EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStreamTag
metadata:
  name: camel-app:latest
  namespace: camel-observability-demo
tag:
  from:
    kind: DockerImage
    name: camel-app:undertow
  importPolicy:
    insecure: true
  referencePolicy:
    type: Local
EOF
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 代替方法も失敗しました${NC}"
        echo ""
        echo "手動でイメージをインポートしてください:"
        echo "  1. Podmanイメージをエクスポート:"
        echo "     podman save -o /tmp/camel-app.tar camel-app:undertow"
        echo ""
        echo "  2. OpenShift内部でロード:"
        echo "     oc debug node/<node-name> -- podman load -i /host/tmp/camel-app.tar"
        exit 1
    fi
fi

echo -e "${GREEN}✅ インポートが成功しました！${NC}"
echo ""

# 4. Deploymentを更新
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: Deploymentを更新"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Deploymentのイメージを更新中..."
oc set image deployment/camel-app \
  camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Deployment更新に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Deployment更新完了${NC}"
echo ""

# 5. ロールアウトを待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: ロールアウト待機"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

# 6. Undertowメトリクスを確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ6: Undertowメトリクス確認"
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
    TOMCAT_COUNT=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep -c "^tomcat")
    if [ "$TOMCAT_COUNT" -gt 0 ]; then
        echo -e "${RED}✗ まだTomcatメトリクスが出力されています${NC}"
        echo ""
        echo "古いイメージが使用されています。"
    else
        echo -e "${YELLOW}⚠ アプリケーションがまだ起動中の可能性があります${NC}"
        echo ""
        echo "もう少し待ってから確認してください:"
        echo "  sleep 60"
        echo "  oc exec $CAMEL_POD -- curl -s http://localhost:8080/actuator/prometheus | grep undertow"
    fi
    exit 1
fi

echo -e "${GREEN}✓ Undertowメトリクスが正常に出力されています！${NC}"
echo ""
echo "Undertowメトリクス:"
echo "$UNDERTOW_METRICS"
echo ""

# 7. Grafana確認
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



