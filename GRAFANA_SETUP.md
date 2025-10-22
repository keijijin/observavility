# Grafana ダッシュボードのセットアップ

## 問題

自動プロビジョニングでダッシュボードが表示されない場合があります。

## 解決方法：手動でダッシュボードをインポート

### 1. Grafanaにアクセス

1. ブラウザで http://localhost:3000 を開く
2. ログイン
   - ユーザー名: `admin`
   - パスワード: `admin`
3. 初回ログイン後、パスワード変更を求められたら「Skip」をクリック

### 2. ダッシュボードをインポート

#### 方法1: JSONファイルを使用（推奨）

1. 左側のメニューで「Dashboards」をクリック
2. 右上の「New」→「Import」をクリック
3. 「Upload JSON file」ボタンをクリック
4. 以下のファイルを選択：
   ```
   /Users/kjin/mobills/observability/demo/docker/grafana/provisioning/dashboards/camel-dashboard.json
   ```
5. 「Load」をクリック
6. 「Import」をクリック

#### 方法2: 新しいダッシュボードを作成

1. 左側のメニューで「Dashboards」をクリック
2. 右上の「New」→「New Dashboard」をクリック
3. 「Add visualization」をクリック
4. データソースで「Prometheus」を選択

### 3. 基本的なパネルを追加

#### JVMメモリ使用量

1. 「Add visualization」をクリック
2. データソースで「Prometheus」を選択
3. メトリクスブラウザで以下のクエリを入力：
   ```
   jvm_memory_used_bytes{application="camel-observability-demo"}
   ```
4. 「Run queries」をクリック
5. パネルタイトルを「JVM Memory Usage」に設定
6. 右上の「Apply」をクリック

#### HTTPリクエストレート

1. 「Add panel」→「Add visualization」をクリック
2. データソースで「Prometheus」を選択
3. クエリを入力：
   ```
   rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
   ```
4. パネルタイトルを「HTTP Request Rate」に設定
5. 「Apply」をクリック

#### アプリケーション稼働時間

1. 「Add panel」→「Add visualization」をクリック
2. データソースで「Prometheus」を選択
3. クエリを入力：
   ```
   process_uptime_seconds{application="camel-observability-demo"}
   ```
4. 可視化タイプを「Stat」に変更
5. パネルタイトルを「Application Uptime」に設定
6. 「Apply」をクリック

#### JVMスレッド数

1. 「Add panel」→「Add visualization」をクリック
2. データソースで「Prometheus」を選択
3. クエリを入力：
   ```
   jvm_threads_live_threads{application="camel-observability-demo"}
   ```
4. 可視化タイプを「Stat」に変更
5. パネルタイトルを「JVM Threads」に設定
6. 「Apply」をクリック

### 4. ダッシュボードを保存

1. 右上の「Save dashboard」アイコン（フロッピーディスク）をクリック
2. ダッシュボード名を入力：`Camel Observability Dashboard`
3. 「Save」をクリック

## 有用なPrometheusクエリ

### JVM関連
```promql
# ヒープメモリ使用量
jvm_memory_used_bytes{application="camel-observability-demo",area="heap"}

# 非ヒープメモリ使用量
jvm_memory_used_bytes{application="camel-observability-demo",area="nonheap"}

# GC停止時間
rate(jvm_gc_pause_seconds_sum[1m])

# スレッド数
jvm_threads_live_threads{application="camel-observability-demo"}
```

### HTTP関連
```promql
# リクエストレート
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# レスポンスタイム（平均）
rate(http_server_requests_seconds_sum{application="camel-observability-demo"}[1m]) / 
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])

# ステータスコード別リクエスト数
http_server_requests_seconds_count{application="camel-observability-demo"}
```

### プロセス関連
```promql
# 稼働時間
process_uptime_seconds{application="camel-observability-demo"}

# CPU使用率
process_cpu_usage{application="camel-observability-demo"}

# オープンファイルディスクリプタ
process_files_open_files{application="camel-observability-demo"}
```

## データソースの確認

### Prometheusデータソースが設定されているか確認

1. 左側のメニューで「Connections」→「Data sources」をクリック
2. 「Prometheus」が表示されているか確認
3. クリックして詳細を確認：
   - URL: `http://prometheus:9090`
   - Access: `Server (default)`
4. 「Save & test」をクリックして接続を確認

### Tempoデータソースの確認

1. 「Data sources」ページで「Tempo」を探す
2. 設定を確認：
   - URL: `http://tempo:3200`

### Lokiデータソースの確認

1. 「Data sources」ページで「Loki」を探す
2. 設定を確認：
   - URL: `http://localhost:3100`

## トラブルシューティング

### データソースが表示されない

データソースを手動で追加：

1. 「Connections」→「Data sources」→「Add data source」
2. 「Prometheus」を選択
3. 設定：
   - Name: `Prometheus`
   - URL: `http://prometheus:9090`
   - Access: `Server (default)`
4. 「Save & test」をクリック

### メトリクスが表示されない

1. Prometheusが正しくメトリクスを収集しているか確認：
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

2. アプリケーションがメトリクスをエクスポートしているか確認：
   ```bash
   curl http://localhost:8080/actuator/prometheus | grep jvm_memory
   ```

### パネルにデータが表示されない

1. クエリが正しいか確認
2. 時間範囲を調整（右上のtime picker）
3. 「Refresh dashboard」ボタンをクリック

## 参考リンク

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Micrometer Metrics](https://micrometer.io/docs/concepts)



