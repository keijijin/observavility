# 負荷テストガイド

Camel Observability Demoの負荷テストツールです。オブザーバビリティの効果を実際に確認できます。

## 📝 テストスクリプト一覧

### 1. `load-test-simple.sh` - シンプルな負荷テスト

順次リクエストを送信する基本的な負荷テスト。

**使用方法:**
```bash
./load-test-simple.sh -c 50 -i 0.5
```

**オプション:**
- `-c COUNT` - リクエスト数（デフォルト: 10）
- `-i INTERVAL` - リクエスト間隔（秒、デフォルト: 1）
- `-h` - ヘルプを表示

**例:**
```bash
# 100リクエストを1秒間隔で送信
./load-test-simple.sh -c 100 -i 1

# 50リクエストを0.5秒間隔で送信（より高頻度）
./load-test-simple.sh -c 50 -i 0.5
```

### 2. `load-test-concurrent.sh` - 並行負荷テスト

複数の同時接続で負荷をかけるテスト。実際のトラフィックパターンをシミュレート。

**使用方法:**
```bash
./load-test-concurrent.sh -r 500 -c 20 -d 60
```

**オプション:**
- `-r REQUESTS` - 総リクエスト数（デフォルト: 100）
- `-c CONCURRENT` - 同時接続数（デフォルト: 10）
- `-d DURATION` - 最大継続時間（秒、デフォルト: 30）
- `-h` - ヘルプを表示

**例:**
```bash
# 20並列で500リクエスト
./load-test-concurrent.sh -r 500 -c 20 -d 60

# 50並列で1000リクエスト（高負荷）
./load-test-concurrent.sh -r 1000 -c 50 -d 120
```

### 3. `load-test-stress.sh` - ストレステスト

段階的に負荷を増やしてシステムの限界を探るテスト。

**使用方法:**
```bash
./load-test-stress.sh
```

**テスト段階:**
1. ウォームアップ (5並列、10秒)
2. 低負荷 (10並列、15秒)
3. 中負荷 (20並列、15秒)
4. 高負荷 (50並列、15秒)
5. ストレス (100並列、20秒)

## 🎯 推奨テストシナリオ

### シナリオ1: オブザーバビリティの基本確認

**目的:** メトリクス、トレース、ログの連携を確認

```bash
# 1. シンプルなテストを実行
./load-test-simple.sh -c 20 -i 2

# 2. Grafanaでメトリクスを確認
# http://localhost:3000

# 3. Tempoでトレースを確認
# Grafana → Explore → Tempo

# 4. ログを確認
tail -f camel-app/app.log
```

### シナリオ2: ボトルネックの発見

**目的:** 処理の遅い部分を特定

```bash
# 並行テストで負荷をかける
./load-test-concurrent.sh -r 200 -c 30 -d 45

# Tempoで処理時間が長いトレースを探す
# payment-processing-routeのボトルネックを確認
```

### シナリオ3: エラーハンドリングの確認

**目的:** エラーの発生とログの相関を確認

```bash
# 高負荷をかけてエラーを発生させる
./load-test-concurrent.sh -r 500 -c 50 -d 60

# エラーログを確認
tail -f camel-app/app.log | grep ERROR

# Lokiでエラーログを検索
# Grafana → Explore → Loki
# クエリ: {app="camel-observability-demo"} |= "ERROR"
```

### シナリオ4: システムの限界確認

**目的:** スケーラビリティとパフォーマンス限界を把握

```bash
# ストレステストを実行
./load-test-stress.sh

# 各段階でGrafanaを確認:
# - JVMメモリ使用量の増加
# - HTTPリクエストレートの推移
# - レスポンスタイムの劣化ポイント
```

## 📊 オブザーバビリティツールでの確認方法

### Grafana（メトリクス）

1. **リアルタイムダッシュボード**
   - URL: http://localhost:3000
   - メトリクス例:
     - `jvm_memory_used_bytes` - メモリ使用量
     - `http_server_requests_seconds_count` - リクエスト数
     - `process_cpu_usage` - CPU使用率

2. **Exploreモード**
   - 左メニュー → Explore
   - データソース: Prometheus
   - カスタムクエリを実行

### Prometheus（メトリクス詳細）

URL: http://localhost:9090

**有用なクエリ:**

```promql
# リクエストレート（過去1分間）
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# 平均レスポンスタイム
rate(http_server_requests_seconds_sum{application="camel-observability-demo"}[1m]) / 
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# JVMヒープメモリ使用量
jvm_memory_used_bytes{application="camel-observability-demo",area="heap"}

# スレッド数
jvm_threads_live_threads{application="camel-observability-demo"}
```

