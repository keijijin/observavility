# 🐳 Podman移行完了サマリー

Docker ComposeからPodman Composeへの移行が完了しました。

## ✅ 完了した作業

### 1. スクリプトの対応 ✅

以下のスクリプトは既にPodman対応済みです：

#### `start-demo.sh`
- Podman環境の自動チェック
- `podman-compose`と`podman compose`の両方に対応
- 自動検出とフォールバック機能

#### `stop-demo.sh`
- Podmanコマンドの自動検出
- クリーンな停止処理

### 2. ドキュメントの更新 ✅

以下のドキュメントをPodman用に更新しました：

| ファイル | 更新内容 |
|---|---|
| `DASHBOARD_DEPLOYMENT_GUIDE.md` | docker-compose → podman-compose |
| `DASHBOARD_DEPLOYMENT_SUMMARY.md` | コマンド例とPodman注意事項を追加 |
| `KAFKA_METRICS_FIX.md` | docker → podman |
| `LOKI_TROUBLESHOOTING.md` | docker-compose.yml注釈を更新 |
| `README.md` | docker-compose.yml注釈を更新 |

### 3. 新規ドキュメント作成 ✅

#### `PODMAN_SETUP_GUIDE.md`（新規）
包括的なPodmanセットアップガイド：
- インストール手順（macOS/Linux）
- Podman Machineの初期化
- Podman Composeのインストール
- 基本コマンド
- トラブルシューティング
- Dockerとの違い

#### `PODMAN_MIGRATION_SUMMARY.md`（このファイル）
移行作業のサマリー

## 🚀 使い方

### デモ環境の起動

```bash
cd demo
./start-demo.sh
```

このスクリプトが自動的に：
1. Podman環境をチェック
2. `podman-compose`または`podman compose`を検出
3. インフラストラクチャを起動

### デモ環境の停止

```bash
cd demo
./stop-demo.sh
```

### Grafanaの再起動

```bash
cd demo

# 方法1: podman-composeを使用
podman-compose restart grafana

# 方法2: podman compose プラグインを使用  
podman compose restart grafana

# 方法3: スクリプトを使用（推奨）
./stop-demo.sh
./start-demo.sh
```

## 📋 コマンド対応表

| 目的 | Docker Compose | Podman Compose |
|---|---|---|
| 起動 | `docker-compose up -d` | `podman-compose up -d` または `podman compose up -d` |
| 停止 | `docker-compose down` | `podman-compose down` または `podman compose down` |
| 再起動 | `docker-compose restart` | `podman-compose restart` または `podman compose restart` |
| ログ確認 | `docker-compose logs -f` | `podman-compose logs -f` または `podman compose logs -f` |
| コンテナ一覧 | `docker ps` | `podman ps` |
| ログ確認 | `docker logs <name>` | `podman logs <name>` |
| コンテナに入る | `docker exec -it <name> /bin/bash` | `podman exec -it <name> /bin/bash` |

## 🔍 トラブルシューティング

### Podmanがインストールされていない

```bash
# macOS
brew install podman

# RHEL/Fedora
sudo dnf install podman

# Ubuntu/Debian
sudo apt-get install podman
```

### Podman Machineが起動していない（macOS/Windows）

```bash
# 初期化
podman machine init

# 起動
podman machine start

# 確認
podman machine list
```

### podman-composeが見つからない

```bash
# pip3でインストール
pip3 install podman-compose

# または、podman compose プラグインを使用
podman compose version
```

### ポートが使用中

```bash
# 使用中のポートを確認
podman ps --format "table {{.Names}}\t{{.Ports}}"

# 競合しているコンテナを停止
podman stop <container-name>
```

### コンテナが起動しない

```bash
# ログを確認
podman-compose logs

# 特定のサービスのログ
podman-compose logs grafana

# コンテナの状態確認
podman ps -a
```

## 💡 重要なポイント

### 1. スクリプトを使用する（推奨）

```bash
# 起動
./start-demo.sh

# 停止
./stop-demo.sh
```

