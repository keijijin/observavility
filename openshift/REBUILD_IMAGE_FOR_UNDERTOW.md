# OpenShift版イメージの再ビルド - Undertow対応

## 🎯 **問題の特定**

### 確認された事実

1. ✅ **ローカルのpom.xml**: Undertowが含まれている
   ```xml
   <!-- Tomcatを除外してUndertowを使用 -->
   <exclusion>
       <artifactId>spring-boot-starter-tomcat</artifactId>
   </exclusion>
   
   <!-- Undertow を追加 -->
   <dependency>
       <artifactId>spring-boot-starter-undertow</artifactId>
   </dependency>
   ```

2. ✅ **ConfigMap**: Undertow設定が完璧に含まれている

3. ✅ **Pod**: Running状態、ConfigMapも正しくマウントされている

4. ❌ **Undertowメトリクス**: 出力されていない

---

## 💡 **根本原因**

**OpenShift上のイメージが古く、Undertowに移行する前のイメージ（Tomcat版）である可能性が高い**

つまり：
- ローカルの`pom.xml`はUndertowに更新されている
- しかし、OpenShift上のイメージは古いまま（Tomcat版）
- ConfigMapでUndertow設定を追加しても、イメージ自体がTomcatを使用している

---

## 🔍 **確認手順**

OpenShift環境で以下を実行して、現在のイメージが使用しているサーバーを確認してください：

### ステップ1: 使用しているサーバーを確認

```bash
# Tomcatメトリクスが出力されるか確認
oc exec camel-app-65dc67884c-gp5hn -- \
  curl -s http://localhost:8080/actuator/prometheus | grep "^tomcat" | head -5

# 期待される出力（Tomcat版の場合）:
# tomcat_sessions_active_current_sessions{...} 0.0
# tomcat_sessions_active_max_sessions{...} -1.0
# ...
```

### ステップ2: Podのログを確認

```bash
# 起動時のログでTomcat/Undertowどちらが使用されているか確認
oc logs camel-app-65dc67884c-gp5hn | grep -i "tomcat\|undertow" | head -10

# Tomcat版の場合の出力例:
# ... Tomcat started on port(s): 8080 (http) ...

# Undertow版の場合の出力例:
# ... Undertow started on port(s): 8080 (http) ...
```

---

## 🚀 **解決方法: 新しいイメージをビルド**

### 方法A: OpenShift BuildConfigを使用（推奨）

```bash
# 1. BuildConfigが存在するか確認
oc get buildconfig camel-app

# 2. 新しいビルドを開始（ソースコードから再ビルド）
oc start-build camel-app --follow

# 3. ビルド完了後、自動的に新しいイメージがデプロイされる
# （ImageStreamタグが更新され、Deploymentが自動的にロールアウトされる）

# 4. 新しいPodが起動するまで待機
oc rollout status deployment/camel-app

# 5. Undertowメトリクスを確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
sleep 30  # アプリケーション起動待機
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"
```

---

### 方法B: ローカルでビルドしてプッシュ

```bash
# 1. ローカルでAMD64イメージをビルド
cd /Users/kjin/mobills/observability/demo
podman build --platform linux/amd64 -t camel-app:latest -f camel-app/Dockerfile .

# 2. OpenShiftレジストリにログイン
oc registry login

# 3. イメージにタグを付ける
REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
podman tag camel-app:latest $REGISTRY_HOST/camel-observability-demo/camel-app:latest

# 4. イメージをプッシュ
podman push $REGISTRY_HOST/camel-observability-demo/camel-app:latest

# 5. Deploymentを最新イメージに更新
oc set image deployment/camel-app \
  camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest

# 6. ロールアウト完了を待機
oc rollout status deployment/camel-app

# 7. Undertowメトリクスを確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
sleep 30
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"
```

---

## 📋 **ビルド時の確認ポイント**

ビルド中のログで以下を確認してください：

### Maven依存関係の解決

```
[INFO] --- maven-dependency-plugin:...
...
[INFO] spring-boot-starter-undertow:jar:3.2.0:compile
[INFO]    io.undertow:undertow-core:jar:2.3.10.Final:compile
[INFO]    io.undertow:undertow-servlet:jar:2.3.10.Final:compile
...
```

### ビルド成功の確認

```
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  XX:XX min
[INFO] Finished at: YYYY-MM-DDTHH:MM:SSZ
[INFO] ------------------------------------------------------------------------
```

---

## ✅ **成功の確認**

新しいイメージで起動したPodから以下のメトリクスが出力されることを確認：

```bash
oc exec <NEW_POD> -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"
```

**期待される出力:**
```
undertow_worker_threads{application="camel-observability-demo"} 200.0
undertow_io_threads{application="camel-observability-demo"} 4.0
undertow_active_requests{application="camel-observability-demo"} 0.0
undertow_request_queue_size{application="camel-observability-demo"} 0.0
```

---

## 🔧 **トラブルシューティング**

### 問題A: ビルドが失敗する

```bash
# ビルドログを確認
oc logs -f bc/camel-app

# よくあるエラー:
# - Maven依存関係の解決エラー
# - ソースコードのエラー
# - リソース不足
```

### 問題B: ビルドは成功したが、まだTomcatメトリクスが出力される

```bash
# 正しいイメージが使用されているか確認
oc describe pod <POD_NAME> | grep "Image:"

# ImageStreamの最新タグを確認
oc describe imagestream camel-app | grep -A 10 "latest"

# Deploymentが最新イメージを参照しているか確認
oc get deployment camel-app -o yaml | grep "image:"
```

### 問題C: 新しいイメージでもUndertowメトリクスが出力されない

```bash
# アプリケーションログを確認
oc logs <POD_NAME> | grep -i "undertow\|error"

# Undertowが正しく起動しているか確認
oc logs <POD_NAME> | grep "Undertow started on port"

# ConfigMapが正しくマウントされているか再確認
oc exec <POD_NAME> -- cat /config/application.yml | grep -A 5 "undertow:"
```

---

## 🎯 **推奨される手順（クイック版）**

最も迅速な解決方法：

```bash
# 1. 確認: 現在Tomcatを使用しているか
oc exec camel-app-65dc67884c-gp5hn -- \
  curl -s http://localhost:8080/actuator/prometheus | grep "^tomcat" | wc -l

# 結果が 0 より大きい場合 → Tomcat版イメージを使用している

# 2. 新しいビルドを実行
oc start-build camel-app --follow

# 3. ロールアウト完了を待機
oc rollout status deployment/camel-app

# 4. Undertowメトリクスを確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
sleep 30
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"

# 5. Grafana Dashboardを確認
oc get route grafana -o jsonpath='{.spec.host}'
# ブラウザで https://<GRAFANA_HOST>/d/undertow-monitoring/ にアクセス
```

---

**作成日**: 2025-10-20  
**対象**: OpenShift 4.x、Spring Boot 3.x with Undertow



