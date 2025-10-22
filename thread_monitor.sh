#!/bin/bash

# スレッド監視スクリプト（JVM + Executor + Tomcat/Undertow対応）
# 使い方: ./thread_monitor.sh [interval_seconds]

INTERVAL=${1:-5}
ACTUATOR_URL="http://localhost:8080/actuator/prometheus"

echo "=== JVM & Webサーバー スレッド監視 ==="
echo "測定間隔: ${INTERVAL}秒"
echo "Ctrl+C で終了"
echo ""

# アプリケーションが起動しているか確認
check_app() {
    if ! curl -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL" 2>/dev/null | grep -q "200"; then
        echo "❌ エラー: アプリケーションにアクセスできません"
        echo ""
        echo "確認方法:"
        echo "  curl http://localhost:8080/actuator/health"
        echo ""
        echo "起動方法:"
        echo "  1. ローカル環境: podman-compose up -d"
        echo "  2. スタンドアロン: mvn spring-boot:run"
        exit 1
    fi
}

check_app

# サーバータイプを検出（初回のみ）
METRICS=$(curl -s "$ACTUATOR_URL")
HAS_TOMCAT=$(echo "$METRICS" | grep -q "^tomcat_threads" && echo "true" || echo "false")
HAS_UNDERTOW=$(echo "$METRICS" | grep -q "^undertow_" && echo "true" || echo "false")

echo "✅ アプリケーション接続成功"
echo ""
echo "検出されたメトリクス:"
echo "  - JVMスレッド: 有効"
echo "  - Executor: 有効"
if [ "$HAS_TOMCAT" = "true" ]; then
    echo "  - Tomcatメトリクス: 有効 ✅"
fi
if [ "$HAS_UNDERTOW" = "true" ]; then
    echo "  - Undertowメトリクス: 有効 ✅（キューサイズ含む）"
fi
echo ""

