# Prometheusエンドポイント有効化ガイド

## 🎯 問題

`/actuator/health`は動作するが、`/actuator/prometheus`が**404 Not Found**になる。

---

## ✅ 解決方法（3ステップ）

### ステップ1: 依存関係を追加

`pom.xml`に以下を追加してください。

```xml
<dependencies>
    <!-- 既存の依存関係 -->
    
    <!-- Spring Boot Actuator（既にある場合はスキップ） -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- ⭐ Prometheus形式でメトリクスを公開するために必須 -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

**重要**: `micrometer-registry-prometheus`がないと、設定だけでは有効になりません。

---

### ステップ2: 設定ファイルを編集

#### application.ymlの場合:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics  # prometheusを追加
      base-path: /actuator
  endpoint:
    prometheus:
      enabled: true  # Prometheusエンドポイントを有効化
  metrics:
    export:
      prometheus:
        enabled: true  # Prometheus形式でエクスポート
```

#### application.propertiesの場合:

```properties
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.endpoints.web.base-path=/actuator
management.endpoint.prometheus.enabled=true
management.metrics.export.prometheus.enabled=true
```

---

### ステップ3: アプリケーションを再起動

```bash
# ビルド
mvn clean package -DskipTests

# 起動
java -jar target/your-application.jar

# または、開発環境の場合
mvn spring-boot:run
```

---

## ✅ 動作確認

### 1. エンドポイント一覧を確認

```bash
curl http://localhost:8080/actuator

# 期待される出力（prometheusが含まれているか確認）
{
  "_links": {
    "self": {...},
    "health": {...},
    "prometheus": {  # ← これがあればOK
      "href": "http://localhost:8080/actuator/prometheus",
      "templated": false
    },
    ...
  }
}
```

### 2. Prometheusエンドポイントを確認

```bash
curl http://localhost:8080/actuator/prometheus | head -20

# 期待される出力（JVMメトリクスが表示される）
# HELP jvm_threads_live_threads The current number of live threads
# TYPE jvm_threads_live_threads gauge
jvm_threads_live_threads{application="your-app-name"} 45.0
# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="PS Eden Space"} 2.1234567E7
...
```

### 3. JVMスレッドメトリクスを確認

```bash
curl http://localhost:8080/actuator/prometheus | grep "jvm_threads"

# 期待される出力
jvm_threads_live_threads{application="your-app"} 45.0
jvm_threads_daemon_threads{application="your-app"} 38.0
jvm_threads_peak_threads{application="your-app"} 129.0
```

---

## 🔍 トラブルシューティング

### ❌ まだ404 Not Foundが出る

#### チェック1: 依存関係が正しく追加されているか確認

```bash
# pom.xmlを確認
grep -A 3 "micrometer-registry-prometheus" pom.xml

# または、依存関係ツリーで確認
mvn dependency:tree | grep micrometer-registry-prometheus
```

**出力がない場合**: ステップ1を再度確認してください。

#### チェック2: 設定が正しいか確認

```bash
# application.ymlを確認
grep -A 10 "management:" src/main/resources/application.yml
```

**`prometheus`が含まれていない場合**: ステップ2を再度確認してください。

#### チェック3: アプリケーションログを確認

```bash
# 起動ログで以下が表示されているか確認
# "Exposing X endpoint(s) beneath base path '/actuator'"
```

**表示されない場合**: アプリケーションが正しく再起動されていない可能性があります。

---

## 📋 完全な設定例（コピー&ペースト用）

### pom.xml

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
        <version>3.2.0</version> <!-- または 2.7.x -->
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

        <!-- Micrometer Prometheus Registry（重要！） -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
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

### application.yml

```yaml
spring:
  application:
    name: your-application-name

server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
      base-path: /actuator
  endpoint:
    health:
      show-details: always
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
```

---

## ⚡ クイックスタート

```bash
# 1. pom.xmlを編集（ステップ1）
# 2. application.ymlを編集（ステップ2）

# 3. ビルド & 起動
mvn clean package -DskipTests
java -jar target/*.jar

# 4. 確認（別のターミナルで実行）
curl http://localhost:8080/actuator/prometheus | head -20

# ✅ JVMメトリクスが表示されれば成功！
```

---

## 📊 取得できるメトリクス

Prometheusエンドポイントが有効になると、以下のメトリクスが自動的に収集されます：

### JVMメトリクス
- `jvm_threads_live_threads` - 稼働中のスレッド数
- `jvm_threads_daemon_threads` - デーモンスレッド数
- `jvm_threads_peak_threads` - ピークスレッド数
- `jvm_memory_used_bytes` - メモリ使用量
- `jvm_memory_max_bytes` - 最大メモリ
- `jvm_gc_pause_seconds` - GC停止時間

### システムメトリクス
- `system_cpu_usage` - システムCPU使用率
- `process_cpu_usage` - プロセスCPU使用率
- `process_uptime_seconds` - 稼働時間

### HTTPメトリクス（Spring Boot 2.x/3.x）
- `http_server_requests_seconds` - HTTPリクエスト処理時間

### Camelメトリクス（Apache Camelを使用している場合）
- `camelExchangesTotal` - 処理されたメッセージ総数
- `camelExchangesFailed` - 失敗したメッセージ数

---

## 🔗 次のステップ

Prometheusエンドポイントが有効になったら、以下のツールを使用できます：

1. **thread_monitor.sh** - スレッド監視スクリプト
   ```bash
   ./thread_monitor.sh 5 http://localhost:8080/actuator/prometheus
   ```

2. **Prometheus** - メトリクス収集サーバー
   ```yaml
   # prometheus.yml
   scrape_configs:
     - job_name: 'your-app'
       static_configs:
         - targets: ['localhost:8080']
       metrics_path: '/actuator/prometheus'
   ```

3. **Grafana** - 可視化ダッシュボード
   - Prometheusをデータソースとして追加
   - JVMダッシュボードをインポート

---

## 📚 参考情報

- [Spring Boot Actuator公式ドキュメント](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Micrometer公式ドキュメント](https://micrometer.io/docs)
- [Prometheusドキュメント](https://prometheus.io/docs/introduction/overview/)

---

## ✅ チェックリスト

導入完了の確認：

- [ ] `pom.xml`に`micrometer-registry-prometheus`を追加
- [ ] `application.yml`で`prometheus`エンドポイントを公開
- [ ] アプリケーションをビルド & 再起動
- [ ] `curl http://localhost:8080/actuator`で`prometheus`が表示される
- [ ] `curl http://localhost:8080/actuator/prometheus`でメトリクスが表示される
- [ ] `jvm_threads_live_threads`などのJVMメトリクスが取得できる

すべてチェックが入れば、設定完了です！🎉

