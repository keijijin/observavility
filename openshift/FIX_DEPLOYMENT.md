# 🔧 OpenShift デプロイメント修正ガイド

## 現在の問題

```bash
$ oc get pods
NAME                          READY   STATUS             RESTARTS       AGE
camel-app-687bf9d9c9-dmz4f    0/1     ErrImagePull       0              6m5s
kafka-5d6697878c-mn4nq        0/1     CrashLoopBackOff   8 (2m4s ago)   18m
```

### 問題1: camel-app - ErrImagePull

**原因**: イメージが内部レジストリに存在しない

```
Failed to pull image "...camel-app:1.0.0": name unknown
```

### 問題2: kafka - CrashLoopBackOff

**原因**: Zookeeper接続またはメモリ不足の可能性

---

## ✅ 解決方法

### 方法1: Binary Build（最も簡単）🚀

#### ステップ1: 既存のリソースをクリーンアップ

```bash
# 問題のあるDeploymentを削除
oc delete deployment camel-app
oc delete service camel-app
oc delete configmap camel-app-config
```

#### ステップ2: ローカルでMavenビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests
```

#### ステップ3: Binary BuildConfigを作成

```bash
oc new-build \
  --name=camel-app \
  --image-stream=openshift/java:openjdk-17-ubi8 \
  --binary=true \
  --strategy=source
```

#### ステップ4: JARファイルをアップロードしてビルド

```bash
oc start-build camel-app \
  --from-file=target/camel-observability-demo-1.0.0.jar \
  --follow
```

**注意**: ビルドには3-5分かかります。

#### ステップ5: アプリケーションをデプロイ

```bash
# ImageStreamからデプロイ
oc new-app camel-app:latest
```

#### ステップ6: ConfigMapを作成

```bash
oc create configmap camel-app-config \
  --from-file=/Users/kjin/mobills/observability/demo/camel-app/src/main/resources/application.yml
```

#### ステップ7: ConfigMapをマウント

```bash
oc set volume deployment/camel-app \
  --add \
  --type=configmap \
  --configmap-name=camel-app-config \
  --mount-path=/config
```

#### ステップ8: 環境変数を設定

```bash
oc set env deployment/camel-app \
  SPRING_CONFIG_LOCATION=file:/config/application.yml \
  LOKI_URL=http://loki:3100/loki/api/v1/push \
  KAFKA_BOOTSTRAP_SERVERS=kafka:9092 \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317
```

#### ステップ9: Routeを作成（外部アクセス用）

```bash
oc expose svc/camel-app

# URLを確認
oc get route camel-app
```

---

### 方法2: 事前ビルドしたイメージをプッシュ

#### ステップ1: OpenShift内部レジストリにログイン

```bash
# レジストリのURLを取得
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')

# トークンを取得してログイン
TOKEN=$(oc whoami -t)
podman login -u $(oc whoami) -p $TOKEN $REGISTRY
```

#### ステップ2: イメージをタグ付けしてプッシュ

```bash
# プロジェクト名を取得
PROJECT=$(oc project -q)

# AMD64イメージをタグ付け
podman tag camel-observability-demo:1.0.0-amd64 $REGISTRY/$PROJECT/camel-app:1.0.0

# プッシュ
podman push $REGISTRY/$PROJECT/camel-app:1.0.0
```

#### ステップ3: Deploymentを再作成

```bash
# 既存のDeploymentを削除
oc delete deployment camel-app

# openshift/camel-app/camel-app-deployment.yaml を適用
oc apply -f /Users/kjin/mobills/observability/demo/openshift/camel-app/camel-app-deployment.yaml
```

---

## 🔧 Kafkaの問題を修正

### 問題の診断

```bash
# Kafkaのログを確認
oc logs kafka-5d6697878c-mn4nq --tail=50

# よくあるエラー:
# - Zookeeper接続エラー
# - メモリ不足 (OOMKilled)
# - ポート競合
```

### 解決策1: メモリとCPUを増やす

```bash
# Kafkaのリソースを増やす
oc set resources deployment/kafka \
  --requests=memory=512Mi,cpu=500m \
  --limits=memory=2Gi,cpu=1000m
```

### 解決策2: Zookeeper接続を確認

```bash
# Zookeeperが動作しているか確認
oc get pods -l app=zookeeper

# Zookeeperのログを確認
oc logs -l app=zookeeper --tail=30

# Kafkaの環境変数を確認
oc get deployment kafka -o jsonpath='{.spec.template.spec.containers[0].env}' | jq .
```

### 解決策3: Kafkaを再作成

```bash
# Kafkaを削除
oc delete deployment kafka
oc delete service kafka
oc delete pvc kafka-data

# 再作成
oc apply -f /Users/kjin/mobills/observability/demo/openshift/kafka/kafka-deployment.yaml