これらのスクリプトは：
- ✅ Podman環境を自動チェック
- ✅ 適切なComposeコマンドを自動選択
- ✅ エラーハンドリング
- ✅ 分かりやすい出力

### 2. Podman Composeのコマンド

**podman-compose**（Python実装）:
```bash
podman-compose up -d
podman-compose down
podman-compose restart grafana
```

**podman compose**（プラグイン）:
```bash
podman compose up -d
podman compose down
podman compose restart grafana
```

どちらを使用しても問題ありません。`start-demo.sh`が自動的に検出します。

### 3. Rootlessモード

Podmanはデフォルトでrootless（非特権）で実行されます：
- ✅ より高いセキュリティ
- ✅ sudoが不要
- ⚠️ 一部のポート（<1024）は追加設定が必要

### 4. ボリュームマウント（macOS/Windows）

Podman Machineを使用する場合：
- ホームディレクトリ配下のみマウント可能
- `/Users`、`/home`配下であれば問題なし
- このプロジェクトは既に対応済み

## 📊 動作確認

### 1. Podman環境の確認

```bash
# Podmanのバージョン
podman --version

# Podman Composeのバージョン
podman-compose --version
# または
podman compose version

# Podman情報
podman info
```

### 2. デモ環境の起動

```bash
cd demo
./start-demo.sh
```

### 3. サービスの確認

```bash
# コンテナ一覧
podman ps

# 期待される出力: 以下のコンテナが Running 状態
# - kafka
# - zookeeper
# - prometheus
# - grafana
# - tempo
# - loki
```

### 4. Grafanaへのアクセス

ブラウザで http://localhost:3000 にアクセス
- ユーザー名: `admin`
- パスワード: `admin`

## 🎯 次のステップ

1. **Podman環境のセットアップ**
   - `PODMAN_SETUP_GUIDE.md`を参照
   - Podmanのインストール
   - Podman Composeのインストール

2. **デモ環境の起動**
   ```bash
   cd demo
   ./start-demo.sh
   ```

3. **Camelアプリケーションの起動**
   ```bash
   cd camel-app
   mvn clean install
   mvn spring-boot:run
   ```

4. **Grafanaダッシュボードの確認**
   - http://localhost:3000
   - 統合ダッシュボードを開く

## 📚 関連ドキュメント

### Podman関連
- **`PODMAN_SETUP_GUIDE.md`** - Podman詳細セットアップガイド（新規）
- **`PODMAN_NOTES.md`** - Podman使用時の注意事項
- **`PODMAN_ISSUE_WORKAROUND.md`** - 既知の問題と回避策

### ダッシュボード関連
- **`DASHBOARD_DEPLOYMENT_GUIDE.md`** - ダッシュボードデプロイ手順（Podman対応済み）
- **`DASHBOARD_DEPLOYMENT_SUMMARY.md`** - デプロイ完了サマリー（Podman対応済み）
- **`DASHBOARD_README.md`** - ダッシュボード詳細説明

### トラブルシューティング
- **`LOKI_TROUBLESHOOTING.md`** - Loki関連問題（Podman対応済み）
- **`KAFKA_METRICS_FIX.md`** - Kafkaメトリクス問題（Podman対応済み）
- **`GRAFANA_DASHBOARD_TROUBLESHOOTING.md`** - Grafana問題

## ✅ チェックリスト

デモ環境を起動する前に：

- [ ] Podmanがインストールされている（`podman --version`）
- [ ] Podman Machineが起動している（macOS/Windows: `podman machine list`）
- [ ] Podman Composeがインストールされている（`podman-compose --version`または`podman compose version`）
- [ ] ポート3000, 8080, 9090, 3100, 3200, 9092が空いている
- [ ] 必要なディスク容量がある（約10GB）

すべてチェックできたら：

```bash
cd demo
./start-demo.sh
```

## 🎉 完了！

Podmanへの移行が完了し、すべてのドキュメントとスクリプトが更新されました。

**スクリプトを使用すれば、Docker ComposeとPodman Composeの違いを意識する必要はありません！**

お疲れ様でした！ 🚀

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

