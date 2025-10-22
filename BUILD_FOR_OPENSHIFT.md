# 🚀 OpenShift用コンテナイメージのビルドガイド

## ⚠️ 重要な注意事項

**Apple Silicon (M1/M2/M3) でビルドする場合、アーキテクチャに注意してください！**

| 環境 | アーキテクチャ | 互換性 |
|------|--------------|--------|
| **Apple Silicon (ローカル)** | ARM64 | ❌ OpenShiftで動作しない |
| **OpenShift (通常)** | x86_64 (AMD64) | ✅ |

---

## 🎯 推奨される方法

### 方法1: OpenShiftでS2Iビルド（最も推奨）✨

**メリット**: 
- アーキテクチャを気にする必要なし
- ローカルでのイメージビルド不要
- OpenShift上で自動的に正しいアーキテクチャでビルド

```bash
# ソースコードをGitにプッシュ後
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_REPO/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --strategy=source

# ビルド状況を確認
oc logs -f bc/camel-app
```

詳細は `openshift/S2I_BUILD_GUIDE.md` を参照。

---

### 方法2: マルチアーキテクチャビルド（Apple Siliconから）

Apple Siliconから**x86_64イメージ**をビルドします。

#### ステップ1: x86_64イメージをビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# --platform linux/amd64 を指定
podman build --platform linux/amd64 -t camel-observability-demo:1.0.0-amd64 .
```

**注意**: 
- ビルド時間が長くなります（エミュレーション）
- QEMUエミュレーターが必要

#### ステップ2: アーキテクチャを確認

```bash
# ビルドしたイメージのアーキテクチャを確認
podman inspect camel-observability-demo:1.0.0-amd64 --format='{{.Architecture}}'
# 出力: amd64 ✅
```

#### ステップ3: OpenShift内部レジストリにプッシュ

```bash
# OpenShiftにログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>

# 内部レジストリのURLを取得
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')

# レジストリにログイン
TOKEN=$(oc whoami -t)
podman login -u $(oc whoami) -p $TOKEN $REGISTRY

# イメージをタグ付け
PROJECT=$(oc project -q)
podman tag camel-observability-demo:1.0.0-amd64 $REGISTRY/$PROJECT/camel-app:1.0.0

# プッシュ
podman push $REGISTRY/$PROJECT/camel-app:1.0.0
```

---

### 方法3: Binary Build（JARファイルをアップロード）

アーキテクチャに依存しないJARファイルをOpenShiftでビルドします。

#### ステップ1: ローカルでMavenビルド

```bash
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests
```

**注意**: JARファイルはアーキテクチャ非依存です。

#### ステップ2: OpenShiftでBinary Build

```bash
# BuildConfigを作成
oc new-build \
  --name=camel-app \
  --image-stream=openshift/java:openjdk-17-ubi8 \
  --binary=true

# JARファイルをアップロードしてビルド
oc start-build camel-app \
  --from-file=target/camel-observability-demo-1.0.0.jar \
  --follow

# デプロイ
oc new-app camel-app:latest
oc expose svc/camel-app
```

---

## 📊 各方法の比較

| 方法 | ローカルビルド | アーキテクチャ問題 | ビルド時間 | 推奨度 |
|-----|--------------|------------------|-----------|--------|
| **S2Iビルド** | 不要 | なし ✅ | 中 | ⭐⭐⭐⭐⭐ |
| **Binary Build** | 必要 (Maven) | なし ✅ | 短 | ⭐⭐⭐⭐ |
| **マルチアーキテクチャ** | 必要 (Podman) | 解決可能 ⚠️ | 長 | ⭐⭐⭐ |
| **ARM64ビルド** | 必要 | 動作しない ❌ | 短 | ❌ 使用不可 |

---

## 🔍 アーキテクチャの確認方法

### ローカルでビルドしたイメージ

```bash
# イメージのアーキテクチャを確認
podman inspect camel-observability-demo:1.0.0 --format='{{.Architecture}}'

# 期待される出力（OpenShift用）:
# amd64  ✅ OpenShiftで動作
# arm64  ❌ OpenShiftで動作しない
```

### OpenShift上の実行環境

```bash
# OpenShiftのノードアーキテクチャを確認
oc get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'

