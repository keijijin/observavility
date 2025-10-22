# 🐳 Podman セットアップガイド

このプロジェクトでは、Dockerの代わりにPodmanを使用します。

## 📋 前提条件

### Podmanのインストール

#### macOS
```bash
brew install podman
```

#### Linux (RHEL/Fedora)
```bash
sudo dnf install podman
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install podman
```

### Podman Machineの初期化（macOS/Windows）

```bash
# Podman Machineの初期化
podman machine init

# Podman Machineの起動
podman machine start

# 状態確認
podman machine list
```

### Podman Composeのインストール

#### 方法1: pip経由（推奨）

```bash
pip3 install podman-compose
```

#### 方法2: Podman Compose プラグイン

最新のPodmanには`podman compose`プラグインが含まれています：

```bash
# プラグインの確認
podman compose version
```

## 🚀 使い方

### 基本コマンド

```bash
# コンテナ一覧
podman ps

# すべてのコンテナ（停止中も含む）
podman ps -a

# イメージ一覧
podman images

# ログ確認
podman logs <container-name>

# コンテナに入る
podman exec -it <container-name> /bin/bash
```

### Podman Composeコマンド

#### podman-compose使用時

```bash
# 起動
podman-compose up -d

# 停止
podman-compose down

# 再起動
podman-compose restart

# ログ確認
podman-compose logs -f

# 特定のサービスのみ再起動
podman-compose restart grafana
```

#### podman compose プラグイン使用時

```bash
# 起動
podman compose up -d

# 停止
podman compose down

# 再起動
podman compose restart

# ログ確認
podman compose logs -f

# 特定のサービスのみ再起動
podman compose restart grafana
```

## 🔧 このプロジェクトでの使用方法

### デモ環境の起動

```bash
cd demo
./start-demo.sh
```

このスクリプトは自動的に以下を実行します：
1. Podman環境の確認
2. `podman-compose`または`podman compose`の検出
3. インフラストラクチャの起動

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
```

## 🔍 トラブルシューティング

### 1. Podman Machineが起動しない（macOS/Windows）

```bash
# Machineの削除
podman machine rm

# 再初期化
podman machine init

# 起動
podman machine start
```

### 2. ポートが使用中

```bash
# 使用中のポートを確認
podman ps --format "table {{.Names}}\t{{.Ports}}"

# 競合しているコンテナを停止
podman stop <container-name>
```

### 3. ボリュームマウントの問題（macOS/Windows）

Podman Machineを使用している場合、ホームディレクトリ配下のみマウント可能です。

```bash
# Machineの設定を確認
podman machine inspect

# ボリュームマウント設定を更新
podman machine set --volume /Users:/Users
podman machine set --volume /private:/private
```

### 4. Rootlessモードでの権限問題

```bash
# UID/GIDマッピングを確認
podman unshare cat /proc/self/uid_map
podman unshare cat /proc/self/gid_map

# サブUID/サブGIDの確認
cat /etc/subuid
cat /etc/subgid
```

### 5. compose-composeが見つからない

```bash
# pip3でインストール
pip3 install --user podman-compose

# パスを確認
which podman-compose

# パスが通っていない場合
export PATH="$HOME/.local/bin:$PATH"
# .bashrc または .zshrc に追加
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## 📊 Dockerとの違い

### コマンドの違い

| Docker | Podman |
|---|---|
| `docker ps` | `podman ps` |
| `docker-compose up` | `podman-compose up` または `podman compose up` |
| `docker logs` | `podman logs` |
| `docker exec` | `podman exec` |
| `docker images` | `podman images` |

### 主な違い

1. **Rootless**: Podmanはデフォルトでrootless（非特権）で実行
2. **デーモンレス**: Podmanはバックグラウンドデーモンを必要としない
3. **互換性**: Dockerと高い互換性を持つ
4. **セキュリティ**: より高いセキュリティレベル

## 🎯 推奨設定

### エイリアスの設定（オプション）

Dockerコマンドに慣れている場合、エイリアスを設定できます：

```bash
# .bashrc または .zshrc に追加
alias docker=podman
alias docker-compose=podman-compose
```

**注意**: このプロジェクトでは既にPodmanを前提としているため、エイリアスは不要です。

## 📚 関連リソース

- **Podman公式サイト**: https://podman.io/
- **Podman Desktop**: https://podman-desktop.io/
- **Podman Compose**: https://github.com/containers/podman-compose
- **Podman Documentation**: https://docs.podman.io/

## 💡 ヒント

### パフォーマンス最適化

```bash
# macOS/WindowsでのPodman Machine設定
podman machine set --cpus 4
podman machine set --memory 8192
podman machine set --disk-size 50
```

### ログの確認

```bash
# すべてのコンテナのログ
podman-compose logs

# 特定のサービスのログ
podman-compose logs grafana

# リアルタイムでログを追跡
podman-compose logs -f grafana
```

### リソースのクリーンアップ

```bash
# 停止中のコンテナを削除
podman container prune

# 未使用のイメージを削除
podman image prune

# 未使用のボリュームを削除
podman volume prune

# すべて削除（注意！）
podman system prune -a --volumes
```

## ✅ 動作確認

### Podman環境のテスト

```bash
# Podmanのバージョン確認
podman --version

# Podman Composeのバージョン確認
podman-compose --version
# または
podman compose version

# テストコンテナの実行
podman run --rm hello-world

# Podman情報の表示
podman info
```

## 🎉 準備完了

Podman環境が整ったら、以下のコマンドでデモを開始できます：

```bash
cd demo
./start-demo.sh
```

お疲れ様でした！ 🚀

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

