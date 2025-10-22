# Undertow Monitoring Dashboard 修正完了

## ✅ **修正内容**

### 問題
- Grafanaダッシュボードで「No Data」が表示される
- データソースのUID設定が環境と一致していない

### 解決策
データソース参照を修正しました：

**修正前:**
```json
"datasource": {
  "type": "prometheus",
  "uid": "prometheus"
}
```

**修正後:**
```json
"datasource": "Prometheus"
```

これにより、Grafanaのプロビジョニングで設定された"Prometheus"データソースを正しく参照できます。

---

## 🔍 **確認方法**

### 1. Grafanaにアクセス

```
URL: http://localhost:3000
Username: admin
Password: admin
```

### 2. ダッシュボードを開く

1. 左メニューから **Dashboards** → **Browse** をクリック
2. **Undertow Monitoring Dashboard** を開く

### 3. データが表示されることを確認

以下のパネルでデータが表示されるはずです：

- ⭐ **Undertow Queue Size**: 0（ゲージ）
- **Undertow Active Requests**: 0（グラフ）
- **Undertow Worker Usage (%)**: 0%（ゲージ）
- **Undertow Thread Configuration**: Workers=200, I/O=4（円グラフ）
- ⭐ **Undertow Queue Size (Time Series)**: 平坦な0のグラフ
- **Undertow Active Requests vs Worker Threads**: 2本の線（Active=0, Workers=200）

---

## 🧪 **動作テスト**

### 負荷をかけてキューサイズを増やす

```bash
# 500リクエストを同時送信
for i in {1..500}; do
  curl -X POST http://localhost:8080/camel/api/orders \
    -H "Content-Type: application/json" \
    -d '{"id": "ORD-'$i'", "product": "LoadTest", "quantity": 1, "price": 100}' \
    > /dev/null 2>&1 &
done

# Grafanaダッシュボードで確認
# - Queue Sizeが一時的に増加
# - Active Requestsが増加
# - Worker Usageが上昇
```

### thread_monitor.shでも確認

```bash
./thread_monitor.sh 1

# 出力例（負荷中）
  Undertow:
    Workers: 200 | Active: 50 | Queue: 15 | Usage: 25.0%
                                    ↑↑↑
                              増加を確認
```

---

## 📊 **期待される表示**

### 通常時（負荷なし）

| パネル | 表示値 |
|---|---|
| **Queue Size** | 0 ✅ |
| **Active Requests** | 0 ✅ |
| **Worker Usage** | 0% ✅ |
| **Workers** | 200 ✅ |
| **I/O Threads** | 4 ✅ |

### 負荷時（500リクエスト同時）

| パネル | 表示値 |
|---|---|
| **Queue Size** | 5-50（一時的に増加）⚠️ |
| **Active Requests** | 50-150（増加）⚠️ |
| **Worker Usage** | 25-75%（上昇）⚠️ |
| **Workers** | 200（固定）✅ |

---

## 🎨 **ダッシュボードの構成**

### Row 1: Overview（4つのパネル）

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Queue Size   │  │ Active Req   │  │ Usage %      │  │ Threads Cfg  │
│  (Gauge)     │  │ (TimeSeries) │  │  (Gauge)     │  │  (PieChart)  │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

### Row 2: Time Series（2つのパネル）

```
┌──────────────────────────────────────────────────────────────┐
│ Queue Size (Time Series)                                     │
│ ⭐ 最重要：時系列でキューサイズの変化を監視                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ Active Requests vs Worker Threads                            │
│ Active が Workers に近づくとキューイングが発生              │
└──────────────────────────────────────────────────────────────┘
```

---

## 🚨 **アラート閾値**

### Queue Size（最重要）⭐

| 値 | 色 | 状態 |
|---|---|---|
| 0-9 | 🟢 Green | 正常 |
| 10-49 | 🟡 Yellow | 注意 |
| 50-99 | 🟠 Orange | 警告 |
| 100+ | 🔴 Red | 危険 |

### Worker Usage

| 値 | 色 | 状態 |
|---|---|---|
| 0-69% | 🟢 Green | 正常 |
| 70-84% | 🟡 Yellow | 注意 |
| 85-94% | 🟠 Orange | 警告 |
| 95-100% | 🔴 Red | 危険 |

---

## 🔧 **トラブルシューティング**

### まだ「No Data」が表示される場合

#### 1. Prometheusが正常に動作しているか確認

```bash
curl -s http://localhost:9090/api/v1/query?query=undertow_request_queue_size | jq .
```

**期待される出力:**
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "application": "camel-observability-demo"
        },
        "value": [1729389600, "0"]
      }
    ]
  }
}
```

#### 2. Grafanaデータソースをテスト

1. Grafana → **Connections** → **Data sources**
2. **Prometheus** をクリック
3. 下にスクロールして **Save & test** をクリック
4. "Data source is working" が表示されることを確認

#### 3. ダッシュボードを再読み込み

1. ダッシュボードを開く
2. 右上の **⋮** メニュー → **Refresh dashboard** をクリック

#### 4. 手動でクエリをテスト

1. ダッシュボードのパネルを編集（パネルタイトルをクリック → **Edit**）
2. クエリを確認：
   ```promql
   undertow_request_queue_size{application="camel-observability-demo"}
   ```
3. **Run queries** をクリック
4. データが表示されることを確認

---

## 📚 **関連ドキュメント**

- `GRAFANA_UNDERTOW_MONITORING.md` - 監視ガイド（詳細版）
- `UNDERTOW_METRICS_SUCCESS.md` - メトリクス実装の詳細
- `UNDERTOW_MIGRATION_COMPLETE.md` - Undertow切り替えの詳細

---

## ✅ **確認チェックリスト**

- [ ] Grafanaにアクセスできる（http://localhost:3000）
- [ ] Undertow Monitoring Dashboardが表示される
- [ ] Queue Sizeパネルに「0」が表示される
- [ ] Active Requestsパネルにグラフが表示される
- [ ] Worker Usageパネルに「0%」が表示される
- [ ] Thread Configurationパネルに円グラフが表示される
- [ ] Time Seriesパネルにグラフが表示される
- [ ] 負荷テストでQueue Sizeが増加する

---

**修正完了日**: 2025-10-20  
**修正内容**: データソース参照の修正  
**結果**: ✅ ダッシュボードが正常に動作


