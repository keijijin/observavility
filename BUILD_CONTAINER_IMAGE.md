# 🐳 コンテナイメージのビルドガイド

Camel Observability Demoのコンテナイメージをビルドする方法を説明します。

---

## 📋 前提条件

以下のいずれかが必要です:
- Podman
- Docker

```bash
# Podmanの場合
podman --version

# Dockerの場合
docker --version
```

---

## 🚀 ビルド方法

### 方法1: camel-app ディレクトリから直接ビルド（推奨）

最もシンプルな方法です。

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# Podmanでビルド
podman build -t camel-observability-demo:1.0.0 .

# または Dockerでビルド
docker build -t camel-observability-demo:1.0.0 .
```

**ビルド時間**: 初回 約3-5分（依存関係のダウンロード含む）

**作成されるイメージサイズ**: 約400-500MB

---

### 方法2: プロジェクトルートから OpenShift 用 Dockerfile を使用

OpenShift用のDockerfileを使う場合:

```bash
cd /Users/kjin/mobills/observability/demo

# Podmanでビルド（-f でDockerfileを指定、最後の引数がビルドコンテキスト）
podman build -f openshift/Dockerfile -t camel-observability-demo:1.0.0 camel-app/

# または Dockerでビルド
docker build -f openshift/Dockerfile -t camel-observability-demo:1.0.0 camel-app/
```

**注意**: 
- `-f openshift/Dockerfile`: Dockerfileのパスを指定
- `camel-app/`: ビルドコンテキスト（pom.xml と src/ があるディレクトリ）

---

## 🔍 2つのDockerfileの違い

### camel-app/Dockerfile
- **用途**: ローカル開発、一般的なKubernetes環境
- **ビルドコンテキスト**: `camel-app/` ディレクトリ
- **コマンド**: `cd camel-app && podman build -t camel-app:1.0.0 .`

### openshift/Dockerfile
- **用途**: OpenShiftデプロイメント
- **ビルドコンテキスト**: `camel-app/` ディレクトリ（プロジェクトルートから指定）
- **コマンド**: `podman build -f openshift/Dockerfile -t camel-app:1.0.0 camel-app/`

**内容はほぼ同じですが、パス構造が異なります。**

---

## ✅ ビルド成功の確認

### イメージが作成されたか確認

```bash
# Podmanの場合
podman images | grep camel-observability-demo

# Dockerの場合
docker images | grep camel-observability-demo
```

**期待される出力:**
```
camel-observability-demo  1.0.0  xxxxx  2 minutes ago  450 MB
```

---

## 🧪 ローカルでイメージをテスト

### コンテナを起動

```bash
# Podmanの場合
podman run -d --name camel-app-test \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=default \
  camel-observability-demo:1.0.0

# Dockerの場合
docker run -d --name camel-app-test \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=default \
  camel-observability-demo:1.0.0
```

### ヘルスチェック

```bash
# コンテナが起動するまで待機（約30秒）
sleep 30

# ヘルスチェック
curl http://localhost:8080/actuator/health

# 期待される出力:
# {"status":"UP"}
```

### アプリケーション情報の確認

```bash
curl http://localhost:8080/actuator/info

# Camelバージョンなどが表示される
```

### コンテナのログ確認

```bash
# Podmanの場合
podman logs camel-app-test

# Dockerの場合
docker logs camel-app-test
```

### コンテナを停止・削除

```bash
# Podmanの場合
podman stop camel-app-test
podman rm camel-app-test

# Dockerの場合
docker stop camel-app-test
docker rm camel-app-test
```

---

## 📦 イメージの詳細

### Multi-stage Build の構造

```dockerfile
# Stage 1: ビルドステージ (Maven)
FROM maven:3.9.5-eclipse-temurin-17 AS build
# → pom.xml と src/ をコピー
# → mvn clean package を実行
# → JAR ファイルを生成

# Stage 2: ランタイムステージ (軽量JRE)
FROM eclipse-temurin:17-jre-alpine
# → Stage 1 から JAR ファイルのみコピー
# → 非rootユーザーで実行
# → ヘルスチェック設定
# → JVM最適化オプション
```

**メリット:**
- 最終イメージにMavenやソースコードが含まれない
- イメージサイズが小さい（約450MB vs 1GB以上）
- セキュリティ向上（ビルドツールが含まれない）

### セキュリティ機能

```dockerfile
# 非rootユーザーで実行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

### JVM最適化

