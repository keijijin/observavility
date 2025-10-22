# 🚨 アラート設定ガイド

## 📋 概要

このガイドでは、SpringBoot + Camel + Kafkaアプリケーションのアラート設定について説明します。

**現在の状況:**
- ✅ **視覚的閾値**: Grafanaダッシュボードに色分け設定済み
- ✅ **Prometheusアラートルール**: 設定ファイル作成済み（要有効化）
- ❌ **通知機能**: 未設定（このガイドで設定方法を説明）

---

## 🎯 アラートの種類

### 1. **クリティカルアラート** 🔴 (severity: critical)
即座の対応が必要な重大な問題

| アラート名 | 閾値 | 持続時間 | 説明 |
|----------|------|---------|------|
| **HighMemoryUsage** | >90% | 2分 | ヒープメモリ使用率が危険 |
| **HighErrorRate** | >10% | 2分 | Camelルートエラー率が高い |
| **HighHTTPErrorRate** | >5% | 2分 | HTTP 5xxエラーが多い |
| **HighGCOverhead** | >20% | 5分 | GCオーバーヘッドが高い |
| **ApplicationDown** | - | 1分 | アプリケーションがダウン |

### 2. **警告アラート** 🟡 (severity: warning)
注意が必要だが、即座の対応は不要

| アラート名 | 閾値 | 持続時間 | 説明 |
|----------|------|---------|------|
| **ModerateMemoryUsage** | >70% | 5分 | メモリ使用率が高め |
| **HighCPUUsage** | >80% | 5分 | CPU使用率が高い |
| **SlowResponseTime** | >1秒 | 3分 | レスポンスタイムが遅い |
| **HighInflightMessages** | >100件 | 3分 | 処理中メッセージが多い |
| **HighThreadCount** | >100個 | 5分 | スレッド数が多い |
| **ModerateGCOverhead** | >10% | 5分 | GCオーバーヘッドが高め |

### 3. **情報アラート** ℹ️ (severity: info)
参考情報として通知

| アラート名 | 閾値 | 持続時間 | 説明 |
|----------|------|---------|------|
| **FrequentGarbageCollection** | >30回/分 | 5分 | GC実行頻度が高い |
| **ApplicationRestarted** | - | 1分 | アプリケーションが再起動 |

---

## 🚀 アラート有効化手順

### 方法1: Prometheusアラート（推奨）

#### ステップ1: Prometheusを再起動

アラートルールファイルを読み込むために、Prometheusを再起動します。

```bash
cd /Users/kjin/mobills/observability/demo
podman restart prometheus
```

#### ステップ2: アラートルールの確認

Prometheusでアラートルールが読み込まれたか確認：

```bash
# ブラウザで開く
open http://localhost:9090/alerts

# または curl で確認
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | {alert: .name, state: .state}'
```

**正常な場合の出力:**
```json
{
  "alert": "HighMemoryUsage",
  "state": "inactive"
}
{
  "alert": "HighErrorRate",
  "state": "inactive"
}
...
```

#### ステップ3: アラートのテスト

負荷をかけてアラートが発火するか確認：

```bash
# 高負荷をかける
./load-test-stress.sh

# Prometheusでアラート状態を確認
open http://localhost:9090/alerts
```

**アラートの状態:**
- 🟢 **Inactive**: 正常（閾値以下）
- 🟡 **Pending**: 閾値超えたが、持続時間未達
- 🔴 **Firing**: アラート発火中！

---

## 📧 通知設定（オプション）

### Alertmanagerを使った通知

#### ステップ1: Alertmanagerの設定ファイル作成

```bash
mkdir -p docker/alertmanager
```

