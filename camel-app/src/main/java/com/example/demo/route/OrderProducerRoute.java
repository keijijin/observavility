package com.example.demo.route;

import com.example.demo.model.Order;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.rest.RestBindingMode;
import org.springframework.stereotype.Component;

import java.util.Random;
import java.util.UUID;

@Slf4j
@Component
public class OrderProducerRoute extends RouteBuilder {

    private final Random random = new Random();
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final String[] products = {"Laptop", "Mouse", "Keyboard", "Monitor", "Headphones"};
    private final String[] customers = {"CUST-001", "CUST-002", "CUST-003", "CUST-004", "CUST-005"};

    @Override
    public void configure() throws Exception {
        // REST設定
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json);

        // REST APIでオーダーを生成
        rest("/api")
            .post("/orders")
                .to("direct:createOrder");

        // オーダー生成ルート
        from("direct:createOrder")
            .routeId("create-order-route")
            .log("=== 新規オーダーを作成しています ===")
            .process(exchange -> {
                Order order = new Order();
                order.setOrderId("ORD-" + UUID.randomUUID().toString().substring(0, 8));
                order.setCustomerId(customers[random.nextInt(customers.length)]);
                order.setProductName(products[random.nextInt(products.length)]);
                order.setQuantity(random.nextInt(5) + 1);
                order.setPrice(random.nextDouble() * 1000 + 100);
                order.setStatus("CREATED");
                order.setTimestamp(System.currentTimeMillis());
                
                exchange.getIn().setBody(order);
                log.info("オーダーを生成しました: {}", order);
            })
            .marshal().json()
            .to("kafka:orders?key=${body.orderId}")
            .log("Kafkaにオーダーを送信しました: ${body}")
            .setBody(constant("Order created successfully"));

        // 定期的にオーダーを自動生成（デモ用）
        // Note: タイマーは無効化しています。REST APIで手動テストしてください。
        // from("timer:order-generator?period=10000&delay=5000")
        //     .routeId("auto-order-generator")
        //     .log("=== 自動オーダー生成タイマー起動 ===")
        //     .to("direct:createOrder");
    }
}

