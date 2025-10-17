# Lokiログ集約 - トラブルシューティングガイド

## 🎉 解決済み: Lokiでログが表示されない問題

このドキュメントは、Lokiでログが表示されない問題の診断と解決方法を記録しています。

---

## 📋 問題の症状

GrafanaのExploreで「Loki」データソースを選択してクエリを実行しても、ログが表示されませんでした。

```
No data
```

---

## 🔍 原因

### メインの問題: ログ送信エージェントが設定されていない

**問題:**
- **Promtail**（Lokiへのログ転送エージェント）が設定されていない
- アプリケーションから直接Lokiにログを送信する設定がない
- ログは生成されているが、Lokiに到達していない

**Lokiアーキテクチャ:**
```
アプリケーション → Promtail → Loki → Grafana
                     ↑
                 (設定されていない！)
```

または

```
アプリケーション → Loki Appender → Loki → Grafana
                     ↑
              (Logback設定で実現)
```

---

## ✅ 解決方法

### 方法1: Loki Logback Appenderを使用（採用した方法）

**メリット:**
- 設定がシンプル
- 追加のコンテナ不要
- リアルタイムでログ送信
- トレースIDとの連携が容易

**デメリット:**
- アプリケーションに依存関係を追加
- Lokiへの送信失敗時にログが失われる可能性

### 方法2: Promtailを使用

**メリット:**
- アプリケーションと疎結合
- ファイルベースのログを収集
- 複数のアプリケーションから収集可能
- バッファリングとリトライ機能

**デメリット:**
- 追加のコンテナが必要
- 設定が複雑
- ファイルI/Oのオーバーヘッド

---

## 🛠️ 実装手順（Loki Logback Appender）

### ステップ1: pom.xmlに依存関係を追加

```xml
<!-- Loki Logback Appender -->
<dependency>
    <groupId>com.github.loki4j</groupId>
    <artifactId>loki-logback-appender</artifactId>
    <version>1.5.1</version>
</dependency>
```

### ステップ2: logback-spring.xmlを設定

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- Loki Appender -->
    <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
        <http>
            <url>http://localhost:3100/loki/api/v1/push</url>
        </http>
        <format>
            <label>
                <pattern>app=${appName:-camel-observability-demo},host=${HOSTNAME:-localhost},level=%level</pattern>
            </label>
            <message>
                <pattern>
                    {
                      "level":"%level",
                      "class":"%logger{36}",
                      "thread":"%thread",
                      "message": "%message",
                      "trace_id":"%X{trace_id:-}",
                      "span_id":"%X{span_id:-}"
                    }
                </pattern>
            </message>
            <sortByTime>true</sortByTime>
        </format>
    </appender>

    <!-- 非同期Lokiアペンダー（パフォーマンス向上） -->
    <appender name="ASYNC_LOKI" class="ch.qos.logback.classic.AsyncAppender">
        <queueSize>1024</queueSize>
        <discardingThreshold>0</discardingThreshold>
        <appender-ref ref="LOKI" />
    </appender>

    <!-- Root Logger -->
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="ASYNC_LOKI"/>
    </root>
</configuration>
```

**重要なポイント:**
- **ラベル**: `app`, `host`, `level` を設定（Grafanaでのフィルタリングに使用）
- **メッセージ**: JSON形式で構造化ログ
- **trace_id/span_id**: トレースとログの連携
- **非同期**: パフォーマンスへの影響を最小化

### ステップ3: アプリケーションを再起動

```bash
cd camel-app
mvn clean package -DskipTests
mvn spring-boot:run
```

---

## 🧪 ログの確認方法

### 1. ターミナルでLokiに直接クエリ

```bash
# ラベル一覧を確認
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.'

# appラベルの値を確認
curl -s "http://localhost:3100/loki/api/v1/label/app/values" | jq '.'

# ログストリーム数を確認
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"}' \
  --data-urlencode "start=$(date -u -v-10M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=10" | jq '.data.result | length'

# 実際のログ内容を確認
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="camel-observability-demo"} | json' \
  --data-urlencode "start=$(date -u -v-5M '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" \
  --data-urlencode "limit=5" | jq '.data.result[0].values[0:3]'
```

### 2. Grafanaで確認

#### 基本的な手順

1. **Grafanaにアクセス**: http://localhost:3000
2. **ログイン**: admin / admin
3. **左メニューから「Explore」をクリック**
4. **データソースで「Loki」を選択**
5. **クエリを入力**

#### おすすめのクエリ

**1. すべてのログを表示:**
```logql
{app="camel-observability-demo"}
```

**2. レベル別にフィルタ:**
```logql
{app="camel-observability-demo", level="ERROR"}
```

**3. JSON形式でパース:**
```logql
{app="camel-observability-demo"} | json
```

**4. 特定のメッセージを検索:**
```logql
{app="camel-observability-demo"} |= "Order"
```

**5. エラーログのみ:**
```logql
{app="camel-observability-demo"} | json | level="ERROR"
```

**6. トレースIDでフィルタ:**
```logql
{app="camel-observability-demo"} | json | trace_id="<trace_id>"
```

**7. レート計算（1分間のログ数）:**
```logql
rate({app="camel-observability-demo"}[1m])
```

**8. エラー数をカウント:**
```logql
sum(count_over_time({app="camel-observability-demo", level="ERROR"}[1m]))
```

---

## 📊 期待される結果

### コマンドラインでの確認

```bash
# ラベル確認
{
  "status": "success",
  "data": [
    "app",
    "host",
    "level"
  ]
}

# appラベルの値
{
  "status": "success",
  "data": [
    "camel-observability-demo"
  ]
}

