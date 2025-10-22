# Camel 4 オブザーバビリティデモ

このデモプロジェクトは、Apache Camel 4とSpring Bootを使用して、オブザーバビリティの3本柱（メトリクス、トレース、ログ）を体感できる実践的な環境です。

## 🎯 デモの目的

- **メトリクス**: PrometheusとGrafanaでCamelルートのパフォーマンスを可視化
- **トレース**: Tempoでリクエストの処理フローとボトルネックを特定
- **ログ**: Lokiで構造化ログを集約し、トレースIDで相関分析

## 📋 前提条件

以下のソフトウェアがインストールされている必要があります：

- Java 17以上
- Maven 3.6以上
- Podman 4.0以上
- podman-compose または podman compose プラグイン

### Podmanのインストール

**macOS:**
```bash
brew install podman
podman machine init
podman machine start
```

**Linux:**
```bash
# Fedora/RHEL/CentOS
sudo dnf install podman

# Ubuntu/Debian
sudo apt-get install podman
```

**Windows:**
[Podman for Windows](https://github.com/containers/podman/blob/main/docs/tutorials/podman-for-windows.md)

**podman-compose のインストール:**
```bash
pip3 install podman-compose
```

## 🏗️ アーキテクチャ

```
┌─────────────────┐
│  Camel App      │
│  (Port: 8080)   │
│  ┌───────────┐  │
│  │ Micrometer├──┼──► Prometheus (9090)
│  │OpenTelemetry│ │
│  │  Logback  │  │
│  └───────────┘  │
└────────┬────────┘
         │
    ┌────┴────┐
    │  Kafka  │ (9092)
    └─────────┘
         │
    ┌────┴────────────────┐
    │                     │
┌───▼────┐  ┌──────▼─────┐  ┌─────────┐
│ Tempo  │  │    Loki    │  │ Grafana │
│ (3200) │  │   (3100)   │  │ (3000)  │
└────────┘  └────────────┘  └─────────┘
```

## 🚀 クイックスタート

### 1. インフラ環境の起動

```bash
cd demo
# podman-compose を使用する場合
podman-compose up -d

# または podman compose プラグインを使用する場合
podman compose up -d
```

起動したサービスを確認：
```bash
# podman-compose の場合
podman-compose ps

# podman compose の場合
podman compose ps
```

すべてのコンテナが `Up` になっていることを確認してください。

### 2. アプリケーションのビルドと起動

```bash
cd camel-app
mvn clean install
mvn spring-boot:run
```

アプリケーションが正常に起動すると、以下のメッセージが表示されます：
```
Started CamelObservabilityDemoApplication in X.XXX seconds
```

### 3. 動作確認

#### ヘルスチェック
```bash
curl http://localhost:8080/camel/api/health
```

#### オーダーを手動で作成
```bash
curl -X POST http://localhost:8080/camel/api/orders
```

**エンドポイント一覧：**
- ヘルスチェック: `GET http://localhost:8080/camel/api/health`
- メトリクス情報: `GET http://localhost:8080/camel/api/metrics`
- オーダー作成: `POST http://localhost:8080/camel/api/orders`
- Actuatorメトリクス: `GET http://localhost:8080/actuator/prometheus`

アプリケーションは自動的に10秒ごとにオーダーを生成します。

## 📊 オブザーバビリティツールへのアクセス

### Grafana（ダッシュボード）
- URL: http://localhost:3000
- ユーザー名: `admin`
- パスワード: `admin`
- 初回ログイン後、パスワード変更をスキップできます

**推奨ダッシュボード**：
1. メイン画面で "Camel Observability Dashboard" を選択
2. データソースが自動的に設定されています

### Prometheus（メトリクス）
- URL: http://localhost:9090
- アプリケーションのメトリクスを確認：
  ```
  camel_exchanges_total
  camel_routes_running_routes
  http_server_requests_seconds_count
  ```

### Tempo（トレース）
- Grafana経由でアクセス：http://localhost:3000/explore
- データソースで "Tempo" を選択
- Search でトレースを検索

### Loki（ログ）
- Grafana経由でアクセス：http://localhost:3000/explore
- データソースで "Loki" を選択
- クエリ例：
  - 全ログ: `{app="camel-observability-demo"}`
  - エラーログ: `{app="camel-observability-demo"} |= "ERROR"`
  - トレースIDで検索: `{app="camel-observability-demo"} | json | trace_id="<32文字のID>"`
  
**💡 重要:** トレースIDで検索する場合、必ず `| json` パーサーを使用してください。

### Kafka UI（オプション）
Kafkaのメッセージを確認したい場合：
```bash
podman exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:29092 \
  --topic orders \
  --from-beginning
```

## 🔍 オブザーバビリティを体感する手順

### ステップ1: メトリクスで異常を検知

1. Grafanaにアクセス（http://localhost:3000）
2. "Camel Observability Dashboard" を開く
3. "Camel Routes - Message Rate" グラフでメッセージ処理レートを確認
4. "Camel Routes - Processing Time" でルートごとの処理時間を確認

**注目ポイント**：
- `payment-processing-route` の処理時間が他より長い（200-500ms）
- 約10%の確率でエラーが発生する設計

### ステップ2: トレースでボトルネックを特定

1. Grafana の Explore に移動（http://localhost:3000/explore）
2. データソースで "Tempo" を選択
3. "Search" タブで最近のトレースを検索
4. 処理時間が長いトレースをクリック

**確認できること**：
- リクエストの全体フロー
  - `order-consumer-route` → `validate-order-route` → `payment-processing-route` → `shipping-route`
- 各ステップの処理時間
- ボトルネックとなっている `payment-processing-route` の特定

### ステップ3: ログで根本原因を解明

1. Grafana の Explore で "Loki" を選択
2. エラーログを検索：
   ```logql
   {app="camel-observability-demo"} |= "ERROR"
   ```
3. または、トレースIDで検索（Tempoから32文字のトレースIDをコピー）：
   ```logql
   {app="camel-observability-demo"} | json | trace_id="<コピーした32文字のID>"
   ```

**確認できること**：
- トレースIDでログとトレースが紐付いている
- エラーの詳細メッセージ
- エラー発生時の処理フロー

**💡 LogQLクエリのポイント:**
- `|=` は文字列検索（生テキスト）
- `| json` の後は、JSONフィールドで検索（例: `trace_id`, `level`）
- トレースIDは必ず32文字（16進数）
- ダブルクォート (`"`) を使用（バッククォート `` ` `` や `'` は不可）

> 詳細ガイド: [LOKI_QUERY_FIXES.md](LOKI_QUERY_FIXES.md)

### ステップ4: 三本柱の連携を体験

1. Grafanaのダッシュボードで **エラー率の上昇** を確認（メトリクス）
2. 該当時間帯のトレースを検索し、**エラーが発生したルート** を特定（トレース）
3. トレースIDを使って **具体的なエラーメッセージ** を確認（ログ）

これがモダンな障害対応フローです！

## 📝 デモシナリオの詳細

### アプリケーションの処理フロー

1. **オーダー生成** (`OrderProducerRoute`)
   - REST APIまたはタイマーでオーダーを生成
   - Kafkaの `orders` トピックに送信

2. **オーダー消費** (`OrderConsumerRoute`)
   - Kafkaからオーダーを受信
   - バリデーション → 支払い → 配送の3ステップで処理

3. **意図的に追加された要素**
   - バリデーション: 50-200ms の処理時間
   - 支払い処理: **200-500ms の遅延**（ボトルネック）
   - 支払い処理: **10%の確率でエラー発生**
   - 配送処理: 100-300ms の処理時間

### 観測可能なメトリクス

- `camel_exchanges_total`: 処理されたメッセージ総数
- `camel_routes_running_routes`: 稼働中のルート数
- `camel_exchange_processing_seconds`: ルートごとの処理時間
- `http_server_requests_seconds_count`: HTTPリクエスト数

## 🛠️ トラブルシューティング

### アプリケーションがメトリクスをエクスポートしない

Prometheusの設定を確認：
```bash
curl http://localhost:8080/actuator/prometheus
```

メトリクスが表示されない場合、アプリケーションを再起動してください。

### Tempoにトレースが表示されない

1. アプリケーションのログで OpenTelemetry のエラーを確認
2. Tempoコンテナが正常に起動しているか確認：
   ```bash
   podman logs tempo
   ```
3. OTLPエンドポイントが正しいか確認（application.yml）

### Lokiにログが表示されない

1. ログファイルが生成されているか確認：
   ```bash
   ls -la camel-app/logs/
   ```
2. 現状、Lokiへのログ送信は Promtail や Fluent Bit などのログシッパーが必要です
   - 簡易版として、ファイルシステムのログを確認できます

### Podmanでhost.containers.internalが使えない

`docker/prometheus/prometheus.yml` の `host.containers.internal` を以下に変更：

**Mac/Windows (Podman Machine使用時):**
```yaml
- targets: ['host.containers.internal:8080']
```

**Linux:**
```yaml
- targets: ['localhost:8080']
```

または、ホストのIPアドレスを直接指定：
```yaml
- targets: ['192.168.x.x:8080']
```

**Podman Machineのトラブルシューティング:**
```bash
# Podman Machineが起動しているか確認
podman machine list

# 再起動
podman machine stop
podman machine start
```

## 🧹 クリーンアップ

### インフラ環境の停止

```bash
cd demo
# podman-compose を使用
podman-compose down

# または podman compose を使用
podman compose down
```

### データも含めてすべて削除

```bash
podman-compose down -v
# または
podman compose down -v
```

### Podman Machineの停止（Mac/Windows）

```bash
podman machine stop
```

## 🎓 オブザーバビリティ体験ガイド

負荷テストを使って、オブザーバビリティを実際に体験しましょう：

👉 **[OBSERVABILITY_EXPERIENCE.md](OBSERVABILITY_EXPERIENCE.md)** - 完全なステップバイステップガイド

このガイドでは以下を学べます：
- メトリクスで異常を検知する方法
- トレースでボトルネックを特定する方法
- ログで根本原因を解明する方法
- 三本柱を連携させた障害対応

**所要時間:** 約50分

## 📚 さらに学ぶために

### プロジェクト内のガイド

- **[OBSERVABILITY_EXPERIENCE.md](OBSERVABILITY_EXPERIENCE.md)** - オブザーバビリティ体験ガイド（推奨！）
- **[GRAFANA_HOWTO.md](GRAFANA_HOWTO.md)** - Grafana基本操作
- **[LOKI_QUERY_FIXES.md](LOKI_QUERY_FIXES.md)** - Lokiクエリのよくある間違いと修正方法
- **[TRACE_ID_SEARCH_GUIDE.md](TRACE_ID_SEARCH_GUIDE.md)** - トレースIDでログを検索する詳細ガイド
- **[LOAD_TESTING.md](LOAD_TESTING.md)** - 負荷テストガイド
- **[API_ENDPOINTS.md](API_ENDPOINTS.md)** - API仕様
- **[PODMAN_NOTES.md](PODMAN_NOTES.md)** - Podman使用のポイント

### 外部リソース

- [Apache Camel 4 Documentation](https://camel.apache.org/manual/latest/)
- [Micrometer Documentation](https://micrometer.io/docs)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)

### 拡張アイデア

1. **Promtail を追加してログをLokiに送信**
   ```yaml
   # docker-compose.yml（podman-compose用）に追加
   promtail:
     image: grafana/promtail:2.9.3
     volumes:
       - ./camel-app/logs:/logs:Z
       - ./docker/promtail:/etc/promtail:Z
     command: -config.file=/etc/promtail/config.yml
   ```
   注: `:Z` はSELinuxラベルを設定します（Linuxで推奨）

2. **アラート設定**
   - Prometheusでアラートルールを設定
   - Grafana でアラートを可視化

3. **複数のCamelアプリケーション**
   - マイクロサービス構成でトレースの威力を体験
   - サービス間のトレース伝播を確認

4. **カスタムメトリクス**
   - ビジネスメトリクスを追加
   - SLI/SLOの設定

## 🎓 まとめ

このデモで体験できたこと：

✅ **メトリクス**: システム全体の健康状態とパフォーマンス傾向の把握  
✅ **トレース**: リクエストフローとボトルネックの特定  
✅ **ログ**: 根本原因の詳細な調査  
✅ **三本柱の連携**: データ駆動型の効率的な障害対応

オブザーバビリティは、単なる監視ではなく、システムの「なぜ」を理解するための強力なアプローチです。

---

**質問や問題があれば、お気軽にお問い合わせください！** 🚀

