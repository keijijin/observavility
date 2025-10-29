# 🔔 Grafanaダッシュボードへのアラート統合ガイド

## 📋 現在の状況

### ✅ 設定済み
- **Prometheusアラート**: 18個のアラートルールが稼働中
- **Grafanaダッシュボード**: 視覚的な閾値表示（色分け）のみ

### ❌ 未設定
- Grafanaダッシュボードパネルへの直接アラート追加

## 🎯 アラートの違い

### Prometheusアラート（現在稼働中）✅

**特徴:**
- Prometheus側で条件を評価
- Alertmanager経由で通知
- ダッシュボードに依存しない
- より信頼性が高い

**利点:**
- ✅ ダッシュボードを開いていなくても動作
- ✅ 集中管理が可能
- ✅ 高度なルーティングと通知設定
- ✅ 既に18個設定済み

**確認方法:**
```
http://localhost:9090/alerts
```

### Grafanaアラート（未設定）

**特徴:**
- Grafana側で条件を評価
- Grafana通知チャネル経由で通知
- ダッシュボードパネルに直接設定

**利点:**
- ✅ ダッシュボードで直接設定・管理
- ✅ 視覚的な設定UI
- ✅ Grafana通知チャネルを利用

**欠点:**
- ❌ Grafanaが停止するとアラートも停止
- ❌ すべてのパネルタイプでサポートされていない

## 🔄 推奨アプローチ

### オプション1: Prometheusアラートを継続使用（推奨）✅

**現在の設定で十分な理由:**
1. ✅ 18個の本番向けアラートが既に稼働
2. ✅ Prometheusは監視専用システムとして設計されている
3. ✅ Grafanaが停止してもアラートは動作
4. ✅ Alertmanagerで高度な通知ルーティングが可能

**Grafanaでの表示:**
```
Grafana → Alerting → Alert Rules
```
ここでPrometheusアラートを確認・表示できます。

### オプション2: Grafanaアラートを追加

特定のパネルにGrafanaアラートを追加する場合。

## 📊 Grafanaアラートの追加方法

### 手順1: アラート対応パネルを確認

Grafanaアラートは以下のパネルタイプでのみサポートされます：
- ✅ Graph
- ✅ Time series
- ✅ Stat
- ❌ Gauge（アラート未対応）
- ❌ Row（アラート未対応）

### 手順2: パネルにアラートを追加

#### UI経由（推奨）

1. Grafanaダッシュボードを開く
2. パネルのタイトルをクリック → **Edit**
3. **Alert** タブをクリック
4. **Create Alert** をクリック
5. アラート条件を設定：
   ```
   WHEN avg() OF query(A, 5m, now) IS ABOVE 90
   ```
6. 通知チャネルを選択
7. **Save** をクリック

#### JSON経由

`camel-comprehensive-dashboard.json` にアラート設定を追加：

```json
{
  "id": 3,
  "type": "timeseries",
  "title": "💻 CPU使用率",
  "targets": [...],
  "alert": {
    "name": "High CPU Usage",
    "message": "CPU使用率が高いです",
    "conditions": [
      {
        "evaluator": {
          "params": [80],
          "type": "gt"
        },
        "operator": {
          "type": "and"
        },
        "query": {
          "params": ["A", "5m", "now"]
        },
        "reducer": {
          "params": [],
          "type": "avg"
        },
        "type": "query"
      }
    ],
    "executionErrorState": "alerting",
    "for": "5m",
    "frequency": "1m",
    "handler": 1,
    "noDataState": "no_data",
    "notifications": [
      {
        "uid": "notification-channel-uid"
      }
    ]
  }
}
```

### 手順3: 通知チャネルの設定

Grafana UI:
1. **Configuration** → **Notification channels**
2. **Add channel** をクリック
3. タイプを選択（Email, Slack, Webhook, etc.）
4. 設定を入力
5. **Test** → **Save**

## 🎨 既存ダッシュボードへのアラート統合例

### 例1: CPU使用率アラート

**Panel ID 3（CPU使用率）にアラートを追加:**

