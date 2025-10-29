# thread_monitor.sh お客様環境での導入ガイド

## 📋 事前確認チェックリスト

`thread_monitor.sh`を実行する前に、以下を確認してください。

### ✅ 必須要件

#### 1. **Spring Boot Actuatorが有効になっているか**

アプリケーションに以下の依存関係が含まれていることを確認：

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

#### 2. **Prometheusエンドポイントが公開されているか**

`application.yml` または `application.properties` に以下の設定があることを確認：

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
```

または

```properties
# application.properties
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.endpoint.prometheus.enabled=true
management.metrics.export.prometheus.enabled=true
```

#### 3. **エンドポイントにアクセスできるか確認**

```bash
# 基本的な確認
curl http://YOUR-HOST:YOUR-PORT/actuator/health

# Prometheusエンドポイントの確認
curl http://YOUR-HOST:YOUR-PORT/actuator/prometheus | head -20
```

**期待される出力**:
```
# HELP jvm_threads_live_threads The current number of live threads
# TYPE jvm_threads_live_threads gauge
jvm_threads_live_threads{application="your-app-name"} 45.0
...
```

---

## 🚀 使い方

### 方法1: コマンドライン引数で指定（推奨）

```bash
# 基本形式
./thread_monitor.sh [測定間隔(秒)] [ActuatorのURL]

# 例1: デフォルト設定（5秒間隔、localhost:8080）
./thread_monitor.sh

# 例2: 測定間隔を変更（3秒間隔）
./thread_monitor.sh 3

# 例3: URLを指定
./thread_monitor.sh 5 http://your-server:8080/actuator/prometheus

# 例4: HTTPSを使用
./thread_monitor.sh 5 https://your-server:8443/actuator/prometheus

# 例5: カスタムパス
./thread_monitor.sh 5 http://your-server:9090/custom-path/actuator/prometheus
```

### 方法2: 環境変数で指定

```bash
# 環境変数を設定してから実行
export ACTUATOR_URL="http://your-server:8080/actuator/prometheus"
./thread_monitor.sh 5

