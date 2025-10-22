# ログ設定ガイド

## 概要

Camel Observabilityデモアプリケーションは、複数の形式でログを出力します：

1. **コンソール出力** - 開発・デバッグ用
2. **プレーンテキストファイル** - 人間が読みやすい形式（`application.log`）
3. **JSON形式ファイル** - 構造化ログ、分析用（`application.json`）
4. **Loki** - 集中ログ管理システムへの送信

## ログファイルの場所

### ローカル実行時

デフォルトでは、ログファイルは以下の場所に出力されます：

```
demo/camel-app/logs/
├── application.log              # プレーンテキスト形式
├── application.json             # JSON形式
├── application.2024-10-21.log   # 日次ローテーション（テキスト）
└── application.2024-10-21.json  # 日次ローテーション（JSON）
```

### ログファイルの確認方法

```bash
# 最新のログをリアルタイムで確認
tail -f demo/camel-app/logs/application.log

# JSON形式のログを整形して表示
cat demo/camel-app/logs/application.json | jq '.'

# 特定のトレースIDでフィルタリング
grep "traceId" demo/camel-app/logs/application.log

# エラーログのみ表示
grep "ERROR" demo/camel-app/logs/application.log
```

## ローカルでの起動方法

### 方法1: 専用スクリプトを使用（推奨）

```bash
cd demo/camel-app
./run-local.sh
```

このスクリプトは以下を自動的に行います：
- ログディレクトリの作成
- 環境変数の設定
- アプリケーションのビルドと起動

### 方法2: 手動起動

```bash
cd demo/camel-app

# ログディレクトリを作成
mkdir -p logs

# 環境変数を設定してアプリケーション起動
export LOG_PATH="$(pwd)/logs"
mvn clean spring-boot:run
```

### 方法3: カスタムログパスを指定

```bash
cd demo/camel-app

# 任意の場所をログディレクトリとして指定
export LOG_PATH="/var/log/camel-app"
mkdir -p $LOG_PATH
mvn spring-boot:run
```

## ログレベルの設定

### 実行時に変更

```bash
# デバッグレベルで起動
mvn spring-boot:run -Dspring-boot.run.arguments="--logging.level.com.example.demo=DEBUG"

# 特定のパッケージのみデバッグ
mvn spring-boot:run -Dspring-boot.run.arguments="--logging.level.org.apache.camel=DEBUG"
```

### application.ymlで永続的に変更

`src/main/resources/application.yml`を編集：

```yaml
logging:
  level:
    root: INFO
    com.example.demo: DEBUG      # アプリケーションログ
    org.apache.camel: DEBUG      # Camelログ
    org.apache.kafka: INFO       # Kafkaログ
```

## ログフォーマット

### プレーンテキスト形式 (application.log)

```
2024-10-21 10:30:45.123 [http-nio-8080-exec-1] INFO  [abc123,def456] c.e.d.route.OrderProducerRoute - Order created: Order(orderId=ORD-001)
```

フォーマット：
- 日時: `2024-10-21 10:30:45.123`
- スレッド: `[http-nio-8080-exec-1]`
- ログレベル: `INFO`
- トレース情報: `[traceId,spanId]`
- ロガー名: `c.e.d.route.OrderProducerRoute`
- メッセージ: `Order created: ...`

### JSON形式 (application.json)

```json
{
  "@timestamp": "2024-10-21T10:30:45.123+09:00",
  "level": "INFO",
  "thread_name": "http-nio-8080-exec-1",
  "logger_name": "com.example.demo.route.OrderProducerRoute",
  "message": "Order created: Order(orderId=ORD-001)",
  "app": "camel-observability-demo",
  "traceId": "abc123",
  "spanId": "def456"
}
```

## Lokiとの連携

ログは自動的にLokiに送信されます。Grafanaから確認できます：

1. Grafanaにアクセス: http://localhost:3000
2. 「Explore」メニューを選択
3. データソースで「Loki」を選択
4. クエリ例：

```logql
# アプリケーション全体のログ
{app="camel-observability-demo"}

# エラーログのみ
{app="camel-observability-demo"} |= "ERROR"

# 特定のトレースIDを検索
{app="camel-observability-demo"} | json | trace_id="abc123"

# 特定のルートのログ
{app="camel-observability-demo"} |= "OrderProducerRoute"
```

## トラブルシューティング

### ログファイルが作成されない

**原因**: ログディレクトリが存在しない、または書き込み権限がない

**解決策**:
```bash
cd demo/camel-app
mkdir -p logs
chmod 755 logs
```

### Lokiにログが送信されない

**原因1**: Lokiサービスが起動していない

**解決策**:
```bash
cd demo
podman-compose ps | grep loki
# Lokiが起動していなければ
podman-compose up -d loki
```

**原因2**: Loki URLが正しくない

**解決策**:
```bash
# 環境変数で正しいURLを設定
export LOKI_URL="http://localhost:3100/loki/api/v1/push"
```

### ログレベルが反映されない

**原因**: logback-spring.xmlまたはapplication.ymlの設定が正しくない

**解決策**:
1. アプリケーションを再起動
2. キャッシュをクリア: `mvn clean`
3. 設定ファイルの構文エラーを確認

### JSON形式のログが読みにくい

**解決策**: `jq`コマンドを使用して整形

```bash
# jqをインストール（macOS）
brew install jq

# ログを整形して表示
tail -f logs/application.json | jq '.'

# 特定のフィールドのみ表示
cat logs/application.json | jq '{timestamp: .["@timestamp"], level, message}'
```

## ログローテーション

ログファイルは自動的にローテーションされます：

- **ローテーション周期**: 日次（毎日0時）
- **保持期間**: 7日間
- **ファイル名形式**: `application.YYYY-MM-DD.log`

古いログファイルは7日後に自動的に削除されます。

## Docker/Podmanコンテナでの実行

コンテナで実行する場合、ログディレクトリをボリュームマウントすることを推奨します：

```bash
podman run -d \
  -p 8080:8080 \
  -v $(pwd)/logs:/app/logs:Z \
  -e LOG_PATH=/app/logs \
  camel-observability-demo:latest
```

## ログ分析のベストプラクティス

### 1. トレースIDでログを追跡

```bash
# トレースIDを取得（APIレスポンスヘッダーから）
TRACE_ID="abc123"

# そのトレースIDに関連するすべてのログを表示
grep "$TRACE_ID" logs/application.log
```

### 2. エラー発生時の前後のログを確認

```bash
# エラー行と前後5行を表示
grep -C 5 "ERROR" logs/application.log
```

### 3. パフォーマンス分析

```bash
# 処理時間が長いリクエストを検索
grep "took.*ms" logs/application.log | awk '{print $NF}' | sort -n | tail -10
```

### 4. JSON形式でのクエリ

```bash
# 特定のトレースIDのログをJSON形式で取得
cat logs/application.json | jq 'select(.traceId == "abc123")'

# エラーレベルのログをカウント
cat logs/application.json | jq 'select(.level == "ERROR")' | wc -l
```

## 設定ファイルの場所

- **Logback設定**: `src/main/resources/logback-spring.xml`
- **アプリケーション設定**: `src/main/resources/application.yml`

設定を変更した場合は、アプリケーションを再起動してください。

## 関連ドキュメント

- [Grafana設定ガイド](GRAFANA_SETUP.md)
- [Lokiトラブルシューティング](LOKI_TROUBLESHOOTING.md)
- [トレースID検索ガイド](TRACE_ID_SEARCH_GUIDE.md)

