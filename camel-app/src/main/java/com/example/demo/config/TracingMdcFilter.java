package com.example.demo.config;

import io.micrometer.tracing.Tracer;
import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@Order(Ordered.LOWEST_PRECEDENCE - 1)  // トレーシングフィルターの後に実行
public class TracingMdcFilter implements Filter {

    private static final Logger log = LoggerFactory.getLogger(TracingMdcFilter.class);
    private final Tracer tracer;

    public TracingMdcFilter(Tracer tracer) {
        this.tracer = tracer;
        log.info("TracingMdcFilter initialized with tracer: {}", tracer != null ? tracer.getClass().getName() : "null");
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        // リクエスト処理前と後でMDCを設定
        updateMdc();
        
        try {
            chain.doFilter(request, response);
        } finally {
            // リクエスト処理後にもMDCを更新（Camelルート内で使用するため）
            updateMdc();
        }
    }
    
    private void updateMdc() {
        if (tracer != null) {
            var span = tracer.currentSpan();
            log.debug("Updating MDC - Current span: {}", span != null);
            
            if (span != null && span.context() != null) {
                String traceId = span.context().traceId();
                String spanId = span.context().spanId();
                
                log.debug("TraceId: {}, SpanId: {}", traceId, spanId);
                
                if (traceId != null && !traceId.isEmpty()) {
                    MDC.put("traceId", traceId);
                }
                if (spanId != null && !spanId.isEmpty()) {
                    MDC.put("spanId", spanId);
                }
            }
        }
    }
}

