# 🚀 OpenShift S2I (Source-to-Image) ビルドガイド

OpenShiftのS2I機能を使うと、**ローカルでのイメージビルドが不要**で、ソースコードから直接デプロイできます。

---

## 🎯 S2Iのメリット

| 項目 | 従来の方法 | S2I |
|-----|----------|-----|
| **ローカルビルド** | 必要 | 不要 ✅ |
| **Dockerfile** | 必要 | 不要 ✅ |
| **Podman/Docker問題** | 影響あり | 影響なし ✅ |
| **OpenShiftとの統合** | 手動 | 自動 ✅ |
| **ビルド環境** | ローカル | OpenShift内 ✅ |

---

## 📋 前提条件

### 1. ソースコードをGitリポジトリにプッシュ

S2Iはソースコードリポジトリ（GitHub、GitLab等）から直接ビルドします。

```bash
cd /Users/kjin/mobills/observability/demo

# Gitリポジトリを初期化（まだの場合）
git init

# すべてのファイルをコミット
git add .
git commit -m "Add Camel Observability Demo"

# GitHubリポジトリにプッシュ
git remote add origin https://github.com/YOUR_USERNAME/camel-observability-demo.git
git branch -M main
git push -u origin main
```

### 2. OpenShiftにログイン

```bash
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>
oc new-project camel-observability-demo
```

---

## 🚀 方法1: S2Iで直接デプロイ（推奨）

### ステップ1: S2Iビルドを作成

```bash
# OpenJDK 17ベースイメージを使用してS2Iビルド
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_USERNAME/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --strategy=source \
  --build-env=MAVEN_ARGS="clean package -DskipTests"
```

**パラメータ説明:**
- `registry.access.redhat.com/ubi9/openjdk-17:latest`: ベースイメージ
- `~https://github.com/...`: ソースコードのURL
- `--context-dir=demo/camel-app`: ビルド対象ディレクトリ
- `--strategy=source`: S2Iビルドを使用
- `--build-env`: Mavenビルドコマンド

### ステップ2: ビルド状況を確認

```bash
# ビルドログをリアルタイム表示
oc logs -f bc/camel-app

# ビルド一覧を確認
oc get builds
```

**ビルド時間**: 初回 約5-10分（依存関係のダウンロード含む）

### ステップ3: ConfigMapを作成

```bash
# application.ymlをConfigMapとして作成
oc create configmap camel-app-config \
  --from-file=/Users/kjin/mobills/observability/demo/camel-app/src/main/resources/application.yml
```

### ステップ4: Deploymentを更新

```bash
# ConfigMapをマウント
oc set volume deployment/camel-app \
  --add \
  --type=configmap \
  --configmap-name=camel-app-config \
  --mount-path=/config

# 環境変数を設定
oc set env deployment/camel-app \
  SPRING_CONFIG_LOCATION=file:/config/application.yml \
  LOKI_URL=http://loki:3100/loki/api/v1/push
```

### ステップ5: サービスとルートを作成

```bash
# Routeを作成（外部アクセス用）
oc expose svc/camel-app

# URLを取得
oc get route camel-app
```

---

## 🚀 方法2: Binary Build（JARファイルを使用）

ローカルでビルドしたJARファイルをOpenShiftにアップロードする方法です。

### ステップ1: ローカルでMavenビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests
```

### ステップ2: BuildConfigを作成

```bash
# BuildConfigを作成（バイナリビルド）
oc new-build \
  --name=camel-app \
  --image-stream=openshift/java:openjdk-17-ubi8 \
  --binary=true
```

### ステップ3: JARファイルをアップロードしてビルド

```bash
# ビルドを開始
oc start-build camel-app \
  --from-file=target/camel-observability-demo-1.0.0.jar \
  --follow

# ビルドの確認
oc get builds
```

### ステップ4: Deploymentを作成

```bash
# 作成したイメージからデプロイ
oc new-app camel-app:latest

