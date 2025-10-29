# trace_id問題の解決 - 完全ガイド

## 🎉 解決済み

ログにtrace_idが含まれるようになりました！

---

## 📋 問題の症状

Lokiのログにtrace_idフィールドは存在するが、値が空文字列でした。

```json
{
  "level": "INFO",
  "message": "オーダーを生成しました",
  "trace_id": "",  // ← 空！
  "span_id": ""
}
```

---

## 🔍 原因

**WebFilterの実行順序の問題**

1. Spring Boot 3.xのMicrometer Tracingは、HTTPリクエストごとに自動的にトレーシングスパンを作成
2. しかし、カスタムFilterが`@Order(Ordered.HIGHEST_PRECEDENCE)`で設定されていたため、**トレーシングフィルターより前に実行**されていた
3. その時点では`tracer.currentSpan()`が`null`を返すため、MDCにtrace_idを設定できない

```
リクエスト
  ↓
[カスタムFilter] ← tracer.currentSpan() == null ❌
  ↓
[Tracingフィルター] ← スパンを作成
  ↓
アプリケーション処理
```

---

## ✅ 解決方法

### 修正内容

**`TracingMdcFilter.java`のOrderを変更:**

```java
// 修正前
@Order(Ordered.HIGHEST_PRECEDENCE)  // 最優先で実行 ❌

// 修正後
@Order(Ordered.LOWEST_PRECEDENCE - 1)  // トレーシングフィルターの後に実行 ✅
```

**修正後の実行順序:**

```
リクエスト
  ↓
[Tracingフィルター] ← スパンを作成
  ↓
[カスタムFilter] ← tracer.currentSpan() != null ✅
  ↓
アプリケーション処理（MDCにtrace_idが設定されている）
```

### 完全なコード

```java
package com.example.demo.config;

import io.micrometer.tracing.Tracer;
import jakarta.servlet.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@Order(Ordered.LOWEST_PRECEDENCE - 1)  // 重要！
public class TracingMdcFilter implements Filter {

    private static final Logger log = LoggerFactory.getLogger(TracingMdcFilter.class);
    private final Tracer tracer;

    public TracingMdcFilter(Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        updateMdc();
        
        try {
            chain.doFilter(request, response);
        } finally {
            updateMdc();  // Camelルート内でも使用するため再設定
        }
    }
    
    private void updateMdc() {
        if (tracer != null) {
            var span = tracer.currentSpan();
            
            if (span != null && span.context() != null) {
                String traceId = span.context().traceId();
                String spanId = span.context().spanId();
                
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
```

---

## 🧪 動作確認

### 1. デバッグログで確認

```bash
# アプリケーションログを確認
tail -f camel-app-startup.log | grep "TraceId:"

# 出力例：
# TraceId: f5c79311bdc18e5c3b0024ceb11e3e8e, SpanId: f2ad3df234aa72be
```

### 2. Lokiで確認

```bash
# trace_idが含まれるログの数を確認
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"} | json | trace_id != ""' \
  --data-urlencode "start=$(date -u -v-10M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=100" | jq '.data.result | map(.values | length) | add'

# 出力例：31（31件のログにtrace_idが含まれる）
```

### 3. Grafanaで確認

**ステップ1: Lokiでログを表示**
```logql
{app="camel-observability-demo"} | json | trace_id != ""
```

**ステップ2: ログ内容を確認**
```json
{
  "level": "INFO",
  "class": "c.e.demo.route.OrderProducerRoute",
  "message": "オーダーを生成しました: Order(orderId=ORD-abc123...",
  "trace_id": "f5c79311bdc18e5c3b0024ceb11e3e8e",  // ✅ 値が入っている！
  "span_id": "f2ad3df234aa72be"
}
```

**ステップ3: トレース連携を確認**
- ログ行の`trace_id`をクリック
- → Tempoのトレース詳細画面に自動遷移
- → 同じtrace_idのスパン階層が表示される

---

## 🎯 Grafanaでの使い方

### ログからトレースへ遷移

1. **Exploreで「Loki」を選択**
2. **クエリを実行:**
   ```logql
   {app="camel-observability-demo"} | json
   ```
3. **ログ一覧が表示される**
4. **任意のログ行を展開**
5. **`trace_id`フィールドの値をクリック**
6. **Tempoのトレース詳細が開く！** ✨

### トレースからログへ遷移

