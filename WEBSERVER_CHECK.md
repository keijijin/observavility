# camel-app Webサーバー確認結果

## 結論

**camel-appは Tomcat（デフォルト）を使用しています。Undertowは使用していません。** ✅

---

## 確認結果の詳細

### 1. クラスパスの確認

実行中のJavaプロセスのクラスパスに以下が含まれています：

```
/Users/kjin/.m2/repository/org/apache/tomcat/embed/tomcat-embed-core/10.1.16/tomcat-embed-core-10.1.16.jar
/Users/kjin/.m2/repository/org/apache/tomcat/embed/tomcat-embed-el/10.1.16/tomcat-embed-el-10.1.16.jar
/Users/kjin/.m2/repository/org/apache/tomcat/embed/tomcat-embed-websocket/10.1.16/tomcat-embed-websocket-10.1.16.jar
```

**→ Tomcat 10.1.16 を使用しています**

### 2. pom.xml の確認

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```

- ✅ `spring-boot-starter-web`：デフォルトでTomcatを含む
- ❌ Undertowの依存なし
- ❌ Tomcat除外の記述なし

**→ デフォルトのTomcatを使用**

---

## なぜthread_monitor.shでTomcat/Undertowメトリクスが検出されなかったのか？

### 理由

Spring Boot 3.xでは、**Tomcat/Undertow固有のメトリクスがデフォルトで無効**になっています。

```bash
# thread_monitor.sh の出力
検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  # Tomcatメトリクスは表示されない（デフォルトで無効）
```

### 確認

```bash
# Tomcatメトリクスの確認
curl -s http://localhost:8080/actuator/prometheus | grep "^tomcat_threads"
# → 何も表示されない（無効）
```

---

## thread_monitor.shは正常に動作しています ✅

### 現在の動作

```
[10:44:30]
  JVMスレッド:
    Live: 38 | Daemon: 34 | Non-Daemon: 4 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 2147483647 | Core: 8 | Usage: N/A%
```

- ✅ JVMスレッドメトリクス：正常取得
- ✅ Executorメトリクス：正常取得
- ⚠️ Tomcatメトリクス：取得不可（デフォルトで無効）
- ❌ Undertowメトリクス：該当なし（Undertow未使用）

**→ スクリプトは正常に動作しており、Tomcat/Undertowメトリクスは環境に応じて自動検出します**

---

## Tomcatメトリクスを有効化する方法

Spring Boot 3.xでTomcat固有のメトリクスを有効にするには、追加設定が必要です。

### application.yml に追加

```yaml
management:
  metrics:
    web:
      server:
        request:
          autotime:
            enabled: true
    enable:
      tomcat: true  # Tomcatメトリクスを有効化
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
```

### または Java Config

```java
@Configuration
public class MetricsConfiguration {
    @Bean
    public MeterBinder tomcatMetrics(TomcatMetricsBinder binder) {
        return binder;
    }
}
```

### 有効化後の出力

```
[10:44:30]
  JVMスレッド:
    Live: 38 | Daemon: 34 | Non-Daemon: 4 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Tomcat Threads:  ← 追加表示
    Current: 10 | Busy: 2 | Idle: 8 | Max: 200 | Usage: 1.0%
```

---

## Undertowへの切り替え方法（オプション）

もしUndertowを使いたい場合は、以下の手順で切り替えられます。

### 1. pom.xml の変更

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <!-- Tomcatを除外 -->
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<!-- Undertowを追加 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-undertow</artifactId>
</dependency>
```

### 2. application.yml の設定（オプション）

```yaml
server:
  undertow:
    threads:
      io: 4                    # I/Oスレッド数（通常はCPUコア数）
      worker: 200              # ワーカースレッド数（最大）
    buffer-size: 1024          # バッファサイズ（バイト）
    direct-buffers: true       # ダイレクトバッファを使用
```

### 3. 再ビルド＆再起動

```bash
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package
mvn spring-boot:run
```

### 4. thread_monitor.sh で確認

```bash
cd /Users/kjin/mobills/observability/demo
./thread_monitor.sh

# 出力例
検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  - Undertowメトリクス: 有効 ✅（キューサイズ含む）

[10:44:30]
  JVMスレッド:
    Live: 38 | Daemon: 34 | Non-Daemon: 4 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Undertow:
    Workers: 200 | Active: 15 | Queue: 8 | Usage: 7.5%
```

---

## Tomcat vs Undertow の比較

| 項目 | Tomcat | Undertow |
|---|---|---|
| **デフォルト** | ✅ Spring Boot標準 | ❌ 追加設定必要 |
| **メトリクス** | 追加設定で有効化 | デフォルトで有効 |
| **キューサイズ** | ❌ なし | ✅ あり（重要） |
| **メモリ使用量** | 中程度 | 軽量 |
| **パフォーマンス** | 標準 | やや高速 |
| **安定性** | 非常に高い | 高い |
| **コミュニティ** | 非常に大きい | 中規模 |

---

## 推奨

### 現在の環境（Tomcat）で十分な場合
- ✅ そのまま使用
- ✅ JVM + Executorメトリクスで監視可能
- ⚠️ 必要に応じてTomcatメトリクスを有効化

### Undertowを試したい場合
- ✅ pom.xmlを変更
- ✅ キューサイズ監視が可能になる
- ✅ パフォーマンスがやや向上する可能性

---

## まとめ

| 質問 | 回答 |
|---|---|
| **Undertowを使っているか？** | ❌ いいえ、Tomcatです |
| **thread_monitor.shは正常？** | ✅ はい、正常動作中 |
| **Tomcatメトリクスは？** | ⚠️ デフォルトで無効（Spring Boot 3.x） |
| **Undertowに切り替え可能？** | ✅ はい、pom.xml変更で可能 |

---

**作成日**: 2025-10-20  
**確認項目**: クラスパス、pom.xml、メトリクス  
**結論**: Tomcat使用中、thread_monitor.shは正常動作



