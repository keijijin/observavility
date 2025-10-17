# 🚨 アラート機能の現在の状態

## ✅ 設定完了項目

### 1. **Prometheusアラートルール**
- ファイル: `docker/prometheus/alert_rules.yml`
- アラート数: **13件**
  - クリティカル: 5件
  - 警告: 6件
  - 情報: 2件
- 状態: **有効化済み** ✅

### 2. **視覚的閾値（Grafanaダッシュボード）**
- ダッシュボード: `camel-comprehensive-dashboard.json`
- 色分け設定: 緑/黄/橙/赤
- 状態: **設定済み** ✅

---

## 📊 アラート一覧

### 🔴 クリティカルアラート（即座の対応が必要）

| # | アラート名 | 閾値 | 持続時間 | 説明 |
|---|----------|------|---------|------|
| 1 | **HighMemoryUsage** | >90% | 2分 | ヒープメモリ使用率が危険レベル |
| 2 | **HighErrorRate** | >10% | 2分 | Camelルートのエラー率が高い |
| 3 | **HighHTTPErrorRate** | >5% | 2分 | HTTP 5xxエラーが多発 |
| 4 | **HighGCOverhead** | >20% | 5分 | GCオーバーヘッドが高すぎる |
| 5 | **ApplicationDown** | - | 1分 | アプリケーションがダウン |

### 🟡 警告アラート（注意が必要）

| # | アラート名 | 閾値 | 持続時間 | 説明 |
|---|----------|------|---------|------|
| 6 | **ModerateMemoryUsage** | >70% | 5分 | メモリ使用率が高め |
| 7 | **HighCPUUsage** | >80% | 5分 | CPU使用率が高い |
| 8 | **SlowResponseTime** | >1秒 | 3分 | レスポンスタイムが遅い |
| 9 | **HighInflightMessages** | >100件 | 3分 | 処理中メッセージが多い |
| 10 | **HighThreadCount** | >100個 | 5分 | スレッド数が多い |
| 11 | **ModerateGCOverhead** | >10% | 5分 | GCオーバーヘッドが高め |

### ℹ️ 情報アラート（参考情報）

| # | アラート名 | 閾値 | 持続時間 | 説明 |
|---|----------|------|---------|------|
| 12 | **FrequentGarbageCollection** | >30回/分 | 5分 | GC実行頻度が高い |
| 13 | **ApplicationRestarted** | - | 1分 | アプリケーションが再起動 |

---

## 🔍 アラート確認方法

### 1. **Prometheus Web UI**（推奨）
```
http://localhost:9090/alerts
```

ここで以下を確認できます：
- アラートの状態（Inactive / Pending / Firing）
- 現在の値
- いつから発火しているか

### 2. **コマンドライン**
```bash
# 全アラートの状態を確認
curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[] | select(.type == "alerting") | "\(.name): \(.state)"'

# 発火中のアラートのみ表示
curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[] | select(.type == "alerting" and .state == "firing") | "\(.name): \(.labels)"'
```

---

## 🧪 アラートのテスト方法

### テスト1: エラー率アラート（HighErrorRate）

本デモでは、支払い処理で約10%の確率でエラーが発生します。

```bash
cd /Users/kjin/mobills/observability/demo

# 大量のリクエストを送信（2分間）
./load-test-concurrent.sh -r 200 -c 30 -d 120

# 2-3分後、Prometheusでアラート確認
open http://localhost:9090/alerts
```

**期待される結果:**
1. 最初は「Inactive」
2. エラー率が10%を超えると「Pending」（黄色）
3. 2分間継続すると「Firing」（赤色） 🔴

### テスト2: メモリ使用率アラート（ModerateMemoryUsage）

