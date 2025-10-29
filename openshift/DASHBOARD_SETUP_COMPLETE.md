# 📊 ダッシュボードセットアップ完了

## ✅ 完了事項

### 1. ConfigMap作成

以下のConfigMapを作成しました：

```bash
oc get configmap | grep grafana
# grafana-datasources         1      (データソース設定)
# grafana-dashboard-provider   1      (ダッシュボードプロバイダー設定)
# grafana-dashboards           3      (ダッシュボードファイル x 3)
```

### 2. ダッシュボードファイル

以下の3つのダッシュボードがプロビジョニングされました：

| ファイル名 | 説明 |
|-----------|------|
| **camel-dashboard.json** | 基本的なシステム概要ダッシュボード |
| **camel-comprehensive-dashboard.json** | 詳細メトリクス（17パネル） |
| **alerts-overview-dashboard.json** | Prometheusアラート監視 |

### 3. Grafana Deployment更新

Grafana Deploymentに以下のボリュームマウントを追加：

```yaml
volumeMounts:
  - name: grafana-dashboard-provider
    mountPath: /etc/grafana/provisioning/dashboards
  - name: grafana-dashboards
    mountPath: /var/lib/grafana/dashboards

volumes:
  - name: grafana-dashboard-provider
    configMap:
      name: grafana-dashboard-provider
  - name: grafana-dashboards
    configMap:
      name: grafana-dashboards
```

---

## 🎯 アクセス方法

### Grafana URL

```bash
# URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "https://${GRAFANA_URL}"
```

**認証情報**: admin / admin

---

## 📊 ダッシュボード確認手順

### 1. ブラウザでGrafanaを開く

```bash
open "https://$(oc get route grafana -o jsonpath='{.spec.host}')"
```

### 2. ログイン

- Username: `admin`
- Password: `admin`

### 3. ダッシュボード一覧を表示

1. **左メニュー（☰）> Dashboards** をクリック
2. または、検索ボックスで「Camel」と入力

### 4. 期待される結果

以下の3つのダッシュボードが表示されるはず：

1. ✅ **Camel Observability Dashboard**
   - システム概要
   - JVMメトリクス
   - HTTP統計

2. ✅ **Camel Comprehensive Dashboard**
   - 17個の詳細パネル
   - System Overview
   - Camel Route Performance
   - HTTP Endpoints
   - JVM Memory Details
   - End-to-End Message Flow

3. ✅ **Alerts Overview Dashboard**
   - Firing/Pending Alerts Count
   - Critical Alerts Table
   - Warning Alerts Table
   - Alert History

---

## 🧪 動作確認

### テスト1: ダッシュボードが表示されるか

```bash
# Grafana APIでダッシュボード一覧を取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
curl -k -u admin:admin "https://${GRAFANA_URL}/api/search?type=dash-db"
```

**期待される出力**: 3つのダッシュボードのJSON配列

### テスト2: メトリクスが表示されるか

1. Grafanaで **Camel Comprehensive Dashboard** を開く
2. 各パネルにデータが表示されているか確認
3. もし「No data」と表示される場合:
   - Camel Appが起動しているか確認: `oc get pods`
   - Prometheusがスクレイプしているか確認: Prometheus UI > Status > Targets

### テスト3: リアルタイム更新

```bash
# 注文を作成してメトリクスが変化するか確認
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

for i in {1..10}; do
  curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"order-${i}\",\"product\":\"商品${i}\",\"quantity\":${i}}"
  sleep 1
done
```

**Grafanaで確認**:
- Request Rate が増加
- Processing Time が記録される
- Exchange Total が増加

---

## 🔧 トラブルシューティング

### ダッシュボードが表示されない場合

#### 1. ConfigMapが作成されているか確認

```bash
oc get configmap grafana-dashboards
oc get configmap grafana-dashboard-provider

# ConfigMapの内容を確認
oc describe configmap grafana-dashboards
```

#### 2. ConfigMapがマウントされているか確認

```bash
# Grafana Pod内でファイルを確認
oc exec deployment/grafana -- ls -la /var/lib/grafana/dashboards/
oc exec deployment/grafana -- ls -la /etc/grafana/provisioning/dashboards/
```

**期待される出力**:
```
/var/lib/grafana/dashboards/:
  camel-dashboard.json
  camel-comprehensive-dashboard.json
  alerts-overview-dashboard.json

/etc/grafana/provisioning/dashboards/:
  dashboards.yaml
```

#### 3. Grafanaのログを確認

```bash
# プロビジョニング関連のログ
oc logs deployment/grafana | grep -i "dashboard\|provision"
```

**期待されるログ**:
```
level=info msg="starting to provision dashboards"
level=info msg="finished to provision dashboards"
```

#### 4. Grafana Podを再起動

```bash
oc rollout restart deployment/grafana

# 起動を待機
oc wait --for=condition=ready pod -l app=grafana --timeout=120s

# ログを確認
oc logs deployment/grafana --tail=50
```

### メトリクスが表示されない場合

#### 1. Prometheusがスクレイプしているか確認

```bash
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
curl -k "https://${PROMETHEUS_URL}/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.job=="camel-app")'
```

**期待される結果**: `health: "up"`

#### 2. Camel Appのメトリクスエンドポイントを確認

```bash
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
curl -k "https://${CAMEL_URL}/actuator/prometheus" | head -20
```

**期待される結果**: メトリクスが出力される

#### 3. データソース設定を確認

Grafana UI:
1. **左メニュー > Connections > Data sources**
2. **Prometheus** をクリック
3. **Test** ボタンをクリック
4. **期待**: "Data source is working"

---

## 📚 参考ドキュメント

| ドキュメント | 説明 |
|------------|------|
| **QUICKTEST.md** | 5分でできるクイックテスト |
| **TEST_GUIDE.md** | 詳細なテストガイド |
| **DEPLOYMENT_SUCCESS.md** | デプロイメント成功ガイド |
| **METRICS_GUIDE.md** | 観測可能なメトリクス一覧 |
| **DASHBOARD_GUIDE.md** | ダッシュボードの使い方 |

---

## 🎉 次のステップ

1. ✅ **クイックテストを実行**: `QUICKTEST.md` に従ってテスト
2. ✅ **負荷テストを実行**: メトリクスの変化を観察
3. ✅ **カスタムダッシュボード作成**: 自分用のダッシュボードを作成
4. ✅ **アラート設定**: しきい値を調整

---

**ダッシュボードのセットアップ完了！オブザーバビリティを体験してください！** 🚀




