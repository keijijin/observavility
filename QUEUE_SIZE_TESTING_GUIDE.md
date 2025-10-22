# Undertowキューサイズを増加させるテスト方法

## 🎯 **問題の理由**

現在キューサイズが常に0である理由は2つあります：

### 1. **実装の制限** ⚠️

```java
// UndertowMetricsConfig.java
public static class UndertowMetrics {
    private volatile int queueSize = 0;  // ← 常に0（更新されない）
}
```

現在の実装では、実際のUndertowの内部キューを取得していません。固定値0を返しているだけです。

### 2. **パフォーマンスに余裕がある** ✅

```
ワーカースレッド: 200
現在の負荷: 100並列（load-test-stress.sh）
→ 余裕: 50%以上
```

100並列では十分にワーカースレッドに余裕があるため、実際にキューイングが発生していません。

---

## 🚀 **キューサイズを増加させる3つの方法**

### 方法1: ワーカースレッド数を極端に減らす ⭐ 推奨

最も簡単で効果的な方法です。

#### ステップ1: application.ymlを編集

```yaml
# camel-app/src/main/resources/application.yml
server:
  port: 8080
  undertow:
    threads:
      io: 4
      worker: 5  # ← 200から5に変更
```

#### ステップ2: アプリケーションを再起動

```bash
cd /Users/kjin/mobills/observability/demo

# 既存プロセスを停止
PID=$(ps aux | grep -i "camel.*Application" | grep -v grep | awk '{print $2}')
if [ -n "$PID" ]; then kill $PID; fi

# 再ビルド＆起動
cd camel-app
mvn clean package -DskipTests
nohup mvn spring-boot:run > ../camel-app-queue-test.log 2>&1 &
```

#### ステップ3: 負荷テスト実行

```bash
cd /Users/kjin/mobills/observability/demo

# 既存のストレステスト（100並列）でも効果あり
./load-test-stress.sh

# または新しい極限テスト
./load-test-extreme-queue.sh  # これから作成
```

#### 期待される結果

```bash
# 5ワーカースレッドでは処理しきれない
undertow_worker_threads: 5.0
undertow_active_requests: 5.0  ← すべてのワーカーがビジー
undertow_request_queue_size: 95.0  ← 残りがキューに！
```

---

### 方法2: より大量の同時リクエスト ⭐ 推奨

ワーカースレッド数を減らさずに、負荷を増やす方法です。

#### 新しい負荷テストスクリプト

```bash
# 1000並列で30秒間負荷をかける
for i in {1..1000}; do
  curl -X POST http://localhost:8080/camel/api/orders \
    -H "Content-Type: application/json" \
    -d '{"id": "ORD-'$i'", "product": "Extreme", "quantity": 1, "price": 100}' \
    > /dev/null 2>&1 &
done

# すぐにメトリクスを確認
watch -n 1 'curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"'
```

---

### 方法3: 人為的な遅延を追加 ⭐⭐

アプリケーション内で処理を意図的に遅くする方法です。

#### アプローチA: REST DSLに遅延を追加

```java
// camel-app/src/main/java/com/example/demo/route/OrderApiRoute.java
rest("/api").description("Order REST API")
    .post("/orders")
    .consumes("application/json")
    .produces("application/json")
    .route()
    .routeId("create-order-route")
    .log("Received order: ${body}")
    .delay(500)  // ← 500ms遅延を追加
    .to("direct:processOrder")
    .end();
```

#### アプローチB: Filterに遅延を追加

```java
// 新規ファイル: camel-app/src/main/java/com/example/demo/config/DelayFilter.java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class DelayFilter implements Filter {
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        try {
            // リクエスト処理を意図的に遅延
            Thread.sleep(300);  // 300ms遅延
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        chain.doFilter(request, response);
    }
}
```

---

## 📊 **各方法の比較**

