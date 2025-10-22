# 🚀 クイックスタートガイド

## 最速でデモを開始する（5分）

### 前提条件

Podmanがインストールされていることを確認：
```bash
podman --version
podman-compose --version  # または podman compose version
```

未インストールの場合：
```bash
# macOS
brew install podman podman-compose
podman machine init
podman machine start

# Linux
sudo dnf install podman  # Fedora/RHEL
pip3 install podman-compose
```

### 1. インフラを起動（1分）

```bash
cd demo
chmod +x start-demo.sh
./start-demo.sh
```

### 2. Camelアプリを起動（3分）

**別のターミナルを開いて：**

```bash
cd demo/camel-app
mvn clean install
mvn spring-boot:run
```

起動メッセージが表示されるまで待機。

### 3. 動作確認（1分）

```bash
# ヘルスチェック
curl http://localhost:8080/camel/api/health

# オーダーを手動作成
curl -X POST http://localhost:8080/camel/api/orders
```

## 📊 オブザーバビリティを体感する

### Grafanaでダッシュボードを見る

1. ブラウザで http://localhost:3000 を開く
2. ログイン（admin / admin）
3. "Camel Observability Dashboard" を選択
4. リアルタイムでメトリクスを確認

### トレースを確認する

1. Grafana の左メニューから "Explore" を選択
2. データソースで "Tempo" を選択
3. "Search" をクリック
4. トレースをクリックして詳細を確認

### ログを確認する

1. Grafana の "Explore" でデータソースを "Loki" に変更
2. クエリ: `{app="camel-observability-demo"}`
3. エラーログを絞り込み: `{app="camel-observability-demo"} |= "ERROR"`
4. トレースIDで検索: `{app="camel-observability-demo"} | json | trace_id="<32文字のID>"`

**💡 重要:** トレースIDで検索する場合、必ず `| json` パーサーを使用してください。詳細は [LOKI_QUERY_FIXES.md](LOKI_QUERY_FIXES.md) を参照。

## 🔍 デモシナリオ

### シナリオ1: エラーの原因を特定する

1. **メトリクス**: Grafanaでエラー率の上昇を確認
2. **トレース**: Tempoで失敗したトレースを見つける
3. **トレースIDをコピー**: トレース画面上部の32文字の16進数を全文コピー
4. **ログ**: LokiでトレースIDを検索
   ```logql
   {app="camel-observability-demo"} | json | trace_id="<コピーしたID>"
   ```
5. **根本原因**: エラーメッセージを確認

### シナリオ2: ボトルネックを発見する

1. **メトリクス**: "Processing Time" グラフで遅いルートを特定
2. **トレース**: 処理時間が長いトレースを開く
3. **分析**: `payment-processing-route` が200-500msかかっていることを確認

## 🛑 停止する

```bash
cd demo
./stop-demo.sh

# または手動で
podman-compose down
# podman compose down
```

Camelアプリは `Ctrl + C` で停止。

### Podman Machineも停止（Mac/Windows）

```bash
podman machine stop
```

## 💡 次のステップ

### 📚 さらに詳しく学ぶ

- **[OBSERVABILITY_EXPERIENCE.md](OBSERVABILITY_EXPERIENCE.md)** - オブザーバビリティ体験ガイド（推奨！）
  - 負荷テストを使った実践的な学習
  - メトリクス、トレース、ログの使い方をステップバイステップで体験
  - 所要時間：約50分

- **[README.md](README.md)** - 詳細な手順とトラブルシューティング

- **[LOAD_TESTING.md](LOAD_TESTING.md)** - 負荷テストの詳細ガイド

---

**楽しいオブザーバビリティ体験を！** 🎉

