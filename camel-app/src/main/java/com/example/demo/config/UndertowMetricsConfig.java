package com.example.demo.config;

import io.micrometer.core.instrument.MeterRegistry;
import io.undertow.Undertow;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;

/**
 * Undertowメトリクス設定
 * Spring Boot 3.xでUndertowメトリクスを有効化
 */
@Configuration
@ConditionalOnClass(Undertow.class)
public class UndertowMetricsConfig {

    private final MeterRegistry meterRegistry;
    
    @Value("${server.undertow.threads.worker:200}")
    private int workerThreads;
    
    @Value("${server.undertow.threads.io:4}")
    private int ioThreads;

    private UndertowMetrics metricsInstance;

    public UndertowMetricsConfig(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    /**
     * Undertowメトリクスを登録
     * Spring Boot 3.xではデフォルトで提供されないため、手動で登録
     */
    @PostConstruct
    public void registerUndertowMetrics() {
        // 新しいインスタンスを作成し、設定値で初期化
        metricsInstance = new UndertowMetrics();
        metricsInstance.setWorkerThreads(workerThreads);
        metricsInstance.setIoThreads(ioThreads);
        
        // すべてのメトリクスを同じ方法で登録
        meterRegistry.gauge("undertow.worker.threads", metricsInstance, UndertowMetrics::getWorkerThreads);
        meterRegistry.gauge("undertow.io.threads", metricsInstance, UndertowMetrics::getIoThreads);
        meterRegistry.gauge("undertow.active.requests", metricsInstance, UndertowMetrics::getActiveRequests);
        meterRegistry.gauge("undertow.request.queue.size", metricsInstance, UndertowMetrics::getQueueSize);
    }

    /**
     * Undertowメトリクスインスタンスを取得
     * 他のコンポーネントから値を更新できるように公開
     */
    public UndertowMetrics getMetricsInstance() {
        return metricsInstance;
    }

    /**
     * Undertowメトリクスのデータホルダー
     * 実際の値はHTTPリクエスト処理時に更新される
     */
    public static class UndertowMetrics {
        private int workerThreads = 200;
        private int ioThreads = 4;
        private volatile int activeRequests = 0;
        private volatile int queueSize = 0;

        public int getWorkerThreads() {
            return workerThreads;
        }

        public void setWorkerThreads(int workerThreads) {
            this.workerThreads = workerThreads;
        }

        public int getIoThreads() {
            return ioThreads;
        }

        public void setIoThreads(int ioThreads) {
            this.ioThreads = ioThreads;
        }

        public int getActiveRequests() {
            return activeRequests;
        }

        public int getQueueSize() {
            return queueSize;
        }

        public void incrementActiveRequests() {
            activeRequests++;
        }

        public void decrementActiveRequests() {
            if (activeRequests > 0) {
                activeRequests--;
            }
        }

        public void updateQueueSize(int size) {
            queueSize = size;
        }
    }
}

