# OpenShift版 Undertow Dashboard 修正手順

## 🎯 **問題**

OpenShift版のGrafanaでUndertow Monitoring Dashboardが表示されない。

---

## ✅ **原因**

ConfigMapファイルには含まれているが、OpenShift環境に適用されていない、またはGrafana Podが再起動されていない。

---

## 🚀 **解決手順（完全版）**

### 前提条件確認

```bash
# OpenShiftにログインしているか確認
oc whoami

# 現在のプロジェクトを確認
oc project
```

---

### ステップ1: ConfigMapの現在の状態を確認

```bash
# ConfigMapが存在するか確認
oc get configmap grafana-dashboards

# 期待される出力:
# NAME                  DATA   AGE
# grafana-dashboards    4      Xd

# ConfigMap内にundertowが含まれているか確認
oc get configmap grafana-dashboards -o yaml | grep -i "undertow-monitoring"

# 期待される出力:
#   undertow-monitoring-dashboard.json: "{...}"
```

**結果の解釈:**

| 結果 | 意味 | 次のアクション |
|---|---|---|
| ConfigMap not found | ConfigMapが適用されていない | → ステップ2へ |
| undertowが見つからない | 古いConfigMapが残っている | → ステップ2へ（更新） |
| undertowが見つかる | ConfigMapは正しい | → ステップ3へ |

---

### ステップ2: ConfigMapを適用/更新

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# ConfigMapを適用（新規作成または更新）
oc apply -f grafana/grafana-dashboards-configmap.yaml

# 期待される出力:
# configmap/grafana-dashboards created
# または
# configmap/grafana-dashboards configured
```

**確認:**
```bash
# 再度確認
oc get configmap grafana-dashboards -o yaml | grep -c "undertow-monitoring"

# 期待される出力: 1以上
```

---

### ステップ3: Grafana Podを再起動

ConfigMapを更新した後、Grafana Podを再起動してダッシュボードを再読み込みします。

```bash
# 現在のGrafana Podを確認
oc get pods -l app=grafana

# 期待される出力:
# NAME                      READY   STATUS    RESTARTS   AGE
# grafana-xxxxx-yyyyy       1/1     Running   0          Xh

# Grafana Podを削除（自動的に再作成される）
oc delete pod -l app=grafana

# 期待される出力:
# pod "grafana-xxxxx-yyyyy" deleted

# 新しいPodの起動を待機（最大120秒）
oc wait --for=condition=ready pod -l app=grafana --timeout=120s

# 期待される出力:
# pod/grafana-zzzzz-wwwww condition met
```

---

### ステップ4: Grafana Podのログを確認

```bash
# Grafana Podのログからundertowダッシュボードの読み込みを確認
oc logs -l app=grafana | grep -i undertow

# 期待される出力:
# logger=live ... msg="Initialized channel handler" channel=grafana/dashboard/uid/undertow-monitoring address=grafana/dashboard/uid/undertow-monitoring
```

**もし何も出力されない場合:**
```bash
# Podの最新ログを全体的に確認
oc logs -l app=grafana --tail=50 | grep -i "dashboard\|provision"

# プロビジョニングに関するエラーがないか確認
oc logs -l app=grafana | grep -i error | tail -20
```

---

### ステップ5: Grafanaにアクセスしてダッシュボードを確認

```bash
# Grafana RouteのURLを取得
oc get route grafana -o jsonpath='{.spec.host}'

# 期待される出力例:
# grafana-camel-observability-demo.apps.cluster.example.com
```

**ブラウザで確認:**

1. 上記URLをブラウザで開く
   ```
   https://grafana-camel-observability-demo.apps.cluster.example.com
   ```

2. ログイン
   - ユーザー名: `admin`
   - パスワード: `admin123`

3. 左メニュー → **Dashboards**

4. 検索ボックスに「**Undertow**」と入力

5. **Undertow Monitoring Dashboard** が表示されることを確認

**または、直接アクセス:**
```
https://grafana-camel-observability-demo.apps.cluster.example.com/d/undertow-monitoring/
```

---

## 🔧 **トラブルシューティング**

### 問題A: ConfigMap適用時にエラー

**エラー例:**
```
Error from server (Forbidden): error when creating "grafana/grafana-dashboards-configmap.yaml": configmaps is forbidden
```

**原因:** 権限不足

**解決策:**
```bash
# 権限を確認
oc auth can-i create configmap
oc auth can-i update configmap

# プロジェクト管理者権限を付与してもらう
```

---

### 問題B: Grafana Podが起動しない

```bash
# Pod状態を詳細確認
oc get pods -l app=grafana

