# OpenShift版 Tempo トレース問題 - 修正完了レポート

## 📋 問題の概要

**症状**: OpenShift版のGrafana Tempoでトレースが表示されない

**エラーメッセージ**:
```
Failed to export spans. The request could not be executed. 
Full error message: Failed to connect to localhost/[0:0:0:0:0:0:0:1]:4318
```

---

## 🔍 根本原因

OpenTelemetry SDKが環境変数`OTEL_EXPORTER_OTLP_ENDPOINT`を認識しておらず、デフォルトの`localhost:4318`に接続しようとしていました。

### なぜ`application.yml`の設定だけでは不十分だったのか？

`application.yml`には以下の設定がありましたが：

```yaml
camel:
  opentelemetry:
    endpoint: http://tempo:4318/v1/traces

management:
  otlp:
    endpoint: http://tempo:4318
    tracing:
      endpoint: http://tempo:4318/v1/traces
```

これらは**Spring Boot/Camel固有の設定**であり、**OpenTelemetry Java Agent/SDK**は直接参照しません。

OpenTelemetry SDKは以下の優先順位で設定を読み込みます：
1. **環境変数** （最優先）
2. システムプロパティ
3. `opentelemetry-configuration.properties`
4. デフォルト値（`localhost:4318`）

---

## ✅ 実施した修正

### 1. 環境変数の追加

`openshift/camel-app/camel-app-deployment.yaml`のDeployment定義に以下の環境変数を追加：

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://tempo:4318
  - name: OTEL_SERVICE_NAME
    value: camel-observability-demo
  - name: OTEL_TRACES_EXPORTER
    value: otlp
```

**各環境変数の役割**:

| 環境変数 | 役割 | 値 |
|---------|------|-----|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLPエクスポーターのベースURL | `http://tempo:4318` |
| `OTEL_SERVICE_NAME` | トレース内のサービス名 | `camel-observability-demo` |
| `OTEL_TRACES_EXPORTER` | 使用するエクスポーター | `otlp` |

### 2. イメージタグの修正

```yaml
# 修正前
image: image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:1.0.0

# 修正後
image: image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest
```

**理由**: `1.0.0`タグが存在せず、`ImagePullBackOff`エラーが発生していたため。

### 3. Deployment再作成

古いReplicaSetを削除し、Deploymentを再作成して環境変数を確実に反映させました。

```bash
oc delete deployment camel-app
oc apply -f camel-app/camel-app-deployment.yaml
oc set image deployment/camel-app camel-app=image-registry.openshift-image-registry.svc:5000/camel-observability-demo/camel-app:latest
```

---

## 🧪 検証結果

### ✅ 成功指標

#### 1. 環境変数が正しく設定されている

```bash
$ oc exec camel-app-79cfcffd5f-wj6ht -- env | grep OTEL
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4318
OTEL_SERVICE_NAME=camel-observability-demo
OTEL_TRACES_EXPORTER=otlp
```

#### 2. OpenTelemetryエラーが解消

```bash
$ oc logs camel-app-79cfcffd5f-wj6ht | grep "Failed to connect to localhost"
(結果: 0件)
```

#### 3. Tempoにトレースが保存されている

```bash
$ curl http://tempo:3200/api/search?tags=service.name=camel-observability-demo
✅ 見つかったトレース: 50個
```

#### 4. テストリクエストが成功

- 5件のPOSTリクエスト → すべてHTTP 200
- 過去30秒間のエラーログ → 0件

---

## 📊 現在の状態

### Pod情報

| 項目 | 値 |
|------|-----|
| Pod名 | `camel-app-79cfcffd5f-wj6ht` |
| 起動時刻 | `2025-10-21T03:04:39Z` |
| ReplicaSet | `camel-app-79cfcffd5f` |
| 状態 | `Running (1/1)` |
| エラー | なし |

### トレース統計

- **総トレース数**: 50+個
- **サービス名**: `camel-observability-demo`
- **エンドポイント**: `http://tempo:4318`
- **エクスポート状態**: ✅ 正常

### 最新トレースID（サンプル）

1. `3c3fcae58a855a5d5c455680e195c20`
2. `1838b9829a4ae48d8bdc6f89a077b50`
3. `281e82e1a253c753cef43d65f2fa86c`
4. `8a7ea441fd4346f5644149394584986`
5. `124cff091fb971506d4e939f6e968b3d`

---

## 🎯 Grafanaでトレースを確認する方法

### アクセス情報

```
🔗 URL: https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/explore
👤 ユーザー名: admin
🔑 パスワード: admin123
```

### 検索手順

1. **Datasource選択**: `Tempo`を選択
2. **Query Type**: `Search`を選択
3. **Service Name**: `camel-observability-demo`を選択
4. **Run query**をクリック

### トレース詳細の確認

各トレースをクリックすると以下が表示されます：

- **スパン一覧**: リクエストの処理フロー
- **タイミング**: 各処理にかかった時間
- **タグ**: `http.method`, `http.status_code`, `span.kind`など
- **ログ**: 関連するログメッセージ

---

## ⚠️ 注意: 古いログについて

**ユーザーが見たエラーログは修正前の古いPodのログです**

### 古いログの見分け方

| 項目 | 修正前（古い） | 修正後（新しい） |
|------|--------------|----------------|
| Pod起動時刻 | `2025-10-21T03:04:39Z`より前 | `2025-10-21T03:04:39Z`以降 |
| ReplicaSet | `camel-app-65dc67884c` / `camel-app-7fff6dcc59` | `camel-app-79cfcffd5f` |
| エラー | `Failed to connect to localhost:4318` | なし |

### Lokiで古いログが表示される理由

Lokiは過去のログを保持しているため、時間範囲を広く設定すると修正前のエラーログも表示されます。

**最新のログのみを確認する方法**:
- 時間範囲を「Last 5 minutes」に設定
- タイムスタンプを確認（`2025-10-21 03:04:39`以降）

---

## 📝 まとめ

### ✅ 修正完了項目

- [x] OpenTelemetry環境変数の追加
- [x] イメージタグの修正（`1.0.0` → `latest`）
- [x] Deployment再作成とPod再起動
- [x] トレース送信の確認
- [x] エラーログの解消

### ✅ 現在の状態

- **Pod**: 正常稼働（エラーなし）
- **トレース**: Tempoに50+個保存
- **OpenTelemetry**: `http://tempo:4318`に正常接続
- **Grafana Tempo**: トレース検索可能

### 🎉 結論

**OpenShift版のTempo連携は正常に動作しています！**

Grafana Tempoで`camel-observability-demo`のトレースを検索すると、すべてのHTTPリクエストのトレースが表示されます。

---

## 📚 参考資料

### OpenTelemetry環境変数

- [OpenTelemetry Environment Variable Specification](https://opentelemetry.io/docs/reference/specification/sdk-environment-variables/)
- [OTLP Exporter Configuration](https://opentelemetry.io/docs/reference/specification/protocol/exporter/)

### トラブルシューティングコマンド

```bash
# 現在のPod確認
oc get pods -l app=camel-app

# 環境変数確認
oc exec <pod-name> -- env | grep OTEL

# エラーログ検索
oc logs <pod-name> | grep "Failed to connect"

# Tempo API確認
oc exec <tempo-pod> -- wget -q -O - 'http://localhost:3200/api/search?tags=service.name=camel-observability-demo'
```

---

**作成日**: 2025-10-21  
**最終更新**: 2025-10-21  
**ステータス**: ✅ 修正完了・動作確認済み