# Routeを作成
oc expose svc/camel-app
```

---

## 🚀 方法3: S2I + プライベートリポジトリ

プライベートリポジトリの場合、認証情報が必要です。

### ステップ1: Secretを作成

```bash
# GitHubのアクセストークンを使用
oc create secret generic github-secret \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_PERSONAL_ACCESS_TOKEN \
  --type=kubernetes.io/basic-auth

# BuildConfigにSecretを関連付け
oc set build-secret --source bc/camel-app github-secret
```

### ステップ2: S2Iビルド

```bash
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_USERNAME/private-repo \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --source-secret=github-secret
```

---

## ✅ ビルド成功の確認

### Podが起動しているか確認

```bash
oc get pods -l deployment=camel-app

# 期待される出力:
# NAME                        READY   STATUS    RESTARTS   AGE
# camel-app-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
```

### ログを確認

```bash
# アプリケーションログ
oc logs -f deployment/camel-app

# ビルドログ
oc logs -f bc/camel-app
```

### ヘルスチェック

```bash
# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"
```

---

## 🔄 コードを更新した場合

### 再ビルド

```bash
# Gitにプッシュ後、再ビルドをトリガー
oc start-build camel-app

# ビルドログを確認
oc logs -f bc/camel-app
```

### Webhook設定（自動ビルド）

```bash
# WebhookのURLを取得
oc describe bc/camel-app | grep -A1 "Webhook GitHub"

# GitHubのリポジトリ設定 → Webhooks → Add webhook
# Payload URL: 上記で取得したURL
# Content type: application/json
```

これで、Gitにプッシュするたびに自動的にOpenShiftでビルドされます。

---

## 🐛 トラブルシューティング

### ビルドが失敗する

```bash
# ビルドログを確認
oc logs bc/camel-app

# よくある原因:
# - pom.xmlが見つからない → context-dirを確認
# - Maven依存関係の解決失敗 → ネットワーク確認
# - メモリ不足 → BuildConfigのリソース制限を増やす
```

### メモリ不足エラー

```bash
# BuildConfigのリソースを増やす
oc patch bc/camel-app -p '{"spec":{"resources":{"limits":{"memory":"2Gi"}}}}'
```

### ビルド時間が長い

```bash
# Mavenキャッシュを有効化
oc set volume bc/camel-app --add --type=persistentVolumeClaim \
  --claim-name=maven-cache \
  --claim-size=5Gi \
  --mount-path=/home/jboss/.m2
```

---

## 📊 S2I vs 従来の方法

### ビルド時間の比較

| 方法 | 初回ビルド | 2回目以降 | 備考 |
|-----|----------|----------|------|
| ローカルPodman/Docker | 3-5分 | 1-2分 | エラーの可能性あり |
| S2I | 5-10分 | 3-5分 | 安定 |
| Binary Build | 1-2分 | 1-2分 | 最速、ローカルビルド必要 |

### リソース使用量

| 方法 | ローカルリソース | OpenShiftリソース |
|-----|-------------|-----------------|
| ローカルビルド | CPU/メモリを使用 | 少ない |
| S2I | 不要 | CPU/メモリを使用 |
| Binary Build | CPU/メモリを使用 | 少ない |

---

## 🎯 推奨される方法

### 開発環境

**Binary Build** - ローカルで開発・ビルドし、JARファイルをアップロード
- ローカルでのテストが容易
- ビルドが高速
- デバッグしやすい

### テスト・本番環境

**S2I** - ソースコードから自動ビルド
- 一貫したビルドプロセス
- Git統合で追跡可能
- Webhookで自動デプロイ

---

## 📚 参考リンク

- [OpenShift S2I Documentation](https://docs.openshift.com/container-platform/latest/openshift_images/using_images/using-s21-images.html)
- [Red Hat OpenJDK S2I Images](https://access.redhat.com/documentation/en-us/red_hat_build_of_openjdk/)

---

**S2Iを使えば、Podmanの問題を完全に回避できます！**🚀


