# Podman使用時の注意事項

このデモは **Podman** を使用するように設定されています。Docker Composeファイルは Podman Compose と互換性があります。

## 🐳 PodmanとDockerの違い

### Podmanの利点
- **デーモンレス**: バックグラウンドデーモンが不要
- **Rootlessモード**: root権限なしでコンテナを実行可能
- **セキュリティ**: より安全なデフォルト設定
- **Docker CLI互換**: 多くのdockerコマンドがそのまま使える

### 主な変更点

1. **ホストアクセス**
   - Docker: `host.docker.internal`
   - Podman: `host.containers.internal`

2. **コマンド**
   - `docker` → `podman`
   - `docker-compose` → `podman-compose` または `podman compose`

3. **ボリュームマウント（Linux）**
   - SELinuxを使用している場合、`:Z` フラグが必要な場合があります
   ```yaml
   volumes:
     - ./logs:/logs:Z
   ```

## 🚀 Podman Machine（Mac/Windows）

Mac や Windows では、Podman Machine という軽量VMを使用します：

```bash
# 初期化（初回のみ）
podman machine init

# 起動
podman machine start

# 状態確認
podman machine list

# SSH接続
podman machine ssh

# 停止
podman machine stop

# 削除
podman machine rm
```

### リソース設定

デフォルトのリソースで不足する場合：
```bash
# Podman Machineの再作成（CPUとメモリを増やす）
podman machine stop
podman machine rm
podman machine init --cpus=4 --memory=8192 --disk-size=50
podman machine start
```

## 🔧 トラブルシューティング

### 1. "connection refused" エラー

Podman Machineが起動しているか確認：
```bash
podman machine list
podman machine start
```

### 2. ホストからコンテナにアクセスできない

`docker/prometheus/prometheus.yml` を確認：

**Mac/Windows:**
```yaml
- targets: ['host.containers.internal:8080']
```

**Linux:**
```yaml
- targets: ['localhost:8080']
```

または、ホストのIPアドレスを取得：
```bash
# Mac/Windows (Podman Machine内)
podman machine ssh
ip addr show
```

### 3. ボリュームのパーミッションエラー（Linux）

SELinuxが有効な場合、ボリュームマウントに `:Z` を追加：
```yaml
volumes:
  - ./logs:/logs:Z
```

または SELinux を一時的に無効化：
```bash
sudo setenforce 0
```

### 4. podman-compose が見つからない

インストール：
```bash
pip3 install podman-compose
```

または、podman compose プラグインを使用：
```bash
podman compose version
```

### 5. コンテナが起動しない

ログを確認：
```bash
podman logs <container-name>
podman ps -a
```

すべてのコンテナを再起動：
```bash
podman-compose down
podman-compose up -d
```

## 📊 パフォーマンス

Podmanは一般的にDockerと同等かそれ以上のパフォーマンスを提供します。ただし、Mac/Windows では Podman Machine（VM）を使用するため、若干のオーバーヘッドがあります。

### パフォーマンスチューニング

1. **Podman Machine のリソース増加**
   ```bash
   podman machine stop
   podman machine rm
   podman machine init --cpus=4 --memory=8192
   podman machine start
   ```

2. **ボリュームマウントの最適化**
   - 大量のファイルI/Oがある場合、`:cached` オプションを検討
   ```yaml
   volumes:
     - ./logs:/logs:cached
   ```

## 🔄 DockerからPodmanへの移行

既存のDocker環境からの移行は簡単です：

1. **Dockerコンテナを停止**
   ```bash
   docker-compose down
   ```

2. **Podmanをインストール**
   ```bash
   brew install podman podman-compose
   podman machine init
   podman machine start
   ```

3. **docker-compose.yml はそのまま使用可能**
   ```bash
   podman-compose up -d
   ```

4. **エイリアスを設定（オプション）**
   ```bash
   # ~/.bashrc または ~/.zshrc に追加
   alias docker='podman'
   alias docker-compose='podman-compose'
   ```

## 📚 参考リンク

- [Podman公式サイト](https://podman.io/)
- [Podman Desktop](https://podman-desktop.io/) - GUIツール
- [Podman Compose](https://github.com/containers/podman-compose)
- [DockerからPodmanへの移行ガイド](https://podman.io/getting-started/installation)

## 💡 ヒント

- **Podman Desktop**: GUIでコンテナを管理したい場合は Podman Desktop をインストール
- **Docker互換性**: 多くの場合 `docker` を `podman` に置き換えるだけで動作します
- **セキュリティ**: Rootlessモードを活用してセキュリティを強化