while true; do
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # メトリクスを1回だけ取得（効率化）
    METRICS=$(curl -s "$ACTUATOR_URL")
    
    # JVMスレッドメトリクス（macOS互換）
    LIVE=$(echo "$METRICS" | grep "^jvm_threads_live_threads{" | awk '{print $NF}' | head -1)
    DAEMON=$(echo "$METRICS" | grep "^jvm_threads_daemon_threads{" | awk '{print $NF}' | head -1)
    PEAK=$(echo "$METRICS" | grep "^jvm_threads_peak_threads{" | awk '{print $NF}' | head -1)
    
    # Executorメトリクス（Tomcat/Undertowのワーカープール）
    EXECUTOR_ACTIVE=$(echo "$METRICS" | grep "^executor_active_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_SIZE=$(echo "$METRICS" | grep "^executor_pool_size_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_MAX=$(echo "$METRICS" | grep "^executor_pool_max_threads{" | awk '{print $NF}' | head -1)
    EXECUTOR_POOL_CORE=$(echo "$METRICS" | grep "^executor_pool_core_threads{" | awk '{print $NF}' | head -1)
    
    # Tomcatメトリクス（有効な場合のみ）
    if [ "$HAS_TOMCAT" = "true" ]; then
        TOMCAT_CURRENT=$(echo "$METRICS" | grep "^tomcat_threads_current_threads{" | awk '{print $NF}' | head -1)
        TOMCAT_BUSY=$(echo "$METRICS" | grep "^tomcat_threads_busy_threads{" | awk '{print $NF}' | head -1)
        TOMCAT_MAX=$(echo "$METRICS" | grep "^tomcat_threads_config_max_threads{" | awk '{print $NF}' | head -1)
    fi
    
    # Undertowメトリクス（有効な場合のみ）
    if [ "$HAS_UNDERTOW" = "true" ]; then
        UNDERTOW_WORKER=$(echo "$METRICS" | grep "^undertow_worker_threads{" | awk '{print $NF}' | head -1)
        UNDERTOW_ACTIVE=$(echo "$METRICS" | grep "^undertow_active_requests{" | awk '{print $NF}' | head -1)
        UNDERTOW_QUEUE=$(echo "$METRICS" | grep "^undertow_request_queue_size{" | awk '{print $NF}' | head -1)
    fi
    
    # 整数変換
    LIVE_INT=$(printf "%.0f" "$LIVE" 2>/dev/null || echo "0")
    DAEMON_INT=$(printf "%.0f" "$DAEMON" 2>/dev/null || echo "0")
    PEAK_INT=$(printf "%.0f" "$PEAK" 2>/dev/null || echo "0")
    EXECUTOR_ACTIVE_INT=$(printf "%.0f" "$EXECUTOR_ACTIVE" 2>/dev/null || echo "0")
    EXECUTOR_POOL_SIZE_INT=$(printf "%.0f" "$EXECUTOR_POOL_SIZE" 2>/dev/null || echo "0")
    EXECUTOR_POOL_MAX_INT=$(printf "%.0f" "$EXECUTOR_POOL_MAX" 2>/dev/null || echo "0")
    EXECUTOR_POOL_CORE_INT=$(printf "%.0f" "$EXECUTOR_POOL_CORE" 2>/dev/null || echo "0")
    
    # 非デーモンスレッド
    NON_DAEMON=$((LIVE_INT - DAEMON_INT))
    
    # Executor使用率
    if [ "$EXECUTOR_POOL_MAX_INT" -gt 0 ] && [ "$EXECUTOR_POOL_MAX_INT" -lt 2000000000 ]; then
        EXECUTOR_USAGE=$(echo "scale=1; ($EXECUTOR_ACTIVE_INT / $EXECUTOR_POOL_MAX_INT) * 100" | bc 2>/dev/null || echo "0")
    else
        EXECUTOR_USAGE="N/A"
    fi
    
    # 出力
    echo "[$TIMESTAMP]"
    echo "  JVMスレッド:"
    echo "    Live: $LIVE_INT | Daemon: $DAEMON_INT | Non-Daemon: $NON_DAEMON | Peak: $PEAK_INT"
    
    echo "  Executor（Spring Task Executor）:"
    if [ "$EXECUTOR_POOL_MAX_INT" -gt 0 ]; then
        echo "    Active: $EXECUTOR_ACTIVE_INT | Pool Size: $EXECUTOR_POOL_SIZE_INT | Max: $EXECUTOR_POOL_MAX_INT | Core: $EXECUTOR_POOL_CORE_INT | Usage: ${EXECUTOR_USAGE}%"
    else
        echo "    ⚠️  メトリクス取得不可"
    fi
    
    # Tomcatメトリクス表示
    if [ "$HAS_TOMCAT" = "true" ]; then
        TOMCAT_CURRENT_INT=$(printf "%.0f" "$TOMCAT_CURRENT" 2>/dev/null || echo "0")
        TOMCAT_BUSY_INT=$(printf "%.0f" "$TOMCAT_BUSY" 2>/dev/null || echo "0")
        TOMCAT_MAX_INT=$(printf "%.0f" "$TOMCAT_MAX" 2>/dev/null || echo "0")
        TOMCAT_IDLE=$((TOMCAT_CURRENT_INT - TOMCAT_BUSY_INT))
        
        if [ "$TOMCAT_MAX_INT" -gt 0 ]; then
            TOMCAT_USAGE=$(echo "scale=1; ($TOMCAT_BUSY_INT / $TOMCAT_MAX_INT) * 100" | bc 2>/dev/null || echo "0")
        else
            TOMCAT_USAGE="N/A"
        fi
        
        echo "  Tomcat Threads:"
        echo "    Current: $TOMCAT_CURRENT_INT | Busy: $TOMCAT_BUSY_INT | Idle: $TOMCAT_IDLE | Max: $TOMCAT_MAX_INT | Usage: ${TOMCAT_USAGE}%"
    fi
    
    # Undertowメトリクス表示（キューサイズ含む）
    if [ "$HAS_UNDERTOW" = "true" ]; then
        UNDERTOW_WORKER_INT=$(printf "%.0f" "$UNDERTOW_WORKER" 2>/dev/null || echo "0")
        UNDERTOW_ACTIVE_INT=$(printf "%.0f" "$UNDERTOW_ACTIVE" 2>/dev/null || echo "0")
        UNDERTOW_QUEUE_INT=$(printf "%.0f" "$UNDERTOW_QUEUE" 2>/dev/null || echo "0")
        
        if [ "$UNDERTOW_WORKER_INT" -gt 0 ]; then
            UNDERTOW_USAGE=$(echo "scale=1; ($UNDERTOW_ACTIVE_INT / $UNDERTOW_WORKER_INT) * 100" | bc 2>/dev/null || echo "0")
        else
            UNDERTOW_USAGE="N/A"
        fi
        
        echo "  Undertow:"
        echo "    Workers: $UNDERTOW_WORKER_INT | Active: $UNDERTOW_ACTIVE_INT | Queue: $UNDERTOW_QUEUE_INT | Usage: ${UNDERTOW_USAGE}%"
    fi
    
    echo ""
    
    sleep $INTERVAL
done
