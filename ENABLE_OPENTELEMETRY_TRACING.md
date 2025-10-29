# OpenTelemetryトレーシング有効化ガイド

## 🎯 トレーシングとは

**トレーシング（分散トレース）** は、リクエストがシステム内をどのように流れたかを可視化する技術です。

### トレーシングで分かること
- ✅ どの処理にどれだけ時間がかかったか
- ✅ どのサービスを経由したか（マイクロサービス環境）
- ✅ どこでエラーが発生したか
- ✅ ボトルネックの特定

---

## 📊 メトリクス vs トレーシング vs ログ

| 種類 | 目的 | 例 | 確認ツール |
|------|------|---|-----------|
| **メトリクス** | 数値で状態監視 | CPU 80%, メモリ 2GB使用 | Prometheus/Grafana |
| **トレーシング** | リクエストの流れ追跡 | API呼び出しに200ms、DB処理に150ms | Tempo/Jaeger |
| **ログ** | 詳細なイベント記録 | "ユーザーXがログインした" | Loki/Elasticsearch |

---

## ✅ OpenTelemetry設定手順（3ステップ）

### ステップ1: 依存関係を追加（pom.xml）

#### Spring Boot 3.x の場合（推奨）

```xml
<dependencies>
    <!-- 既存の依存関係 -->
    
    <!-- Spring Boot Actuator（メトリクスとトレーシング基盤） -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- ⭐ Micrometer Tracing with OpenTelemetry -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-tracing-bridge-otel</artifactId>
    </dependency>
    
    <!-- ⭐ OpenTelemetry Exporter（Tempoへ送信） -->
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
    </dependency>
</dependencies>
```

#### Spring Boot 2.x の場合

```xml
<dependencies>
    <!-- Spring Boot Actuator -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- Spring Cloud Sleuth with OpenTelemetry -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-sleuth</artifactId>
    </dependency>
    
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-sleuth-otel-autoconfigure</artifactId>
    </dependency>
    
    <!-- OpenTelemetry Exporter -->
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
        <version>1.31.0</version>
    </dependency>
</dependencies>
```

---

### ステップ2: 設定ファイルを編集

#### application.yml（Spring Boot 3.x）

```yaml
spring:
  application:
    name: your-application-name  # トレースに表示されるサービス名

management:
  # トレーシング設定
  tracing:
    sampling:
      probability: 1.0  # サンプリング確率（1.0 = 100%、0.1 = 10%）
    # MDC（Mapped Diagnostic Context）にトレースIDを含める
    baggage:
      correlation:
        enabled: true
      remote-fields:
        - trace_id
        - span_id
  
  # OpenTelemetry Exporter設定
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces  # TempoのOTLP HTTPエンドポイント
      # endpoint: http://localhost:4317  # TempoのOTLP gRPCエンドポイント（代替）
```

#### application.yml（Spring Boot 2.x + Sleuth）

```yaml
spring:
  application:
    name: your-application-name
  
  sleuth:
    otel:
      config:
        trace-id-ratio-based: 1.0  # サンプリング確率
      exporter:
        otlp:
          endpoint: http://localhost:4317  # Tempo gRPCエンドポイント
```

#### application.properties形式の場合

```properties
spring.application.name=your-application-name

# Spring Boot 3.x
management.tracing.sampling.probability=1.0
management.tracing.baggage.correlation.enabled=true
management.otlp.tracing.endpoint=http://localhost:4318/v1/traces
```

---

### ステップ3: Tempoサーバーを起動

トレースを収集・保存するために、Tempoサーバーが必要です。

#### Docker Composeで起動する場合

```yaml
# docker-compose.yml
version: '3.8'

services:
  tempo:
    image: grafana/tempo:2.3.1
    container_name: tempo
    ports:
      - "3200:3200"   # Tempo API（クエリ用）
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
    volumes:
      - ./tempo-config.yaml:/etc/tempo.yaml
      - tempo-data:/tmp/tempo
    command: [ "-config.file=/etc/tempo.yaml" ]

volumes:
  tempo-data:
```

#### Tempo設定ファイル（tempo-config.yaml）

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/traces

query_frontend:
  search:
    enabled: true
```

#### Tempoを起動

```bash
docker-compose up -d tempo
```

---

### ステップ4: アプリケーションを再起動

```bash
# ビルド
mvn clean package -DskipTests

