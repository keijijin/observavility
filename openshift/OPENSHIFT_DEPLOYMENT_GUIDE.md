# 🚀 OpenShiftデプロイメントガイド

本デモ環境をOpenShift上で動かすための完全ガイドです。

**🔔 最新情報**: camel-appがTomcatから**Undertow**に移行されました！詳細は [UNDERTOW_MIGRATION.md](./UNDERTOW_MIGRATION.md) を参照してください。

---

## 📋 目次

1. [前提条件](#前提条件)
2. [アーキテクチャ概要](#アーキテクチャ概要)
3. [Undertow移行について](#undertow移行について) ⭐ NEW
4. [事前準備](#事前準備)
5. [デプロイ手順](#デプロイ手順)
6. [動作確認](#動作確認)
7. [トラブルシューティング](#トラブルシューティング)
8. [クリーンアップ](#クリーンアップ)

---

## 🎯 前提条件

### 必要なツール

```bash
# OpenShift CLI (oc)
oc version

# kubectl (オプション)
kubectl version --client

# podman または docker
podman --version
```

### OpenShift環境

以下のいずれかの環境が必要です：

#### オプション1: OpenShift Local (CRC)
```bash
# OpenShift Localのインストール
# https://developers.redhat.com/products/openshift-local/overview

crc setup
crc start
```

#### オプション2: OpenShift Online / Dedicated / Container Platform
- クラスタへのアクセス権限
- プロジェクト作成権限
- ルート作成権限

#### オプション3: Red Hat Developer Sandbox
- 無料で利用可能
- https://developers.redhat.com/developer-sandbox

### 必要なリソース

| コンポーネント | CPU | メモリ | ストレージ |
|------------|-----|--------|----------|
| Kafka | 1 core | 2Gi | 10Gi |
| Zookeeper | 0.5 core | 1Gi | 5Gi |
| Prometheus | 0.5 core | 2Gi | 10Gi |
| Grafana | 0.5 core | 1Gi | 5Gi |
| Tempo | 0.5 core | 1Gi | 10Gi |
| Loki | 0.5 core | 1Gi | 10Gi |
| Camel App | 1 core | 2Gi | - |
| **合計** | **4.5 cores** | **10Gi** | **50Gi** |

---

## 🏗️ アーキテクチャ概要

### OpenShift上のコンポーネント構成

```
┌─────────────────────────────────────────────────────────┐
│              OpenShift Cluster                          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Namespace: camel-observability-demo            │   │
│  │                                                 │   │
│  │  ┌──────────────┐    ┌──────────────┐          │   │
│  │  │   Kafka      │←───│  Zookeeper   │          │   │
│  │  │  (Service)   │    │  (Service)   │          │   │
│  │  └──────┬───────┘    └──────────────┘          │   │
│  │         │                                       │   │
│  │         ↓                                       │   │
│  │  ┌──────────────┐                              │   │
│  │  │  Camel App   │                              │   │
│  │  │  (Deploy)    │───→ OpenTelemetry            │   │
│  │  └──────┬───────┘       ↓                      │   │
│  │         │          ┌────────────┐              │   │
│  │         │          │   Tempo    │              │   │
│  │         │          │ (Traces)   │              │   │
│  │         │          └────────────┘              │   │
│  │         │                                       │   │
│  │         ├────→ Prometheus  ←─────┐             │   │
│  │         │      (Metrics)          │             │   │
│  │         │                         │             │   │
│  │         └────→ Loki               │             │   │
│  │              (Logs)               │             │   │
│  │                                   │             │   │
│  │              ┌────────────────────┘             │   │
│  │              │                                  │   │
│  │         ┌────▼──────┐                          │   │
│  │         │  Grafana  │                          │   │
│  │         │  (UI)     │                          │   │
│  │         └───────────┘                          │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Routes (External Access):                             │
│   - grafana-route → Grafana UI                         │
│   - camel-app-route → Camel REST API                   │
│   - prometheus-route → Prometheus UI                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## ⚡ Undertow移行について

### 🎯 **変更点**

camel-appが**Tomcat**から**Undertow**に移行されました。

### 📊 **メリット**

| 項目 | Tomcat | Undertow | 改善 |
|---|---|---|---|
| **メモリ使用量** | 高 | 低 | ✅ 10-15%削減 |
| **スループット** | 標準 | 高 | ✅ 10-20%向上 |
| **レイテンシ** | 標準 | 低 | ✅ 5-10%削減 |
| **起動時間** | 標準 | 速い | ✅ 10%向上 |

### 📈 **新しいメトリクス**

Undertow専用のメトリクスが追加されました：

- `undertow_worker_threads` - ワーカースレッド数（デフォルト: 200）
- `undertow_request_queue_size` - リクエストキューサイズ（0が理想）
- `undertow_active_requests` - アクティブリクエスト数
- `undertow_io_threads` - I/Oスレッド数（デフォルト: 4）

### 📊 **Grafanaダッシュボード**

**Undertow Monitoring Dashboard** が追加されました：

- ⭐ Undertow Queue Size（ゲージ）
- Undertow Active Requests（時系列）
- Undertow Worker Usage %（ゲージ）
- ⭐ Undertow Queue Size（時系列）

### 📚 **詳細ドキュメント**

Undertow移行の詳細は [UNDERTOW_MIGRATION.md](./UNDERTOW_MIGRATION.md) を参照してください。

---

## 🔧 事前準備

### ステップ1: OpenShiftにログイン

```bash
# OpenShift Localの場合
eval $(crc oc-env)
oc login -u developer https://api.crc.testing:6443

# またはトークンでログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>
```

### ステップ2: プロジェクト（Namespace）の作成

```bash
# プロジェクト作成
oc new-project camel-observability-demo

# 確認
oc project
```

### ステップ3: コンテナイメージのビルド（Camel App）

#### オプション1: Dockerfile からビルド（推奨）

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# Dockerfileを使ってビルド
podman build -t camel-observability-demo:1.0.0 .

# または、プロジェクトルートから
cd /Users/kjin/mobills/observability/demo
podman build -f camel-app/Dockerfile -t camel-observability-demo:1.0.0 camel-app/

# OpenShift内部レジストリにプッシュ（後述）
```

#### オプション2: OpenShift S2I (Source-to-Image)

```bash
# Mavenプロジェクトから直接ビルド
oc new-app registry.access.redhat.com/ubi8/openjdk-17~https://github.com/YOUR_REPO/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app
```

---

## 🚀 デプロイ手順

### デプロイスクリプトの実行

すべてのマニフェストを一括デプロイ:

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./deploy.sh
```

### または個別にデプロイ

#### 1. Kafka & Zookeeper のデプロイ

```bash
oc apply -f kafka/
```

待機:
```bash
oc wait --for=condition=ready pod -l app=zookeeper --timeout=300s
oc wait --for=condition=ready pod -l app=kafka --timeout=300s
```

#### 2. Prometheus のデプロイ

```bash
oc apply -f prometheus/
```

#### 3. Grafana のデプロイ

```bash
oc apply -f grafana/
```

#### 4. Tempo のデプロイ

```bash
oc apply -f tempo/
```

#### 5. Loki のデプロイ

```bash
oc apply -f loki/
```

#### 6. Camel App のデプロイ

```bash
# ConfigMapとSecretの作成（必要に応じて）
oc create configmap camel-app-config --from-file=camel-app/application.yml

# デプロイ
oc apply -f camel-app/
```

### すべてのリソースを確認

```bash
# Pod一覧
oc get pods

# Service一覧
oc get svc

# Route一覧
oc get route

# PVC一覧
oc get pvc
```

---

## 🌐 外部アクセスの設定（Routes）

### Grafana UI へのアクセス

```bash
# Routeの作成
oc expose svc/grafana

# URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana URL: https://${GRAFANA_URL}"

# ブラウザで開く
open "https://${GRAFANA_URL}"
```

デフォルト認証情報:
- ユーザー名: `admin`
- パスワード: `admin` (初回ログイン時に変更を求められます)

### Camel App REST API へのアクセス

```bash
# Routeの作成
oc expose svc/camel-app

# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
echo "Camel App URL: https://${CAMEL_URL}"

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"

# オーダー作成
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","product":"laptop","quantity":1}'
```

### Prometheus UI へのアクセス

```bash
# Routeの作成
oc expose svc/prometheus

# URLを取得
PROM_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
echo "Prometheus URL: https://${PROM_URL}"
```

---

## ✅ 動作確認

### 1. すべてのPodが起動しているか確認

```bash
oc get pods

# 期待される出力:
# NAME                         READY   STATUS    RESTARTS   AGE
# kafka-xxxxx                  1/1     Running   0          5m
# zookeeper-xxxxx              1/1     Running   0          5m
# prometheus-xxxxx             1/1     Running   0          4m
# grafana-xxxxx                1/1     Running   0          4m
# tempo-xxxxx                  1/1     Running   0          3m
# loki-xxxxx                   1/1     Running   0          3m
# camel-app-xxxxx              1/1     Running   0          2m
```

### 2. サービスの疎通確認

```bash
# Camel App のヘルスチェック
oc exec -it deployment/camel-app -- curl http://localhost:8080/actuator/health

# Prometheusのターゲット確認
oc exec -it deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

### 3. Grafana でデータソースの確認

1. Grafana にアクセス
2. Configuration → Data Sources
3. 以下が設定されているか確認:
   - Prometheus
   - Tempo
   - Loki

### 4. メトリクスの確認

```bash
# Prometheus でメトリクスを確認
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
curl -k "https://${CAMEL_URL}/actuator/prometheus" | grep camel_exchanges_total
```

### 5. トレースの確認

1. Grafana → Explore → Tempo
2. 「Search」タブで「Run query」
3. トレース一覧が表示されるか確認

### 6. ログの確認

1. Grafana → Explore → Loki
2. クエリ: `{app="camel-app"}`
3. 「Run query」でログが表示されるか確認

---

## 🔄 負荷テストの実行

### OpenShift上での負荷テスト

```bash
# Camel App のURLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 負荷テスト用のJobを作成
cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
spec:
  template:
    spec:
      containers:
      - name: load-test
        image: curlimages/curl:latest
        command:
        - /bin/sh
        - -c
        - |
          for i in \$(seq 1 100); do
            curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \\
              -H "Content-Type: application/json" \\
              -d "{\"id\":\"order-\${i}\",\"product\":\"laptop\",\"quantity\":1}"
            sleep 0.1
          done
      restartPolicy: Never
EOF

# Jobの実行状況を確認
oc get jobs
oc logs job/load-test -f
```

---

## 🐛 トラブルシューティング

### Pod が起動しない場合

```bash
# Pod の詳細を確認
oc describe pod <POD_NAME>

# ログを確認
oc logs <POD_NAME>

# 前のコンテナのログを確認（再起動した場合）
oc logs <POD_NAME> --previous
```

### イメージのPull エラー

```bash
# ImagePullBackOff の場合、イメージ名を確認
oc get pod <POD_NAME> -o yaml | grep image:

# プライベートレジストリの場合、Secretを作成
oc create secret docker-registry regcred \
  --docker-server=<YOUR_REGISTRY> \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_PASSWORD> \
  --docker-email=<YOUR_EMAIL>

# DeploymentにSecretを追加
oc set serviceaccount deployment/camel-app default
oc patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}'
```

### 永続ストレージの問題

```bash
# PVCの状態を確認
oc get pvc

# Bound になっていない場合、StorageClassを確認
oc get storageclass

# デフォルトのStorageClassを設定
oc patch storageclass <STORAGE_CLASS_NAME> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### サービス間の接続エラー

```bash
# DNSの確認
oc exec -it deployment/camel-app -- nslookup kafka

# サービスの確認
oc get svc

# NetworkPolicyが原因の場合、ポリシーを確認
oc get networkpolicy
```

### Grafana でデータが表示されない

```bash
# Prometheusのターゲット確認
oc port-forward svc/prometheus 9090:9090
# ブラウザで http://localhost:9090/targets

# データソースの設定を確認
# Grafana内部からはServiceDNSを使用: http://prometheus:9090
```

---

## 🧹 クリーンアップ

### すべてのリソースを削除

```bash
# プロジェクト全体を削除
oc delete project camel-observability-demo

# または個別に削除
cd /Users/kjin/mobills/observability/demo/openshift
./cleanup.sh
```

### 個別のリソースを削除

```bash
# Camel App のみ削除
oc delete -f camel-app/

# Kafka のみ削除
oc delete -f kafka/
```

---

## 📊 スケーリング

### Camel App のスケールアウト

```bash
# レプリカ数を増やす
oc scale deployment/camel-app --replicas=3

# 確認
oc get pods -l app=camel-app

# オートスケーリングの設定
oc autoscale deployment/camel-app --min=2 --max=10 --cpu-percent=70
```

### Horizontal Pod Autoscaler (HPA) の確認

```bash
oc get hpa
```

---

## 🔒 セキュリティ設定

### TLS/HTTPSの有効化

```bash
# Routeに自己署名証明書を使用（デフォルト）
oc create route edge grafana --service=grafana

# または既存の証明書を使用
oc create route edge grafana --service=grafana \
  --cert=tls.crt \
  --key=tls.key \
  --ca-cert=ca.crt
```

### RBAC（Role-Based Access Control）

```bash
# サービスアカウントの作成
oc create serviceaccount camel-app-sa

# Roleの作成（必要に応じて）
oc create role camel-app-role --verb=get,list --resource=pods

# RoleBindingの作成
oc create rolebinding camel-app-rolebinding \
  --role=camel-app-role \
  --serviceaccount=camel-observability-demo:camel-app-sa
```

---

## 📈 モニタリング

### OpenShift の組み込みモニタリング

```bash
# OpenShift Webコンソールで確認
# Observe → Dashboards → camel-observability-demo
```

### メトリクスの確認

```bash
# Prometheusメトリクスをスクレイプ
oc port-forward svc/prometheus 9090:9090

# ブラウザで http://localhost:9090
```

---

## 🎯 ベストプラクティス

### 1. リソースの制限と要求を設定

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### 2. ヘルスチェックの設定

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
```

### 3. ConfigMap と Secret の利用

```bash
# 設定ファイルをConfigMapに
oc create configmap camel-app-config --from-file=application.yml

# 機密情報はSecretに
oc create secret generic camel-app-secret \
  --from-literal=kafka-password=secret123
```

### 4. 永続ストレージの使用

```yaml
volumeMounts:
  - name: prometheus-data
    mountPath: /prometheus
volumes:
  - name: prometheus-data
    persistentVolumeClaim:
      claimName: prometheus-pvc
```

---

## 📚 参考リンク

- [OpenShift Documentation](https://docs.openshift.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Apache Camel on Kubernetes](https://camel.apache.org/camel-k/latest/)
- [Grafana on Kubernetes](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

## 🎉 まとめ

このガイドに従うことで、ローカルのPodman/Docker Compose環境からOpenShiftへの移行が完了します。

**主な変更点:**
- ✅ Docker Compose → Kubernetes Manifests
- ✅ localhost → Kubernetes Service DNS
- ✅ Volumes → PersistentVolumeClaims
- ✅ ポートマッピング → Services & Routes

**次のステップ:**
1. マニフェストファイルを確認・カスタマイズ
2. `deploy.sh` スクリプトでデプロイ
3. Grafana UIで動作確認
4. 負荷テストで検証

---

**OpenShift上でオブザーバビリティの三本柱を体験しましょう！**🚀

