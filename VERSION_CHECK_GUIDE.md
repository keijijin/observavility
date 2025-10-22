# 🔍 バージョン情報の確認方法

## 📊 GrafanaでCamelバージョンを確認する方法

### 方法1: Actuator Infoエンドポイント（最も簡単）

#### ブラウザで確認

```
http://localhost:8080/actuator/info
```

#### コマンドラインで確認

```bash
curl -s http://localhost:8080/actuator/info | jq '.'
```

**出力例:**
```json
{
  "app": {
    "name": "camel-observability-demo",
    "description": "Apache Camel 4 Observability Demo",
    "version": "1.0.0"
  },
  "camel": {
    "version": "4.8.0",
    "name": "camel-observability-demo",
    "uptime": "10h15m",
    "uptimeMillis": 36900000,
    "status": "Started"
  },
  "spring-boot": {
    "version": "3.2.0"
  },
  "java": {
    "version": "21.0.7",
    "vendor": "Homebrew",
    "runtime": "OpenJDK Runtime Environment"
  }
}
```

---

### 方法2: Prometheus Metricsから確認

#### JVM情報（Java/JDKバージョン）

```bash
curl -s http://localhost:8080/actuator/prometheus | grep jvm_info
```

**PromQLクエリ:**
```promql
jvm_info{application="camel-observability-demo"}
```

**結果:**
```
jvm_info{
  application="camel-observability-demo",
  runtime="OpenJDK Runtime Environment",
  vendor="Homebrew",
  version="21.0.7"
}
```

---

### 方法3: Grafanaダッシュボードで確認

#### ステップ1: Grafana Exploreを開く

```
http://localhost:3000/explore
```

#### ステップ2: Prometheusを選択

上部のデータソースドロップダウンから **「Prometheus」** を選択

#### ステップ3: JVM情報クエリ

```promql
jvm_info{application="camel-observability-demo"}
```

「Run query」をクリック → **Table** ビューに切り替え

**表示される情報:**
- **runtime**: OpenJDK Runtime Environment
- **vendor**: Homebrew
- **version**: 21.0.7（JDKバージョン）

#### ステップ4: Camelバージョンの確認

現時点では、Camelのバージョンは`/actuator/info`エンドポイントでのみ確認可能です。

```bash
curl -s http://localhost:8080/actuator/info | jq '.camel.version'
```

**出力:**
```
"4.8.0"
```

---

## 🎯 各バージョンの確認コマンド一覧

### Apache Camelバージョン

```bash
# actuator/info経由
curl -s http://localhost:8080/actuator/info | jq -r '.camel.version'

# pom.xmlから確認
grep -A1 '<camel.version>' demo/camel-app/pom.xml
```

**結果:** `4.8.0`

---

### Spring Bootバージョン

```bash
# actuator/info経由
curl -s http://localhost:8080/actuator/info | jq -r '."spring-boot".version'

# pom.xmlから確認
grep -A3 '<parent>' demo/camel-app/pom.xml | grep '<version>'
```

**結果:** `3.2.0`

---

### Javaバージョン

```bash
# actuator/info経由
curl -s http://localhost:8080/actuator/info | jq -r '.java.version'

# Prometheusメトリクス経由
curl -s http://localhost:9090/api/v1/query?query=jvm_info | \
  jq -r '.data.result[0].metric.version'
```

**結果:** `21.0.7`

---

### アプリケーションバージョン

```bash
# actuator/info経由
curl -s http://localhost:8080/actuator/info | jq -r '.app.version'

# pom.xmlから確認
grep -A1 '<artifactId>camel-observability-demo</artifactId>' demo/camel-app/pom.xml | grep '<version>'
```

**結果:** `1.0.0`

---

### Kafkaバージョン

```bash
# Kafkaコンテナで確認
podman exec -it kafka kafka-broker-api-versions --version
```

---

### Prometheusバージョン

```bash
# prometheus_build_infoメトリクス
curl -s http://localhost:9090/api/v1/query?query=prometheus_build_info | \
  jq -r '.data.result[0].metric.version'

# または直接Prometheusに問い合わせ
curl -s http://localhost:9090/api/v1/status/buildinfo | jq '.data.version'
```

**結果:** `v2.48.0`

---

### Grafanaバージョン

```bash
# Grafana APIから確認
curl -s http://localhost:3000/api/health | jq '.version'
```

**結果:** （Grafanaのバージョン）

---

### Tempoバージョン

