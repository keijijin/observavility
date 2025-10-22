# Tempoトレーシング - トラブルシューティングガイド

## 🎉 解決済み: トレースが表示されない問題

このドキュメントは、Tempoでトレースが表示されない問題の診断と解決方法を記録しています。

---

## 📋 問題の症状

Grafanaの「Explore」で「Tempo」データソースを選択し、「Run query」をクリックしてもトレース一覧が空でした。

```json
{
  "traces": [],
  "metrics": {
    "completedJobs": 1,
    "totalJobs": 1
  }
}
```

---

## 🔍 原因

### 1. プロトコルの不一致（初期の問題）

**問題:**
- `OpenTelemetryConfig.java`で`OtlpGrpcSpanExporter`（gRPCプロトコル）を使用
- `application.yml`では`http://localhost:4318`（HTTPプロトコル、ポート4318）を指定
- gRPCエクスポーターはHTTPエンドポイントに送信できない

**解決策:**
- `OtlpGrpcSpanExporter` → `OtlpHttpSpanExporter`に変更
- または、手動設定を削除してSpring BootとCamelの自動設定を使用

### 2. YAMLの重複キー（メインの問題）

**問題:**
```yaml
camel:
  springboot:
    name: camel-observability-demo
  ...

# 別の場所で
camel:  # ← 重複！
  opentelemetry:
    enabled: true
```

YAMLで同じキー（`camel:`）が2回定義され、パースエラーが発生。

**エラーメッセージ:**
```
org.yaml.snakeyaml.constructor.DuplicateKeyException: while constructing a mapping
```

**解決策:**
```yaml
camel:
  springboot:
    name: camel-observability-demo
  component:
    kafka:
      ...
  # 同じcamelキーの下にopentelemetryを配置
  opentelemetry:
    enabled: true
    endpoint: http://localhost:4318/v1/traces
    service-name: ${spring.application.name}
```

### 3. プロパティ名の形式（細かい問題）

**問題:**
```yaml
camel:
  opentelemetry:
    serviceName: xxx      # ← camelCase
    spanProcessor: batch   # ← 未サポートのプロパティ
    encoding: protobuf     # ← 未サポートのプロパティ
```

Camel OpenTelemetry Starterは`camelCase`ではなく`kebab-case`を使用。また、一部のプロパティはサポートされていない。

**解決策:**
```yaml
camel:
  opentelemetry:
    enabled: true
    endpoint: http://localhost:4318/v1/traces
    service-name: ${spring.application.name}  # ← kebab-case
```

### 4. 手動OpenTelemetry設定との競合

**問題:**
- `OpenTelemetryConfig.java`で手動設定
- `camel-opentelemetry-starter`の自動設定
- 両方が同時に動作して競合

**解決策:**
- 手動設定を削除（バックアップとして`.backup`に改名）
- Camel とSpring Bootの自動設定を使用

---

## ✅ 最終的な正しい設定

### pom.xml

```xml
<!-- Camel OpenTelemetry -->
<dependency>
    <groupId>org.apache.camel.springboot</groupId>
    <artifactId>camel-opentelemetry-starter</artifactId>
    <version>${camel.version}</version>
</dependency>

<!-- Micrometer Tracing (Spring Boot 3.x用) -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>

<!-- OpenTelemetry Exporter -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
```

### application.yml

```yaml
spring:
  application:
    name: camel-observability-demo

# Camel設定
camel:
  springboot:
    name: camel-observability-demo
  component:
    kafka:
      brokers: localhost:9092
      auto-offset-reset: earliest
      group-id: camel-demo-group
  # Camel OpenTelemetry設定（同じcamelキーの下）
  opentelemetry:
    enabled: true
    endpoint: http://localhost:4318/v1/traces
    service-name: ${spring.application.name}

# Spring Boot Actuator設定
management:
  tracing:
    sampling:
      probability: 1.0  # すべてのリクエストをトレース
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces
```

### OpenTelemetryConfig.java

**削除またはバックアップ**（自動設定を使用するため）

---

## 🧪 トレースの確認方法

### 1. ターミナルでTempoに直接クエリ

```bash
# 最新のトレース一覧を取得
curl -s "http://localhost:3200/api/search?limit=20" | jq '.'

# 特定のサービスでフィルタ
curl -s "http://localhost:3200/api/search?tags=service.name%3Dcamel-observability-demo&limit=10" | jq '.'

# 特定のトレースIDを取得
curl -s "http://localhost:3200/api/traces/{traceID}" | jq '.'
```

### 2. Grafanaで確認

1. **Grafanaにアクセス**: http://localhost:3000
2. **ログイン**: admin / admin
3. **左メニューから「Explore」をクリック**
4. **データソースで「Tempo」を選択**
5. **「Search」タブをクリック**
6. **「Run query」をクリック**
7. **トレース一覧が表示される** ✅
8. **任意のトレースをクリックして詳細を確認**

---

## 📊 期待される結果

### コマンドラインでの確認

```json
{
  "traces": [
    {
      "traceID": "b270f9fffd4f36a856c5956aff281db8",
      "rootServiceName": "camel-observability-demo",
      "rootTraceName": "orders",
      "startTimeUnixNano": "1760423243751344000",
      "durationMs": 729
    },
    {
      "traceID": "ee3a2dacd15e7992921f0072e7769540",
      "rootServiceName": "camel-observability-demo",
      "rootTraceName": "http post",
      "startTimeUnixNano": "1760423243747087000",
      "durationMs": 4
    }
  ],
  "metrics": {
    "inspectedTraces": 15,
    "inspectedBytes": "67021",
    "completedJobs": 1,
    "totalJobs": 1
  }
}
```