```json
{
  "id": 3,
  "gridPos": {"h": 6, "w": 6, "x": 6, "y": 1},
  "type": "timeseries",
  "title": "💻 CPU使用率",
  "targets": [
    {
      "expr": "process_cpu_usage{application=\"camel-observability-demo\"} * 100",
      "legendFormat": "CPU Usage",
      "refId": "A"
    }
  ],
  "alert": {
    "name": "High CPU Usage Alert",
    "message": "CPU使用率が80%を超えています",
    "conditions": [
      {
        "evaluator": {
          "params": [80],
          "type": "gt"
        },
        "operator": {
          "type": "and"
        },
        "query": {
          "params": ["A", "5m", "now"]
        },
        "reducer": {
          "params": [],
          "type": "avg"
        },
        "type": "query"
      }
    ],
    "executionErrorState": "alerting",
    "for": "5m",
    "frequency": "1m",
    "handler": 1,
    "noDataState": "no_data"
  },
  "fieldConfig": {...}
}
```

### 例2: メモリ使用率アラート

**Panel ID 4（ヒープメモリ）にアラートを追加:**

```json
{
  "id": 4,
  "type": "timeseries",
  "title": "🧠 ヒープメモリ使用率",
  "alert": {
    "name": "High Memory Usage Alert",
    "message": "ヒープメモリ使用率が90%を超えています",
    "conditions": [
      {
        "evaluator": {
          "params": [90],
          "type": "gt"
        },
        "query": {
          "params": ["A", "2m", "now"]
        },
        "reducer": {
          "type": "avg"
        },
        "type": "query"
      }
    ],
    "for": "2m",
    "frequency": "30s"
  }
}
```

## ⚠️ 注意事項

### Gaugeパネルの制限

現在のダッシュボードには多くの `gauge` パネルがありますが、**Grafanaアラートは gauge パネルではサポートされていません**。

**対処法:**
1. Gaugeパネルを `timeseries` パネルに変更
2. Prometheusアラートを使用（既に設定済み）
3. 別の監視パネルを追加してそこにアラートを設定

### パフォーマンス影響

- Grafanaアラートが多すぎるとGrafanaのパフォーマンスに影響
- 推奨: 重要なメトリクスのみGrafanaアラートを追加
- Prometheusアラートと併用する場合は重複に注意

## 🎯 ベストプラクティス

### 1. Prometheusアラート（主要）

**使用場面:**
- ✅ システム全体の重要なアラート
- ✅ SLA/SLO関連のアラート
- ✅ 24/7監視が必要なアラート

### 2. Grafanaアラート（補助）

**使用場面:**
- ✅ ダッシュボード固有の視覚的アラート
- ✅ 開発/テスト環境の簡易アラート
- ✅ 特定のダッシュボードユーザー向けアラート

## 📚 関連ドキュメント

- **ALERT_SETUP_PRODUCTION.md** - Prometheusアラート設定ガイド
- **ALERT_PRODUCTION_SUMMARY.md** - アラート設定サマリー
- **GRAFANA_ALERTS_GUIDE.md** - Grafanaアラート基本ガイド

## ✅ 推奨設定

### 現在の設定で推奨 ✅

1. **Prometheusアラート**: 既に18個設定済み
   - クリティカル: 6個
   - 警告: 9個
   - 情報: 3個

2. **Grafanaダッシュボード**: 視覚的な閾値表示
   - 色分けで状態を把握
   - リアルタイムモニタリング

3. **通知**: Alertmanager経由（要設定）
   - Email
   - Slack
   - PagerDuty
   - Webhook

### 追加でGrafanaアラートが必要な場合

1. **通知チャネルの設定**
2. **重要な5-10個のパネルにのみ追加**
3. **Prometheusアラートとの重複を避ける**

## 🎉 まとめ

- ✅ **Prometheusアラート**: 既に完璧に設定済み
- ✅ **Grafanaダッシュボード**: 視覚的な監視に最適
- ⏳ **Grafanaアラート**: 必要に応じて追加可能（オプション）

**推奨**: 現在の設定（Prometheusアラート + Grafana視覚化）で十分です！

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22