# ログストリーム数
3  # または複数の数値
```

### Grafanaでの表示

- **ログ一覧**: 時系列で表示
- **レベル**: INFO, DEBUG, ERROR など色分けされる
- **構造化ログ**: JSON形式のフィールドが展開される
- **トレース連携**: trace_idをクリックしてTempoに遷移可能

---

## 🔍 トラブルシューティング手順

### ステップ1: Lokiの状態確認

```bash
# Lokiコンテナが起動しているか
podman ps | grep loki

# Lokiのログ確認
podman logs loki --tail 50

# Lokiのヘルスチェック
curl http://localhost:3100/ready
```

**期待される結果:**
- コンテナが「Up」状態
- ログにエラーがない
- `/ready`が成功応答（または"Ingester not ready"は一時的な正常状態）

### ステップ2: アプリケーションの状態確認

```bash
# アプリケーションが起動しているか
curl http://localhost:8080/actuator/health

# Loki appenderのログを確認
grep -i "loki" camel-app-startup.log
```

**期待される結果:**
- ヘルスチェックが`"UP"`
- Loki4jの初期化ログがある
- エラーログがない

### ステップ3: ネットワーク接続確認

```bash
# アプリからLokiへの接続確認
curl -v http://localhost:3100/loki/api/v1/push

# ポートが開いているか
lsof -i :3100 || netstat -an | grep 3100
```

### ステップ4: ログデータの生成

```bash
# テストリクエストを送信
curl -X POST http://localhost:8080/camel/api/orders \
  -H "Content-Type: application/json" \
  -d '{"orderId":"TEST-001","product":"TestProduct","quantity":1}'

# 数秒待ってからLokiで確認
sleep 5
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.data | length'
```

**期待される結果:**
- リクエストが成功（200 OK）
- ラベル数が0より大きい

---

## 🛠️ よくある問題と解決策

### 問題1: "No data" が表示される

**症状:**
- Grafanaで`{app="camel-observability-demo"}`を実行しても何も表示されない

**解決:**
1. **時間範囲を確認**: 右上の時間範囲を「Last 15 minutes」などに設定
2. **ラベル名を確認**: `curl -s "http://localhost:3100/loki/api/v1/label/app/values" | jq '.'`
3. **ログが送信されているか確認**: アプリケーションにリクエストを送る
4. **Grafanaのデータソースを確認**: Loki URL が`http://loki:3100`（コンテナ内）

### 問題2: "Connection refused"

**症状:**
```
Failed to send log batch to Loki
```

**解決:**
- Lokiが起動しているか確認
- `application.yml`または`logback-spring.xml`のLoki URLを確認
- Podmanのネットワーク設定を確認: `host.containers.internal`を使用

### 問題3: ログは送信されているがGrafanaに表示されない

**症状:**
- `curl`ではログが見えるがGrafanaでは見えない

**解決:**
- Grafanaのデータソース設定を確認:
  - URL: `http://loki:3100`（コンテナ間通信）
  - または`http://localhost:3100`（ホストから）
- Grafanaを再起動: `podman restart grafana`
- ブラウザのキャッシュをクリア

### 問題4: "Error parsing labels"

**症状:**
```
Error parsing labels: invalid label format
```

**解決:**
- `logback-spring.xml`のラベルパターンを確認
- ラベル名は英数字とアンダースコアのみ（ハイフン不可）
- 正しい形式: `app=myapp,host=localhost,level=INFO`

### 問題5: パフォーマンスが低下

**症状:**
- アプリケーションのレスポンスが遅い
- CPU使用率が高い

**解決:**
- **非同期アペンダーを使用**（既に設定済み）
- **ログレベルを調整**: `DEBUG` → `INFO`
- **サンプリングを導入**: すべてのログを送信しない
- **バッチサイズを調整**: `logback-spring.xml`で設定

---

## 📚 Promtailを使用する方法（代替案）

Promtailを使用したい場合の設定例:

### docker-compose.ymlに追加

```yaml
promtail:
  image: grafana/promtail:2.9.3
  container_name: promtail
  volumes:
    - ./docker/promtail/promtail-config.yaml:/etc/promtail/config.yaml
    - ../camel-app/logs:/logs
  command: -config.file=/etc/promtail/config.yaml
  depends_on:
    - loki
```

### promtail-config.yaml

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: camel-app
    static_configs:
      - targets:
          - localhost
        labels:
          job: camel-app
          app: camel-observability-demo
          __path__: /logs/application*.json

    pipeline_stages:
      - json:
          expressions:
            level: level
            message: message
            trace_id: trace_id
      - labels:
          level:
```

---

## ✅ チェックリスト

デプロイ前に以下を確認:

- [ ] `pom.xml`にLoki appender依存関係が含まれている
- [ ] `logback-spring.xml`にLoki appenderが設定されている
- [ ] ラベル設定が正しい（`app`, `host`, `level`）
- [ ] Lokiコンテナが起動している
- [ ] ネットワーク接続が確立されている
- [ ] Grafanaのデータソース設定が正しい
- [ ] 時間範囲が適切に設定されている

---

## 🎉 成功の確認

以下が確認できれば成功です：

1. ✅ アプリケーションが正常に起動
2. ✅ Lokiにラベルが存在（`app`, `host`, `level`）
3. ✅ `curl`でログデータが取得できる
4. ✅ GrafanaでLokiからログを検索・表示できる
5. ✅ JSON形式のログが正しくパースされる
6. ✅ トレースIDでログとトレースが連携できる

---

## 🔗 参考リンク

- [Loki公式ドキュメント](https://grafana.com/docs/loki/latest/)
- [Loki4j GitHub](https://github.com/loki4j/loki-logback-appender)
- [LogQL クエリ言語](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)

---

このガイドを使って、Lokiでログを正常に収集・表示できます！🚀


