#!/bin/bash

# UndertowイメージをローカルでビルドしてOpenShiftにプッシュするスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 Undertowイメージのビルドとプッシュ"
echo "========================================="
echo ""

# 1. 前提条件確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: 前提条件確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Podmanの確認
if ! command -v podman &> /dev/null; then
    echo -e "${RED}✗ podmanが見つかりません${NC}"
    echo ""
    echo "podmanをインストールしてから再実行してください:"
    echo "  brew install podman"
    exit 1
fi
echo "✓ podman: $(podman --version)"

# OpenShift CLIの確認
if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗ oc (OpenShift CLI)が見つかりません${NC}"
    exit 1
fi
echo "✓ oc: $(oc version --client | head -1)"

# OpenShiftログイン確認
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗ OpenShiftにログインしていません${NC}"
    echo ""
    echo "OpenShiftにログインしてから再実行してください:"
    echo "  oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>"
    exit 1
fi
echo "✓ OpenShift: ログイン済み ($(oc whoami))"
echo ""

# 2. ソースディレクトリの確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: ソースディレクトリ確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="$SCRIPT_DIR/../camel-app"

echo "ビルドコンテキスト: $BUILD_CONTEXT"

if [ ! -f "$BUILD_CONTEXT/Dockerfile" ]; then
    echo -e "${RED}✗ Dockerfileが見つかりません: $BUILD_CONTEXT/Dockerfile${NC}"
    exit 1
fi
echo "✓ Dockerfile: 存在"

if [ ! -f "$BUILD_CONTEXT/pom.xml" ]; then
    echo -e "${RED}✗ pom.xmlが見つかりません${NC}"
    exit 1
fi
echo "✓ pom.xml: 存在"

# pom.xmlにUndertowが含まれているか確認
echo ""
echo "pom.xmlのUndertow依存関係:"
grep -A 2 "spring-boot-starter-undertow" "$BUILD_CONTEXT/pom.xml" | head -3
echo ""

read -p "イメージをビルドしますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "キャンセルしました"
    exit 0
fi

# 3. イメージのビルド
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: Undertowイメージのビルド"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "イメージをビルド中..."
echo "（5-10分かかる場合があります）"
echo ""

cd "$BUILD_CONTEXT"
podman build --platform linux/amd64 -t camel-app:undertow -f Dockerfile .

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ イメージのビルドに失敗しました${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ イメージのビルドが成功しました！${NC}"
echo ""

# ビルドしたイメージを確認
echo "ビルドしたイメージ:"
podman images | grep "camel-app"
echo ""

# 4. OpenShiftレジストリにログイン
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ4: OpenShiftレジストリにログイン"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# OpenShift内部レジストリの外部ルートを確認
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -z "$REGISTRY" ]; then
    echo -e "${RED}✗ OpenShiftレジストリのルートが見つかりません${NC}"
    echo ""
    echo "OpenShift管理者に連絡して、レジストリの外部アクセスを有効にしてください。"
    echo ""
    echo "または、内部レジストリを使用する場合:"
    REGISTRY="image-registry.openshift-image-registry.svc:5000"
    echo "内部レジストリを使用します: $REGISTRY"
else
    echo "レジストリURL: $REGISTRY"
fi
echo ""

echo "OpenShiftレジストリにログイン中..."
if ! oc registry login; then
    echo -e "${RED}✗ レジストリへのログインに失敗しました${NC}"
    echo ""
    echo "手動でログインしてから再実行してください:"
    echo "  oc registry login"
    exit 1
fi

echo -e "${GREEN}✓ レジストリにログインしました${NC}"
echo ""

# 5. イメージにタグを付ける
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ5: イメージにタグを付ける"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TARGET_IMAGE="$REGISTRY/camel-observability-demo/camel-app:latest"
echo "ターゲットイメージ: $TARGET_IMAGE"

podman tag camel-app:undertow "$TARGET_IMAGE"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ タグ付けに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ タグ付けが完了しました${NC}"
echo ""

# 6. イメージをプッシュ
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ6: イメージをプッシュ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "イメージをOpenShiftにプッシュ中..."
echo "（数分かかる場合があります）"
echo ""

podman push "$TARGET_IMAGE"

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}✗ イメージのプッシュに失敗しました${NC}"
    echo ""
    echo "トラブルシューティング:"
    echo "  1. レジストリへのアクセス権限を確認"
    echo "  2. プロジェクト名が正しいか確認"
    echo "  3. ネットワーク接続を確認"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ イメージのプッシュが完了しました！${NC}"
echo ""

# 7. Deploymentを更新
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ7: Deploymentを更新"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Deploymentのイメージを更新中..."
oc set image deployment/camel-app \
  camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Deployment更新に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Deployment更新が完了しました${NC}"
echo ""

# 8. ロールアウトを待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ8: ロールアウト待機"
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
echo -e "${GREEN}✓ ロールアウトが完了しました！${NC}"
echo ""

# 9. Undertowメトリクスを確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ9: Undertowメトリクス確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "新しいPod: $CAMEL_POD"
echo ""

echo "アプリケーション起動待機（30秒）..."
sleep 30
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
        echo "古いイメージキャッシュが使用されている可能性があります。"
        echo ""
        echo "以下を試してください:"
        echo "  1. Podを強制削除:"
        echo "     oc delete pod -l app=camel-app --force --grace-period=0"
        echo ""
        echo "  2. ImageStreamを確認:"
        echo "     oc describe imagestream camel-app"
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

# 10. Grafana確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 成功！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Prometheusがメトリクスをスクレイプするまで待機（30秒）..."
sleep 30

GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)

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

