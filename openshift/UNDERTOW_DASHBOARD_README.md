# OpenShift版 Undertow Monitoring Dashboard

## 📊 **状況説明**

OpenShift版の`grafana-dashboards-configmap.yaml`には**既にUndertow Monitoring Dashboardが含まれています**。

しかし、OpenShift環境で表示されない場合は、ConfigMapの適用とGrafana Podの再起動が必要です。

---

## ✅ **ConfigMapの内容確認**

### 含まれているダッシュボード

| ダッシュボード | ファイル名 | 状態 |
|---|---|---|
| アラート監視 | alerts-overview-dashboard.json | ✅ 含まれる |
| Camel包括的 | camel-comprehensive-dashboard.json | ✅ 含まれる |
| Camel基本 | camel-dashboard.json | ✅ 含まれる |
| **Undertow監視** | **undertow-monitoring-dashboard.json** | ✅ **含まれる** |

### Undertowダッシュボードの内容

- ⭐ Undertow Queue Size（ゲージ）
- Undertow Active Requests（時系列）
- Undertow Worker Usage %（ゲージ）
- Undertow Thread Configuration（ドーナツ）
- ⭐ Undertow Queue Size（時系列）
- Active Requests vs Worker Threads（時系列）

---

## 🚀 **OpenShiftへの適用方法**

### 方法1: 自動スクリプト（推奨）⭐

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# 実行権限を付与（初回のみ）
chmod +x APPLY_UNDERTOW_DASHBOARD.sh

# スクリプト実行
./APPLY_UNDERTOW_DASHBOARD.sh
```

**スクリプトが実行すること:**
1. ✅ OpenShift接続確認
2. ✅ プロジェクト確認/切り替え
3. ✅ ConfigMapファイル検証
4. ✅ Undertowダッシュボード存在確認
5. ✅ ConfigMapをOpenShiftに適用
6. ✅ Grafana Podを再起動
7. ✅ 新しいPodの起動待機
8. ✅ Grafana URLの表示

---

### 方法2: 手動適用

#### ステップ1: OpenShiftにログイン

```bash
# OpenShift CLIでログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>

# プロジェクトに切り替え
oc project camel-observability-demo
```

#### ステップ2: ConfigMapを適用

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# ConfigMapを適用（更新）
oc apply -f grafana/grafana-dashboards-configmap.yaml
```

**期待される出力:**
```
configmap/grafana-dashboards configured
```

#### ステップ3: Grafana Podを再起動

```bash
# 現在のGrafana Podを削除（自動的に再作成される）
oc delete pod -l app=grafana

# 新しいPodの起動を待機
oc wait --for=condition=ready pod -l app=grafana --timeout=120s
```

**期待される出力:**
```
pod "grafana-xxxxx" deleted
pod/grafana-yyyyy condition met
```

#### ステップ4: Grafanaにアクセス

```bash
# Grafana RouteのURLを取得
oc get route grafana -o jsonpath='{.spec.host}'

# 出力例:
# grafana-camel-observability-demo.apps.cluster.example.com
```

ブラウザで開く：
```
https://grafana-camel-observability-demo.apps.cluster.example.com
```

**ログイン情報:**
- ユーザー名: `admin`
- パスワード: `admin123`

---

## 🔍 **ダッシュボード確認方法**

### Grafana UIで確認

1. Grafanaにログイン
2. 左メニュー → **Dashboards**
3. 以下のダッシュボードが表示されるはず：
   - 🚨 アラート監視ダッシュボード
   - Camel Observability Dashboard
   - 47a6270d-3b6c-5c9b-afdb-5b8d09dd1b84
   - **Undertow Monitoring Dashboard** ← これ！

### 直接アクセス

```
https://<GRAFANA_ROUTE>/d/undertow-monitoring/
```

---

## 🧪 **動作確認**

### ConfigMapの確認

```bash
# ConfigMapが存在するか確認
oc get configmap grafana-dashboards

# ConfigMap内にundertowが含まれるか確認
oc get configmap grafana-dashboards -o yaml | grep -i undertow

# 期待される出力:
#   undertow-monitoring-dashboard.json: "{...}"
```

### Grafana Podの確認

```bash
# Grafana Podの状態確認
oc get pods -l app=grafana

# 期待される出力:
# NAME                       READY   STATUS    RESTARTS   AGE
# grafana-xxxxx              1/1     Running   0          2m

# Grafana Podのログ確認
oc logs -l app=grafana | grep -i undertow

# 期待される出力:
# logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/undertow-monitoring
```

