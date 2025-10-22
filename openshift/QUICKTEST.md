# 🚀 クイックテスト - OpenShiftオブザーバビリティデモ

## 📋 5分でできる動作確認

---

## 1️⃣ 環境確認（1分）

```bash
# すべてのPodが正常か確認
oc get pods

# 期待: すべて Running
```

---

## 2️⃣ REST API テスト（1分）

```bash
# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"
# 期待: {"status":"UP"}

# 注文を作成（Kafkaへメッセージ送信）
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","product":"商品A","quantity":10}'
# 期待: {"orderId":"order-001","status":"accepted"...}
```

---

## 3️⃣ Grafanaダッシュボード確認（2分）

```bash
# Grafana URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"
```

### ブラウザでアクセス

1. **ログイン**: admin / admin
2. **左メニュー > Dashboards** をクリック
3. **ダッシュボード一覧**:
   - ✅ Camel Observability Dashboard
   - ✅ Camel Comprehensive Dashboard
   - ✅ Alerts Overview Dashboard

### Comprehensive Dashboard で確認

- **System Overview**:
  - Uptime（稼働時間）
  - Heap Memory Usage（メモリ使用率）
  - Active Threads（スレッド数）
- **HTTP Endpoints**:
  - Request Rate（リクエスト数）
  - Response Time（レスポンス時間）

---

## 4️⃣ トレース確認（1分）

### Grafana Tempoで確認

1. Grafana **左メニュー > Explore**
2. データソースで **Tempo** を選択
3. **Search** タブ:
   - Service Name: `camel-observability-demo`
   - **Run query** をクリック
4. トレース一覧から1つクリック
5. **期待**: `http post` → `/api/orders` → `orders` の階層が表示

---

## 5️⃣ ログ確認（1分）

### Grafana Lokiで確認

1. Grafana **左メニュー > Explore**
2. データソースで **Loki** を選択
3. クエリ:
   ```logql
   {app="camel-observability-demo"}
   ```
4. **Run query** をクリック
5. **期待**: ログが表示される

### trace_idでログ検索

1. Tempoでトレースを表示
2. トレースIDをコピー
3. Lokiで検索:
   ```logql
   {app="camel-observability-demo"} | json | trace_id="<コピーしたID>"
   ```
4. **期待**: そのトレースに関連するログのみ表示

---

## ✅ テスト完了！

すべてのテストが成功したら、以下を試してください：

### 📚 詳細テスト
- **openshift/TEST_GUIDE.md** - 詳細なテストガイド
- 負荷テスト
- アラートテスト
- メトリクス確認

### 🎯 次のステップ
- カスタムダッシュボードの作成
- アラートルールの追加
- 本番環境への展開

---

**オブザーバビリティを体験してください！** 🎉



