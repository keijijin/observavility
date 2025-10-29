# OpenShift版 Undertow Dashboard "No Data" 問題の完全解決ガイド

## 📋 **現在の状況**

### ✅ **完了している作業**

1. **ConfigMap修正**: 完璧に完了
   - ✅ `server.undertow.threads` 設定追加
   - ✅ `management.metrics.enable.undertow: true` 追加
   - ✅ ConfigMapは正常にOpenShiftに適用済み

2. **Grafana Dashboard**: 正常に配置済み
   - ✅ `grafana-dashboards-configmap.yaml` に Undertow Dashboard 含まれる
   - ✅ ダッシュボードJSON設定も正しい（`datasource: "Prometheus"`）

---

### ❌ **未解決の問題**

**camel-app Pod が起動していない**

**Pod状態:**
```
NAME                          READY   STATUS             RESTARTS   AGE
camel-app-687bf9d9c9-z5v47    0/1     ImagePullBackOff   0          XXm
```

**エラー:**
```
Failed to pull image "image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:1.0.0": 
reading manifest 1.0.0 in image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app: 
manifest unknown
```

---

## 🎯 **根本原因**

Undertow Dashboard が "No Data" を表示している理由は、以下の流れです：

```
camel-app Pod が起動していない
  ↓
Undertowメトリクスが出力されない
  ↓
Prometheusがメトリクスをスクレイプできない
  ↓
Grafana Dashboard に "No Data" と表示される
```

**つまり、イメージ問題を解決すれば、すべて解決します！**

---

## 🚀 **解決手順（完全版）**

### **ステップ1: イメージ問題を解決**

以下のコマンドを実行してください：

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./FIX_IMAGE_ISSUE.sh
```

このスクリプトが自動で実行すること：
1. ImageStreamとタグを確認
2. 正しいタグが見つかれば、Deploymentを更新
3. タグが見つからなければ、新しいビルドを実行
4. Podの起動を待機
5. **Undertowメトリクスを確認**

---

### **ステップ2: Podの起動を確認**

```bash
# Podの状態を確認
oc get pods -l app=camel-app

# 期待される状態:
# NAME                          READY   STATUS    RESTARTS   AGE
# camel-app-xxxxx-yyyyy         1/1     Running   0          XXm
```

---

### **ステップ3: Undertowメトリクスを確認**

```bash
# camel-app Pod名を取得
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')

# Undertowメトリクスを確認
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

### **ステップ4: Prometheusでメトリクスを確認**

```bash
# Port Forwardを実行
oc port-forward svc/prometheus 9090:9090 &

# ブラウザで以下にアクセス:
# http://localhost:9090/graph

# クエリを実行:
undertow_request_queue_size
```

データが表示されれば、Prometheusは正常にスクレイプしています。

---

### **ステップ5: Grafana Dashboardを確認**

```bash
# Grafana URLを取得
oc get route grafana -o jsonpath='{.spec.host}'
```

ブラウザで以下にアクセス：
```
https://<GRAFANA_HOST>/d/undertow-monitoring/
```

**期待される表示:**
- ✅ Undertow Queue Size: 0（緑色のゲージ）
- ✅ Undertow Active Requests: グラフが表示される
- ✅ Undertow Worker Usage: 数値が表示される
- ✅ Undertow Thread Configuration: Workers: 200, I/O: 4

---

## 🔧 **トラブルシューティング**

### 問題A: `./FIX_IMAGE_ISSUE.sh` 実行後もPodが起動しない

```bash
# Podのイベントを確認
oc describe pod -l app=camel-app

# 一般的な原因:
# - イメージビルドが失敗している
# - リソース不足
# - ConfigMapマウントエラー
```

---

### 問題B: Podは起動したが、Undertowメトリクスが出力されない

```bash
# Podログを確認
oc logs -l app=camel-app --tail=100

# ConfigMapが正しくマウントされているか確認
oc exec <POD_NAME> -- cat /config/application.yml | grep -A 5 "undertow:"

# アプリケーションが完全に起動するまで待つ（1-2分）
sleep 60
oc exec <POD_NAME> -- curl -s http://localhost:8080/actuator/prometheus | grep undertow
```

---

### 問題C: メトリクスは出力されているが、Grafanaで "No Data"

```bash
# Prometheusがcamel-appをスクレイプしているか確認
oc port-forward svc/prometheus 9090:9090 &
# ブラウザで http://localhost:9090/targets を開く
# camel-app が「UP」であることを確認

# Prometheusでクエリを実行
# http://localhost:9090/graph
# クエリ: undertow_request_queue_size

# データが表示されない場合:
# 1. Prometheusの設定を確認
# 2. ServiceMonitorまたはスクレイプ設定を確認
# 3. ネットワーク接続を確認
```

---

## 📊 **完全チェックリスト**

以下を順番に確認してください：

### Phase 1: イメージ
- [ ] `oc get imagestream camel-app` でImageStreamが存在する
- [ ] ImageStreamに有効なタグが存在する
- [ ] Deploymentのイメージタグが正しい

### Phase 2: Pod
- [ ] `oc get pods -l app=camel-app` でPodが存在する
- [ ] Podの状態が `Running`
- [ ] Podのログにエラーがない

### Phase 3: ConfigMap
- [ ] ConfigMapに `server.undertow` 設定がある
- [ ] ConfigMapに `management.metrics.enable.undertow: true` がある
- [ ] PodがConfigMapを正しくマウントしている

### Phase 4: メトリクス
- [ ] `/actuator/prometheus` エンドポイントが応答する
- [ ] `undertow_*` メトリクスが出力される
- [ ] メトリクスのラベルが正しい（`application="camel-observability-demo"`）

### Phase 5: Prometheus
- [ ] Prometheusが起動している
- [ ] Prometheusのターゲットに `camel-app` が存在する
- [ ] ターゲットの状態が「UP」
- [ ] Prometheusでクエリ `undertow_request_queue_size` を実行できる

### Phase 6: Grafana
- [ ] Grafanaが起動している
- [ ] Datasource "Prometheus" が正しく設定されている
- [ ] Dashboard "Undertow Monitoring Dashboard" が存在する
- [ ] ブラウザのキャッシュをクリアした
- [ ] **データが表示される** ← ゴール！

---

## 🎯 **最も迅速な解決方法**

**たった1つのコマンドを実行するだけ：**

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./FIX_IMAGE_ISSUE.sh
```

このスクリプトがイメージ問題を解決し、Podを起動させ、Undertowメトリクスを確認します。

スクリプト実行後、60-90秒待ってから Grafana Dashboard にアクセスしてください。

---

## 📚 **関連ドキュメント**

- `FIX_IMAGE_ISSUE.sh` - イメージ問題自動修正スクリプト
- `APPLY_UNDERTOW_FIX.sh` - ConfigMap適用スクリプト（既に完了）
- `UNDERTOW_FIX_EXPLANATION.md` - 詳細な問題説明
- `OPENSHIFT_DEPLOYMENT_GUIDE.md` - OpenShiftデプロイメント完全ガイド

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**現在の状態**: ConfigMap修正完了、イメージ問題が未解決



