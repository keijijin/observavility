# Lokiログ集約 - トラブルシューティングガイド

## 📖 概要

このドキュメントは、Lokiでログが表示されない問題の診断と解決方法を記録しています。

---

## 🚀 クイックスタート: 接続テスト

まず、Loki接続テストスクリプトを実行して問題を診断します：

```bash
cd demo
./test-loki-connection.sh
```

このスクリプトは以下を自動的にチェックします：
- Lokiサービスの稼働状態
- Lokiへのログ送信テスト
- ログクエリの実行テスト
- Camelアプリケーションのログ確認

---

## 📋 よくある問題の症状

### 症状1: "No data" が表示される

GrafanaのExploreで「Loki」データソースを選択してクエリを実行しても、ログが表示されない。

```
No data
```

### 症状2: ログファイルは生成されているがLokiで見えない

アプリケーションのログファイル（`logs/application.log`）は生成されているが、Grafanaで検索できない。

### 症状3: "Connection refused" エラー

アプリケーションログに以下のエラーが表示される：

```
Failed to send log batch to Loki: Connection refused
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
    <springProperty scope="context" name="appName" source="spring.application.name"/>

    <!-- Loki Appender -->
    <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
        <http>
            <url>${LOKI_URL:-http://localhost:3100/loki/api/v1/push}</url>
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
                      "trace_id":"%mdc{traceId}",
                      "span_id":"%mdc{spanId}"
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
        <appender-ref ref="JSON_FILE"/>
        <appender-ref ref="TEXT_FILE"/>
    </root>
</configuration>
```

**重要なポイント:**
- **LOKI_URL**: 環境変数で上書き可能（デフォルト: `http://localhost:3100/loki/api/v1/push`）
- **ラベル**: `app`, `host`, `level` を設定（Grafanaでのフィルタリングに使用）
- **メッセージ**: JSON形式で構造化ログ
- **trace_id/span_id**: MDC（Mapped Diagnostic Context）経由でトレースとログを連携
- **非同期**: パフォーマンスへの影響を最小化
- **ファイル出力**: Lokiへの送信失敗時のバックアップとして、JSON/テキスト形式でもファイルに出力

### ステップ3: アプリケーションを起動

**方法1: 専用スクリプトを使用（推奨）**

```bash
cd camel-app
./run-local.sh
```

このスクリプトは以下を自動的に実行します：
- ログディレクトリの作成
- 環境変数（LOG_PATH, LOKI_URL）の設定
- アプリケーションのビルドと起動

**方法2: 手動起動**

```bash
cd camel-app
mkdir -p logs
export LOG_PATH="$(pwd)/logs"
export LOKI_URL="http://localhost:3100/loki/api/v1/push"
mvn clean spring-boot:run
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

**原因:**
1. Lokiにログが送信されていない
2. Grafanaのデータソース設定が正しくない
3. 時間範囲が適切でない
4. ラベル名が間違っている

**解決策:**

**ステップ1: 接続テストスクリプトを実行**
```bash
cd demo
./test-loki-connection.sh
```

**ステップ2: 時間範囲を確認**
- Grafanaの右上の時間範囲を「Last 15 minutes」または「Last 1 hour」に設定

**ステップ3: ラベル名を確認**
```bash
# 利用可能なラベルを確認
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.'

# appラベルの値を確認
curl -s "http://localhost:3100/loki/api/v1/label/app/values" | jq '.'
```

**ステップ4: ログを生成**
```bash
# テストリクエストを送信してログを生成
curl -X POST http://localhost:8080/camel/api/orders \
  -H "Content-Type: application/json" \
  -d '{"orderId":"TEST-001","product":"Test","quantity":1}'
```

**ステップ5: Grafanaのデータソースを確認**
- URL: `http://loki:3100`（コンテナ内からのアクセス）
- Access: `Server (default)` または `Proxy`