| 方法 | 難易度 | 効果 | 本番環境への影響 | 推奨度 |
|---|---|---|---|---|
| **ワーカー数削減** | ⭐ 簡単 | ⭐⭐⭐ 高 | ❌ 非推奨 | ⭐⭐⭐ |
| **大量リクエスト** | ⭐⭐ 中 | ⭐⭐ 中 | ✅ 安全 | ⭐⭐⭐ |
| **人為的遅延** | ⭐⭐⭐ 難 | ⭐⭐⭐ 高 | ⚠️ テスト専用 | ⭐⭐ |

---

## 🧪 **実践的なテストシナリオ**

### シナリオ1: 最小ワーカーテスト（最も簡単）

```bash
# 1. ワーカーを5に設定（application.yml編集）
# 2. アプリケーション再起動
# 3. 既存のストレステスト実行

./load-test-stress.sh

# 4. Grafanaで確認
# http://localhost:3000 → Undertow Monitoring Dashboard
```

**期待される結果:**
- Queue Size: 20-100
- Active Requests: 5（常に満杯）
- Worker Usage: 100%

### シナリオ2: 極限負荷テスト

```bash
# 1. ワーカー数: 200（デフォルト）
# 2. 極限負荷テスト実行

./load-test-extreme-queue.sh  # 1000並列

# 3. リアルタイム監視
watch -n 1 './thread_monitor.sh'
```

**期待される結果:**
- Queue Size: 50-200
- Active Requests: 180-200
- Worker Usage: 90-100%

---

## 📝 **注意事項**

### ⚠️ ワーカースレッド数を減らす場合

```yaml
# テスト環境でのみ使用
server:
  undertow:
    threads:
      worker: 5  # 本番環境では絶対に使わない
```

**警告:**
- 本番環境では使用しないでください
- テスト後は必ず元の値（200）に戻してください
- アプリケーションが非常に遅くなります

### ✅ 安全なテスト方法

1. **開発環境でのみ実施**
2. **テスト後は設定を元に戻す**
3. **監視ツールでリアルタイム確認**

---

## 🎯 **現在の実装の限界**

### 問題

```java
// UndertowMetricsConfig.java
private volatile int queueSize = 0;  // 常に0

public int getQueueSize() {
    return queueSize;  // 更新ロジックがない
}
```

現在の実装では、**実際のUndertowの内部キューサイズを取得していません**。

### 解決策（将来的な改善）

本物のUndertowメトリクスを取得するには、以下のいずれかが必要：

1. **Undertow内部APIを使用** (複雑)
2. **WebFilter/Interceptorでリクエストを追跡** (実装可能)
3. **Spring Boot 3.x用のカスタムメトリクス実装** (推奨)

---

## 💡 **推奨アプローチ**

最も簡単で効果的な方法：

### ステップ1: ワーカースレッドを5に設定

```bash
# application.ymlを編集
server:
  undertow:
    threads:
      worker: 5
```

### ステップ2: アプリケーション再起動

```bash
cd /Users/kjin/mobills/observability/demo
# 停止＆再起動コマンド（後述）
```

### ステップ3: ストレステスト実行

```bash
./load-test-stress.sh
```

### ステップ4: Grafanaで確認

```
http://localhost:3000
→ Undertow Monitoring Dashboard
→ Queue Sizeを確認
```

### ステップ5: 元に戻す

```bash
# application.ymlを編集
server:
  undertow:
    threads:
      worker: 200  # 元の値に戻す

# 再起動
```

---

## 🔧 **すぐに試せるコマンド**

### ワーカー数を5に変更してテスト

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# application.ymlを編集（worker: 5）
sed -i.bak 's/worker: 200/worker: 5/' src/main/resources/application.yml

# 再ビルド＆起動
mvn clean package -DskipTests
kill $(ps aux | grep 'camel.*Application' | grep -v grep | awk '{print $2}')
nohup mvn spring-boot:run > ../test-queue.log 2>&1 &

# 起動を待つ
sleep 10

# ストレステスト実行
cd ..
./load-test-stress.sh

# メトリクス確認
curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"

# 元に戻す
cd camel-app
mv src/main/resources/application.yml.bak src/main/resources/application.yml
```

---

**作成日**: 2025-10-20  
**トピック**: Undertowキューサイズのテスト方法  
**推奨**: ワーカースレッド数を5に減らして既存のストレステストを実行


