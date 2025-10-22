# Grafana ダッシュボード トラブルシューティング

## 🎯 **Undertow Monitoring Dashboardが表示されない場合**

### ✅ **解決済み！**

Grafanaコンテナを再起動したことで、Undertow Monitoring Dashboardが正常にプロビジョニングされました。

---

## 📊 **ダッシュボードの確認方法**

### ステップ1: Grafanaにアクセス

```
URL: http://localhost:3000
ユーザー名: admin
パスワード: admin123
```

### ステップ2: ダッシュボード一覧を開く

1. 左メニューの **Dashboards** をクリック
2. または、URLバーで `http://localhost:3000/dashboards` にアクセス

### ステップ3: Undertow Monitoring Dashboardを探す

ダッシュボード一覧に以下が表示されるはずです：

- 🚨 アラート監視ダッシュボード
- Camel Observability Dashboard
- 47a6270d-3b6c-5c9b-afdb-5b8d09dd1b84
- **Undertow Monitoring Dashboard** ← これ！

### 直接リンク

```
http://localhost:3000/d/undertow-monitoring/
```

---

## 🔍 **もし表示されない場合**

### 方法1: Grafanaを再起動

```bash
cd /Users/kjin/mobills/observability/demo

# Grafanaコンテナを再起動
podman restart grafana

# 20秒待機
sleep 20

# ブラウザを再読み込み
```

### 方法2: ブラウザのキャッシュをクリア

```
Chrome: Cmd + Shift + R (macOS)
Firefox: Cmd + Shift + R (macOS)
Safari: Cmd + Option + E (macOS)
```

### 方法3: ダッシュボードファイルの存在を確認

```bash
# ローカルファイルシステム
ls -lh docker/grafana/provisioning/dashboards/undertow-monitoring-panels.json

# Grafanaコンテナ内
podman exec grafana ls -lh /etc/grafana/provisioning/dashboards/undertow-monitoring-panels.json
```

**期待される出力:**
```
-rw-r--r-- 1 grafana root 12.9K undertow-monitoring-panels.json
```

### 方法4: Grafanaログを確認

```bash
# undertow-monitoringのプロビジョニングログを確認
podman logs grafana 2>&1 | grep -i "undertow-monitoring"

# 期待される出力:
# logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/undertow-monitoring
```

### 方法5: 手動インポート

ダッシュボードが自動プロビジョニングされない場合、手動でインポートできます：

```bash
# 1. Grafanaにログイン
# 2. 左メニュー → Dashboards → Import
# 3. "Upload JSON file" をクリック
# 4. 以下のファイルを選択:
#    /Users/kjin/mobills/observability/demo/docker/grafana/provisioning/dashboards/undertow-monitoring-panels.json
```

---

## 🧪 **ダッシュボードが正常にロードされたことを確認**

### Grafanaログ確認

```bash
podman logs grafana 2>&1 | grep "Initialized channel handler.*dashboard"
```

**期待される出力:**
```
logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/alerts-overview
logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/camel-comprehensive
logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/undertow-monitoring
```

### Grafana API経由で確認

```bash
# ダッシュボード一覧を取得
curl -s -u admin:admin123 http://localhost:3000/api/search?type=dash-db | jq -r '.[] | .title'
```

**期待される出力:**
```
🚨 アラート監視ダッシュボード
Camel Observability Dashboard
47a6270d-3b6c-5c9b-afdb-5b8d09dd1b84
Undertow Monitoring Dashboard
```

---

## 📋 **ダッシュボードの内容**

### Undertow Monitoring Dashboard

#### パネル1: ⭐ Undertow Queue Size（ゲージ）
- **メトリクス**: `undertow_request_queue_size`
- **説明**: リクエストキューのサイズ
- **閾値**:
  - 🟢 緑: 0（正常）
  - 🟡 黄: 10-50（注意）
  - 🟠 オレンジ: 50-100（警告）
  - 🔴 赤: 100+（危険）

#### パネル2: Undertow Active Requests（時系列）
- **メトリクス**: `undertow_active_requests`
- **説明**: 現在処理中のリクエスト数