**ステップ6: Grafanaとデータソースを再起動**
```bash
cd demo
podman-compose restart grafana loki
```

### 問題2: "Connection refused"

**症状:**
アプリケーションログに以下のエラーが表示される：
```
Failed to send log batch to Loki
java.net.ConnectException: Connection refused
```

**原因:**
1. Lokiサービスが起動していない
2. Loki URLが間違っている
3. ファイアウォールがポートをブロックしている

**解決策:**

**ステップ1: Lokiの状態を確認**
```bash
# Lokiコンテナが起動しているか確認
podman ps | grep loki

# Lokiが起動していない場合
cd demo
podman-compose up -d loki
```

**ステップ2: Lokiのヘルスチェック**
```bash
curl http://localhost:3100/ready
# 期待される応答: "ready" または HTTP 200
```

**ステップ3: Loki URLを確認**

ローカル実行の場合、`logback-spring.xml`のLoki URLは：
```xml
<url>${LOKI_URL:-http://localhost:3100/loki/api/v1/push}</url>
```

環境変数で設定することも可能：
```bash
export LOKI_URL="http://localhost:3100/loki/api/v1/push"
```

**ステップ4: ネットワーク接続をテスト**
```bash
# Lokiへの接続をテスト
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"app":"test"},"values":[["'$(date +%s%N)'","test message"]]}]}'

# 期待される応答: HTTP 204 No Content
```

### 問題3: ログは送信されているがGrafanaに表示されない

**症状:**
- `curl`ではログが取得できるが、Grafanaでは "No data" が表示される
- 接続テストスクリプトではログが見つかる

**原因:**
1. Grafanaのデータソース設定が正しくない
2. Grafanaのデータソースキャッシュが古い
3. ブラウザキャッシュの問題

**解決策:**

**ステップ1: データソース設定を確認**

Grafanaの設定ファイル（`docker/grafana/provisioning/datasources/datasources.yml`）を確認：
```yaml
- name: Loki
  type: loki
  access: proxy
  uid: loki
  url: http://loki:3100
  editable: true
```

**ステップ2: Grafanaでデータソースをテスト**
1. Grafana管理画面: http://localhost:3000
2. メニュー → Configuration → Data sources
3. Loki を選択
4. 下部の「Test」ボタンをクリック
5. "Data source is working" が表示されることを確認

**ステップ3: Grafanaを再起動**
```bash
cd demo
podman-compose restart grafana

# または完全に再作成
podman-compose stop grafana
podman-compose rm -f grafana
podman-compose up -d grafana
```

**ステップ4: ブラウザキャッシュをクリア**
- ハードリロード: Ctrl+Shift+R（Windows/Linux）または Cmd+Shift+R（Mac）
- または別のブラウザで試す

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

### docker-compose.yml（podman-compose用）に追加

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

### デプロイ前の確認

- [ ] `pom.xml`にLoki appender依存関係が含まれている
- [ ] `logback-spring.xml`にLoki appenderが設定されている
- [ ] ラベル設定が正しい（`app`, `host`, `level`）
- [ ] Lokiコンテナが起動している
- [ ] ネットワーク接続が確立されている
- [ ] Grafanaのデータソース設定が正しい（uid: loki）
- [ ] 時間範囲が適切に設定されている
- [ ] ログディレクトリが存在する（`logs/`）

### トラブルシューティング時の確認

1. **接続テストを実行**
```bash
cd demo
./test-loki-connection.sh
```

2. **Lokiの状態確認**
```bash
podman ps | grep loki
curl http://localhost:3100/ready
```

3. **ログファイルの確認**
```bash
# ローカルログファイルが生成されているか
ls -lh demo/camel-app/logs/

# 最新のログを確認
tail -f demo/camel-app/logs/application.log
```

4. **Loki4jのログを確認**
```bash
# アプリケーションログからLoki関連のエラーを検索
grep -i "loki4j" demo/camel-app/logs/application.log
```

