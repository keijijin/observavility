package com.example.demo.route;

import com.example.demo.model.Order;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.apache.camel.builder.RouteBuilder;
import org.springframework.stereotype.Component;

import java.util.Random;

@Slf4j
@Component
public class OrderConsumerRoute extends RouteBuilder {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Random random = new Random();

    @Override
    public void configure() throws Exception {
        // Kafkaからオーダーを受信
        from("kafka:orders?groupId=camel-demo-group")
            .routeId("order-consumer-route")
            .log("=== Kafkaからオーダーを受信しました ===")
            .unmarshal().json(Order.class)
            .log("オーダーを処理中: ${body.orderId}")
            .to("direct:validateOrder");

        // オーダーバリデーション
        from("direct:validateOrder")
            .routeId("validate-order-route")
            .log("オーダーをバリデーション中: ${body.orderId}")
            .process(exchange -> {
                Order order = exchange.getIn().getBody(Order.class);
                
                // バリデーション処理をシミュレート（50-200ms）
                Thread.sleep(random.nextInt(150) + 50);
                
                if (order.getQuantity() > 10) {
                    log.warn("オーダー数量が多すぎます: {}", order.getOrderId());
                    throw new IllegalArgumentException("Quantity too high");
                }
                
                log.info("バリデーション成功: {}", order.getOrderId());
            })
            .to("direct:processPayment")
            .onException(IllegalArgumentException.class)
                .log("バリデーションエラー: ${exception.message}")
                .handled(true)
                .to("direct:handleError")
            .end();

        // 支払い処理
        from("direct:processPayment")
            .routeId("payment-processing-route")
            .log("支払いを処理中: ${body.orderId}")
            .process(exchange -> {
                Order order = exchange.getIn().getBody(Order.class);
                
                // 支払い処理をシミュレート（意図的に遅延を追加：200-500ms）
                int delay = random.nextInt(300) + 200;
                Thread.sleep(delay);
                
                // 10%の確率でエラーをシミュレート
                if (random.nextInt(10) == 0) {
                    log.error("支払い処理エラー: {}", order.getOrderId());
                    throw new RuntimeException("Payment processing failed");
                }
                
                order.setStatus("PAID");
                log.info("支払い処理完了: {} (処理時間: {}ms)", order.getOrderId(), delay);
            })
            .to("direct:shipOrder")
            .onException(RuntimeException.class)
                .log("支払いエラー: ${exception.message}")
                .handled(true)
                .to("direct:handleError")
            .end();

        // 配送処理
        from("direct:shipOrder")
            .routeId("shipping-route")
            .log("配送を準備中: ${body.orderId}")
            .process(exchange -> {
                Order order = exchange.getIn().getBody(Order.class);
                
                // 配送処理をシミュレート（100-300ms）
                Thread.sleep(random.nextInt(200) + 100);
                
                order.setStatus("SHIPPED");
                log.info("配送完了: {}", order.getOrderId());
            })
            .log("✅ オーダー処理完了: ${body.orderId} - ステータス: ${body.status}");

        // エラーハンドリング
        from("direct:handleError")
            .routeId("error-handling-route")
            .log("⚠️ エラーハンドリング中")
            .process(exchange -> {
                Order order = exchange.getIn().getBody(Order.class);
                if (order != null) {
                    order.setStatus("FAILED");
                    log.error("オーダー失敗: {}", order.getOrderId());
                }
            });
    }
}