### Tempo（トレース）

1. Grafana → Explore → Tempo
2. 「Search」でトレースを検索
3. 処理時間が長いトレースをクリック

**確認ポイント:**
- 全体の処理フロー
- 各ステップの処理時間
- ボトルネックの特定（payment-processing-route）

### Loki（ログ）

1. Grafana → Explore → Loki
2. クエリ例:

```logql
# すべてのログ
{app="camel-observability-demo"}

# エラーログのみ
{app="camel-observability-demo"} |= "ERROR"

# 特定のルートのログ
{app="camel-observability-demo"} |= "payment-processing"

# トレースIDで検索
{app="camel-observability-demo"} |= "trace_id=abc-123"
```

## 🔍 確認すべきポイント

### 1. メトリクス

- **HTTPリクエストレート**: 負荷に応じて増加
- **レスポンスタイム**: 負荷が高いと増加
- **JVMメモリ**: 徐々に増加、GCで減少
- **スレッド数**: 並行処理で増加

### 2. トレース

- **処理フロー**: order-consumer → validate → payment → shipping
- **ボトルネック**: payment-processing-routeが200-500ms
- **エラートレース**: 約10%の確率でエラー発生

### 3. ログ

- **処理ログ**: 各ステップの実行ログ
- **エラーログ**: 失敗したオーダーの詳細
- **トレースIDの相関**: ログとトレースの紐付け

## ⚠️ 注意事項

### リソース消費

- ストレステストは大量のリクエストを送信します
- システムリソース（CPU、メモリ）を消費します
- ローカル環境での実行を推奨

### 推奨スペック

- CPU: 4コア以上
- メモリ: 8GB以上
- ディスク: 十分な空き容量

### テスト実行時の推奨事項

1. **事前準備**
   - すべてのサービスが起動していることを確認
   - Grafanaでダッシュボードを開いておく

2. **テスト中**
   - Grafanaでリアルタイム監視
   - システムリソースの確認（Activity MonitorやTop）

3. **テスト後**
   - メトリクスの推移を分析
   - トレースで詳細調査
   - ログで根本原因を確認

## 🚀 高度な使用例

### カスタム負荷パターン

```bash
# 1. ウォームアップ
./load-test-simple.sh -c 10 -i 1

# 2. 段階的に負荷を上げる
./load-test-concurrent.sh -r 50 -c 5 -d 10
./load-test-concurrent.sh -r 100 -c 10 -d 15
./load-test-concurrent.sh -r 200 -c 20 -d 20

# 3. クールダウン
sleep 30

# 4. 再度負荷をかける
./load-test-concurrent.sh -r 300 -c 30 -d 30
```

### 長時間テスト

```bash
# 5分間継続的に負荷をかける
./load-test-concurrent.sh -r 10000 -c 25 -d 300
```

### パフォーマンス比較

```bash
# テスト1: 低並列
./load-test-concurrent.sh -r 200 -c 10 -d 40 > results_10c.txt

# 少し待機
sleep 60

# テスト2: 高並列
./load-test-concurrent.sh -r 200 -c 50 -d 40 > results_50c.txt

# 結果を比較
diff results_10c.txt results_50c.txt
```

## 📚 参考情報

### オブザーバビリティの三本柱との対応

| 柱 | 確認内容 | ツール |
|----|---------|--------|
| メトリクス | リクエスト数、レスポンスタイム、リソース使用量 | Prometheus, Grafana |
| トレース | 処理フロー、ボトルネック | Tempo |
| ログ | エラー詳細、処理ログ | Loki |

### トラブルシューティング

**問題: リクエストが失敗する**
- アプリケーションが起動しているか確認
- エンドポイントが正しいか確認
- ログでエラーを確認

**問題: メトリクスが表示されない**
- Prometheusがメトリクスを収集しているか確認
- Grafanaのデータソースが正しく設定されているか確認

**問題: テストが遅い**
- 並行数を調整
- リクエスト数を減らす
- システムリソースを確認

## 💡 ヒント

1. **まずは小さく始める**: load-test-simple.shから始めて、徐々に負荷を上げる
2. **リアルタイム監視**: テスト実行中はGrafanaを開いておく
3. **結果を記録**: スクリーンショットやメトリクスを保存して比較
4. **複数回実行**: 一貫性のある結果を得るために複数回テスト

---

**楽しいオブザーバビリティ体験を！** 🎉



