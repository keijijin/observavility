package com.example.demo.route;

import lombok.extern.slf4j.Slf4j;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.rest.RestBindingMode;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class HealthCheckRoute extends RouteBuilder {

    @Override
    public void configure() throws Exception {
        // REST設定
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json);

        // REST APIでヘルスチェック
        rest("/api")
            .get("/health")
                .to("direct:healthCheck")
            .get("/metrics")
                .to("direct:metricsInfo");

        from("direct:healthCheck")
            .routeId("health-check-route")
            .log("ヘルスチェックリクエストを受信")
            .setBody(constant("{\"status\":\"UP\",\"service\":\"camel-observability-demo\"}"))
            .setHeader("Content-Type", constant("application/json"));

        from("direct:metricsInfo")
            .routeId("metrics-info-route")
            .log("メトリクス情報リクエストを受信")
            .setBody(constant("{\"message\":\"メトリクスは /actuator/prometheus で確認できます\"}"))
            .setHeader("Content-Type", constant("application/json"));
    }
}

