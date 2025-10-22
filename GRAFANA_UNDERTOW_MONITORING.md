# Grafana Undertowキューサイズ監視ガイド

## ✅ **結論**

1. **Grafanaで監視できます** ✅
2. **監視すべきです** ⭐ **最重要メトリクスの1つ**

---

## 🎯 **なぜUndertowキューサイズを監視すべきか？**

### 1. パフォーマンス問題の早期発見 ⚠️

```
Queue Size = 0  ✅ すべてのリクエストが即座に処理されている
Queue Size > 0  ⚠️ リクエストが待機している = パフォーマンス低下
Queue Size > 50 🚨 深刻な問題 = ユーザー影響大
```

### 2. スケーリングの判断材料 📈

キューサイズが継続的に増加 = **スケールアウトが必要**

### 3. 障害の予兆検知 🔍

- **突然のスパイク**: 異常なトラフィック増加
- **緩やかな増加**: データベースのスロークエリ、外部API遅延
- **一定の高水準**: キャパシティ不足

---

## 📊 **Grafana監視設定**

### 方法1: 既存ダッシュボードに追加（推奨）

#### ステップ1: Grafanaにログイン

```bash
# Grafana URL
http://localhost:3000

# デフォルト認証情報
Username: admin
Password: admin
```

#### ステップ2: ダッシュボードを開く

1. **Dashboards** → **Browse**
2. **Camel Comprehensive Dashboard** を開く

#### ステップ3: パネルを追加

1. 右上の **Add panel** をクリック
2. **Add a new panel** を選択
3. 以下の設定を入力

---

## 📈 **推奨PromQLクエリ**

### 1. Undertowキューサイズ（最重要）⭐

```promql
# 現在のキューサイズ
undertow_request_queue_size{application="camel-observability-demo"}
```

**パネル設定:**
- **Title**: Undertow Queue Size
- **Unit**: short
- **Thresholds**: 
  - Yellow: 10
  - Red: 50

### 2. Undertow使用率

```promql
# ワーカースレッド使用率（%）
(undertow_active_requests{application="camel-observability-demo"} / undertow_worker_threads{application="camel-observability-demo"}) * 100
```

**パネル設定:**
- **Title**: Undertow Worker Usage (%)
- **Unit**: percent (0-100)
- **Thresholds**:
  - Yellow: 70
  - Orange: 85
  - Red: 95

### 3. アクティブリクエスト vs ワーカースレッド

```promql
# アクティブリクエスト数
undertow_active_requests{application="camel-observability-demo"}

# ワーカースレッド数（最大）
undertow_worker_threads{application="camel-observability-demo"}
```

**パネル設定:**
- **Title**: Undertow Active Requests vs Workers
- **Visualization**: Time series
- **Legend**: {{__name__}}

### 4. Undertowスループット

```promql
# 秒間処理リクエスト数（推定）
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
```

**パネル設定:**
- **Title**: Undertow Throughput (req/sec)
- **Unit**: reqps (requests per second)

---

## 🎨 **完全なダッシュボード構成例**

### Row 1: Undertow Overview

| Panel | Query | 重要度 |
|---|---|---|
| **Queue Size** | `undertow_request_queue_size` | ⭐⭐⭐ |
| **Active Requests** | `undertow_active_requests` | ⭐⭐ |
| **Worker Threads** | `undertow_worker_threads` | ⭐ |
| **I/O Threads** | `undertow_io_threads` | ⭐ |

### Row 2: Undertow Performance

| Panel | Query | 重要度 |
|---|---|---|
| **Usage %** | `(active / workers) * 100` | ⭐⭐⭐ |
| **Throughput** | `rate(http_requests[1m])` | ⭐⭐ |
| **Response Time** | `histogram_quantile(0.99, ...)` | ⭐⭐ |

---

## 🚨 **推奨アラート設定**

### Prometheusアラートルール

`docker/prometheus/alert_rules.yml`に追加：

```yaml
groups:
  - name: undertow-alerts
    rules:
      # キューサイズアラート（最重要）
      - alert: HighUndertowQueueSize
        expr: undertow_request_queue_size{application="camel-observability-demo"} > 50
        for: 2m
        labels:
          severity: warning
          component: undertow
        annotations:
          summary: "High Undertow Queue Size ({{ $labels.instance }})"
          description: "Undertow queue size is {{ $value }}. Requests are waiting to be processed. Consider scaling out."

      - alert: CriticalUndertowQueueSize
        expr: undertow_request_queue_size{application="camel-observability-demo"} > 100
        for: 1m
        labels:
          severity: critical
          component: undertow
        annotations:
          summary: "Critical Undertow Queue Size ({{ $labels.instance }})"
          description: "Undertow queue size is {{ $value }}. System is severely overloaded. Immediate action required."

      # 使用率アラート
      - alert: HighUndertowWorkerUsage
        expr: (undertow_active_requests{application="camel-observability-demo"} / undertow_worker_threads{application="camel-observability-demo"}) * 100 > 85
        for: 3m
        labels:
          severity: warning
          component: undertow
        annotations:
          summary: "High Undertow Worker Usage ({{ $labels.instance }})"
          description: "Undertow worker usage is at {{ $value | printf \"%.2f\" }}%. Approaching capacity limits."

      - alert: UndertowWorkersSaturated
        expr: (undertow_active_requests{application="camel-observability-demo"} / undertow_worker_threads{application="camel-observability-demo"}) * 100 > 95
        for: 2m
        labels:
          severity: critical
          component: undertow
        annotations:
          summary: "Undertow Workers Saturated ({{ $labels.instance }})"
          description: "Undertow worker usage is at {{ $value | printf \"%.2f\" }}%. All workers are busy. New requests will be queued."
```