# 通常の出力:
# amd64 amd64 amd64  ← x86_64環境
```

---

## ⚠️ よくある問題

### 問題1: ARM64イメージをデプロイして起動しない

```bash
# ログを確認
oc logs deployment/camel-app

# エラーメッセージ:
exec /usr/bin/java: exec format error
```

**原因**: アーキテクチャの不一致

**解決策**: x86_64イメージを再ビルドするか、S2Iを使用

### 問題2: マルチアーキテクチャビルドが遅い

```bash
# Apple Siliconでamd64をビルドするとエミュレーションが発生
podman build --platform linux/amd64 ...
```

**原因**: QEMUエミュレーターによるパフォーマンス低下

**解決策**: 
- S2Iビルドを使用（推奨）
- CI/CDパイプラインでx86_64環境でビルド

### 問題3: マルチプラットフォーム対応が必要

```bash
# Buildah を使ってマルチアーキテクチャビルド
buildah bud \
  --platform linux/amd64,linux/arm64 \
  --manifest camel-observability-demo:1.0.0 \
  .
```

---

## 🎯 推奨ワークフロー

### 開発環境（Apple Silicon ローカル）

```bash
# ローカル実行用（ARM64）
cd camel-app
podman build -t camel-observability-demo:1.0.0-local .

# ローカルでテスト
podman run -d -p 8080:8080 camel-observability-demo:1.0.0-local
```

### OpenShiftデプロイ

**オプションA: S2Iビルド（推奨）**
```bash
# GitHubにプッシュ後
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_REPO/... \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --strategy=source
```

**オプションB: Binary Build**
```bash
# ローカルでMavenビルド
mvn clean package -DskipTests

# OpenShiftにアップロード
oc new-build --name=camel-app --image-stream=openjdk-17:latest --binary=true
oc start-build camel-app --from-file=target/camel-observability-demo-1.0.0.jar --follow
```

---

## 📝 Dockerfileの修正（参考）

### ローカル用（ARM64）

```dockerfile
# Apple Silicon用
FROM eclipse-temurin:17-jre
# ... (現在のDockerfile)
```

### OpenShift用（x86_64）

```dockerfile
# OpenShift用（同じDockerfileだが --platform で指定）
FROM eclipse-temurin:17-jre
# ... (同じ内容)
```

**ビルド時に指定**:
```bash
# ローカル用
podman build -t camel-app:local .

# OpenShift用
podman build --platform linux/amd64 -t camel-app:openshift .
```

---

## 🔧 トラブルシューティング

### QEMUがインストールされていない

```bash
# macOSの場合
brew install qemu

# Podmanを再起動
podman machine stop
podman machine start
```

### マルチアーキテクチャビルドが失敗する

```bash
# エラー:
exec /bin/sh: exec format error
```

**解決策**: S2IまたはBinary Buildを使用

---

## 🎯 まとめ

### ✅ 推奨される方法

| 環境 | 方法 | 理由 |
|-----|------|------|
| **OpenShift** | S2Iビルド | アーキテクチャを気にする必要なし、最もシンプル |
| **ローカル開発** | 通常ビルド (ARM64) | 高速、ローカルテストに最適 |

### ⚠️ 避けるべき方法

- ❌ Apple SiliconでビルドしたARM64イメージをOpenShiftにデプロイ
- ❌ アーキテクチャを確認せずにイメージをプッシュ

### 💡 ベストプラクティス

1. **開発**: ローカル（ARM64）でビルド・テスト
2. **デプロイ**: OpenShiftでS2Iビルド（自動的にx86_64）
3. **確認**: 常にアーキテクチャを確認する習慣をつける

---

## 🚀 クイックリファレンス

```bash
# ローカル開発（Apple Silicon）
cd camel-app
podman build -t camel-app:local .
podman run -d -p 8080:8080 camel-app:local

# OpenShiftデプロイ（S2I）
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_REPO/... \
  --name=camel-app \
  --context-dir=demo/camel-app

# アーキテクチャ確認
podman inspect IMAGE --format='{{.Architecture}}'
oc get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'
```

---

**重要**: OpenShiftへのデプロイには**S2Iビルド**を強く推奨します！ 🎯