```bash
# ストレステストで負荷をかける
./load-test-stress.sh

# メモリ使用率をリアルタイムで確認
watch -n 5 'curl -s "http://localhost:9090/api/v1/query?query=jvm_memory_used_bytes%7Barea%3D%22heap%22%7D%2Fjvm_memory_max_bytes%7Barea%3D%22heap%22%7D" | jq ".data.result[0].value[1]"'
```

**期待される結果:**
- メモリ使用率が70%を超えると「ModerateMemoryUsage」が発火

### テスト3: アプリケーションダウンアラート（ApplicationDown）

```bash
# アプリケーションを停止
pkill -f spring-boot:run

# 1分後、Prometheusでアラート確認
# 「ApplicationDown」が Firing になるはず

# 再起動
cd camel-app
mvn spring-boot:run
```

---

## 📈 現在の状態

### アラートの状態（例）

すべてのアラートが正常な場合：
```
HighMemoryUsage: inactive
HighErrorRate: inactive
HighHTTPErrorRate: inactive
HighGCOverhead: inactive
ApplicationDown: inactive
ModerateMemoryUsage: inactive
HighCPUUsage: inactive
SlowResponseTime: inactive
HighInflightMessages: inactive
HighThreadCount: inactive
ModerateGCOverhead: inactive
FrequentGarbageCollection: inactive
ApplicationRestarted: inactive
```

---

## ⚠️ 未実装機能

### 通知機能（Alertmanager）

現在、アラートが発火しても**通知は送られません**。

**実装されている:**
- ✅ アラートルールの評価
- ✅ アラート状態の表示（Prometheus Web UI）
- ✅ Grafanaダッシュボードでの視覚化

**実装されていない:**
- ❌ Slack通知
- ❌ Email通知
- ❌ PagerDuty通知
- ❌ Webhook通知

### 通知機能を追加する方法

詳細は **[ALERTING_GUIDE.md](ALERTING_GUIDE.md)** の「通知設定（オプション）」セクションを参照してください。

簡単な手順：
1. Alertmanagerコンテナを追加
2. `alertmanager.yml` を設定
3. Slack Webhook URLなどを設定
4. Prometheusに接続

---

## 🎯 現在のアラート機能まとめ

| 機能 | 状態 | 説明 |
|-----|------|------|
| **アラートルール定義** | ✅ 完了 | 13件のアラートルール設定済み |
| **アラート評価** | ✅ 稼働中 | Prometheusが15秒ごとに評価 |
| **アラート状態表示** | ✅ 利用可能 | http://localhost:9090/alerts で確認 |
| **視覚的閾値** | ✅ 設定済み | Grafanaダッシュボードで色分け |
| **通知機能** | ❌ 未実装 | Alertmanager設定が必要 |

---

## 💡 推奨アクション

### 1. **現在の状態を確認**
```bash
# ブラウザで確認
open http://localhost:9090/alerts

# すべて "inactive" なら正常
```

### 2. **負荷テストでアラートをテスト**
```bash
cd /Users/kjin/mobills/observability/demo
./load-test-concurrent.sh -r 200 -c 30 -d 120

# 2-3分後に再度確認
open http://localhost:9090/alerts
```

### 3. **Grafanaで視覚的に確認**
```bash
# ダッシュボードを開く
open http://localhost:3000/d/camel-comprehensive

# メモリ使用率やエラー率が閾値を超えると色が変わる
# 緑 → 黄 → 橙 → 赤
```

### 4. **通知機能が必要な場合**
[ALERTING_GUIDE.md](ALERTING_GUIDE.md) を参照して、Alertmanagerを設定してください。

---

## 📚 関連ドキュメント

- **[ALERTING_GUIDE.md](ALERTING_GUIDE.md)** - アラート設定の詳細ガイド
- **[METRICS_GUIDE.md](METRICS_GUIDE.md)** - メトリクス体系ガイド
- **[DASHBOARD_GUIDE.md](DASHBOARD_GUIDE.md)** - ダッシュボード利用ガイド

---

**最終更新:** 2025年10月15日
**アラートバージョン:** v1.0


