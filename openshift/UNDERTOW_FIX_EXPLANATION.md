# OpenShift版 Undertow Dashboard "No Data" 問題の修正

## 🎯 問題の特定

OpenShift環境で「Undertow Monitoring Dashboard」を開くと、すべてのパネルに **「No Data」** と表示される問題がありました。

---

## 🔍 原因の調査

### 調査結果

1. ✅ **Grafana datasource設定**: 正常
   - `name: Prometheus` と正しく設定されている
   
2. ✅ **ダッシュボードJSON設定**: 正常
   - `"datasource": "Prometheus"` と正しく設定されている

3. ❌ **camel-app ConfigMap**: **設定不足**
   - `server.undertow.threads` 設定がない
   - `management.metrics.enable.undertow: true` 設定がない

---

## 💡 根本原因

### Spring Boot 3.x のデフォルト動作

Spring Boot 3.x では、**Undertowメトリクスがデフォルトで無効**になっています。

ローカル環境（Docker Compose）では以下の設定が含まれていましたが、OpenShift版には含まれていませんでした：

```yaml
# ローカル版の application.yml には含まれていた設定

server:
  undertow:
    threads:
      io: 4                    # I/Oスレッド数
      worker: 200              # ワーカースレッド数（最大）
    buffer-size: 1024
    direct-buffers: true

management:
  metrics:
    enable:
      undertow: true          # ← これが最重要！
```

---

## ✅ 修正内容

### 修正ファイル

`openshift/camel-app/camel-app-deployment.yaml`

### 追加した設定

#### 1. Undertow サーバー設定

```yaml
server:
  port: 8080
  # Undertow 設定
  undertow:
    threads:
      io: 4                    # I/Oスレッド数（通常はCPUコア数）
      worker: 200              # ワーカースレッド数（最大）
    buffer-size: 1024          # バッファサイズ（バイト）
    direct-buffers: true       # ダイレクトバッファを使用
```

**効果:**
- Undertowのスレッド数を明示的に設定
- `undertow_worker_threads`、`undertow_io_threads` メトリクスが出力される

---

#### 2. Undertow メトリクス有効化

```yaml
management:
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
    # Undertowメトリクスを有効化
    enable:
      undertow: true          # ← 追加！
```

**効果:**
- Spring Boot 3.x で Undertow メトリクスが有効化される
- 以下のメトリクスが Prometheus に公開される：
  - `undertow_worker_threads`
  - `undertow_io_threads`
  - `undertow_active_requests`
  - `undertow_request_queue_size`

---

## 🚀 適用方法

### 自動適用（推奨）⭐

```bash
cd /Users/kjin/mobills/observability/demo/openshift
chmod +x APPLY_UNDERTOW_FIX.sh
./APPLY_UNDERTOW_FIX.sh
```

**スクリプトが自動で実行すること:**
1. ✅ ConfigMapをバックアップ
2. ✅ 修正済みConfigMapを適用
3. ✅ camel-app Podを再起動
4. ✅ Undertowメトリクスの出力を確認
5. ✅ Grafana URLを表示

---

### 手動適用

```bash
# 1. OpenShiftにログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>

# 2. プロジェクトに切り替え
oc project camel-observability-demo

# 3. ConfigMapをバックアップ
oc get configmap camel-app-config -o yaml > /tmp/camel-app-config-backup.yaml

# 4. 修正済みConfigMapを適用（ConfigMapのみ）
oc apply -f camel-app/camel-app-deployment.yaml --dry-run=client -o yaml | \
  awk '/^kind: ConfigMap/,/^---/' | \
  head -n -1 | \
  oc apply -f -

# 5. camel-app Podを再起動
oc delete pod -l app=camel-app

# 6. Podの起動を待機
oc wait --for=condition=ready pod -l app=camel-app --timeout=180s

# 7. Undertowメトリクスを確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow_"

# 期待される出力:
# undertow_worker_threads{application="camel-observability-demo"} 200.0
# undertow_request_queue_size{application="camel-observability-demo"} 0.0
# undertow_active_requests{application="camel-observability-demo"} 0.0
# undertow_io_threads{application="camel-observability-demo"} 4.0
```

---

## 📊 確認方法

### 1. メトリクスの出力確認

```bash
# camel-app Podからメトリクスを取得
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep undertow
```

**期待される出力:**
```
undertow_worker_threads{application="camel-observability-demo"} 200.0
undertow_io_threads{application="camel-observability-demo"} 4.0
undertow_active_requests{application="camel-observability-demo"} 0.0
undertow_request_queue_size{application="camel-observability-demo"} 0.0
```

---

### 2. Prometheus確認

```bash
# Port Forwardを実行
oc port-forward svc/prometheus 9090:9090 &

# ブラウザで以下にアクセス:
# http://localhost:9090/graph

# クエリを実行:
undertow_request_queue_size
```

**期待される結果:**
- グラフにデータが表示される
- 値は `0` (キューイングが発生していない正常状態)

