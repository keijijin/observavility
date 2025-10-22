# Undertow版 OpenShift クイックスタート

## 🎯 **概要**

Undertow版のcamel-appをOpenShiftにデプロイする最短手順です。

---

## ⚡ **3ステップでデプロイ**

### ステップ1: OpenShiftにログイン

```bash
# OpenShift CLIでログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>

# プロジェクトを作成
oc new-project camel-observability-demo
```

### ステップ2: Camel App（Undertow版）をデプロイ

#### オプションA: 事前ビルドイメージを使用

```bash
cd /Users/kjin/mobills/observability/demo

# AMD64イメージをビルド
podman build --platform linux/amd64 -f openshift/Dockerfile -t camel-app:undertow .

# イメージをタグ付けしてプッシュ（Quay.ioの例）
podman tag camel-app:undertow quay.io/<your-username>/camel-app:undertow
podman push quay.io/<your-username>/camel-app:undertow

# OpenShiftにデプロイ
oc new-app quay.io/<your-username>/camel-app:undertow --name=camel-app
oc expose svc/camel-app
```

#### オプションB: OpenShiftでビルド（推奨）

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# デプロイメントを適用
oc apply -f camel-app/camel-app-deployment.yaml

# サービスを作成
oc create service clusterip camel-app --tcp=8080:8080

# ルートを作成
oc expose svc/camel-app
```

### ステップ3: オブザーバビリティスタックをデプロイ

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# すべてのコンポーネントをデプロイ
./deploy.sh

# または、個別にデプロイ
oc apply -f kafka/
oc apply -f prometheus/
oc apply -f grafana/
oc apply -f tempo/
oc apply -f loki/
```

---

## ✅ **動作確認**

### 1. Undertowメトリクスの確認

```bash
# camel-app Podのメトリクスを確認
oc exec -it deployment/camel-app -- \
  curl -s http://localhost:8080/actuator/prometheus | grep undertow

# 期待される出力:
# undertow_worker_threads{application="camel-observability-demo",} 200.0
# undertow_request_queue_size{application="camel-observability-demo",} 0.0
# undertow_active_requests{application="camel-observability-demo",} 0.0
# undertow_io_threads{application="camel-observability-demo",} 4.0
```

### 2. Grafanaダッシュボードの確認

```bash
# GrafanaのURLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana URL: https://$GRAFANA_URL"

# ブラウザで開く
open "https://$GRAFANA_URL"
```

**ログイン情報:**
- ユーザー名: `admin`
- パスワード: `admin123`

**確認するダッシュボード:**
1. **Camel Observability Dashboard** - 既存
2. **Alerts Overview Dashboard** - 既存
3. **Camel Comprehensive Dashboard** - 既存
4. **Undertow Monitoring Dashboard** - 新規追加 ⭐

### 3. REST APIテスト

```bash
# camel-appのRouteを取得
CAMEL_ROUTE=$(oc get route camel-app -o jsonpath='{.spec.host}')

# POSTリクエスト
curl -X POST "https://${CAMEL_ROUTE}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id": "ORD-001", "product": "Test Product", "quantity": 1, "price": 100}'

# 期待される出力:
# "Order created successfully"
```

---

## 📊 **Undertowメトリクスの見方**

### Grafana: Undertow Monitoring Dashboard

#### ⭐ Undertow Queue Size（ゲージ）

```
値: 0 → ✅ 正常（リクエストがキューに溜まっていない）
値: 10-50 → ⚠️ 注意（一時的な負荷）
値: 50+ → 🚨 警告（ワーカースレッド不足）
```

#### Undertow Worker Usage %（ゲージ）

```
値: 0-50% → ✅ 正常
値: 50-85% → ⚠️ 注意
値: 85-95% → 🟠 警告
値: 95-100% → 🚨 危険（スケールアップ必要）
```

#### Undertow Active Requests（時系列）

```
通常: 0-50
高負荷: 100-150
危険: 150-200（ワーカースレッド数に近い）
```

---

## 🔧 **設定のカスタマイズ**

### ワーカースレッド数の変更

#### 方法1: 環境変数で設定

```bash
# Deploymentを編集
oc set env deployment/camel-app \
  SERVER_UNDERTOW_THREADS_WORKER=100 \
  SERVER_UNDERTOW_THREADS_IO=4

# Podが再起動されます
```

#### 方法2: ConfigMapで設定

```bash
# ConfigMapを作成
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: camel-app-config
data:
  application.yml: |
    server:
      undertow:
        threads:
          worker: 100
          io: 4
EOF

# Deploymentに追加
oc set volumes deployment/camel-app \
  --add --type=configmap \
  --name=config \
  --configmap-name=camel-app-config \
  --mount-path=/app/config
```

---

## 🧪 **負荷テスト**

### 簡単な負荷テスト

```bash
CAMEL_ROUTE=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 100件の並列リクエスト
for i in {1..100}; do
  curl -X POST "https://${CAMEL_ROUTE}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d '{"id": "ORD-'$i'", "product": "Load Test", "quantity": 1, "price": 100}' &
done
wait

# Grafanaでメトリクスを確認
echo "Grafana URL: https://$(oc get route grafana -o jsonpath='{.spec.host}')"
```

### ストレステスト（OpenShift版）

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# ストレステストスクリプト実行
./stress_test.sh

# リアルタイムでGrafanaを確認
```

---

## 🔍 **トラブルシューティング**

### 問題: Undertowメトリクスが表示されない

```bash
# Podのログを確認
oc logs -f deployment/camel-app | grep -i undertow

# 期待される出力:
# Undertow started on port(s) 8080 (http)
```

### 問題: キューサイズが常にNaN

```bash
# UndertowMetricsConfig.javaが含まれているか確認
oc exec -it deployment/camel-app -- \
  ls -la /app/BOOT-INF/classes/com/example/demo/config/

# 期待される出力:
# UndertowMetricsConfig.class
```

**解決策**: イメージを再ビルドして再デプロイ

### 問題: Grafanaダッシュボードが表示されない

```bash
# ConfigMapを確認
oc get configmap grafana-dashboards -o yaml | grep undertow

# 期待される出力:
#   undertow-monitoring-dashboard.json: "{...}"

# Grafana Podを再起動
oc delete pod -l app=grafana
```

---

## 📚 **関連ドキュメント**

- [UNDERTOW_MIGRATION.md](./UNDERTOW_MIGRATION.md) - 完全な移行ガイド
- [OPENSHIFT_DEPLOYMENT_GUIDE.md](./OPENSHIFT_DEPLOYMENT_GUIDE.md) - 詳細なデプロイ手順
- [QUICKSTART.md](./QUICKSTART.md) - 基本的なクイックスタート

---

## ✅ **確認チェックリスト**

デプロイ後、以下を確認してください：

- [ ] camel-app Podが起動している
- [ ] Undertowメトリクスが取得できる
- [ ] Grafana Undertow Monitoring Dashboardが表示される
- [ ] REST APIが正常に動作する
- [ ] Prometheusでundertowメトリクスが確認できる
- [ ] 負荷テストでキューサイズが増減する

---

**作成日**: 2025-10-20  
**バージョン**: 1.0  
**対象環境**: OpenShift 4.x with Undertow


