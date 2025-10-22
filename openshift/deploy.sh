#!/bin/bash
# OpenShift デプロイメントスクリプト

set -e

echo "=========================================="
echo "  OpenShift デプロイメント開始"
echo "=========================================="
echo ""

# 現在のプロジェクトを確認
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    echo "❌ OpenShiftにログインしていません"
    echo "   以下のコマンドでログインしてください:"
    echo "   oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>"
    exit 1
fi

echo "📦 現在のプロジェクト: $CURRENT_PROJECT"
echo ""

# プロジェクトが camel-observability-demo でない場合、確認
if [ "$CURRENT_PROJECT" != "camel-observability-demo" ]; then
    echo "⚠️  現在のプロジェクトが 'camel-observability-demo' ではありません"
    read -p "このプロジェクトにデプロイしますか? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "デプロイをキャンセルしました"
        exit 1
    fi
fi

# スクリプトのディレクトリに移動
cd "$(dirname "$0")"

echo "=========================================="
echo "  1. Zookeeper のデプロイ"
echo "=========================================="
oc apply -f kafka/zookeeper-deployment.yaml
echo "⏳ Zookeeperの起動を待機中..."
oc wait --for=condition=ready pod -l app=zookeeper --timeout=300s 2>/dev/null || true
echo "✅ Zookeeper デプロイ完了"
echo ""

echo "=========================================="
echo "  2. Kafka のデプロイ"
echo "=========================================="
oc apply -f kafka/kafka-deployment.yaml
echo "⏳ Kafkaの起動を待機中..."
sleep 30
oc wait --for=condition=ready pod -l app=kafka --timeout=300s 2>/dev/null || true
echo "✅ Kafka デプロイ完了"
echo ""

echo "=========================================="
echo "  3. Prometheus のデプロイ"
echo "=========================================="
oc apply -f prometheus/prometheus-configmap.yaml
oc apply -f prometheus/prometheus-deployment.yaml
echo "⏳ Prometheusの起動を待機中..."
sleep 20
oc wait --for=condition=ready pod -l app=prometheus --timeout=300s 2>/dev/null || true
echo "✅ Prometheus デプロイ完了"
echo ""

echo "=========================================="
echo "  4. Tempo のデプロイ"
echo "=========================================="
oc apply -f tempo/tempo-deployment.yaml
echo "⏳ Tempoの起動を待機中..."
sleep 20
oc wait --for=condition=ready pod -l app=tempo --timeout=300s 2>/dev/null || true
echo "✅ Tempo デプロイ完了"
echo ""

echo "=========================================="
echo "  5. Loki のデプロイ"
echo "=========================================="
oc apply -f loki/loki-deployment.yaml
echo "⏳ Lokiの起動を待機中..."
sleep 20
oc wait --for=condition=ready pod -l app=loki --timeout=300s 2>/dev/null || true
echo "✅ Loki デプロイ完了"
echo ""

echo "=========================================="
echo "  6. Grafana のデプロイ"
echo "=========================================="
oc apply -f grafana/grafana-deployment.yaml
echo "⏳ Grafanaの起動を待機中..."
sleep 30
oc wait --for=condition=ready pod -l app=grafana --timeout=300s 2>/dev/null || true
echo "✅ Grafana デプロイ完了"
echo ""

echo "=========================================="
echo "  7. Camel App のデプロイ"
echo "=========================================="
echo "⚠️  注意: Camel Appのイメージが事前にビルドされている必要があります"
echo ""
read -p "Camel Appをデプロイしますか? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    oc apply -f camel-app/camel-app-deployment.yaml
    echo "⏳ Camel Appの起動を待機中..."
    sleep 30
    oc wait --for=condition=ready pod -l app=camel-app --timeout=300s 2>/dev/null || true
    echo "✅ Camel App デプロイ完了"
else
    echo "⏭️  Camel App のデプロイをスキップしました"
    echo "   後で手動でデプロイする場合:"
    echo "   oc apply -f camel-app/camel-app-deployment.yaml"
fi
echo ""

echo "=========================================="
echo "  デプロイメント完了"
echo "=========================================="
echo ""

# リソースの確認
echo "📦 デプロイされたリソース:"
echo ""
echo "Pods:"
oc get pods
echo ""
echo "Services:"
oc get svc
echo ""
echo "Routes:"
oc get route
echo ""
echo "PVCs:"
oc get pvc
echo ""

# アクセスURLの表示
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")

echo "=========================================="
echo "  アクセスURL"
echo "=========================================="
echo ""
echo "🌐 Grafana:"
if [ "$GRAFANA_URL" != "N/A" ]; then
    echo "   https://${GRAFANA_URL}"
    echo "   ユーザー名: admin"
    echo "   パスワード: admin"
else
    echo "   ❌ Routeが作成されていません"
fi
echo ""
echo "📊 Prometheus:"
if [ "$PROMETHEUS_URL" != "N/A" ]; then
    echo "   https://${PROMETHEUS_URL}"
else
    echo "   ❌ Routeが作成されていません"
fi
echo ""
echo "🐪 Camel App:"
if [ "$CAMEL_URL" != "N/A" ]; then
    echo "   https://${CAMEL_URL}"
    echo "   Health: https://${CAMEL_URL}/actuator/health"
    echo "   Metrics: https://${CAMEL_URL}/actuator/prometheus"
else
    echo "   ❌ Routeが作成されていません、またはデプロイされていません"
fi
echo ""

echo "=========================================="
echo "  次のステップ"
echo "=========================================="
echo ""
echo "1. Grafanaにアクセスしてダッシュボードを確認"
echo "2. Camel Appにリクエストを送信してテスト:"
echo "   curl -k -X POST https://${CAMEL_URL}/camel/api/orders \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"id\":\"order-001\",\"product\":\"laptop\",\"quantity\":1}'"
echo ""
echo "3. 詳細なガイドは OPENSHIFT_DEPLOYMENT_GUIDE.md を参照"
echo ""
echo "=========================================="



