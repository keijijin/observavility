# プロジェクト構造

```
demo/
├── README.md                          # 詳細な手順書
├── QUICKSTART.md                      # クイックスタートガイド
├── PROJECT_STRUCTURE.md               # このファイル
├── docker-compose.yml                 # Podman Compose設定（Docker Compose互換）
├── start-demo.sh                      # 起動スクリプト
├── stop-demo.sh                       # 停止スクリプト
│
├── camel-app/                         # Spring Boot + Camel アプリケーション
│   ├── pom.xml                        # Maven設定
│   ├── .gitignore
│   ├── logs/                          # ログファイル出力先
│   └── src/
│       └── main/
│           ├── java/com/example/demo/
│           │   ├── CamelObservabilityDemoApplication.java  # メインクラス
│           │   ├── config/
│           │   │   └── OpenTelemetryConfig.java            # OpenTelemetry設定
│           │   ├── model/
│           │   │   └── Order.java                          # オーダーモデル
│           │   └── route/
│           │       ├── OrderProducerRoute.java             # Kafkaへメッセージ送信
│           │       ├── OrderConsumerRoute.java             # Kafkaからメッセージ受信・処理
│           │       └── HealthCheckRoute.java               # ヘルスチェックAPI
│           └── resources/
│               ├── application.yml                         # アプリケーション設定
│               └── logback-spring.xml                      # ログ設定
│
└── docker/                            # コンテナ関連設定（Podman/Docker両対応）
    ├── prometheus/
    │   └── prometheus.yml             # Prometheus設定（メトリクス収集）
    ├── tempo/
    │   └── tempo.yaml                 # Tempo設定（トレース収集）
    ├── loki/
    │   └── loki-config.yaml           # Loki設定（ログ収集）
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── datasources.yml    # データソース自動設定
            └── dashboards/
                ├── dashboards.yml     # ダッシュボードプロバイダー設定
                └── camel-dashboard.json  # Camelダッシュボード定義
```

## 主要コンポーネント

### 📦 Camelアプリケーション

| ファイル | 役割 |
|---------|------|
| `OrderProducerRoute.java` | REST APIとタイマーでオーダーを生成し、Kafkaに送信 |
| `OrderConsumerRoute.java` | Kafkaからオーダーを受信し、3段階の処理フロー（バリデーション→支払い→配送）を実行 |
| `HealthCheckRoute.java` | ヘルスチェックとメトリクス情報のAPI |
| `OpenTelemetryConfig.java` | 分散トレーシングの設定 |
| `application.yml` | Camel、Kafka、メトリクス、トレースの統合設定 |
| `logback-spring.xml` | 構造化ログ（JSON形式）の設定 |

### 🐳 Dockerサービス

| サービス | ポート | 役割 |
|---------|-------|------|
| **zookeeper** | 2181 | Kafkaの調整サービス |
| **kafka** | 9092 | メッセージングプラットフォーム |
| **prometheus** | 9090 | メトリクス収集・保存 |
| **tempo** | 3200, 4317 | トレース収集・保存 |
| **loki** | 3100 | ログ収集・保存 |
| **grafana** | 3000 | 可視化ダッシュボード |

### 📊 オブザーバビリティデータフロー

```
Camelアプリ
    │
    ├─[メトリクス]─► Micrometer ─► Prometheus ─► Grafana
    │
    ├─[トレース]───► OpenTelemetry ─► Tempo ─► Grafana
    │
    └─[ログ]───────► Logback (JSON) ─► ファイル ─(手動)─► Loki ─► Grafana
```

## 🔧 カスタマイズポイント

### メトリクスを追加する

`OrderConsumerRoute.java` にカスタムメトリクスを追加：

```java
@Autowired
private MeterRegistry meterRegistry;

// カウンターの例
meterRegistry.counter("orders.processed", "status", order.getStatus()).increment();
```

### トレースにタグを追加

```java
Span span = tracer.spanBuilder("custom-operation").startSpan();
span.setAttribute("order.id", orderId);
// ... 処理 ...
span.end();
```

### ログにカスタムフィールドを追加

```java
MDC.put("order_id", orderId);
log.info("Processing order");
MDC.remove("order_id");
```

## 📖 関連ドキュメント

- [README.md](README.md) - 詳細な手順とトラブルシューティング
- [QUICKSTART.md](QUICKSTART.md) - 最速で始める手順
- [API_ENDPOINTS.md](API_ENDPOINTS.md) - APIエンドポイント一覧
- [PODMAN_NOTES.md](PODMAN_NOTES.md) - Podman使用時の注意事項