### camel-appメトリクス確認

```bash
# camel-appからUndertowメトリクスが取得できるか確認
oc exec deployment/camel-app -- \
  curl -s http://localhost:8080/actuator/prometheus | grep undertow

# 期待される出力:
# undertow_worker_threads{application="camel-observability-demo",} 200.0
# undertow_request_queue_size{application="camel-observability-demo",} 0.0
# undertow_active_requests{application="camel-observability-demo",} 0.0
# undertow_io_threads{application="camel-observability-demo",} 4.0
```

---

## 🛠️ **トラブルシューティング**

### 問題1: ConfigMapは適用されたがダッシュボードが表示されない

**原因**: Grafana Podが再起動されていない

**解決策**:
```bash
oc delete pod -l app=grafana
oc wait --for=condition=ready pod -l app=grafana --timeout=120s
```

### 問題2: ダッシュボードは表示されるがデータがない

**原因**: camel-appが起動していない、またはメトリクスが有効化されていない

**解決策**:
```bash
# camel-appの状態確認
oc get pods -l app=camel-app

# メトリクス確認
oc exec deployment/camel-app -- \
  curl -s http://localhost:8080/actuator/prometheus | grep undertow
```

### 問題3: "No Data" と表示される

**原因**: Prometheusがメトリクスを収集していない

**解決策**:
```bash
# Prometheusの状態確認
oc get pods -l app=prometheus

# Prometheus Targetの確認
oc port-forward svc/prometheus 9090:9090
# ブラウザで http://localhost:9090/targets を開く
# camel-appのターゲットが"UP"であることを確認
```

### 問題4: ConfigMap適用時にエラー

**原因**: YAMLファイルのフォーマットエラー、または権限不足

**解決策**:
```bash
# YAMLファイルの検証
oc apply -f grafana/grafana-dashboards-configmap.yaml --dry-run=client

# 権限確認
oc auth can-i create configmap
oc auth can-i update configmap grafana-dashboards
```

---

## 📋 **チェックリスト**

ダッシュボードが正常に表示されることを確認するためのチェックリスト：

- [ ] OpenShiftにログインしている
- [ ] camel-observability-demoプロジェクトにいる
- [ ] ConfigMapファイルが存在する（grafana/grafana-dashboards-configmap.yaml）
- [ ] ConfigMapにundertow-monitoring-dashboard.jsonが含まれる
- [ ] ConfigMapをOpenShiftに適用した
- [ ] Grafana Podを再起動した
- [ ] Grafana Podがrunning状態である
- [ ] Grafana UIでダッシュボード一覧に表示される
- [ ] Undertow Monitoring Dashboardを開いてデータが表示される
- [ ] すべてのパネルがデータを表示している

---

## 📚 **関連ドキュメント**

| ドキュメント | 内容 |
|---|---|
| `APPLY_UNDERTOW_DASHBOARD.sh` | 自動適用スクリプト |
| `UNDERTOW_MIGRATION.md` | Undertow移行の完全ガイド |
| `UNDERTOW_QUICKSTART.md` | クイックスタートガイド |
| `OPENSHIFT_DEPLOYMENT_GUIDE.md` | 詳細なデプロイ手順 |

---

## 💡 **重要なポイント**

### ✅ ConfigMapには既に含まれています

OpenShift版の`grafana-dashboards-configmap.yaml`には**既にUndertow Monitoring Dashboardが含まれています**。

### ⚠️ 適用とPod再起動が必要

ConfigMapをOpenShiftに適用し、Grafana Podを再起動する必要があります。

### 🚀 自動スクリプトが最も簡単

`APPLY_UNDERTOW_DASHBOARD.sh`を実行するだけで、すべて自動で実行されます。

---

## 🎯 **まとめ**

| 質問 | 回答 |
|---|---|
| **ConfigMapにUndertowダッシュボードは含まれているか？** | ✅ はい、既に含まれています |
| **どのように適用するか？** | `./APPLY_UNDERTOW_DASHBOARD.sh` を実行 |
| **手動で適用できるか？** | ✅ はい、`oc apply -f grafana/grafana-dashboards-configmap.yaml` |
| **Grafana Podの再起動は必要か？** | ✅ はい、必須です |
| **ダッシュボードは必要か？** | ✅ はい、Undertowパフォーマンス監視に不可欠 |

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**対象環境**: OpenShift 4.x