# 起動を待つ
oc wait --for=condition=available --timeout=300s deployment/kafka
```

---

## 📊 デプロイメントの確認

### すべてのPodが正常か確認

```bash
oc get pods

# 期待される出力:
# NAME                          READY   STATUS    RESTARTS   AGE
# camel-app-xxx                 1/1     Running   0          2m
# grafana-xxx                   1/1     Running   0          15m
# kafka-xxx                     1/1     Running   0          3m
# loki-xxx                      1/1     Running   0          15m
# prometheus-xxx                1/1     Running   0          15m
# tempo-xxx                     1/1     Running   0          15m
# zookeeper-xxx                 1/1     Running   0          20m
```

### アプリケーションのヘルスチェック

```bash
# Camel Appのヘルスチェック
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
curl "https://${CAMEL_URL}/actuator/health"

# Grafanaへのアクセス
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"
```

### ログの確認

```bash
# Camel Appのログ
oc logs -f deployment/camel-app

# すべてのコンポーネントのログ
oc logs -f -l app=camel-app --tail=50
```

---

## 🚨 トラブルシューティング

### ImagePullBackOff が解決しない

```bash
# ImageStreamを確認
oc get imagestreams

# Buildを確認
oc get builds
oc logs build/camel-app-1

# イメージが存在するか確認
oc get imagestreamtags
```

### CrashLoopBackOff が続く

```bash
# Podの詳細を確認
oc describe pod <POD_NAME>

# 直前のログを確認
oc logs <POD_NAME> --previous

# リソース不足の可能性
oc get nodes
oc describe node <NODE_NAME>
```

### アプリケーションが起動しない

```bash
# イベントを確認
oc get events --sort-by='.lastTimestamp' | tail -20

# Deploymentのステータスを確認
oc rollout status deployment/camel-app

# ConfigMapが正しくマウントされているか
oc exec deployment/camel-app -- ls -la /config
oc exec deployment/camel-app -- cat /config/application.yml
```

---

## 🎯 自動修正スクリプト

すべての手順を自動実行するスクリプト:

```bash
#!/bin/bash
set -e

echo "=== 🚀 OpenShiftデプロイメントを修正 ==="

# 1. 既存リソースをクリーンアップ
echo "ステップ1: クリーンアップ"
oc delete deployment camel-app 2>/dev/null || true
oc delete service camel-app 2>/dev/null || true
oc delete configmap camel-app-config 2>/dev/null || true
oc delete bc camel-app 2>/dev/null || true
oc delete is camel-app 2>/dev/null || true

# 2. Mavenビルド
echo "ステップ2: Mavenビルド"
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests

# 3. Binary Build
echo "ステップ3: Binary Build"
oc new-build \
  --name=camel-app \
  --image-stream=openshift/java:openjdk-17-ubi8 \
  --binary=true \
  --strategy=source

# 4. ビルド実行
echo "ステップ4: ビルド実行"
oc start-build camel-app \
  --from-file=target/camel-observability-demo-1.0.0.jar \
  --follow

# 5. デプロイ
echo "ステップ5: デプロイ"
oc new-app camel-app:latest

# 6. ConfigMap
echo "ステップ6: ConfigMap"
oc create configmap camel-app-config \
  --from-file=src/main/resources/application.yml

# 7. ConfigMapをマウント
echo "ステップ7: ConfigMapマウント"
oc set volume deployment/camel-app \
  --add \
  --type=configmap \
  --configmap-name=camel-app-config \
  --mount-path=/config

# 8. 環境変数
echo "ステップ8: 環境変数"
oc set env deployment/camel-app \
  SPRING_CONFIG_LOCATION=file:/config/application.yml \
  LOKI_URL=http://loki:3100/loki/api/v1/push \
  KAFKA_BOOTSTRAP_SERVERS=kafka:9092 \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317

# 9. Route
echo "ステップ9: Route作成"
oc expose svc/camel-app

# 10. Kafka修正
echo "ステップ10: Kafkaリソース調整"
oc set resources deployment/kafka \
  --requests=memory=512Mi,cpu=500m \
  --limits=memory=2Gi,cpu=1000m

echo ""
echo "✅ 完了！"
echo ""
echo "確認:"
oc get pods
echo ""
oc get route camel-app
```

このスクリプトを保存して実行:

```bash
bash /tmp/fix_camel_app.sh
```

---

## 📚 参考資料

- **S2I_BUILD_GUIDE.md** - S2Iビルドの詳細
- **BUILD_FOR_OPENSHIFT.md** - OpenShift用イメージビルド
- **OPENSHIFT_DEPLOYMENT_GUIDE.md** - 完全なデプロイメントガイド

---

**問題を修正して、すべてのPodを正常稼働させましょう！** 🚀



