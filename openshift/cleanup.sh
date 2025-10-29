#!/bin/bash
# OpenShift クリーンアップスクリプト

set -e

echo "=========================================="
echo "  OpenShift リソースのクリーンアップ"
echo "=========================================="
echo ""

# 現在のプロジェクトを確認
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    echo "❌ OpenShiftにログインしていません"
    exit 1
fi

echo "📦 現在のプロジェクト: $CURRENT_PROJECT"
echo ""

# 確認
echo "⚠️  以下のリソースが削除されます:"
echo ""
oc get all,pvc,configmap,route | grep -v "service/openshift\|service/kubernetes" || echo "リソースが見つかりません"
echo ""

read -p "本当に削除しますか? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "クリーンアップをキャンセルしました"
    exit 0
fi

# スクリプトのディレクトリに移動
cd "$(dirname "$0")"

echo "🗑️  リソースを削除中..."
echo ""

# Camel App
echo "Camel App を削除中..."
oc delete -f camel-app/camel-app-deployment.yaml --ignore-not-found=true

# Grafana
echo "Grafana を削除中..."
oc delete -f grafana/grafana-deployment.yaml --ignore-not-found=true

# Loki
echo "Loki を削除中..."
oc delete -f loki/loki-deployment.yaml --ignore-not-found=true

# Tempo
echo "Tempo を削除中..."
oc delete -f tempo/tempo-deployment.yaml --ignore-not-found=true

# Prometheus
echo "Prometheus を削除中..."
oc delete -f prometheus/prometheus-deployment.yaml --ignore-not-found=true
oc delete -f prometheus/prometheus-configmap.yaml --ignore-not-found=true

# Kafka
echo "Kafka を削除中..."
oc delete -f kafka/kafka-deployment.yaml --ignore-not-found=true

# Zookeeper
echo "Zookeeper を削除中..."
oc delete -f kafka/zookeeper-deployment.yaml --ignore-not-found=true

echo ""
echo "⏳ リソースの削除を待機中..."
sleep 10

echo ""
echo "=========================================="
echo "  クリーンアップ完了"
echo "=========================================="
echo ""

# 残っているリソースを確認
echo "残っているリソース:"
oc get all,pvc | grep -v "service/openshift\|service/kubernetes" || echo "すべてのリソースが削除されました"

echo ""
echo "💡 プロジェクト自体を削除する場合:"
echo "   oc delete project $CURRENT_PROJECT"
echo ""