5. **Grafanaで確認**
- データソースのテストが成功するか
- 時間範囲が適切か（Last 15 minutes など）
- クエリ構文が正しいか

---

## 🎉 成功の確認

以下が確認できれば成功です：

### 1. ✅ ローカルログファイルの生成
```bash
ls -lh demo/camel-app/logs/
# 期待: application.log と application.json が存在
```

### 2. ✅ Lokiへの接続成功
```bash
cd demo
./test-loki-connection.sh
# すべてのチェックが✅で完了
```

### 3. ✅ Lokiにラベルが存在
```bash
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.'
# "app", "host", "level" が含まれる
```

### 4. ✅ ログデータが取得できる
```bash
curl -s "http://localhost:3100/loki/api/v1/label/app/values" | jq '.'
# "camel-observability-demo" が含まれる
```

### 5. ✅ Grafanaでログが表示される
- Grafana Explore: http://localhost:3000/explore
- データソース: Loki
- クエリ: `{app="camel-observability-demo"}`
- ログエントリが時系列で表示される

### 6. ✅ JSON形式のログが正しくパースされる
```logql
{app="camel-observability-demo"} | json
```
- `level`, `class`, `thread`, `message`, `trace_id`, `span_id` フィールドが表示される

### 7. ✅ トレースIDでログとトレースが連携できる
- Grafana Explore でログを表示
- trace_id をクリック
- Tempoのトレース詳細画面に遷移

---

## 📈 パフォーマンスの確認

正常に動作している場合の期待値：

- **ログ送信レイテンシ**: < 100ms
- **Grafanaクエリ応答時間**: < 2秒
- **アプリケーションへの影響**: 最小限（非同期送信のため）

```bash
# Lokiのメトリクスを確認
curl -s http://localhost:3100/metrics | grep loki_ingester
```

---

## 🔗 参考リンク

- [Loki公式ドキュメント](https://grafana.com/docs/loki/latest/)
- [Loki4j GitHub](https://github.com/loki4j/loki-logback-appender)
- [LogQL クエリ言語](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)
- [ログ設定ガイド](LOGGING_GUIDE.md) - ローカルログファイルの設定と確認方法

---

## 📝 まとめ

### 問題の主な原因

1. **ログファイルが見えない**
   - ログディレクトリが作成されていない
   - ログパスが相対パスで、実行ディレクトリに依存していた
   - 解決: `LOG_PATH` 環境変数で制御可能に変更

2. **Grafana Lokiでログが見えない**
   - Lokiにログが送信されていない
   - Grafanaのデータソース設定に uid が設定されていなかった
   - Lokiの設定制限が厳しすぎた
   - 解決: データソース設定の改善、Loki設定の緩和

### 改善された点

✅ **ログファイル出力**
- プレーンテキスト形式: `logs/application.log`（読みやすい）
- JSON形式: `logs/application.json`（分析用）
- 日次ローテーション（7日間保持）

✅ **Loki統合**
- 環境変数でLoki URLを設定可能
- MDC経由でトレースIDを自動連携
- 非同期送信でパフォーマンス影響を最小化

✅ **トラブルシューティングツール**
- `run-local.sh`: アプリケーション起動スクリプト
- `test-loki-connection.sh`: Loki接続テストスクリプト
- 詳細なドキュメント

### クイックリファレンス

**アプリケーション起動:**
```bash
cd demo/camel-app
./run-local.sh
```

**Loki接続テスト:**
```bash
cd demo
./test-loki-connection.sh
```

**ログファイル確認:**
```bash
tail -f demo/camel-app/logs/application.log
```

**Grafanaでログ検索:**
```logql
{app="camel-observability-demo"}
{app="camel-observability-demo"} |= "ERROR"
{app="camel-observability-demo"} | json | trace_id="YOUR_TRACE_ID"
```

---

このガイドを使って、Lokiでログを正常に収集・表示できます！🚀