1. **Exploreで「Tempo」を選択**
2. **Search」タブで「Run query」**
3. **トレース一覧から任意のトレースをクリック**
4. **スパン詳細画面で「Logs for this span」をクリック**
5. **Lokiのログが開く！** ✨

---

## 📊 期待される結果

### コマンドライン

```bash
$ curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"} | json | trace_id != ""' \
  --data-urlencode "limit=5" | jq '.data.result[0].values[0][1]' | jq '{level, message: (.message[0:50]), trace_id, span_id}'

{
  "level": "INFO",
  "message": "オーダーを生成しました: Order(orderId=ORD-5cc30f40",
  "trace_id": "f5c79311bdc18e5c3b0024ceb11e3e8e",
  "span_id": "f2ad3df234aa72be"
}
```

### Grafana

- ✅ すべてのHTTPリクエストログにtrace_idが含まれる
- ✅ ログとトレースが相互にリンクされる
- ✅ ログ→トレース、トレース→ログの双方向遷移が可能

---

## 🔑 重要なポイント

### 1. Filterの順序

Spring Boot 3.xでは、以下のFilterが自動的に登録されます：

| Order | Filter | 説明 |
|-------|--------|------|
| `Ordered.HIGHEST_PRECEDENCE` | Security Filters | セキュリティ関連 |
| 中間 | **Tracing Filter** | スパンの作成 ⭐ |
| `Ordered.LOWEST_PRECEDENCE - 1` | **TracingMdcFilter** | MDC設定 ⭐ |
| `Ordered.LOWEST_PRECEDENCE` | Error Handling | エラーハンドリング |

**カスタムFilterは、トレーシングFilterより後に実行する必要がある！**

### 2. MDCキー名

Spring Boot 3.xのデフォルトMDCキー：
- `traceId` (小文字の'Id') ← `trace_id`ではない！
- `spanId` (小文字の'Id') ← `span_id`ではない！

**logback-spring.xmlでも`traceId`と`spanId`を使用:**
```xml
<pattern>
  {
    "trace_id":"%mdc{traceId}",  <!-- traceIdを使用 -->
    "span_id":"%mdc{spanId}"      <!-- spanIdを使用 -->
  }
</pattern>
```

### 3. application.ymlの設定

```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # 全リクエストをトレース（本番環境では0.1など）
    baggage:
      correlation:
        enabled: true  # MDC連携を有効化
```

---

## 🛠️ トラブルシューティング

### 問題1: trace_idがまだ空

**確認事項:**
```bash
# 1. Filterが正しく登録されているか
grep "TracingMdcFilter initialized" camel-app-startup.log

# 2. スパンが取得できているか
grep "Current span: true" camel-app-startup.log

# 3. trace_idの値が取得できているか
grep "TraceId:" camel-app-startup.log
```

**解決策:**
- Filterの`@Order`を確認
- `micrometer-tracing-bridge-otel`依存関係を確認
- `management.tracing.sampling.probability`が0でないことを確認

### 問題2: 一部のログにのみtrace_idが含まれる

**原因:**
- HTTPリクエスト外のログ（起動時、バックグラウンドタスクなど）にはtrace_idが含まれない

**これは正常な動作です！**

### 問題3: Grafanaでログからトレースに遷移できない

**確認事項:**
1. Grafanaのデータソース設定（Loki）
2. `tracesToLogs`設定が正しいか確認:
   ```yaml
   jsonData:
     tracesToLogs:
       datasourceUid: 'tempo'
       tags: ['trace_id']
   ```

---

## ✅ チェックリスト

- [ ] `TracingMdcFilter`が`@Order(Ordered.LOWEST_PRECEDENCE - 1)`で設定されている
- [ ] `logback-spring.xml`で`%mdc{traceId}`と`%mdc{spanId}`を使用
- [ ] `application.yml`で`management.tracing.sampling.probability: 1.0`
- [ ] `pom.xml`に`micrometer-tracing-bridge-otel`が含まれている
- [ ] Lokiでtrace_idが空でないログが確認できる
- [ ] GrafanaでログからトレースへのリンクI
が機能する

---

## 🎉 成功！

これで、ログとトレースが完全に統合されました：

✅ **メトリクス** (Prometheus) - システムの健全性  
✅ **トレース** (Tempo) - リクエストの流れ  
✅ **ログ** (Loki) - 詳細な診断情報  
✅ **統合** - ログ ↔ トレースの相互リンク

完全なオブザーバビリティが実現しました！🚀




