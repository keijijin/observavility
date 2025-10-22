#!/bin/bash

# camel-app の状態を詳細確認するスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔍 camel-app 状態確認"
echo "========================================="
echo ""

# 1. Deployment確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Deployment状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if oc get deployment camel-app &> /dev/null; then
    oc get deployment camel-app
    echo ""
    echo "Deployment詳細:"
    oc describe deployment camel-app | grep -A 10 "Replicas:\|Conditions:\|Events:"
else
    echo -e "${RED}✗ camel-app Deploymentが見つかりません${NC}"
    echo ""
    echo "Deploymentを作成する必要があります:"
    echo "  oc apply -f camel-app/camel-app-deployment.yaml"
    exit 1
fi
echo ""

# 2. ReplicaSet確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. ReplicaSet状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

oc get replicaset -l app=camel-app
echo ""

# 3. Pod確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Pod状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

POD_COUNT=$(oc get pods -l app=camel-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$POD_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ camel-app Podが見つかりません${NC}"
    echo ""
    echo "考えられる原因:"
    echo "  1. Deploymentが作成されていない"
    echo "  2. ReplicaSetがPodを作成できない"
    echo "  3. イメージが見つからない"
    echo "  4. リソース不足"
    echo ""
else
    oc get pods -l app=camel-app
    echo ""
    
    # Pod詳細
    echo "Pod詳細:"
    for pod in $(oc get pods -l app=camel-app -o name); do
        echo ""
        echo "=== $pod ==="
        oc describe "$pod" | tail -30
    done
fi
echo ""

# 4. Events確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. 最近のイベント（camel-app関連）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

oc get events --sort-by='.lastTimestamp' | grep -i camel-app | tail -20
echo ""

# 5. イメージ確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. イメージ確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

EXPECTED_IMAGE=$(oc get deployment camel-app -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
echo "期待されるイメージ: $EXPECTED_IMAGE"
echo ""

# ImageStreamの確認
if echo "$EXPECTED_IMAGE" | grep -q "image-registry.openshift-image-registry.svc:5000"; then
    echo "OpenShift内部レジストリを使用しています"
    echo ""
    
    # ImageStreamが存在するか確認
    if oc get imagestream camel-app &> /dev/null; then
        echo "✓ ImageStream camel-app が存在します"
        oc get imagestream camel-app
        echo ""
        echo "ImageStreamのタグ:"
        oc get imagestreamtag -l app=camel-app 2>/dev/null || echo "  タグが見つかりません"
    else
        echo -e "${RED}✗ ImageStream camel-app が見つかりません${NC}"
        echo ""
        echo "イメージをビルドしてプッシュする必要があります:"
        echo "  cd ../demo"
        echo "  podman build --platform linux/amd64 -t camel-app:1.0.0 -f camel-app/Dockerfile ."
        echo "  podman tag camel-app:1.0.0 default-route-openshift-image-registry.apps.<cluster>/camel-observability-demo/camel-app:1.0.0"
        echo "  podman push default-route-openshift-image-registry.apps.<cluster>/camel-observability-demo/camel-app:1.0.0"
    fi
else
    echo "外部イメージを使用しています: $EXPECTED_IMAGE"
fi
echo ""

# 6. ConfigMap確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. ConfigMap確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if oc get configmap camel-app-config &> /dev/null; then
    echo "✓ ConfigMap camel-app-config が存在します"
    echo ""
    echo "Undertow設定の確認:"
    oc get configmap camel-app-config -o yaml | grep -A 8 "server:" | head -9
    echo ""
    echo "Undertowメトリクス設定の確認:"
    oc get configmap camel-app-config -o yaml | grep -A 3 "enable:" | head -4
else
    echo -e "${RED}✗ ConfigMap camel-app-config が見つかりません${NC}"
    echo ""
    echo "ConfigMapを作成する必要があります:"
    echo "  oc apply -f camel-app/camel-app-deployment.yaml"
fi
echo ""

# 7. リソースクォータ確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. リソースクォータ・制限確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "ResourceQuota:"
oc get resourcequota 2>/dev/null || echo "  ResourceQuotaは設定されていません"
echo ""

echo "LimitRange:"
oc get limitrange 2>/dev/null || echo "  LimitRangeは設定されていません"
echo ""

# 8. まとめと推奨アクション
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 診断まとめ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$POD_COUNT" -eq 0 ]; then
    echo -e "${RED}⚠ camel-app Podが起動していません${NC}"
    echo ""
    echo "推奨される対処順序:"
    echo ""
    echo "1. Deploymentが存在するか確認"
    echo "   oc get deployment camel-app"
    echo ""
    echo "2. Deploymentが存在しない場合、作成"
    echo "   oc apply -f camel-app/camel-app-deployment.yaml"
    echo ""
    echo "3. イメージが存在するか確認"
    echo "   oc get imagestream camel-app"
    echo ""
    echo "4. イメージが存在しない場合、ビルドしてプッシュ"
    echo "   （OPENSHIFT_DEPLOYMENT_GUIDE.md を参照）"
    echo ""
    echo "5. Eventsを確認してエラーを特定"
    echo "   oc get events --sort-by='.lastTimestamp' | grep camel-app"
    echo ""
else
    POD_NAME=$(oc get pods -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    POD_STATUS=$(oc get pods -l app=camel-app -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    
    echo "Pod名: $POD_NAME"
    echo "Pod状態: $POD_STATUS"
    echo ""
    
    if [ "$POD_STATUS" != "Running" ]; then
        echo -e "${YELLOW}⚠ Podが Running 状態ではありません${NC}"
        echo ""
        echo "詳細を確認:"
        echo "  oc describe pod $POD_NAME"
        echo "  oc logs $POD_NAME"
    else
        echo -e "${GREEN}✓ Podは正常に起動しています${NC}"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


