# 🎉 Apple Silicon (ARM64) でのビルド成功ガイド

## 問題の経緯

Podman 5.5.0でイメージをビルドしようとした際、以下のエラーが発生しました:

```
ERRO[xxxx] 1 error occurred:
	* archive/tar: write too long
```

## 根本原因

### 1. ビルドコンテキストに巨大なファイルが含まれていた

```bash
logs/                   769MB  ← 主な原因
  application.2025-10-15.json  602MB
  application.json             136MB
  application.2025-10-14.json   17MB
app.log                 1.8MB
```

**合計**: 約770MB の不要なファイル

### 2. ベースイメージがARM64非対応

```dockerfile
FROM eclipse-temurin:17-jre-alpine  # ← ARM64イメージなし
```

エラー:
```
no image found in image index for architecture "arm64", variant "v8", OS "linux"
```

### 3. ユーザー作成コマンドの構文エラー

Alpine構文 (`addgroup -S`) をDebian/Ubuntu版で使用していた。

---

## 解決手順

### ステップ1: ログファイルを削除

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# logs/ ディレクトリを削除
rm -rf logs/

# app.log を削除
rm -f app.log

# ビルドコンテキストサイズを確認
du -sh .
# 結果: 63M (元々は834M)
```

### ステップ2: .dockerignore を更新

```bash
# logs/ と *.log を .dockerignore に追加
cat >> .dockerignore << 'EOF'
logs/
app.log
*.log
EOF
```

### ステップ3: Dockerfile を修正（ARM64対応）

#### 変更1: ベースイメージをARM64対応版に変更

```dockerfile
# 修正前
FROM eclipse-temurin:17-jre-alpine

# 修正後
FROM eclipse-temurin:17-jre  # ARM64対応
```

#### 変更2: ユーザー作成コマンドをDebian/Ubuntu構文に変更

```dockerfile
# 修正前 (Alpine構文)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

# 修正後 (Debian/Ubuntu構文)
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --create-home --home-dir /app appuser && \
    chown -R appuser:appgroup /app
```

### ステップ4: ビルド実行

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# Podmanでビルド
podman build -t camel-observability-demo:1.0.0 .
```

**結果**:
```
Successfully tagged localhost/camel-observability-demo:1.0.0
```

---

## 修正後のDockerfile全体

```dockerfile
# Multi-stage build for Camel App
# ビルドコンテキストは camel-app ディレクトリ

# Stage 1: Build
FROM maven:3.9.5-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime (ARM64 compatible)
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy JAR from build stage
COPY --from=build /app/target/camel-observability-demo-1.0.0.jar app.jar

# Create non-root user for security (Debian/Ubuntu syntax)
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --create-home --home-dir /app appuser && \
    chown -R appuser:appgroup /app
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# JVM optimization
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom \
               -XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0"

# Run application
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
```

---

## 更新された .dockerignore

```
# Maven
target/
!target/camel-observability-demo-1.0.0.jar
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar

# IDE
.idea/
.vscode/
*.iml
*.ipr
*.iws
.project
.classpath
.settings/

# OS
.DS_Store
Thumbs.db

# Logs (重要！)
*.log
logs/
app.log

# Temporary files
*.tmp
*.bak
*.swp
*~
```

---

## ベストプラクティス

### 1. ログファイルの管理

**問題**: アプリケーションが生成するログファイルがビルドコンテキストに含まれる

**解決策**:
- ログは常に `logs/` ディレクトリに出力
- `.dockerignore` に `logs/` と `*.log` を追加
- 定期的に `logs/` を削除またはローテーション

```bash
# ビルド前に実行
rm -rf camel-app/logs/ camel-app/*.log
```

### 2. Apple Silicon (M1/M2/M3) でのイメージ選択

**ARM64対応イメージを選ぶ**:

| ベースイメージ | ARM64対応 | 推奨 |
|--------------|---------|------|
| `eclipse-temurin:17-jre` | ✅ | ⭐⭐⭐⭐⭐ |
| `eclipse-temurin:17-jre-alpine` | ❌ | 使用不可 |
| `amazoncorretto:17` | ✅ | ⭐⭐⭐⭐ |
| `openjdk:17-jre-slim` | ✅ | ⭐⭐⭐ |

### 3. ビルドコンテキストの最適化

```bash
# ビルドコンテキストサイズを確認
du -sh camel-app/

# ファイル数を確認
find camel-app/ -type f | wc -l

# 大きなファイルを確認
find camel-app/ -type f -exec ls -lh {} \; | sort -k5 -h -r | head -10
```

**推奨サイズ**: < 100MB

### 4. Multi-stage build の活用

```dockerfile
# Stage 1: 依存関係のダウンロード + ビルド
FROM maven:... AS build

# Stage 2: 軽量なランタイムイメージ
FROM eclipse-temurin:17-jre
COPY --from=build /app/target/*.jar app.jar
```

**メリット**:
- 最終イメージサイズが小さい
- ビルドツール（Maven等）を含まない
- セキュリティリスクが低い

---

## トラブルシューティング

### ビルドが遅い

```bash
# Maven依存関係をキャッシュ
podman build --layers -t camel-observability-demo:1.0.0 .
```

### イメージサイズが大きすぎる

```bash
# イメージサイズを確認
podman images camel-observability-demo:1.0.0

# レイヤーごとのサイズを確認
podman history camel-observability-demo:1.0.0
```

### HEALTHCHECK 警告

```
level=warning msg="HEALTHCHECK is not supported for OCI image format..."
```

**原因**: PodmanのデフォルトはOCI形式で、HEALTHCHECKをサポートしていない

**解決策**: 無視して問題なし。Kubernetes/OpenShiftでは別途ヘルスチェックを定義。

---

## 検証

### イメージの確認

```bash
# イメージ一覧
podman images | grep camel-observability-demo

# イメージの詳細
podman inspect camel-observability-demo:1.0.0
```

### イメージのテスト

```bash
# コンテナを起動
podman run -d --name camel-app-test -p 8080:8080 camel-observability-demo:1.0.0

# ログを確認
podman logs -f camel-app-test

# ヘルスチェック
curl http://localhost:8080/actuator/health

# クリーンアップ
podman stop camel-app-test
podman rm camel-app-test
```

---

## まとめ

### 問題

1. ❌ Podman 5.5.0 の `archive/tar: write too long` エラー
2. ❌ 巨大なログファイル (769MB) がビルドコンテキストに含まれていた
3. ❌ ベースイメージがARM64非対応
4. ❌ ユーザー作成コマンドの構文エラー

### 解決策

1. ✅ ログファイルを削除 (`rm -rf logs/ *.log`)
2. ✅ `.dockerignore` を更新 (logs/ と *.log を追加)
3. ✅ ARM64対応ベースイメージに変更 (`eclipse-temurin:17-jre`)
4. ✅ Debian/Ubuntu構文に修正 (`groupadd` / `useradd`)

### 結果

✅ **ビルド成功！**
```
Successfully tagged localhost/camel-observability-demo:1.0.0
```

---

## 今後のビルドコマンド

```bash
# シンプルなビルド（推奨）
cd /Users/kjin/mobills/observability/demo/camel-app
podman build -t camel-observability-demo:1.0.0 .

# キャッシュを使わずビルド
podman build --no-cache -t camel-observability-demo:1.0.0 .

# 進捗を詳しく表示
podman build --progress=plain -t camel-observability-demo:1.0.0 .
```

---

**これでApple Siliconで完璧にビルドできます！** 🎉