```bash
# Tempoコンテナで確認
podman exec tempo /tempo --version
```

---

### Lokiバージョン

```bash
# Lokiコンテナで確認
podman exec loki /loki --version
```

---

## 📊 バージョン一覧表の生成スクリプト

```bash
#!/bin/bash
# version_report.sh

echo "=========================================="
echo "  システムバージョン情報"
echo "=========================================="
echo ""
echo "生成時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "📦 アプリケーション:"
echo "  Apache Camel: $(curl -s http://localhost:8080/actuator/info | jq -r '.camel.version')"
echo "  Spring Boot: $(curl -s http://localhost:8080/actuator/info | jq -r '."spring-boot".version')"
echo "  Java/JDK: $(curl -s http://localhost:8080/actuator/info | jq -r '.java.version')"
echo "  アプリバージョン: $(curl -s http://localhost:8080/actuator/info | jq -r '.app.version')"
echo ""

echo "🔧 観測ツール:"
echo "  Prometheus: $(curl -s http://localhost:9090/api/v1/status/buildinfo | jq -r '.data.version')"
echo "  Grafana: $(curl -s http://localhost:3000/api/health | jq -r '.version')"
echo "  Tempo: $(podman exec tempo /tempo --version 2>&1 | head -1 | awk '{print $3}')"
echo "  Loki: $(podman exec loki /loki --version 2>&1 | head -1 | awk '{print $3}')"
echo ""

echo "📡 メッセージング:"
echo "  Kafka: $(podman exec kafka kafka-broker-api-versions --version 2>&1 | head -1)"
echo ""

echo "=========================================="
```

### 使用方法

```bash
cd /Users/kjin/mobills/observability/demo
chmod +x version_report.sh
./version_report.sh
```

---

## 🎯 Grafanaダッシュボードに追加する方法

### 将来の改善案: アプリケーション情報パネル

Grafanaダッシュボードに「Text」パネルを追加して、静的なバージョン情報を表示することができます。

#### ステップ1: ダッシュボードを編集

```
http://localhost:3000/d/camel-comprehensive
```

右上の⚙️（設定）→ 「Add panel」

#### ステップ2: Visualization: Text を選択

#### ステップ3: Markdown形式で記述

```markdown
# 📦 システム情報

| コンポーネント | バージョン |
|------------|-----------|
| Apache Camel | 4.8.0 |
| Spring Boot | 3.2.0 |
| Java | 21.0.7 |
| Prometheus | 2.48.0 |
| Grafana | (current) |
| Tempo | (deployed) |
| Loki | (deployed) |

**確認コマンド:**
```bash
curl http://localhost:8080/actuator/info
```
```

#### ステップ4: パネルタイトル

```
システムバージョン情報
```

#### ステップ5: 保存

右上の「Save」をクリック

---

## 💡 ベストプラクティス

### 1. バージョン情報を`/actuator/info`で常に公開

`application.yml`:
```yaml
spring:
  info:
    app:
      name: ${spring.application.name}
      version: @project.version@
      description: ${project.description}
    camel:
      version: 4.8.0

management:
  info:
    env:
      enabled: true
    java:
      enabled: true
    os:
      enabled: true
```

### 2. CI/CDパイプラインでバージョンを自動更新

```bash
# Mavenプロパティから自動的に取得
mvn spring-boot:build-info
```

### 3. README.mdにバージョン情報を記載

```markdown
## バージョン情報

- Apache Camel: 4.8.0
- Spring Boot: 3.2.0
- Java: 21+
```

---

## 📚 まとめ

### ❌ 現状

- Camelバージョンは**Prometheusメトリクスとして公開されていない**
- Grafanaで直接確認できない

### ✅ 確認方法

| 方法 | URL/コマンド | 情報 |
|-----|------------|------|
| **Actuator Info** | `http://localhost:8080/actuator/info` | Camel, Spring Boot, Java |
| **Prometheus Metrics** | `jvm_info` | Java/JDK |
| **Grafana Explore** | PromQL: `jvm_info` | Java/JDK |
| **コマンドライン** | `curl` + `jq` | すべて |

### 🎯 推奨アプローチ

1. **日常の確認**: `/actuator/info`エンドポイント
2. **自動化**: バージョンレポートスクリプト
3. **ドキュメント**: README.mdに記載
4. **Grafana**: Textパネルで静的に表示

---

**Camelのバージョンは`/actuator/info`で簡単に確認できます！**🎉



