# OpenShift版 Undertow Dashboard "No Data" 修正ガイド

## 🎯 症状

Undertow Monitoring Dashboardは表示されるが、すべてのパネルに「No Data」と表示される。

---

## 🔍 原因の特定

「No Data」になる原因は主に以下の3つです：

### 原因A: Grafana Datasource名の不一致 ⭐ **最も一般的**

ダッシュボードが参照しているdatasource名と、Grafanaに登録されているdatasource名が異なる。

### 原因B: メトリクスが存在しない

camel-appがundertowメトリクスを出力していない、またはPrometheusがスクレイプしていない。

### 原因C: メトリクスラベルの不一致

PromQLクエリで指定しているラベルと、実際のメトリクスのラベルが異なる。

---

## 🚀 自動修正（推奨）

最も迅速に問題を特定・修正するには、自動スクリプトを使用してください：

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# 実行権限を付与（初回のみ）
chmod +x FIX_UNDERTOW_NO_DATA.sh

# スクリプトを実行
./FIX_UNDERTOW_NO_DATA.sh
```

**スクリプトが自動で行うこと:**
1. ✅ Grafanaのdatasource名を確認
2. ✅ ダッシュボードの設定を確認
3. ✅ 名前の一致・不一致を判定
4. ✅ 不一致の場合、自動修正を提案
5. ✅ メトリクスの存在確認
6. ✅ ラベルの一致確認

---

## 🔧 手動修正

自動スクリプトが使えない場合や、詳細な調査が必要な場合は手動で修正してください。

### ステップ1: Grafana Datasource名を確認

```bash
# Grafana Podを特定
GRAFANA_POD=$(oc get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')

# Datasource設定ファイルを確認
oc exec "$GRAFANA_POD" -- cat /etc/grafana/provisioning/datasources/datasources.yml

# 期待される出力例:
# apiVersion: 1
# datasources:
#   - name: Prometheus  ← この名前を確認！
#     type: prometheus
#     access: proxy
#     url: http://prometheus:9090
```

**重要**: `name` フィールドの値をメモしてください（例: `Prometheus`）。

---

### ステップ2: ダッシュボードのdatasource設定を確認

```bash
# ConfigMap内のdatasource設定を確認
oc get configmap grafana-dashboards -o yaml | grep -o '"datasource":"[^"]*"' | head -3

# 期待される出力例:
# "datasource":"Prometheus"
# "datasource":"Prometheus"
# "datasource":"Prometheus"
```

---

### ステップ3: 名前が一致するか確認

| ステップ1の結果 | ステップ2の結果 | 判定 | 対処 |
|---|---|---|---|
| `Prometheus` | `"datasource":"Prometheus"` | ✅ 一致 | → ステップ4へ |
| `prometheus` | `"datasource":"Prometheus"` | ❌ 不一致 | → ステップ3-Aへ |
| `Prometheus-1` | `"datasource":"Prometheus"` | ❌ 不一致 | → ステップ3-Aへ |

---

### ステップ3-A: Datasource名の不一致を修正

**方法1: ダッシュボードを修正（推奨）**

ダッシュボードのdatasource設定を、Grafanaに登録されている名前に合わせます。

```bash
# 例: Grafanaのdatasource名が "prometheus" の場合

# ConfigMapをバックアップ
oc get configmap grafana-dashboards -o yaml > /tmp/grafana-dashboards-backup.yaml

# ConfigMapを修正（"Prometheus" → "prometheus" に置換）
oc get configmap grafana-dashboards -o yaml | \
  sed 's/"datasource":"Prometheus"/"datasource":"prometheus"/g' | \
  oc replace -f -

# Grafana Podを再起動
oc delete pod -l app=grafana
oc wait --for=condition=ready pod -l app=grafana --timeout=120s
```

**方法2: Grafana Datasourceを修正（非推奨）**

Grafanaのdatasource名を、ダッシュボードが期待している名前に合わせます。

```bash
# grafana/grafana-datasources-configmap.yaml を編集
# name: prometheus → name: Prometheus に変更

oc apply -f grafana/grafana-datasources-configmap.yaml
oc delete pod -l app=grafana
oc wait --for=condition=ready pod -l app=grafana --timeout=120s
```

---

### ステップ4: メトリクスの存在確認

Datasource名が一致しているのに「No Data」の場合、メトリクス自体が存在しない可能性があります。

```bash
# camel-app Podを特定
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')

# camel-appからundertowメトリクスを取得
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow_"

# 期待される出力:
# undertow_worker_threads{...} 200.0
# undertow_request_queue_size{...} 0.0
# undertow_active_requests{...} 0.0
# undertow_io_threads{...} 4.0
```

**何も出力されない場合:**

```bash
# camel-appの設定を確認
oc get deployment camel-app -o yaml | grep -A 10 "JAVA_OPTS\|application.yml"

# 以下の設定が必要:
# management.metrics.enable.undertow: true
```

**設定がない場合、ConfigMapを修正:**

```bash
# ConfigMapを編集
oc edit configmap camel-app-config

# 以下を追加:
# management:
#   metrics:
#     enable:
#       undertow: true

# camel-appを再起動
oc rollout restart deployment/camel-app
oc rollout status deployment/camel-app
```

---

### ステップ5: Prometheusのスクレイプ確認

メトリクスがcamel-appから出力されているのに「No Data」の場合、Prometheusがスクレイプしていない可能性があります。

```bash
# Port Forwardを実行
oc port-forward svc/prometheus 9090:9090 &

# ブラウザで以下にアクセス:
# http://localhost:9090/targets

# camel-appのターゲットが「UP」であることを確認
```

**ターゲットが存在しない、または「DOWN」の場合:**

```bash
# Prometheusの設定を確認
PROMETHEUS_POD=$(oc get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
oc exec "$PROMETHEUS_POD" -- cat /etc/prometheus/prometheus.yml

# scrape_configs に camel-app が含まれているか確認
```

**設定がない場合、prometheus-config ConfigMapを修正:**

```bash
oc edit configmap prometheus-config

# scrape_configs セクションに以下を追加:
#   - job_name: 'camel-app'
#     static_configs:
#       - targets: ['camel-app:8080']
#     metrics_path: '/actuator/prometheus'

# Prometheusを再起動
oc delete pod -l app=prometheus
oc wait --for=condition=ready pod -l app=prometheus --timeout=120s
```

---

### ステップ6: メトリクスラベルの確認

メトリクスは存在するが「No Data」の場合、ラベルが一致していない可能性があります。

```bash
# 実際のメトリクスのラベルを確認
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "undertow_request_queue_size"

# 出力例:
# undertow_request_queue_size{application="camel-observability-demo"} 0.0
# または
# undertow_request_queue_size{application="my-app",instance="pod-xyz"} 0.0
```

**ダッシュボードが期待しているラベル:**
```promql
undertow_request_queue_size{application="camel-observability-demo"}
```

**実際のメトリクスのラベルが異なる場合:**

ConfigMap内のPromQLクエリを修正する必要があります。

```bash
# 例: ラベルを削除してすべてのundertowメトリクスを取得
oc get configmap grafana-dashboards -o yaml | \
  sed 's/{application=\\"camel-observability-demo\\"}//g' | \
  oc replace -f -

# Grafana Podを再起動
oc delete pod -l app=grafana
oc wait --for=condition=ready pod -l app=grafana --timeout=120s
```

---

## 🔍 詳細デバッグ

上記の手順でも解決しない場合、詳細デバッグスクリプトを実行してください：

```bash
cd /Users/kjin/mobills/observability/demo/openshift

chmod +x DEBUG_UNDERTOW_NO_DATA.sh
./DEBUG_UNDERTOW_NO_DATA.sh
```

このスクリプトは以下を確認します：
- ✅ camel-app Pod状態
- ✅ camel-appのメトリクス出力
- ✅ Prometheusのメトリクス保存状態
- ✅ Prometheusでのクエリ実行結果
- ✅ Grafana datasource設定
- ✅ ConfigMap内のdashboard設定

**出力結果を保存して共有してください。**

---

## 📋 チェックリスト

問題解決のための完全なチェックリストです：

### Datasource設定
- [ ] Grafana Podが起動している
- [ ] Grafana datasource設定ファイルが存在する (`/etc/grafana/provisioning/datasources/`)
- [ ] Prometheus datasourceが登録されている
- [ ] Datasource名を確認した（例: `Prometheus`）
- [ ] ダッシュボードのdatasource設定を確認した
- [ ] **Datasource名が完全に一致している** ← **最重要**

### メトリクス出力
- [ ] camel-app Podが起動している
- [ ] camel-appの`/actuator/prometheus`エンドポイントにアクセスできる
- [ ] `undertow_*`メトリクスが出力されている
- [ ] `management.metrics.enable.undertow: true`が設定されている

### Prometheusスクレイプ
- [ ] Prometheus Podが起動している
- [ ] Prometheusの設定に`camel-app`ターゲットが含まれている
- [ ] Prometheusのターゲット画面で`camel-app`が「UP」
- [ ] Prometheusでクエリ`undertow_request_queue_size`を実行できる

### ラベル設定
- [ ] 実際のメトリクスのラベルを確認した
- [ ] ダッシュボードのPromQLクエリのラベルと一致している

### Grafana設定
- [ ] ConfigMapが最新の状態
- [ ] Grafana Podを再起動した
- [ ] ダッシュボードが読み込まれている
- [ ] ブラウザのキャッシュをクリアした

---

## 🎯 よくある解決パターン

### パターン1: Datasource名が小文字だった

**症状**: すべて正常だが「No Data」

**原因**: Grafanaのdatasource名が`prometheus`（小文字）だが、ダッシュボードは`Prometheus`（大文字）を参照

**解決策**:
```bash
oc get configmap grafana-dashboards -o yaml | \
  sed 's/"datasource":"Prometheus"/"datasource":"prometheus"/g' | \
  oc replace -f -
oc delete pod -l app=grafana
```

---

### パターン2: undertowメトリクスが無効

**症状**: 他のメトリクスは取得できるが、undertowだけ「No Data」

**原因**: Spring Boot 3.xではundertowメトリクスがデフォルトで無効

**解決策**:
```bash
oc edit configmap camel-app-config
# management.metrics.enable.undertow: true を追加
oc rollout restart deployment/camel-app
```

---

### パターン3: Prometheusがcamel-appをスクレイプしていない

**症状**: camel-appからメトリクスは取得できるが、Prometheusに保存されていない

**原因**: Prometheusの`scrape_configs`に`camel-app`が含まれていない

**解決策**:
```bash
oc edit configmap prometheus-config
# scrape_configs に camel-app を追加
oc delete pod -l app=prometheus
```

---

## 📚 関連ドキュメント

- `FIX_UNDERTOW_NO_DATA.sh` - 自動修正スクリプト
- `DEBUG_UNDERTOW_NO_DATA.sh` - 詳細デバッグスクリプト
- `FIX_UNDERTOW_DASHBOARD.md` - ダッシュボードが表示されない場合のガイド
- `UNDERTOW_MIGRATION.md` - Undertow移行ガイド

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**対象**: OpenShift 4.x、Spring Boot 3.x、Grafana 10.x