# Podのイベントを確認
oc describe pod -l app=grafana

# Podのログを確認
oc logs -l app=grafana --previous
```

**一般的な原因:**
- イメージの取得エラー
- PVC（Persistent Volume Claim）のマウントエラー
- リソース不足

---

### 問題C: ダッシュボードは表示されるがデータがない

```bash
# camel-appが起動しているか確認
oc get pods -l app=camel-app

# camel-appのメトリクスを確認
oc exec deployment/camel-app -- \
  curl -s http://localhost:8080/actuator/prometheus | grep undertow

# 期待される出力:
# undertow_worker_threads{...} 200.0
# undertow_request_queue_size{...} 0.0
# undertow_active_requests{...} 0.0
# undertow_io_threads{...} 4.0

# Prometheusがターゲットを認識しているか確認
oc port-forward svc/prometheus 9090:9090 &
# ブラウザで http://localhost:9090/targets を開く
# camel-app のターゲットが "UP" であることを確認
```

---

## 🤖 **自動スクリプトの使用（推奨）**

手動での実行が面倒な場合、自動スクリプトを使用してください：

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# スクリプトに実行権限を付与（初回のみ）
chmod +x APPLY_UNDERTOW_DASHBOARD.sh

# スクリプトを実行
./APPLY_UNDERTOW_DASHBOARD.sh
```

**スクリプトが実行すること:**
1. ✅ OpenShift接続確認
2. ✅ プロジェクト確認・切り替え
3. ✅ ConfigMapファイル検証
4. ✅ ConfigMap適用
5. ✅ Grafana Pod再起動
6. ✅ 起動待機
7. ✅ アクセスURL表示

---

## 📋 **完全チェックリスト**

以下のチェックリストを順番に確認してください：

### 前提条件
- [ ] OpenShiftにログインしている (`oc whoami`)
- [ ] camel-observability-demoプロジェクトにいる (`oc project`)

### ConfigMap
- [ ] ConfigMapファイルが存在する (`ls openshift/grafana/grafana-dashboards-configmap.yaml`)
- [ ] ConfigMapにundertowが含まれる (`grep undertow openshift/grafana/grafana-dashboards-configmap.yaml`)
- [ ] OpenShift上にConfigMapが存在する (`oc get configmap grafana-dashboards`)
- [ ] ConfigMap内にundertowが含まれる (`oc get configmap grafana-dashboards -o yaml | grep undertow`)

### Grafana Pod
- [ ] Grafana Podが存在する (`oc get pods -l app=grafana`)
- [ ] Grafana PodがRunning状態である
- [ ] Grafana Podを再起動した (`oc delete pod -l app=grafana`)
- [ ] 新しいPodが起動した (`oc wait --for=condition=ready pod -l app=grafana`)
- [ ] Grafana Podログにundertowがある (`oc logs -l app=grafana | grep undertow`)

### Grafana UI
- [ ] Grafana Routeが存在する (`oc get route grafana`)
- [ ] ブラウザでGrafanaにアクセスできる
- [ ] ログインできる (admin/admin123)
- [ ] Dashboards一覧を開ける
- [ ] 検索で"Undertow"と入力できる
- [ ] **Undertow Monitoring Dashboard**が表示される ← ゴール！

### メトリクス
- [ ] camel-app Podが起動している (`oc get pods -l app=camel-app`)
- [ ] camel-appからundertowメトリクスが取得できる
- [ ] Prometheusがcamel-appを認識している
- [ ] ダッシュボードにデータが表示される

---

## 🎯 **最小限の修正コマンド（クイック版）**

最も迅速に問題を解決するコマンド：

```bash
# 1. ConfigMapを適用
oc apply -f /Users/kjin/mobills/observability/demo/openshift/grafana/grafana-dashboards-configmap.yaml

# 2. Grafana Podを再起動
oc delete pod -l app=grafana && oc wait --for=condition=ready pod -l app=grafana --timeout=120s

# 3. Grafana URLを取得
echo "Grafana URL: https://$(oc get route grafana -o jsonpath='{.spec.host}')"

# 4. ダッシュボード確認
echo "Undertow Dashboard: https://$(oc get route grafana -o jsonpath='{.spec.host}')/d/undertow-monitoring/"
```

**これを実行してから、ブラウザでGrafanaを開いてください！**

---

## 📚 **関連ドキュメント**

- `APPLY_UNDERTOW_DASHBOARD.sh` - 自動適用スクリプト
- `UNDERTOW_DASHBOARD_README.md` - 詳細な説明
- `UNDERTOW_MIGRATION.md` - Undertow移行ガイド

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**対象**: OpenShift 4.x



