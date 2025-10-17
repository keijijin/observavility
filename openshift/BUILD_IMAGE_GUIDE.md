# 🐳 Camel Appイメージのビルドガイド

OpenShift上でCamel Appを動かすために、コンテナイメージをビルドしてレジストリにプッシュする必要があります。

---

## 📋 方法1: Podman/Dockerでビルド → OpenShiftレジストリにプッシュ

### ステップ1: イメージをビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# Dockerfileを使ってビルド（最もシンプル）
podman build -t camel-app:1.0.0 .

# または、プロジェクトルートから
cd /Users/kjin/mobills/observability/demo
podman build -f camel-app/Dockerfile -t camel-app:1.0.0 camel-app/
```

### ステップ2: OpenShift内部レジストリにログイン

```bash
# OpenShift内部レジストリのホスト名を取得
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)

# レジストリが公開されていない場合、公開する
if [ -z "$REGISTRY" ]; then
    oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
    sleep 10
    REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
fi

echo "Registry: $REGISTRY"

# レジストリにログイン
TOKEN=$(oc whoami -t)
podman login -u $(oc whoami) -p $TOKEN $REGISTRY --tls-verify=false
```

### ステップ3: イメージをタグ付けしてプッシュ

```bash
# プロジェクト名を取得
PROJECT=$(oc project -q)

# イメージをタグ付け
podman tag camel-app:1.0.0 $REGISTRY/$PROJECT/camel-app:1.0.0

# プッシュ
podman push $REGISTRY/$PROJECT/camel-app:1.0.0 --tls-verify=false
```

### ステップ4: ImageStreamの確認

```bash
# ImageStreamが作成されたか確認
oc get imagestream

# 詳細を確認
oc describe imagestream camel-app
```

### ステップ5: Deploymentを更新

```bash
# camel-app-deployment.yaml の image フィールドを更新
# image: image-registry.openshift-image-registry.svc:5000/<PROJECT>/camel-app:1.0.0

# デプロイ
oc apply -f openshift/camel-app/camel-app-deployment.yaml
```

---

## 📋 方法2: OpenShift Source-to-Image (S2I)

OpenShiftのS2I機能を使うと、ソースコードから直接ビルドできます。

### ステップ1: ソースコードをGitリポジトリにプッシュ

```bash
# GitHubなどにリポジトリを作成し、コードをプッシュ
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/camel-observability-demo.git
git push -u origin main
```

### ステップ2: OpenShiftでビルド

```bash
# S2Iビルドを作成（Javaベースイメージを使用）
oc new-app registry.access.redhat.com/ubi8/openjdk-17~https://github.com/YOUR_USERNAME/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --strategy=source

# ビルドの進行状況を確認
oc logs -f bc/camel-app
```

### ステップ3: サービスとルートの作成

```bash
# ConfigMapを作成
oc create configmap camel-app-config --from-file=camel-app/src/main/resources/application.yml

# Deploymentを更新してConfigMapをマウント
oc set volume deployment/camel-app --add --type=configmap \
  --configmap-name=camel-app-config \
  --mount-path=/config

# 環境変数を設定
oc set env deployment/camel-app SPRING_CONFIG_LOCATION=file:/config/application.yml

# Routeを作成
oc expose svc/camel-app

# URLを取得
oc get route camel-app
```

---

## 📋 方法3: BuildConfig + Binary Build

ローカルでビルドしたJARをOpenShiftに転送してイメージ化します。

### ステップ1: ローカルでビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests
```

### ステップ2: BuildConfig を作成

```bash
# BuildConfig を作成
oc new-build --name=camel-app \
  --image-stream=openjdk-17:latest \
  --binary=true
```

### ステップ3: JARをアップロードしてビルド

```bash
# ビルドを開始
oc start-build camel-app --from-file=target/camel-observability-demo-1.0.0.jar --follow

# ビルドの確認
oc get builds
```

### ステップ4: Deployment を作成

```bash
# 既存のマニフェストを使用
oc apply -f openshift/camel-app/camel-app-deployment.yaml

# またはDeploymentを新規作成
oc new-app camel-app:latest
```

---

## 🔍 イメージの確認

### ビルドされたイメージを確認

```bash
# ImageStreamを確認
oc get is

# 詳細を確認
oc describe is camel-app

# イメージのタグを確認
oc get istag
```

### イメージをローカルにプル（オプション）

```bash
# OpenShift レジストリからプル
podman pull $REGISTRY/$PROJECT/camel-app:1.0.0 --tls-verify=false

# 確認
podman images | grep camel-app
```

---

## 🐛 トラブルシューティング

### ビルドエラー

```bash
# ビルドログを確認
oc logs bc/camel-app

# ビルドPodのログを確認
oc logs -f $(oc get pod -l openshift.io/build.name -o name | head -1)
```

### レジストリにログインできない

```bash
# トークンを確認
oc whoami -t

# レジストリのRouteを確認
oc get route -n openshift-image-registry

# レジストリが公開されていない場合
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

### イメージがPullできない

```bash
# ImageStreamの確認
oc get is camel-app -o yaml

# Deploymentで使用しているイメージ名を確認
oc get deployment camel-app -o yaml | grep image:

# 内部レジストリのサービスDNSを使用
# image: image-registry.openshift-image-registry.svc:5000/<PROJECT>/camel-app:1.0.0
```

---

## 📝 Dockerfileの詳細

作成済みの `openshift/Dockerfile` は以下の特徴があります:

### Multi-stage Build

```dockerfile
# ステージ1: Mavenビルド
FROM maven:3.9.5-eclipse-temurin-17 AS build

# ステージ2: ランタイム（軽量）
FROM eclipse-temurin:17-jre-alpine
```

**メリット:**
- 最終イメージサイズが小さい
- ビルドツールが含まれない（セキュリティ向上）

### セキュリティ対策

```dockerfile
# 非rootユーザーを作成
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

### ヘルスチェック

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
```

---

## 🎯 推奨アプローチ

| 方法 | メリット | デメリット | 推奨度 |
|-----|---------|----------|--------|
| **Podman Build + Push** | 柔軟性が高い | 手動作業が多い | ⭐⭐⭐ |
| **S2I** | 自動化、シンプル | カスタマイズが難しい | ⭐⭐⭐⭐ |
| **Binary Build** | ローカルビルド可 | 2段階の手順 | ⭐⭐ |

### 開発環境
→ **Podman Build + Push** または **Binary Build**

### 本番環境
→ **S2I** または **CI/CD パイプライン**

---

## 🚀 次のステップ

イメージのビルドが完了したら:

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./deploy.sh
```

デプロイスクリプトが自動的にすべてのコンポーネントをデプロイします。

---

**イメージビルドが完了したら、OpenShiftデプロイメントガイドに戻ってデプロイを続行してください！**🎉

