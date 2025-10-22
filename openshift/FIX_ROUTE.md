# 🔧 OpenShift Route 修正ガイド

## 🐛 問題

Camel AppのRouteが"Application is not available"エラーを返していました。

## 🔍 原因

**Route と Service のポート名の不一致**

- **Route**: `targetPort: http` を指定
- **Service**: ポート名が `8080-tcp` と `8443-tcp`
- **結果**: Routeが正しいポートを見つけられない

## ✅ 解決方法

### 修正コマンド

```bash
# 古いRouteを削除
oc delete route camel-app

# 正しいポート名で新しいRouteを作成
oc create route edge camel-app --service=camel-app --port=8080-tcp
```

### 確認コマンド

```bash
# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"

# 期待される出力:
# {"status":"UP","components":{...}}
```

---

## 📋 トラブルシューティング手順

### 1. Podの状態を確認

```bash
# Podが起動しているか
oc get pods

# 期待: すべて Running
```

### 2. Podのラベルを確認

```bash
# Camel App Podのラベル
oc get pod <POD_NAME> -o jsonpath='{.metadata.labels}' | jq .

# 例:
# {
#   "deployment": "camel-app",
#   "pod-template-hash": "57974f7598"
# }
```

### 3. Serviceのselectorを確認

```bash
# Serviceのselector
oc get svc camel-app -o jsonpath='{.spec.selector}' | jq .

# 例:
# {
#   "deployment": "camel-app"
# }
```

**重要**: PodのラベルとServiceのselectorが一致している必要があります。

### 4. Endpointsを確認

```bash
# ServiceがPodを選択しているか
oc get endpoints camel-app

# 期待される出力:
# NAME        ENDPOINTS                           AGE
# camel-app   10.135.0.76:8080,10.135.0.76:8443   118m
```

**Endpointsが空の場合**: ServiceのselectorとPodのラベルが一致していません。

### 5. Serviceのポート名を確認

```bash
# Serviceのポート設定
oc get svc camel-app -o yaml | grep -A 10 "ports:"

# 例:
# ports:
#   - name: 8080-tcp
#     port: 8080
#     targetPort: 8080
```

### 6. Routeのtargetportを確認

```bash
# Routeの設定
oc get route camel-app -o yaml | grep -A 5 "port:"

# 例:
# port:
#   targetPort: 8080-tcp
```

**重要**: Routeの`targetPort`はServiceのポート名と一致している必要があります。

### 7. Pod IPに直接アクセスして確認

```bash
# Pod IPを取得
POD_IP=$(oc get pod <POD_NAME> -o jsonpath='{.status.podIP}')

# Pod IPに直接アクセス
oc exec deployment/prometheus -- wget -q -O- "http://${POD_IP}:8080/actuator/health"
```

**成功した場合**: アプリケーションは正常に動作しており、問題はRouteまたはServiceの設定にあります。

---

## 🎯 正しいRoute設定

### オプション1: oc create route（推奨）

```bash
# TLS有効のRouteを作成
oc create route edge camel-app \
  --service=camel-app \
  --port=8080-tcp

# TLSなしのRouteを作成
oc expose svc camel-app --port=8080-tcp
```

### オプション2: YAMLファイルから作成

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: camel-app
spec:
  port:
    targetPort: 8080-tcp  # Serviceのポート名と一致
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: camel-app
```

```bash
# YAMLファイルから適用
oc apply -f route.yaml
```

---

## 📚 参考情報

### OpenShift Routeのドキュメント

- [OpenShift Routes](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)
- [Creating Routes](https://docs.openshift.com/container-platform/latest/networking/routes/secured-routes.html)

### よくある問題

| 問題 | 原因 | 解決方法 |
|------|------|---------|
| **Application is not available** | Routeの設定ミス | Routeを再作成 |
| **502 Bad Gateway** | Podがダウン | Podを再起動 |
| **504 Gateway Time-out** | アプリケーションの処理が遅い | タイムアウト設定を調整 |
| **No resources found** | Podのラベルが間違っている | Deployment/Serviceを確認 |

---

## ✅ 完了チェックリスト

- [ ] Podが`Running`状態
- [ ] PodのラベルとServiceのselectorが一致
- [ ] Endpointsが設定されている
- [ ] Routeの`targetPort`がServiceのポート名と一致
- [ ] `curl -k https://<ROUTE_URL>/actuator/health` が成功

---

**Route修正完了！** 🎉



