#!/bin/bash

# camel-app イメージ問題を修正するスクリプト

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "🔧 camel-app イメージ問題修正"
echo "========================================="
echo ""

# 1. ImageStream確認
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ1: ImageStream確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if oc get imagestream camel-app &> /dev/null; then
    echo "✓ ImageStream camel-app が存在します"
    echo ""
    oc get imagestream camel-app
    echo ""
    
    echo "ImageStreamのタグ:"
    oc get imagestreamtag -l app=camel-app 2>/dev/null || oc get is camel-app -o jsonpath='{.status.tags[*].tag}' 2>/dev/null
    echo ""
    echo ""
    
    # 最新のタグを確認
    LATEST_TAG=$(oc get is camel-app -o jsonpath='{.status.tags[0].tag}' 2>/dev/null)
    if [ -n "$LATEST_TAG" ]; then
        echo "最新のタグ: $LATEST_TAG"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎯 解決策: Deploymentのイメージタグを更新"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Deploymentのイメージを最新のタグに変更します:"
        echo "  現在: image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:1.0.0"
        echo "  変更後: image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:$LATEST_TAG"
        echo ""
        
        read -p "Deploymentのイメージタグを更新しますか? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Deploymentを更新中..."
            oc set image deployment/camel-app \
              camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:$LATEST_TAG
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Deployment更新成功${NC}"
                echo ""
                echo "Podの再起動を待機中..."
                oc rollout status deployment/camel-app --timeout=180s
                echo ""
                
                # Undertowメトリクス確認
                CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [ -n "$CAMEL_POD" ]; then
                    echo "新しいPod: $CAMEL_POD"
                    echo ""
                    echo "アプリケーション起動待機（30秒）..."
                    sleep 30
                    echo ""
                    echo "Undertowメトリクス確認:"
                    oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_" || echo -e "${YELLOW}⚠ undertowメトリクスが見つかりません（アプリケーション起動中の可能性）${NC}"
                fi
            else
                echo -e "${RED}✗ Deployment更新失敗${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ タグが見つかりません${NC}"
        echo ""
        echo "ImageStreamにタグが存在しません。"
        echo "新しいビルドを実行する必要があります。"
    fi
else
    echo -e "${RED}✗ ImageStream camel-app が見つかりません${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 解決策: 新しいイメージをビルド"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "ImageStreamが存在しないため、イメージをビルドする必要があります。"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. BuildConfig確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if oc get buildconfig camel-app &> /dev/null; then
    echo "✓ BuildConfig camel-app が存在します"
    echo ""
    oc get buildconfig camel-app
    echo ""
    
    echo "過去のビルド履歴:"
    oc get builds -l app=camel-app --sort-by=.metadata.creationTimestamp | tail -5
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 解決策: 新しいビルドを実行"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "新しいビルドを開始しますか? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "新しいビルドを開始中..."
        oc start-build camel-app --follow
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓ ビルド成功${NC}"
            echo ""
            
            # 最新のタグを確認
            NEW_TAG=$(oc get is camel-app -o jsonpath='{.status.tags[0].tag}' 2>/dev/null)
            if [ -n "$NEW_TAG" ]; then
                echo "新しいタグ: $NEW_TAG"
                echo ""
                
                # Deploymentを自動的に更新
                echo "Deploymentのイメージを更新中..."
                oc set image deployment/camel-app \
                  camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:$NEW_TAG
                
                echo ""
                echo "Podの再起動を待機中..."
                oc rollout status deployment/camel-app --timeout=180s
                
                # Undertowメトリクス確認
                CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [ -n "$CAMEL_POD" ]; then
                    echo ""
                    echo "新しいPod: $CAMEL_POD"
                    echo ""
                    echo "アプリケーション起動待機（30秒）..."
                    sleep 30
                    echo ""
                    echo "Undertowメトリクス確認:"
                    oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null | grep "^undertow_"
                fi
            fi
        else
            echo ""
            echo -e "${RED}✗ ビルド失敗${NC}"
            echo ""
            echo "ビルドログを確認してください:"
            echo "  oc logs -f bc/camel-app"
        fi
    fi
else
    echo -e "${RED}✗ BuildConfig camel-app が見つかりません${NC}"
    echo ""
    echo "BuildConfigが存在しません。"
    echo "OPENSHIFT_DEPLOYMENT_GUIDE.md を参照して、"
    echo "ローカルでイメージをビルドしてプッシュしてください。"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 まとめ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "現在の状況:"
oc get pods -l app=camel-app
echo ""
echo "ImageStream状態:"
oc get imagestream camel-app 2>/dev/null || echo "  ImageStreamが見つかりません"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