---

## 📋 **監視すべき閾値**

### キューサイズ

| Queue Size | 状態 | アラート | 対応 |
|---|---|---|---|
| **0-10** | ✅ 正常 | なし | 監視継続 |
| **11-50** | ⚠️ 注意 | Info | 原因調査を開始 |
| **51-100** | 🟠 警告 | Warning | スレッド数増加を検討 |
| **101+** | 🚨 危険 | Critical | **即座のスケールアウト** |

### 使用率

| Usage % | 状態 | アラート | 対応 |
|---|---|---|---|
| **0-70%** | ✅ 正常 | なし | 問題なし |
| **71-85%** | ⚠️ 注意 | Info | 監視強化 |
| **86-95%** | 🟠 警告 | Warning | キャパシティ増強を検討 |
| **96-100%** | 🚨 危険 | Critical | **即座の対応** |

---

## 🧪 **動作確認**

### 1. 負荷テストでキューサイズを増やす

```bash
# 同時に500リクエストを送信
for i in {1..500}; do
  curl -X POST http://localhost:8080/camel/api/orders \
    -H "Content-Type: application/json" \
    -d '{"id": "ORD-'$i'", "product": "LoadTest", "quantity": 1, "price": 100}' \
    > /dev/null 2>&1 &
done

# キューサイズを確認
curl -s http://localhost:8080/actuator/prometheus | grep "undertow_request_queue_size"
```

### 2. Grafanaで確認

1. Grafanaダッシュボードを開く
2. **Undertow Queue Size**パネルを確認
3. リアルタイムでキューサイズの増加を確認

### 3. thread_monitor.shで確認

```bash
./thread_monitor.sh 1

# 出力例
  Undertow:
    Workers: 200 | Active: 150 | Queue: 35 | Usage: 75.0%
                                    ↑↑↑
                              キューサイズ増加
```

---

## 💡 **実践的な使い方**

### シナリオ1: 通常運用時

```
Queue Size = 0-5
Usage = 30-50%
→ ✅ 正常、問題なし
```

### シナリオ2: トラフィック増加時

```
Queue Size = 15-30
Usage = 70-80%
→ ⚠️ 監視を強化、スケールアウトの準備
```

### シナリオ3: 障害発生時

```
Queue Size = 100+
Usage = 100%
→ 🚨 即座にスケールアウト、または問題のあるサービスを調査
```

---

## 🔧 **チューニング指針**

### キューサイズが常に高い場合

#### オプション1: ワーカースレッド数を増やす

```yaml
# application.yml
server:
  undertow:
    threads:
      worker: 300  # 200 → 300に増加
```

#### オプション2: アプリケーションをスケールアウト

```bash
# Docker Composeの場合
docker-compose up --scale camel-app=3
```

#### オプション3: ボトルネックを特定

```promql
# レスポンスタイムが遅いエンドポイントを特定
histogram_quantile(0.99, sum by (uri, le) (rate(http_server_requests_seconds_bucket[5m])))
```

---

## 📊 **Grafanaダッシュボード完成イメージ**

```
┌─────────────────────────────────────────────────────────────┐
│ Undertow Monitoring Dashboard                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Queue Size   │  │ Active Req   │  │ Usage %      │    │
│  │    0         │  │     15       │  │   7.5%       │    │
│  │              │  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Undertow Queue Size (Time Series)                   │  │
│  │                                                      │  │
│  │     /\                                               │  │
│  │    /  \                                              │  │
│  │___/____\_____________________________________________│  │
│  │                                                      │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Undertow Active Requests vs Worker Threads          │  │
│  │                                                      │  │
│  │ ━━━ Active (15)                                     │  │
│  │ ━━━ Workers (200)                                   │  │
│  │                                                      │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 **まとめ**

| 質問 | 回答 |
|---|---|
| **Grafanaで監視できるか？** | ✅ はい、Prometheusから取得可能 |
| **監視する必要があるか？** | ✅ **はい、最重要メトリクスの1つ** |
| **何を監視すべきか？** | キューサイズ、使用率、スループット |
| **アラートは必要か？** | ✅ はい、Queue > 50で警告推奨 |

---

## 📚 **次のステップ**

1. ✅ Grafanaダッシュボードにパネルを追加
2. ✅ Prometheusアラートルールを設定
3. ✅ 負荷テストでキューサイズの動作を確認
4. ✅ 閾値を環境に合わせて調整

---

**Undertowキューサイズは、パフォーマンス問題を早期発見するための最も重要なメトリクスの1つです！** 🚀

---

**作成日**: 2025-10-20  
**対象**: Undertowキューサイズ監視  
**重要度**: ⭐⭐⭐ 最重要