**`docker/alertmanager/alertmanager.yml`:**
```yaml
global:
  resolve_timeout: 5m

# ルート設定
route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  
  # 重要度別のルーティング
  routes:
    - match:
        severity: critical
      receiver: 'critical-receiver'
      repeat_interval: 30m
    
    - match:
        severity: warning
      receiver: 'warning-receiver'
      repeat_interval: 1h
    
    - match:
        severity: info
      receiver: 'info-receiver'
      repeat_interval: 3h

# 受信者設定
receivers:
  - name: 'default-receiver'
    # デフォルトは何もしない
    
  - name: 'critical-receiver'
    # Slackへの通知（要設定）
    # slack_configs:
    #   - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    #     channel: '#alerts-critical'
    #     title: '🚨 クリティカルアラート'
    #     text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'
    
    # Emailへの通知（要設定）
    # email_configs:
    #   - to: 'your-email@example.com'
    #     from: 'alertmanager@example.com'
    #     smarthost: 'smtp.gmail.com:587'
    #     auth_username: 'your-email@example.com'
    #     auth_password: 'your-app-password'
    
  - name: 'warning-receiver'
    # 警告用の通知先
    
  - name: 'info-receiver'
    # 情報用の通知先

# アラートの抑制設定
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

#### ステップ2: docker-compose.ymlにAlertmanagerを追加

**`docker-compose.yml` に追加:**
```yaml
  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./docker/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:Z
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped
```

#### ステップ3: Prometheusにalertmanager設定を追加

**`docker/prometheus/prometheus.yml` に追加:**
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

#### ステップ4: サービスを起動

```bash
podman-compose up -d alertmanager
podman restart prometheus
```

#### ステップ5: Alertmanagerの確認

```
http://localhost:9093
```

---

## 📊 Grafanaアラート（簡易版）

Grafanaの組み込みアラート機能を使う方法

### ステップ1: Grafanaでアラートを作成

1. ダッシュボードを開く
   ```
   http://localhost:3000/d/camel-comprehensive
   ```

2. 任意のパネルの右上 → **「...」** → **「Edit」**

3. 左サイドバーから **「Alert」** タブをクリック

4. **「Create alert rule from this panel」** をクリック

5. アラート条件を設定：
   ```
   例: ヒープメモリ使用率が90%超え
   
   条件:
   WHEN avg() OF query(A, 5m, now) IS ABOVE 0.9
   
   評価間隔: 1m
   For: 2m
   ```

6. **通知先を設定** （Contact pointsで設定）

7. **「Save」** をクリック

### ステップ2: Contact Pointsの設定

1. **Alerting** → **Contact points** → **「New contact point」**

2. 通知先を選択：
   - **Email**
   - **Slack**
   - **Webhook**
   - **Discord**
   - **PagerDuty**
   など

3. 必要な情報を入力して **「Test」** → **「Save contact point」**

---

## 🧪 アラートのテスト

### 1. メモリ使用率アラートのテスト

```bash
# メモリを大量に使う処理を実行
curl -X POST http://localhost:8080/camel/api/orders

# 高負荷をかける
cd /Users/kjin/mobills/observability/demo
./load-test-stress.sh
```

**確認:**
```bash
# Prometheusでアラート状態を確認
open http://localhost:9090/alerts

# 2-5分待つと "Pending" → "Firing" に変わる
```

### 2. エラー率アラートのテスト

本デモでは、支払い処理で約10%の確率でエラーが発生するように設定されています。

```bash
# 大量のリクエストを送信
./load-test-concurrent.sh -r 200 -c 30 -d 120

# 2-3分後、エラー率が10%を超えるとアラート発火
```

### 3. アプリケーションダウンアラートのテスト

```bash
# アプリケーションを停止
pkill -f spring-boot:run

# 1分後、ApplicationDownアラートが発火

# 再起動
cd camel-app
mvn spring-boot:run
```

---

## 📝 アラート設定のベストプラクティス

### 1. **適切な閾値設定**
- 本番環境の実データに基づいて調整
- 誤検知（False Positive）を減らす
- 見逃し（False Negative）を防ぐ

### 2. **持続時間の設定**
- 一時的なスパイクでアラートを出さない
- クリティカル: 1-2分
- 警告: 3-5分
- 情報: 5-10分

### 3. **アラートの階層化**
```
Level 1: Critical（即座の対応）
         ↓