# 起動
java -jar target/your-application.jar

# または開発環境
mvn spring-boot:run
```

---

## ✅ 動作確認

### 1. アプリケーションにリクエストを送信

```bash
# 何かしらのAPIを呼び出す
curl http://localhost:8080/api/orders

# または
curl http://localhost:8080/actuator/health
```

### 2. ログでトレースIDを確認

アプリケーションログに**トレースID**と**スパンID**が表示されることを確認：

```
2025-10-29 15:30:45 [a1b2c3d4e5f6g7h8,i9j0k1l2m3n4o5p6] - Processing order ORD-12345
                     ^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^
                     トレースID              スパンID
```

### 3. Tempoでトレースを確認

#### 方法A: Tempo APIで直接確認

```bash
# 最近のトレース一覧を取得
curl http://localhost:3200/api/search

# 特定のトレースIDでクエリ
curl "http://localhost:3200/api/traces/<trace-id>"
```

#### 方法B: Grafanaで確認（推奨）

1. GrafanaにTempoをデータソースとして追加

```yaml
# Grafana設定
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      tracesToLogs:
        datasourceUid: 'loki'
```

2. Grafanaで「Explore」を開く

3. データソースで「Tempo」を選択

4. 「Search」タブでトレースを検索

---

## 🔍 トレーシングの確認ポイント

### ✅ 正常に動作している場合

1. **アプリケーションログにトレースIDが表示される**
   ```
   [trace-id,span-id] - ログメッセージ
   ```

2. **TempoのAPIでトレースが検索できる**
   ```bash
   curl http://localhost:3200/api/search
   # 結果が返ってくる
   ```

3. **Grafanaでトレースが可視化できる**
   - リクエストの処理時間がグラフで表示される
   - 各処理のスパンが階層構造で表示される

### ❌ トラブルシューティング

#### 問題1: ログにトレースIDが表示されない

**原因**: 依存関係が不足している

**確認**:
```bash
mvn dependency:tree | grep micrometer-tracing
mvn dependency:tree | grep opentelemetry-exporter
```

**解決**: ステップ1の依存関係を確認してください。

#### 問題2: Tempoにトレースが送信されない

**原因1**: Tempoが起動していない

**確認**:
```bash
curl http://localhost:4318/v1/traces
# 404ではなく、405 Method Not Allowedが返ればTempo起動中
```

**原因2**: エンドポイントURLが間違っている

**確認**: `application.yml`の`management.otlp.tracing.endpoint`を確認

**解決**:
```yaml
# HTTPの場合（推奨）
management.otlp.tracing.endpoint: http://localhost:4318/v1/traces

# gRPCの場合
management.otlp.tracing.endpoint: http://localhost:4317
```

#### 問題3: サンプリング確率の設定ミス

**原因**: `probability: 0.0`になっている

**確認**:
```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # 1.0（100%）に設定
```

---

## 📊 サンプリング確率の調整

本番環境では、すべてのトレースを記録すると負荷が高くなります。サンプリング確率を調整してください。

```yaml
management:
  tracing:
    sampling:
      probability: 0.1  # 10%のリクエストのみトレース
```

| 環境 | 推奨値 | 説明 |
|------|--------|------|
| **開発環境** | `1.0` (100%) | すべてのトレースを記録してデバッグ |
| **ステージング環境** | `0.5` (50%) | 半分のリクエストをトレース |
| **本番環境（低トラフィック）** | `0.5` (50%) | 負荷が少ない場合 |
| **本番環境（高トラフィック）** | `0.1` (10%) または `0.01` (1%) | 負荷を抑える |

---

## 🎯 高度な設定

### Apache Camelでのトレーシング

Apache Camelを使用している場合、追加の設定が可能です：

#### 依存関係

```xml
<!-- Camel OpenTelemetry -->
<dependency>
    <groupId>org.apache.camel.springboot</groupId>
    <artifactId>camel-opentelemetry-starter</artifactId>
    <version>4.8.0</version>
</dependency>
```

#### application.yml

```yaml
camel:
  opentelemetry:
    enabled: true
    endpoint: http://localhost:4318/v1/traces
    service-name: ${spring.application.name}
