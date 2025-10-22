# OpenShift版 Undertow Dashboard "No Data" クイック修正ガイド

## 🚀 **今すぐ実行してください**

OpenShift環境で以下のコマンドを順番に実行してください：

---

### **ステップ1: ImageStreamとタグを確認**

```bash
# ImageStreamの存在確認
oc get imagestream camel-app

# ImageStreamの詳細（タグ情報）を確認
oc describe imagestream camel-app | grep -A 5 "latest"
```

**期待される出力例:**
```
Name:                   camel-app
Namespace:              camel-observability-demo
Created:                4 days ago
Labels:                 app=camel-app
Annotations:            <none>
Image Repository:       image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app
Image Lookup:           local=false
Unique Images:          3
Tags:                   3

latest
  tagged from sha256:xxxxx
  
  * image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app@sha256:xxxxx
      4 hours ago
```

---

### **ステップ2: 正しいタグを取得**

```bash
# 最新のタグを取得
LATEST_TAG=$(oc get is camel-app -o jsonpath='{.status.tags[0].tag}')
echo "最新のタグ: $LATEST_TAG"
```

**期待される出力:**
```
最新のタグ: latest
```

---

### **ステップ3: Deploymentのイメージタグを更新**

```bash
# Deploymentを最新のタグに更新
oc set image deployment/camel-app \
  camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:$LATEST_TAG

# 期待される出力:
# deployment.apps/camel-app image updated
```

---

### **ステップ4: Podの再起動を待機**

```bash
# ロールアウトの進行状況を監視
oc rollout status deployment/camel-app --timeout=180s

# 期待される出力:
# Waiting for deployment "camel-app" rollout to finish: 0 of 1 updated replicas are available...
# deployment "camel-app" successfully rolled out
```

---

### **ステップ5: Podの状態を確認**

```bash
# Pod一覧を表示
oc get pods -l app=camel-app

# 期待される出力:
# NAME                          READY   STATUS    RESTARTS   AGE
# camel-app-xxxxx-yyyyy         1/1     Running   0          2m
```

---

### **ステップ6: Undertowメトリクスを確認**

```bash
# 新しいPod名を取得
CAMEL_POD=$(oc get pod -l app=camel-app -o jsonpath='{.items[0].metadata.name}')
echo "Pod名: $CAMEL_POD"

# アプリケーションの起動を待機（30秒）
echo "アプリケーション起動待機中..."
sleep 30

# Undertowメトリクスを確認
oc exec "$CAMEL_POD" -- curl -s http://localhost:8080/actuator/prometheus | grep "^undertow_"
```

**期待される出力:**
```
undertow_worker_threads{application="camel-observability-demo",} 200.0
undertow_io_threads{application="camel-observability-demo",} 4.0
undertow_active_requests{application="camel-observability-demo",} 0.0
undertow_request_queue_size{application="camel-observability-demo",} 0.0
```

---

### **ステップ7: Grafana Dashboard を確認**

```bash
# Grafana URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo ""
echo "========================================="
echo "✅ 修正完了！"
echo "========================================="
echo ""
echo "Grafana URL: https://$GRAFANA_URL"
echo "Undertow Dashboard: https://$GRAFANA_URL/d/undertow-monitoring/"
echo ""
echo "ログイン情報:"
echo "  ユーザー名: admin"
echo "  パスワード: admin123"
echo ""
```

**ブラウザで以下を確認:**
1. 上記URLをブラウザで開く
2. ログイン（admin / admin123）
3. Undertow Monitoring Dashboard にアクセス
4. **データが表示されることを確認！**

---

## 🔧 **トラブルシューティング**

### 問題A: ImageStreamが見つからない

**エラー:**
```
Error from server (NotFound): imagestreams.image.openshift.io "camel-app" not found
```

**解決策:**
```bash
# BuildConfigを確認
oc get buildconfig camel-app

# BuildConfigが存在する場合、新しいビルドを実行
oc start-build camel-app --follow

# BuildConfigが存在しない場合、OPENSHIFT_DEPLOYMENT_GUIDE.md を参照してイメージをビルド
```

---

### 問題B: Podが起動しない（別のエラー）

```bash
# Podの詳細を確認
oc describe pod -l app=camel-app

# Podのログを確認
oc logs -l app=camel-app --tail=50

# よくあるエラー:
# - CrashLoopBackOff: アプリケーションエラー → ログを確認
# - Pending: リソース不足 → ノードのリソースを確認
# - CreateContainerConfigError: ConfigMapエラー → ConfigMapを確認
```

---

### 問題C: Undertowメトリクスが出力されない

```bash
# ConfigMapが正しくマウントされているか確認
oc exec <POD_NAME> -- cat /config/application.yml | grep -A 8 "server:"

# 期待される出力:
# server:
#   port: 8080
#   undertow:
#     threads:
#       io: 4
#       worker: 200

# メトリクス有効化設定を確認
oc exec <POD_NAME> -- cat /config/application.yml | grep -A 3 "enable:"

# 期待される出力:
#     enable:
#       undertow: true

# もう少し待ってから再確認（アプリケーションの起動に時間がかかる場合）
sleep 60
oc exec <POD_NAME> -- curl -s http://localhost:8080/actuator/prometheus | grep undertow
```

---

### 問題D: メトリクスは出力されているが、Grafanaで "No Data"

```bash
# Prometheusがcamel-appをスクレイプしているか確認
oc port-forward svc/prometheus 9090:9090 &

# ブラウザで以下にアクセス:
# http://localhost:9090/targets

# camel-app が「UP」であることを確認

# Prometheusでクエリを実行:
# http://localhost:9090/graph
# クエリ: undertow_request_queue_size

# データが表示されない場合:
# 1. しばらく待つ（スクレイプ間隔は15-30秒）
# 2. Prometheusの設定を確認
# 3. Grafanaのブラウザキャッシュをクリア
```

---

## 📋 **完全自動化スクリプト**

上記の手順を自動で実行するスクリプトも用意しています：

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./FIX_IMAGE_ISSUE.sh
```

このスクリプトは対話式で、各ステップを確認しながら実行します。

---

## ✅ **成功の確認**

すべて正常に完了すると、以下が確認できます：

1. ✅ Pod状態: `Running`
2. ✅ Undertowメトリクス: 4種類すべて出力される
3. ✅ Prometheus: クエリでデータが取得できる
4. ✅ Grafana Dashboard: すべてのパネルにデータが表示される

---

**作成日**: 2025-10-20  
**推奨実行時間**: 5-10分