---

### 3. Grafana Dashboard確認

```bash
# Grafana URLを取得
oc get route grafana -o jsonpath='{.spec.host}'
```

ブラウザで以下にアクセス:
```
https://<GRAFANA_HOST>/d/undertow-monitoring/
```

**期待される表示:**

| パネル | 期待される表示 |
|---|---|
| ⭐ Undertow Queue Size | 0（緑色のゲージ） |
| Undertow Active Requests | グラフが表示される（通常は0付近） |
| Undertow Worker Usage (%) | 0-5%程度（低負荷時） |
| Undertow Thread Configuration | Workers: 200, I/O Threads: 4 |
| ⭐ Undertow Queue Size (Time Series) | 時系列グラフが表示される |
| Undertow Active Requests vs Worker Threads | 複数の系列がグラフに表示される |

---

## 🔧 トラブルシューティング

### 問題A: 修正後も「No Data」が表示される

**原因1: ブラウザキャッシュ**

```bash
# ブラウザの強制リロード
# Chrome/Firefox: Ctrl + Shift + R (Windows/Linux)
#                 Cmd + Shift + R (macOS)
```

**原因2: Prometheusがまだスクレイプしていない**

```bash
# 30-60秒待ってからリロード
# Prometheusのスクレイプ間隔は15-30秒が一般的
```

**原因3: Prometheusがcamel-appをスクレイプしていない**

```bash
# Prometheusのターゲットを確認
oc port-forward svc/prometheus 9090:9090 &
# ブラウザで http://localhost:9090/targets を開く
# camel-app が「UP」であることを確認
```

---

### 問題B: Undertowメトリクスが出力されない

```bash
# 1. ConfigMapが正しく反映されているか確認
oc get configmap camel-app-config -o yaml | grep -A 5 "undertow"

# 期待される出力:
#     undertow:
#       threads:
#         io: 4
#         worker: 200
#       ...
#     enable:
#       undertow: true

# 2. Podが新しいConfigMapを読み込んでいるか確認
oc describe pod -l app=camel-app | grep -A 10 "Mounts:"

# 3. Podログを確認
oc logs -l app=camel-app --tail=100 | grep -i "undertow\|metric"

# 4. Podを強制再起動
oc delete pod -l app=camel-app --force --grace-period=0
```

---

### 問題C: Podが起動しない

```bash
# Pod状態を確認
oc get pods -l app=camel-app

# Podの詳細を確認
oc describe pod -l app=camel-app

# Podログを確認
oc logs -l app=camel-app --tail=100

# よくあるエラー:
# - ImagePullBackOff: イメージが見つからない
# - CrashLoopBackOff: アプリケーションエラー
# - Pending: リソース不足
```

---

## 📝 変更の差分

### Before (修正前)

```yaml
server:
  port: 8080

management:
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
```

### After (修正後)

```yaml
server:
  port: 8080
  # Undertow 設定
  undertow:
    threads:
      io: 4
      worker: 200
    buffer-size: 1024
    direct-buffers: true

management:
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
    # Undertowメトリクスを有効化
    enable:
      undertow: true
```

---

## 🎓 学んだこと

### Spring Boot 3.x の注意点

1. **Undertowメトリクスはデフォルトで無効**
   - `management.metrics.enable.undertow: true` を明示的に設定する必要がある

2. **サーバー設定は自動検出されない**
   - `server.undertow.threads` を設定しないと、デフォルト値が使用される
   - メトリクスには設定値が反映されるため、明示的に設定すべき

3. **ローカルとOpenShift環境の設定を統一**
   - ローカルで動作していても、OpenShift環境に設定を反映する必要がある
   - ConfigMapの内容を定期的に同期することが重要

---

## 📚 関連ドキュメント

- `APPLY_UNDERTOW_FIX.sh` - 自動修正適用スクリプト
- `UNDERTOW_NO_DATA_FIX_GUIDE.md` - 「No Data」問題の完全ガイド
- `UNDERTOW_MIGRATION.md` - Undertow移行ガイド
- `GRAFANA_UNDERTOW_MONITORING.md` - Grafanaでのモニタリング方法

---

## ✅ チェックリスト

修正が完了したか確認するためのチェックリスト：

- [ ] ConfigMapに`server.undertow.threads`設定が含まれている
- [ ] ConfigMapに`management.metrics.enable.undertow: true`設定が含まれている
- [ ] ConfigMapをOpenShift環境に適用した
- [ ] camel-app Podを再起動した
- [ ] camel-appからundertowメトリクスが出力されることを確認した
- [ ] Prometheusでundertowメトリクスをクエリできることを確認した
- [ ] Grafanaの「Undertow Monitoring Dashboard」でデータが表示されることを確認した
- [ ] すべてのパネルに「No Data」が表示されなくなった

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**対象**: OpenShift 4.x、Spring Boot 3.x、Apache Camel 4.x