#### パネル3: Undertow Worker Usage %（ゲージ）
- **メトリクス**: `(undertow_active_requests / undertow_worker_threads) * 100`
- **説明**: ワーカースレッド使用率
- **閾値**:
  - 🟢 緑: 0-70%（正常）
  - 🟡 黄: 70-85%（注意）
  - 🟠 オレンジ: 85-95%（警告）
  - 🔴 赤: 95-100%（危険）

#### パネル4: Undertow Thread Configuration（ドーナツチャート）
- **メトリクス**: `undertow_worker_threads`, `undertow_io_threads`
- **説明**: ワーカースレッド数とI/Oスレッド数の構成

#### パネル5: ⭐ Queue Size (Time Series)
- **メトリクス**: `undertow_request_queue_size`
- **説明**: キューサイズの時系列変化
- **用途**: スパイクや継続的な増加を監視

#### パネル6: Active Requests vs Worker Threads（時系列）
- **メトリクス**:
  - `undertow_active_requests` - アクティブリクエスト
  - `undertow_worker_threads` - ワーカースレッド最大値
  - `undertow_worker_threads * 0.85` - 警告閾値（85%）
  - `undertow_worker_threads * 0.95` - 危険閾値（95%）
- **説明**: アクティブリクエスト数がワーカースレッド数に近づくとキューイングが発生

---

## 🔧 **プロビジョニング設定の確認**

### ファイル構造

```
demo/docker/grafana/provisioning/
├── dashboards/
│   ├── alerts-overview-dashboard.json
│   ├── camel-comprehensive-dashboard.json
│   ├── camel-dashboard.json
│   ├── undertow-monitoring-panels.json  ← Undertowダッシュボード
│   └── dashboards.yml                   ← プロビジョニング設定
└── datasources/
    └── datasources.yml
```

### dashboards.yml の内容

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

この設定により、`/etc/grafana/provisioning/dashboards` ディレクトリ内のすべての`.json`ファイルが自動的にダッシュボードとしてロードされます。

---

## 🐛 **よくある問題と解決策**

### 問題1: ダッシュボードが表示されない

**原因**: Grafanaが起動時にファイルを読み込んでいない

**解決策**:
```bash
podman restart grafana
sleep 20
# ブラウザを再読み込み
```

### 問題2: ダッシュボードは表示されるがデータがない

**原因**: camel-appが起動していない、またはUndertowメトリクスが有効化されていない

**解決策**:
```bash
# camel-appの状態確認
podman ps | grep camel-app

# Undertowメトリクスの確認
curl -s http://localhost:8080/actuator/prometheus | grep undertow

# 期待される出力:
# undertow_worker_threads{...} 200.0
# undertow_request_queue_size{...} 0.0
# undertow_active_requests{...} 0.0
# undertow_io_threads{...} 4.0
```

### 問題3: "No Data" と表示される

**原因**: Prometheusがメトリクスを収集していない

**解決策**:
```bash
# Prometheusの状態確認
podman ps | grep prometheus

# Prometheusのtargets確認
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.scrapeUrl | contains("camel-app"))'

# camel-appのメトリクスがPrometheusに存在するか確認
curl -s 'http://localhost:9090/api/v1/query?query=undertow_worker_threads' | jq
```

---

## ✅ **チェックリスト**

ダッシュボードが正常に動作していることを確認するためのチェックリスト：

- [ ] Grafanaコンテナが起動している (`podman ps | grep grafana`)
- [ ] camel-appコンテナが起動している (`podman ps | grep camel-app`)
- [ ] Undertowメトリクスが取得できる (`curl http://localhost:8080/actuator/prometheus | grep undertow`)
- [ ] Prometheusがメトリクスを収集している
- [ ] Grafanaでダッシュボード一覧に表示される
- [ ] ダッシュボードを開いてデータが表示される
- [ ] すべてのパネルがデータを表示している

---

## 📚 **関連ドキュメント**

- `GRAFANA_UNDERTOW_MONITORING.md` - Undertowメトリクスの詳細ガイド
- `UNDERTOW_DASHBOARD_FIX.md` - ダッシュボード修正の履歴
- `UNDERTOW_QUEUE_EXPLANATION.md` - キューサイズの説明

---

**作成日**: 2025-10-20  
**最終更新**: 2025-10-20  
**トピック**: Grafana Undertow Monitoring Dashboard トラブルシューティング