# または1行で
ACTUATOR_URL="http://your-server:8080/actuator/prometheus" ./thread_monitor.sh 5
```

### 方法3: スクリプトファイルを編集（永続的な変更）

スクリプトの10行目を直接編集：

```bash
# 修正前
ACTUATOR_URL=${2:-${ACTUATOR_URL:-http://localhost:8080/actuator/prometheus}}

# 修正後（お客様の環境に合わせる）
ACTUATOR_URL=${2:-${ACTUATOR_URL:-http://your-server:8080/actuator/prometheus}}
```

---

## 🔍 トラブルシューティング

### ❌ エラー: 「アプリケーションにアクセスできません」

#### 原因1: ホスト名/ポート番号が間違っている

**確認方法**:
```bash
# アプリケーションが起動しているか確認
netstat -an | grep LISTEN | grep 8080

# または
ss -tulpn | grep 8080
```

**解決方法**: 正しいホスト名とポート番号を指定してください。

#### 原因2: Actuatorエンドポイントが有効になっていない

**確認方法**:
```bash
# 利用可能なエンドポイントを確認
curl http://YOUR-HOST:YOUR-PORT/actuator

# 出力に "prometheus" が含まれているか確認
```

**解決方法**: `application.yml`で`prometheus`エンドポイントを有効にしてください（上記「必須要件」参照）。

#### 原因3: ファイアウォール/ネットワーク問題

**確認方法**:
```bash
# ポートが開いているか確認
telnet YOUR-HOST YOUR-PORT

# または
nc -zv YOUR-HOST YOUR-PORT
```

**解決方法**: ファイアウォール設定を確認し、必要なポートを開放してください。

#### 原因4: HTTPSで証明書エラー

**確認方法**:
```bash
curl -v https://YOUR-HOST:YOUR-PORT/actuator/prometheus
```

**解決方法**: 自己署名証明書の場合、curlに`-k`オプションを追加する必要があります。

スクリプトの20行目を以下のように修正：
```bash
# 修正前
if ! curl -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL" 2>/dev/null | grep -q "200"; then

# 修正後（証明書検証をスキップ）
if ! curl -k -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL" 2>/dev/null | grep -q "200"; then
```

また、53行目と73行目の`curl`コマンドにも`-k`を追加：
```bash
# 53行目
METRICS=$(curl -k -s "$ACTUATOR_URL")
```

---

## 📊 動作確認

### 正常に動作している場合の出力例

```
=== JVM & Webサーバー スレッド監視 ===
接続先: http://your-server:8080/actuator/prometheus
測定間隔: 5秒
Ctrl+C で終了

✅ アプリケーション接続成功

検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  - Undertowメトリクス: 有効 ✅（キューサイズ含む）

[14:30:15]
  JVMスレッド:
    Live: 45 | Daemon: 38 | Non-Daemon: 7 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 2 | Pool Size: 10 | Max: 200 | Core: 8 | Usage: 1.0%
  Undertow:
    Workers: 200 | Active: 5 | Queue: 0 | Usage: 2.5%
```

---

## 🔐 セキュリティ考慮事項

### 認証が必要な環境の場合

Actuatorエンドポイントに認証が必要な場合、スクリプトを以下のように修正してください：

#### Basic認証の追加

```bash
# 環境変数で認証情報を設定
export ACTUATOR_USER="your-username"
export ACTUATOR_PASS="your-password"
export ACTUATOR_URL="http://your-server:8080/actuator/prometheus"

# curlコマンドに認証を追加（スクリプトの20行目と53行目を修正）
curl -u "$ACTUATOR_USER:$ACTUATOR_PASS" -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL"
```

#### Bearerトークン認証の場合

```bash
# 環境変数でトークンを設定
export ACTUATOR_TOKEN="your-bearer-token"
export ACTUATOR_URL="http://your-server:8080/actuator/prometheus"

# curlコマンドにトークンを追加
curl -H "Authorization: Bearer $ACTUATOR_TOKEN" -s -o /dev/null -w "%{http_code}" "$ACTUATOR_URL"
```

---

## 📝 カスタマイズ例

### 例1: リモートサーバーの監視

```bash
# サーバーAの監視
./thread_monitor.sh 3 http://server-a:8080/actuator/prometheus

# サーバーBの監視（別のターミナルで）
./thread_monitor.sh 3 http://server-b:8080/actuator/prometheus
```

### 例2: HTTPS環境での使用

```bash
# HTTPS + カスタムポート
./thread_monitor.sh 5 https://your-server:8443/actuator/prometheus
```

### 例3: ロードバランサー経由

```bash
# ロードバランサーのURLを指定
./thread_monitor.sh 5 https://lb.example.com/app1/actuator/prometheus
```

### 例4: コンテキストパスがある場合

```bash
# /myappというコンテキストパスがある場合
./thread_monitor.sh 5 http://your-server:8080/myapp/actuator/prometheus
```

---

## ✅ 導入前チェックリスト

お客様環境で使用する前に、以下を確認してください：

- [ ] Spring Boot Actuatorが有効
- [ ] Micrometer Prometheusレジストリが有効
- [ ] `application.yml`でPrometheusエンドポイントが公開されている
- [ ] ファイアウォールで必要なポートが開いている
- [ ] `curl`コマンドでActuatorエンドポイントにアクセスできる
- [ ] JVMメトリクス（`jvm_threads_*`）が取得できる
- [ ] 正しいホスト名とポート番号を特定済み
- [ ] HTTPSの場合、証明書の問題を解決済み
- [ ] 認証が必要な場合、認証方法を確認済み

---

## 📞 サポート

問題が発生した場合は、以下の情報を提供してください：

1. **アプリケーション情報**
   - Spring Bootバージョン
   - 使用しているWebサーバー（Tomcat/Undertow/Jetty）
   
2. **エラーメッセージ**
   - スクリプトの出力全体
   
3. **環境情報**
   - OS（Linux/Windows/macOS）
   - curlのバージョン（`curl --version`）
   
4. **動作確認結果**
   ```bash
   # 以下のコマンドの出力
   curl -v http://YOUR-HOST:YOUR-PORT/actuator/health
   curl http://YOUR-HOST:YOUR-PORT/actuator
   curl http://YOUR-HOST:YOUR-PORT/actuator/prometheus | head -50
   ```

---

## 📚 関連ドキュメント

- `THREAD_MONITOR_UNDERTOW.md` - 詳細な使用方法とメトリクス説明
- `ACTUATOR_GUIDE_UPDATE.md` - Actuator設定ガイド
- `ACTUATOR_METRICS_GUIDE.md` - メトリクス詳細ガイド

