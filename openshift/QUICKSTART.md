# 🚀 OpenShift クイックスタート

最速でOpenShift上にデモ環境をデプロイする手順です。

**🔔 最新情報**: camel-appが**Undertow**に移行されました！詳細は [UNDERTOW_MIGRATION.md](./UNDERTOW_MIGRATION.md) を参照してください。

---

## ⚡ 3ステップでデプロイ

### ステップ1: OpenShiftにログイン

```bash
# OpenShift CLIでログイン
oc login --token=<YOUR_TOKEN> --server=<YOUR_SERVER>

# プロジェクトを作成
oc new-project camel-observability-demo
```

### ステップ2: Camel Appをデプロイ

#### オプションA: S2Iでビルド（推奨・最も簡単）✨

ソースコードから直接OpenShift上でビルドします。**イメージビルド不要！**

```bash
# GitHubにコードをプッシュ後
oc new-app registry.access.redhat.com/ubi9/openjdk-17:latest~https://github.com/YOUR_USERNAME/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app \
  --strategy=source

# ビルド状況を確認
oc logs -f bc/camel-app

# 完了後、サービスとルートを作成
oc expose svc/camel-app
```

**メリット:**
- ローカルでのイメージビルド不要
- Podmanの問題を回避
- OpenShiftが自動的にビルド

#### オプションB: 事前ビルドしたJARをデプロイ

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# ローカルでビルド
mvn clean package -DskipTests

# JARファイルをOpenShiftにアップロード
oc new-build --name=camel-app \
  --image-stream=openjdk-17:latest \
  --binary=true

oc start-build camel-app --from-file=target/camel-observability-demo-1.0.0.jar --follow

# デプロイ
oc new-app camel-app:latest
oc expose svc/camel-app
```

#### オプションC: Podmanでビルド（注意: バグあり）

```bash
# ソースコードをGitHubにプッシュ後
oc new-app registry.access.redhat.com/ubi8/openjdk-17~https://github.com/YOUR_REPO/camel-observability-demo \
  --name=camel-app \
  --context-dir=demo/camel-app
```

### ステップ3: デプロイ

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# すべてをデプロイ
./deploy.sh
```

待機時間: **約5-10分**

---

## ✅ 動作確認

### すべてのPodが起動しているか確認

```bash
oc get pods

# すべて Running になっているはず
```

### Grafanaにアクセス

```bash
# URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"

# ブラウザで開く
open "https://${GRAFANA_URL}"
```

**ログイン:**
- ユーザー名: `admin`
- パスワード: `admin`

### Camel Appにリクエストを送信

```bash
# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"

# オーダー作成
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","product":"laptop","quantity":1}'
```

### Grafanaでデータを確認

1. **メトリクス**: Explore → Prometheus → `rate(http_server_requests_seconds_count[1m])`
2. **トレース**: Explore → Tempo → Search → Run query
3. **ログ**: Explore → Loki → `{app="camel-app"}` → Run query

---

## 🧹 クリーンアップ

```bash
cd /Users/kjin/mobills/observability/demo/openshift

# すべて削除
./cleanup.sh

# またはプロジェクト全体を削除
oc delete project camel-observability-demo
```

---

## 📚 詳細ガイド

- **完全ガイド**: [OPENSHIFT_DEPLOYMENT_GUIDE.md](./OPENSHIFT_DEPLOYMENT_GUIDE.md)
- **イメージビルド**: [BUILD_IMAGE_GUIDE.md](./BUILD_IMAGE_GUIDE.md)

---

**5分でOpenShift上のオブザーバビリティ環境を構築！**🎉