### Grafanaでの表示

- **トレース一覧**: 各リクエストがリスト形式で表示
- **サービス名**: `camel-observability-demo`
- **トレース名**: `orders`, `http post`, `http get /actuator/health`など
- **期間**: 各トレースの処理時間（ミリ秒）

---

## 🔍 トラブルシューティング手順

### ステップ1: Tempoの状態確認

```bash
# Tempoコンテナが起動しているか
podman ps | grep tempo

# Tempoのログ確認
podman logs tempo --tail 50

# Tempoのヘルスチェック
curl http://localhost:3200/ready
```

**期待される結果:**
- コンテナが「Up」状態
- ログにエラーがない
- `/ready`が成功応答（または"Ingester not ready"は正常）

### ステップ2: アプリケーションの状態確認

```bash
# アプリケーションが起動しているか
curl http://localhost:8080/actuator/health

# 起動ログでOpenTelemetry初期化を確認
grep -i "opentelemetry\|tracing" camel-app-startup.log
```

**期待される結果:**
- ヘルスチェックが`"UP"`
- エラーログがない

### ステップ3: YAMLの構文確認

```bash
# YAMLファイルの構文チェック
python3 -c "import yaml; yaml.safe_load(open('src/main/resources/application.yml'))" 2>&1

# または
ruby -ryaml -e "YAML.load_file('src/main/resources/application.yml')" 2>&1
```

**期待される結果:**
- エラーなし
- 特に「duplicate key」や「mapping」エラーがないこと

### ステップ4: トレースデータの生成

```bash
# テストリクエストを送信
curl -X POST http://localhost:8080/camel/api/orders \
  -H "Content-Type: application/json" \
  -d '{"orderId":"TEST-001","product":"TestProduct","quantity":1}'

# 数秒待ってからTempoで確認
sleep 5
curl -s "http://localhost:3200/api/search?limit=10" | jq '.traces | length'
```

**期待される結果:**
- リクエストが成功（200 OK）
- トレース数が0より大きい

### ステップ5: ネットワーク接続確認

```bash
# アプリからTempoへの接続確認
# （アプリコンテナ内から実行する場合）
curl -v http://localhost:4318/v1/traces

# ポートが開いているか
lsof -i :4318 || netstat -an | grep 4318
```

---

## 🛠️ よくある問題と解決策

### 問題1: `DuplicateKeyException`

**症状:**
```
org.yaml.snakeyaml.constructor.DuplicateKeyException
```

**解決:**
- `application.yml`で同じキーが複数回定義されていないか確認
- 特に`camel:`、`spring:`、`management:`などのトップレベルキー

### 問題2: `UnsatisfiedDependencyException`

**症状:**
```
Error creating bean with name 'openTelemetryEventNotifier'
Could not bind properties to 'OpenTelemetryConfigurationProperties'
```

**解決:**
- プロパティ名を`kebab-case`に変更（例: `serviceName` → `service-name`）
- サポートされていないプロパティを削除
- 手動設定を削除して自動設定を使用

### 問題3: トレースは送信されているがGrafanaに表示されない

**症状:**
- Tempoログに`inspectedTraces: 0`
- またはGrafanaで「No data」

**解決:**
- Grafanaのデータソース設定を確認:
  - URL: `http://tempo:3200`（コンテナ内）または`http://localhost:3200`（ホストから）
- 時間範囲を確認（最近のデータのみ）
- Grafanaを再起動: `podman restart grafana`

### 問題4: `Connection refused`

**症状:**
```
Failed to export spans. Server responded with gRPC status code 14
```

**解決:**
- Tempoが起動しているか確認
- エンドポイントのポート番号を確認（4317=gRPC, 4318=HTTP）
- プロトコル（gRPC/HTTP）とポートが一致しているか確認

---

## 📚 参考資料

### 公式ドキュメント

- [Apache Camel OpenTelemetry](https://camel.apache.org/components/latest/opentelemetry.html)
- [Spring Boot Actuator - Observability](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.observability)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry](https://opentelemetry.io/docs/)

### 設定例

- [Camel OpenTelemetry Starter](https://github.com/apache/camel-spring-boot/tree/main/components-starter/camel-opentelemetry-starter)
- [Spring Boot Micrometer Tracing](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.micrometer-tracing)

---

## ✅ チェックリスト

デプロイ前に以下を確認:

- [ ] `pom.xml`に必要な依存関係がすべて含まれている
  - [ ] `camel-opentelemetry-starter`
  - [ ] `micrometer-tracing-bridge-otel`
  - [ ] `opentelemetry-exporter-otlp`
- [ ] `application.yml`の構文が正しい
  - [ ] YAMLキーの重複がない
  - [ ] プロパティ名が`kebab-case`
  - [ ] エンドポイントURLが正しい（`http://localhost:4318/v1/traces`）
- [ ] 手動OpenTelemetry設定を削除または無効化
- [ ] Tempoコンテナが起動している
- [ ] ネットワーク接続が確立されている
- [ ] サンプリング確率が適切（開発時は`1.0`、本番では`0.1`など）

---

## 🎉 成功の確認

以下が確認できれば成功です：

1. ✅ アプリケーションが正常に起動
2. ✅ エラーログがない
3. ✅ Tempoにトレースデータが保存される
4. ✅ GrafanaでTempoからトレースを検索・表示できる
5. ✅ トレース詳細でスパン（span）階層が確認できる

---

このガイドを使って、オブザーバビリティ環境を正常に動作させることができます！🚀



