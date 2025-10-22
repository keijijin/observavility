# thread_monitor.sh 修正完了

## 問題

```bash
./thread_monitor.sh 10
エラー: サーバータイプを検出できませんでした
```

---

## 原因

スクリプトがTomcat/Undertow固有のメトリクスを探していたが、これらは**デフォルトで有効になっていない**。

### 確認結果

```bash
# Tomcatメトリクス → ❌ なし
curl -s http://localhost:8080/actuator/prometheus | grep "tomcat_threads"

# Undertowメトリクス → ❌ なし  
curl -s http://localhost:8080/actuator/prometheus | grep "undertow"

# JVMスレッドメトリクス → ✅ あり
curl -s http://localhost:8080/actuator/prometheus | grep "jvm_threads"

# Executorメトリクス → ✅ あり
curl -s http://localhost:8080/actuator/prometheus | grep "executor"
```

---

## 解決策

**利用可能なメトリクスを使用**するようにスクリプトを修正：

| 旧 | 新 |
|---|---|
| ❌ `tomcat_threads_*` | ✅ `jvm_threads_*` |
| ❌ `undertow_*` | ✅ `executor_*` |

---

## 新しい監視項目

### 1. JVMスレッド（全体）

```bash
jvm_threads_live_threads       # 稼働中のスレッド総数
jvm_threads_daemon_threads     # デーモンスレッド数
jvm_threads_peak_threads       # ピークスレッド数
```

**計算項目**:
- **Non-Daemon threads** = `live_threads - daemon_threads`

### 2. Executorスレッドプール（Webサーバーのワーカープール）

```bash
executor_active_threads        # アクティブ（処理中）のスレッド数
executor_pool_size_threads     # 現在のプールサイズ
executor_pool_max_threads      # 最大スレッド数
executor_pool_core_threads     # コアスレッド数
```

**計算項目**:
- **Usage (%)** = `(active_threads / max_threads) * 100`

---

## 使い方

### 基本

```bash
cd /Users/kjin/mobills/observability/demo

# デフォルト（5秒間隔）
./thread_monitor.sh

# カスタム間隔（3秒）
./thread_monitor.sh 3
```

### 出力例

```
=== JVM & Executor スレッド監視 ===
測定間隔: 3秒
Ctrl+C で終了

✅ アプリケーション接続成功

監視項目:
  - JVMスレッド（全体）
  - Executor（Tomcat/Undertowのワーカースレッドプール）

[09:52:15]
  JVMスレッド:
    Live: 38 | Daemon: 28 | Non-Daemon: 10 | Peak: 40
  Executor（Webサーバーワーカープール）:
    Active: 1 | Pool Size: 8 | Max: 200 | Core: 8 | Usage: 0.5%

[09:52:18]
  JVMスレッド:
    Live: 40 | Daemon: 29 | Non-Daemon: 11 | Peak: 42
  Executor（Webサーバーワーカープール）:
    Active: 3 | Pool Size: 10 | Max: 200 | Core: 8 | Usage: 1.5%
```

---

## 解説

### JVMスレッドとは？

- **Live threads**: JVM全体で稼働中のスレッド総数（Camel、Kafka、タイマーなど全て含む）
- **Daemon threads**: バックグラウンドで動作するデーモンスレッド（GC、コンパイラなど）
- **Non-Daemon threads**: アプリケーションロジックを実行するメインスレッド
- **Peak threads**: アプリケーション起動以降の最大スレッド数

### Executorスレッドプールとは？

Spring BootのWebサーバー（Tomcat/Undertow）が使用する**ワーカースレッドプール**のこと。

- **Active threads**: 現在HTTPリクエストを処理中のスレッド数
- **Pool size**: 現在確保されているスレッド数（動的に増減）
- **Max threads**: 最大スレッド数（`server.tomcat.threads.max`で設定）
- **Core threads**: 常時確保されるコアスレッド数

**使用率が高い（>80%）と**:
- リクエストの待ち時間が増加
- スレッドプールの拡張が必要

---

## Tomcat固有メトリクスを有効化したい場合

もしTomcat固有のメトリクス（`tomcat_threads_*`）を有効にしたい場合:

### 1. 依存関係を追加（`pom.xml`）

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### 2. MBean設定を有効化（`application.yml`）

```yaml
management:
  metrics:
    export:
      simple:
        enabled: true
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
```

### 3. Tomcat MBean Exporterを有効化

Spring Boot 3.xでは、Tomcat固有のメトリクスは**デフォルトで無効**になっています。

---

## まとめ

| 項目 | 状態 |
|---|---|
| **問題** | Tomcat/Undertowメトリクスが無効 |
| **解決策** | JVM + Executorメトリクスを使用 |
| **監視可能** | ✅ JVMスレッド、Executorスレッドプール |
| **スクリプト** | `thread_monitor.sh`（修正済み） |

---

**作成日**: 2025-10-20  
**対象**: `demo/thread_monitor.sh`  
**修正理由**: Tomcat/Undertow固有メトリクスがデフォルトで無効のため、JVM + Executorメトリクスに変更