```

---

### カスタムスパンの追加

コード内で独自のスパンを追加できます：

```java
import io.micrometer.tracing.Tracer;
import io.micrometer.tracing.Span;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class OrderService {
    
    @Autowired
    private Tracer tracer;
    
    public void processOrder(String orderId) {
        // カスタムスパンを作成
        Span span = tracer.nextSpan().name("process-order").start();
        try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
            // ビジネスロジック
            validateOrder(orderId);
            saveOrder(orderId);
            
            // タグを追加
            span.tag("order.id", orderId);
            span.tag("order.status", "completed");
        } finally {
            span.end();
        }
    }
}
```

---

### HTTPクライアントでのトレース伝播

RestTemplateやWebClientを使用する場合、トレースIDを自動的に伝播できます：

#### RestTemplate

```java
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {
    
    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        // 自動的にトレースヘッダーが追加される
        return builder.build();
    }
}
```

#### WebClient

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class WebClientConfig {
    
    @Bean
    public WebClient webClient(WebClient.Builder builder) {
        // 自動的にトレースヘッダーが追加される
        return builder.build();
    }
}
```

---

## 📋 完全な設定例（コピー&ペースト用）

### pom.xml（Spring Boot 3.x）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>your-app</artifactId>
    <version>1.0.0</version>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Actuator -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <!-- Micrometer Prometheus（メトリクス用） -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>

        <!-- Micrometer Tracing with OpenTelemetry（トレーシング用） -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-tracing-bridge-otel</artifactId>
        </dependency>

        <!-- OpenTelemetry Exporter -->
        <dependency>
            <groupId>io.opentelemetry</groupId>
            <artifactId>opentelemetry-exporter-otlp</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### application.yml（完全版）

```yaml
spring:
  application:
    name: your-application-name

server:
  port: 8080

management:
  # エンドポイント公開
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
      base-path: /actuator
  
  # ヘルスチェック
  endpoint:
    health:
      show-details: always
    prometheus:
      enabled: true
  
  # メトリクス（Prometheus）
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
  
  # トレーシング（OpenTelemetry）
  tracing:
    sampling:
      probability: 1.0  # 100%サンプリング（開発環境）
    baggage:
      correlation:
        enabled: true
      remote-fields:
        - trace_id
        - span_id
  
  # OTLP Exporter
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces

# ログ設定
logging:
  level:
    root: INFO
    com.example: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%X{traceId:-},%X{spanId:-}] %-5level %logger{36} - %msg%n"
```

---

## ⚡ クイックスタート

```bash
# 1. pom.xmlを編集（依存関係追加）
# 2. application.ymlを編集（トレーシング設定）

# 3. Tempoを起動
docker run -d --name tempo \
  -p 3200:3200 \
  -p 4317:4317 \
  -p 4318:4318 \
  grafana/tempo:2.3.1

# 4. アプリケーションをビルド & 起動
mvn clean package -DskipTests
java -jar target/*.jar

# 5. APIを呼び出してトレース生成
curl http://localhost:8080/api/test

# 6. ログでトレースIDを確認
# [a1b2c3d4e5f6g7h8,i9j0k1l2m3n4o5p6] と表示されればOK

# 7. Tempoでトレースを確認
curl http://localhost:3200/api/search | jq
```

---

## 📚 参考情報

- [OpenTelemetry公式ドキュメント](https://opentelemetry.io/docs/)
- [Spring Boot Observability](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.micrometer-tracing)
- [Micrometer Tracing](https://micrometer.io/docs/tracing)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)

---

## ✅ チェックリスト

OpenTelemetryトレーシングの導入完了確認：

- [ ] `micrometer-tracing-bridge-otel`を追加
- [ ] `opentelemetry-exporter-otlp`を追加
- [ ] `application.yml`でトレーシングを有効化
- [ ] `management.otlp.tracing.endpoint`を設定
- [ ] Tempoサーバーが起動している（ポート4318または4317）
- [ ] アプリケーションを再起動
- [ ] ログに`[traceId,spanId]`が表示される
- [ ] Tempo APIでトレースが検索できる

すべてチェックが入れば、OpenTelemetryトレーシングの設定完了です！🎉

---

## 🔗 次のステップ

トレーシングが有効になったら：

1. **Grafanaでトレースを可視化**
   - TempoをGrafanaのデータソースに追加
   - トレースとログを連携（Trace to Logs）

2. **パフォーマンス分析**
   - どの処理が遅いか特定
   - ボトルネックを見つけて改善

3. **エラー追跡**
   - エラーが発生したリクエストのトレースを確認
   - 原因となった処理を特定