Level 2: Warning（監視強化）
         ↓
Level 3: Info（参考情報）
```

### 4. **通知先の使い分け**
- **Critical**: Slack + Email + PagerDuty（24時間対応）
- **Warning**: Slack（営業時間内対応）
- **Info**: ログのみ（通知不要）

### 5. **アラート疲れの防止**
- 重複アラートを抑制（inhibit_rules）
- 繰り返し通知の間隔を調整（repeat_interval）
- 重要でないアラートは削除

---

## 🔧 トラブルシューティング

### Q1: アラートルールが読み込まれない

**A:** Prometheusログを確認：
```bash
podman logs prometheus | grep -i error

# 設定ファイルの構文チェック
podman exec prometheus promtool check rules /etc/prometheus/alert_rules.yml
```

### Q2: アラートが発火しない

**A:** 以下を確認：
1. メトリクスが正しく収集されているか
   ```bash
   curl -s http://localhost:9090/api/v1/query?query=jvm_memory_used_bytes
   ```

2. アラート式が正しいか
   ```bash
   # Prometheusの「Graph」タブでクエリを実行
   (jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.9
   ```

3. 持続時間（for:）が長すぎないか

### Q3: 通知が届かない

**A:** Alertmanagerログを確認：
```bash
podman logs alertmanager | tail -50

# Alertmanagerの状態確認
curl http://localhost:9093/api/v2/status
```

---

## 📚 アラートクエリリファレンス

### メモリ関連

```promql
# ヒープメモリ使用率
(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.9

# ヒープメモリ増加率
rate(jvm_memory_used_bytes{area="heap"}[5m]) > 10000000  # 10MB/sec

# GCオーバーヘッド
jvm_gc_overhead_percent > 20
```

### Camel関連

```promql
# エラー率
(rate(camel_exchanges_failed_total[5m]) / rate(camel_exchanges_total[5m])) > 0.1

# 処理中メッセージ
camel_exchanges_inflight > 100

# 平均処理時間
(rate(camel_route_policy_seconds_sum[5m]) / rate(camel_route_policy_seconds_count[5m])) > 2
```

### HTTP関連

```promql
# HTTPエラー率（5xx）
(rate(http_server_requests_seconds_count{status=~"5.."}[5m]) / 
 rate(http_server_requests_seconds_count[5m])) > 0.05

# 平均レスポンスタイム
(rate(http_server_requests_seconds_sum[5m]) / 
 rate(http_server_requests_seconds_count[5m])) > 1

# リクエストレート急増
rate(http_server_requests_seconds_count[5m]) > 100
```

---

## 🎯 まとめ

### アラート設定の3ステップ

```
1️⃣ Prometheusアラートルール作成（完了✅）
   ↓
2️⃣ Prometheus再起動して有効化
   ↓
3️⃣ Alertmanagerで通知先設定（オプション）
```

### 現在の状況

| 項目 | 状態 | アクション |
|-----|------|----------|
| アラートルール | ✅ 作成済み | Prometheus再起動 |
| 視覚的閾値 | ✅ 設定済み | なし |
| 通知機能 | ⚠️ 未設定 | Alertmanager設定 |

### 最小限の設定で始める

```bash
# 1. Prometheusを再起動（アラートルール有効化）
podman restart prometheus

# 2. アラート確認
open http://localhost:9090/alerts

# 3. 負荷テストでアラート発火を確認
./load-test-stress.sh
```

これで、アラートが発火すると、Prometheusの `/alerts` ページで確認できます！

**通知が必要な場合は、Alertmanagerを追加設定してください。**

---

## 📖 関連ドキュメント

- **[METRICS_GUIDE.md](METRICS_GUIDE.md)** - メトリクス体系ガイド
- **[DASHBOARD_GUIDE.md](DASHBOARD_GUIDE.md)** - ダッシュボード利用ガイド
- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)



