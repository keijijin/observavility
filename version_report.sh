#!/bin/bash
# システムバージョン情報レポート生成スクリプト

echo "=========================================="
echo "  システムバージョン情報"
echo "=========================================="
echo ""
echo "生成時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "📦 アプリケーション:"
CAMEL_VERSION=$(curl -s http://localhost:8080/actuator/info 2>/dev/null | jq -r '.camel.version' 2>/dev/null)
SPRING_VERSION=$(curl -s http://localhost:8080/actuator/info 2>/dev/null | jq -r '."spring-boot".version' 2>/dev/null)
JAVA_VERSION=$(curl -s http://localhost:8080/actuator/info 2>/dev/null | jq -r '.java.version' 2>/dev/null)
APP_VERSION=$(curl -s http://localhost:8080/actuator/info 2>/dev/null | jq -r '.app.version' 2>/dev/null)

echo "  Apache Camel: ${CAMEL_VERSION:-N/A}"
echo "  Spring Boot: ${SPRING_VERSION:-N/A}"
echo "  Java/JDK: ${JAVA_VERSION:-N/A}"
echo "  アプリバージョン: ${APP_VERSION:-N/A}"
echo ""

echo "🔧 観測ツール:"
PROM_VERSION=$(curl -s http://localhost:9090/api/v1/status/buildinfo 2>/dev/null | jq -r '.data.version' 2>/dev/null)
GRAFANA_VERSION=$(curl -s http://localhost:3000/api/health 2>/dev/null | jq -r '.version' 2>/dev/null)
TEMPO_VERSION=$(podman exec tempo /tempo --version 2>&1 | head -1 | awk '{print $3}' 2>/dev/null)
LOKI_VERSION=$(podman exec loki /loki --version 2>&1 | head -1 | awk '{print $3}' 2>/dev/null)

echo "  Prometheus: ${PROM_VERSION:-N/A}"
echo "  Grafana: ${GRAFANA_VERSION:-N/A}"
echo "  Tempo: ${TEMPO_VERSION:-N/A}"
echo "  Loki: ${LOKI_VERSION:-N/A}"
echo ""

echo "📡 メッセージング:"
KAFKA_VERSION=$(podman exec kafka kafka-broker-api-versions --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' 2>/dev/null || echo "N/A")
echo "  Kafka: ${KAFKA_VERSION}"
echo ""

echo "🐳 コンテナランタイム:"
PODMAN_VERSION=$(podman --version | awk '{print $3}')
echo "  Podman: ${PODMAN_VERSION}"
echo ""

echo "=========================================="
echo ""
echo "📝 詳細情報:"
echo "  Actuator Info: http://localhost:8080/actuator/info"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000"
echo ""
echo "=========================================="