```dockerfile
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom \
               -XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0"
```

- `+UseContainerSupport`: コンテナのメモリ制限を認識
- `MaxRAMPercentage=75.0`: 利用可能メモリの75%までヒープに使用

### ヘルスチェック

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
```

---

## 🚢 レジストリへのプッシュ

### Docker Hub へプッシュ

```bash
# Docker Hubにログイン
podman login docker.io

# イメージをタグ付け
podman tag camel-observability-demo:1.0.0 docker.io/YOUR_USERNAME/camel-observability-demo:1.0.0

# プッシュ
podman push docker.io/YOUR_USERNAME/camel-observability-demo:1.0.0
```

### OpenShift内部レジストリへプッシュ

詳細は `/Users/kjin/mobills/observability/demo/openshift/BUILD_IMAGE_GUIDE.md` を参照してください。

```bash
# レジストリのホスト名を取得
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')

# ログイン
TOKEN=$(oc whoami -t)
podman login -u $(oc whoami) -p $TOKEN $REGISTRY --tls-verify=false

# タグ付け
podman tag camel-observability-demo:1.0.0 $REGISTRY/camel-observability-demo/camel-app:1.0.0

# プッシュ
podman push $REGISTRY/camel-observability-demo/camel-app:1.0.0 --tls-verify=false
```

---

## 🔄 イメージの更新

### コードを変更した後

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# 再ビルド（キャッシュを利用して高速化）
podman build -t camel-observability-demo:1.0.0 .

# または新しいバージョンタグで
podman build -t camel-observability-demo:1.0.1 .
```

### キャッシュを使わずにビルド

```bash
# Podman
podman build --no-cache -t camel-observability-demo:1.0.0 .

# Docker
docker build --no-cache -t camel-observability-demo:1.0.0 .
```

---

## 🐛 トラブルシューティング

### ビルドエラー: Maven依存関係の解決に失敗

```bash
# 原因: ネットワーク問題、またはMaven Central障害
# 解決策: リトライするか、--no-cache でビルド

podman build --no-cache -t camel-observability-demo:1.0.0 .
```

### ビルドエラー: JARファイルが見つからない

```bash
# 原因: pom.xmlのバージョンと実際のJARファイル名が一致しない
# 解決策: pom.xmlの<version>を確認

grep '<version>' pom.xml | head -5

# Dockerfileの COPY --from=build の行を確認
grep "COPY --from=build" Dockerfile
```

### イメージサイズが大きすぎる

```bash
# Multi-stage buildを使用しているか確認
grep "FROM.*AS build" Dockerfile

# .dockerignore が適切に設定されているか確認
cat .dockerignore
```

### ヘルスチェックが失敗する

```bash
# コンテナ内でヘルスチェックを手動実行
podman exec camel-app-test wget -qO- http://localhost:8080/actuator/health

# アプリケーションが起動しているか確認
podman logs camel-app-test
```

---

## 📊 ビルド時間とイメージサイズ

### 標準的な環境での目安

| ビルドタイプ | 初回ビルド | 2回目以降 | イメージサイズ |
|------------|----------|----------|--------------|
| Multi-stage | 3-5分 | 1-2分 | 約450MB |
| Single-stage | 2-3分 | 1-2分 | 約1GB以上 |

**Multi-stage buildを使用することで:**
- イメージサイズ: 50%以上削減
- セキュリティ: ビルドツール不要
- 起動時間: わずかに高速化

---

## 🎯 まとめ

### 推奨されるワークフロー

```bash
# 1. camel-appディレクトリに移動
cd /Users/kjin/mobills/observability/demo/camel-app

# 2. コードを編集
# vim src/main/java/com/example/demo/...

# 3. ビルド
podman build -t camel-observability-demo:1.0.0 .

# 4. ローカルテスト
podman run -d --name test -p 8080:8080 camel-observability-demo:1.0.0
curl http://localhost:8080/actuator/health

# 5. 問題なければ、レジストリにプッシュ
podman push ...
```

### チェックリスト

- ✅ Dockerfileが存在する (`camel-app/Dockerfile`)
- ✅ .dockerignoreが設定されている
- ✅ pom.xmlのバージョンが正しい
- ✅ Multi-stage buildを使用している
- ✅ 非rootユーザーで実行している
- ✅ ヘルスチェックが設定されている
- ✅ JVM最適化オプションが設定されている

---

**これでコンテナイメージのビルドは完璧です！**🐳



