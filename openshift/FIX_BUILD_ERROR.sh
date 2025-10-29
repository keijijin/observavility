#!/bin/bash

# OpenShift BuildConfig修正スクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 BuildConfig修正 - ソースから再ビルド"
echo "========================================="
echo ""

# 1. 問題の説明
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 問題の原因"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "BuildConfigがBinary Source（ローカルからのアップロード）を"
echo "期待していますが、ソースファイルが提供されていません。"
echo ""
echo "エラー:"
echo "  rsync: link_stat \"/tmp/src/*\" failed: No such file or directory"
echo ""

# 2. ソースディレクトリの確認
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/../camel-app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: ソースディレクトリの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ ソースディレクトリが見つかりません: $SOURCE_DIR${NC}"
    echo ""
    echo "このスクリプトは以下のディレクトリ構造を期待しています:"
    echo "  /Users/kjin/mobills/observability/demo/"
    echo "    ├── camel-app/  ← ソースコード"
    echo "    └── openshift/  ← このスクリプト"
    exit 1
fi

echo "✓ ソースディレクトリが見つかりました: $SOURCE_DIR"
echo ""

# pom.xmlとDockerfileの存在確認
if [ ! -f "$SOURCE_DIR/pom.xml" ]; then
    echo -e "${RED}✗ pom.xmlが見つかりません${NC}"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/Dockerfile" ]; then
    echo -e "${RED}✗ Dockerfileが見つかりません${NC}"
    exit 1
fi

echo "✓ pom.xml: 存在"
echo "✓ Dockerfile: 存在"
echo ""

# pom.xmlにundertowが含まれているか確認
echo "pom.xmlのUndertow依存関係確認:"
grep -A 2 "spring-boot-starter-undertow" "$SOURCE_DIR/pom.xml" | head -3
echo ""

# 3. ビルド方法の選択
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ2: ビルド方法の選択"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "2つの方法があります:"
echo ""
echo "【方法A: Binary Build（ローカルからアップロード）】"
echo "  利点: 既存のBuildConfigをそのまま使用"
echo "  欠点: ローカルのソースコードをアップロードする必要がある"
echo ""
echo "【方法B: Dockerfile Build（推奨）】"
echo "  利点: Dockerfile を直接使用、BuildConfig修正が必要"
echo "  欠点: BuildConfigを再作成する必要がある"
echo ""

read -p "方法を選択してください (a/b): " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Aa]$ ]]; then
    # 方法A: Binary Build
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "方法A: Binary Buildでソースをアップロード"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "ソースディレクトリ: $SOURCE_DIR"
    echo ""
    
    # 一時ディレクトリを作成してソースをコピー
    TEMP_DIR=$(mktemp -d)
    echo "一時ディレクトリを作成: $TEMP_DIR"
    
    # 必要なファイルをコピー
    cp -r "$SOURCE_DIR"/* "$TEMP_DIR/"
    
    # .gitignoreされているファイルを除外
    if [ -f "$TEMP_DIR/target" ]; then
        rm -rf "$TEMP_DIR/target"
    fi
    
    echo "✓ ソースファイルを準備しました"
    echo ""
    
    echo "ビルドを開始します..."
    oc start-build camel-app --from-dir="$TEMP_DIR" --follow
    
    BUILD_STATUS=$?
    
    # 一時ディレクトリを削除
    rm -rf "$TEMP_DIR"
    
    if [ $BUILD_STATUS -ne 0 ]; then
        echo ""
        echo -e "${RED}✗ ビルドが失敗しました${NC}"
        exit 1
    fi
    
elif [[ $REPLY =~ ^[Bb]$ ]]; then
    # 方法B: Dockerfile Build
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "方法B: Dockerfile Buildに変更"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "⚠ この方法では、既存のBuildConfigを削除して再作成します。"
    echo ""
    read -p "続行しますか? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました"
        exit 0
    fi
    
    echo ""
    echo "既存のBuildConfigを削除中..."
    oc delete buildconfig camel-app
    
    echo ""
    echo "新しいBuildConfig（Dockerfile Build）を作成中..."
    
    # Dockerfile Buildの方法を案内
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 次のステップ:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Dockerfile Buildは、ローカルでイメージをビルドして"
    echo "OpenShiftにプッシュする方法が最も確実です。"
    echo ""
    echo "以下のコマンドを実行してください:"
    echo ""
    echo "  cd $SOURCE_DIR/.."
    echo "  podman build --platform linux/amd64 -t camel-app:undertow -f camel-app/Dockerfile ."
    echo ""
    echo "  # OpenShiftレジストリにログイン"
    echo "  oc registry login"
    echo ""
    echo "  # イメージにタグを付ける"
    echo "  REGISTRY=\$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')"
    echo "  podman tag camel-app:undertow \$REGISTRY/camel-observability-demo/camel-app:latest"
    echo ""
    echo "  # プッシュ"
    echo "  podman push \$REGISTRY/camel-observability-demo/camel-app:latest"
    echo ""
    echo "  # Deploymentを更新"
    echo "  oc set image deployment/camel-app \\"
    echo "    camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest"
    echo ""
    
    exit 0
else
    echo "無効な選択です"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ビルドが完了しました！${NC}"
echo ""

# 4. ロールアウト待機
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ3: Deploymentロールアウト待機"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

oc rollout status deployment/camel-app --timeout=300s

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ロールアウトが失敗しました${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ロールアウトが完了しました！${NC}"
echo ""

# 5. Undertowメトリクス確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "新しいPod: $CAMEL_POD"
echo ""

echo "アプリケーション起動待機（30秒）..."
sleep 30

echo ""
echo "Undertowメトリクスを確認中..."
UNDERTOW_METRICS=$(oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_")

if [ -z "$UNDERTOW_METRICS" ]; then
    echo -e "${RED}✗ Undertowメトリクスが見つかりません${NC}"
    echo ""
    echo "Tomcatメトリクスを確認:"
    oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^tomcat" | head -3
else
    echo -e "${GREEN}✓ Undertowメトリクスが出力されています！${NC}"
    echo ""
    echo "$UNDERTOW_METRICS"
    echo ""
    
    GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 成功！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Grafana Dashboard: https://$GRAFANA_URL/d/undertow-monitoring/"
fi

echo ""



