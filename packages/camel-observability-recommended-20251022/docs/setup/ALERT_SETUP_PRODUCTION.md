# 🚨 本番環境向けアラート設定ガイド

本番環境向けのPrometheusアラート設定の完全ガイドです。

## 📋 含まれるアラート

### 🔴 クリティカルアラート（6個） - 即座の対応が必要

| アラート名 | 閾値 | 持続時間 | コンポーネント |
|-----------|------|---------|-------------|
| **HighMemoryUsage** | > 90% | 2分 | JVM |
| **HighErrorRate** | > 10% | 2分 | Camel |
| **HighHTTPErrorRate** | > 5% | 2分 | HTTP |
| **HighGCOverhead** | > 20% | 5分 | JVM |
| **ApplicationDown** | ダウン | 1分 | Application |
| **UndertowRequestQueueFull** | > 100 | 2分 | Undertow |

### 🟡 警告アラート（9個） - 注意が必要

| アラート名 | 閾値 | 持続時間 | コンポーネント |
|-----------|------|---------|-------------|
| **ModerateMemoryUsage** | > 70% | 5分 | JVM |
| **HighCPUUsage** | > 80% | 5分 | System |
| **SlowResponseTime** | > 1秒 | 3分 | HTTP |
| **HighRunningRoutes** | > 20 | 5分 | Camel |
| **HighThreadCount** | > 100 | 5分 | JVM |
| **ModerateGCOverhead** | > 10% | 5分 | JVM |
| **UndertowHighRequestLoad** | > 60% | 5分 | Undertow |
| **UndertowModerateQueueSize** | > 50 | 3分 | Undertow |
| **SlowCamelRouteProcessing** | > 5秒 | 3分 | Camel |

### ℹ️ 情報アラート（3個） - 参考情報

| アラート名 | 閾値 | 持続時間 | コンポーネント |
|-----------|------|---------|-------------|
| **FrequentGarbageCollection** | > 30回/分 | 5分 | JVM |
| **ApplicationRestarted** | 再起動検出 | 1分 | Application |
| **HighMemoryAllocationRate** | > 10MB/s | 5分 | JVM |

## 🚀 ローカル版セットアップ

### 前提条件

- ✅ Podmanが起動している
- ✅ Prometheusコンテナが実行中
- ✅ Camelアプリケーションが実行中

### ステップ1: アラートルールの確認

アラートルールファイルは既に作成されています：

```bash
cat demo/docker/prometheus/alert_rules.yml
```

### ステップ2: Prometheusを再起動

アラートルールを有効化するためにPrometheusを再起動します：

```bash
cd demo
podman-compose restart prometheus
# または
podman compose restart prometheus
```

### ステップ3: アラートルールの確認

Prometheusでアラートルールが読み込まれたか確認：

```bash
# ブラウザで確認
open http://localhost:9090/alerts

# またはAPIで確認
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | {alert: .name, state: .state}' | head -30
```

**期待される出力:**
```json
{
  "alert": "HighMemoryUsage",
  "state": "inactive"
}
{
  "alert": "HighErrorRate",
  "state": "inactive"
}
...
```

### ステップ4: アラートのテスト

負荷をかけてアラートが正しく発火するか確認：

```bash
# 高負荷テスト
cd demo
./load-test-stress.sh

# アラート状態を確認
open http://localhost:9090/alerts
```

## ☁️ OpenShift版セットアップ

### 前提条件

- ✅ OpenShift環境に接続されている
- ✅ `camel-observability-demo` プロジェクトが存在
- ✅ Prometheusがデプロイされている

### ステップ1: アラートルールConfigMapの適用

```bash
cd demo/openshift

# ConfigMapを作成/更新
oc apply -f prometheus/alert-rules-configmap.yaml

# ConfigMapが作成されたことを確認
oc get configmap prometheus-alert-rules
```

### ステップ2: Prometheus DeploymentにConfigMapをマウント

Prometheus DeploymentにアラートルールConfigMapをマウントします：

```bash
# Prometheus Deploymentを編集
oc edit deployment prometheus
```

以下のボリュームとボリュームマウントを追加：

```yaml
spec:
  template:
    spec:
      volumes:
        - name: prometheus-config
          configMap:
            name: prometheus-config
        - name: prometheus-alert-rules  # 追加
          configMap:
            name: prometheus-alert-rules  # 追加
      containers:
      - name: prometheus
        volumeMounts:
          - name: prometheus-config
            mountPath: /etc/prometheus/prometheus.yml
            subPath: prometheus.yml
          - name: prometheus-alert-rules  # 追加
            mountPath: /etc/prometheus/alert_rules.yml  # 追加
            subPath: alert_rules.yml  # 追加
```

### ステップ3: Prometheus ConfigMapにrule_filesを追加

Prometheus ConfigMapを更新して、アラートルールファイルを読み込むように設定：

```bash
oc edit configmap prometheus-config
```

`prometheus.yml` に以下を追加：

```yaml
rule_files:
  - "alert_rules.yml"
```

### ステップ4: Prometheusを再起動

```bash
# Prometheusを再起動
oc rollout restart deployment/prometheus

# 再起動完了を待機
oc rollout status deployment/prometheus
```

### ステップ5: アラートルールの確認

```bash
# Prometheus URLを取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

# ブラウザで確認
open https://$PROMETHEUS_URL/alerts

# またはAPIで確認
curl -k -s https://$PROMETHEUS_URL/api/v1/rules | jq '.data.groups[].rules[] | {alert: .name, state: .state}' | head -30
```

### 自動化スクリプト

簡単にセットアップできるスクリプトを作成：

```bash
#!/bin/bash
# demo/openshift/SETUP_ALERTS.sh

set -e

echo "🚨 アラート設定をOpenShiftに適用します..."

# ConfigMapを適用
oc apply -f prometheus/alert-rules-configmap.yaml

echo "✅ ConfigMapを適用しました"

# Prometheus URLを表示
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$PROMETHEUS_URL" ]; then
    echo ""
    echo "📊 Prometheusアラート確認URL:"
    echo "   https://$PROMETHEUS_URL/alerts"
fi

echo ""
echo "⚠️  注意: Prometheus Deploymentでアラートルールファイルをマウントする必要があります。"
echo "   詳細は ALERT_SETUP_PRODUCTION.md を参照してください。"
```

## 📧 通知設定（オプション）

アラートを受信するための通知設定です。

### Prometheus Alertmanager設定

#### 1. Alertmanager ConfigMapを作成

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: camel-observability-demo
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    
    route:
      group_by: ['alertname', 'severity']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default-receiver'
      routes:
        - match:
            severity: critical
          receiver: 'critical-receiver'
          continue: true
        - match:
            severity: warning
          receiver: 'warning-receiver'
          continue: true
    
    receivers:
      - name: 'default-receiver'
        webhook_configs:
          - url: 'http://webhook-receiver:8080/alerts'
      
      - name: 'critical-receiver'
        email_configs:
          - to: 'alerts-critical@example.com'
            from: 'prometheus@example.com'
            smarthost: 'smtp.example.com:587'
            auth_username: 'prometheus@example.com'
            auth_password: 'YOUR_PASSWORD'
        slack_configs:
          - api_url: 'YOUR_SLACK_WEBHOOK_URL'
            channel: '#alerts-critical'
            title: '🔴 Critical Alert'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'
      
      - name: 'warning-receiver'
        slack_configs:
          - api_url: 'YOUR_SLACK_WEBHOOK_URL'
            channel: '#alerts-warning'
            title: '🟡 Warning Alert'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'
```

#### 2. Prometheus設定を更新

`prometheus.yml` に Alertmanager の設定を追加：

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### Grafana通知設定

Grafana で直接アラートを設定することもできます。

#### 1. 通知チャネルを作成

Grafana UI:
1. **Configuration** → **Notification channels**
2. **Add channel** をクリック
3. タイプを選択（Email, Slack, PagerDuty, Webhook など）
4. 設定を入力して **Test** をクリック
5. **Save** をクリック

#### 2. ダッシュボードパネルにアラートを設定

1. パネルを編集
2. **Alert** タブをクリック
3. **Create Alert** をクリック
4. 条件を設定
5. 通知チャネルを選択
6. **Save** をクリック

## 📊 アラートの監視

### Prometheus Alerts UI

```
http://localhost:9090/alerts  # ローカル版
https://<prometheus-route>/alerts  # OpenShift版
```

**表示される情報:**
- 🟢 **Inactive**: アラート条件に達していない
- 🟡 **Pending**: 条件に達しているが、`for` の期間中
- 🔴 **Firing**: アラートが発火している

### Grafana Alerts Overview Dashboard

既に用意されている「アラート監視ダッシュボード」を使用：

```
demo/docker/grafana/provisioning/dashboards/alerts-overview-dashboard.json
```

このダッシュボードには以下が含まれます：
- 発火中のアラート数
- 保留中のアラート数
- アラート一覧（重要度別）

## 🧪 アラートのテスト

### 1. HighMemoryUsage のテスト

メモリ使用率を上げてアラートをトリガー：

```bash
# Camelアプリケーションで大量のデータを処理
for i in {1..1000}; do
  curl -X POST http://localhost:8080/camel/api/orders
  sleep 0.1
done

# メモリ使用率を確認
curl -s http://localhost:8080/actuator/prometheus | grep jvm_memory_used_bytes
```

### 2. HighErrorRate のテスト

エラーを発生させてアラートをトリガー：

```bash
# 無効なリクエストを送信
for i in {1..100}; do
  curl -X POST http://localhost:8080/camel/api/invalid-endpoint
done

# エラー率を確認
open http://localhost:9090/graph?g0.expr=rate(camel_exchanges_failed_total%5B5m%5D)
```

### 3. UndertowRequestQueueFull のテスト

高負荷をかけてキューを溢れさせる：

```bash
# 極端な負荷テスト
cd demo
./load-test-extreme-queue.sh

# キューサイズを確認
curl -s http://localhost:8080/actuator/prometheus | grep undertow_request_queue_size
```

## 📋 アラート対応マニュアル

### 🔴 HighMemoryUsage

**症状**: ヒープメモリ使用率が90%を超えている

**即座の対応**:
1. ヒープダンプを取得: `jmap -dump:format=b,file=heap.hprof <pid>`
2. メモリ使用状況を確認: `jstat -gcutil <pid> 1000`
3. 一時的な対処: アプリケーションを再起動

**根本対応**:
- ヒープサイズを増やす: `-Xmx4g` → `-Xmx8g`
- メモリリークを調査（ヒープダンプを分析）
- 不要なキャッシュをクリア

### 🔴 HighErrorRate

**症状**: Camelルートのエラー率が10%を超えている

**即座の対応**:
1. エラーログを確認: `tail -f logs/application.log | grep ERROR`
2. 影響範囲を確認: どのルートでエラーが発生しているか
3. 外部依存サービスの状態を確認（Kafka, DB など）

**根本対応**:
- エラーの原因を特定して修正
- リトライロジックの見直し
- エラーハンドリングの改善

### 🔴 UndertowRequestQueueFull

**症状**: リクエストキューサイズが100を超えている

**即座の対応**:
1. ワーカースレッド数を増やす
2. 一時的にリクエストを制限
3. アプリケーションをスケールアウト

**根本対応**:
- `server.undertow.threads.worker` を増やす
- OpenShiftでレプリカ数を増やす: `oc scale deployment/camel-app --replicas=3`
- パフォーマンスボトルネックを調査

### 🟡 SlowResponseTime

**症状**: HTTPレスポンスタイムが1秒を超えている

**即座の対応**:
1. スロークエリログを確認
2. 外部API呼び出しの状況を確認
3. データベース接続プールの状態を確認

**根本対応**:
- クエリの最適化
- キャッシュの導入
- 非同期処理の検討

## 🎯 ベストプラクティス

### 1. アラート疲労の回避

- ✅ 適切な閾値を設定（誤検知を避ける）
- ✅ `for` パラメータで一時的なスパイクを無視
- ✅ 重要度に応じて通知チャネルを分ける

### 2. アラートのテスト

- ✅ 定期的にアラートをテストする
- ✅ 負荷テストでアラートが正しく発火するか確認
- ✅ 通知が正しく届くか確認

### 3. ドキュメント化

- ✅ 各アラートの対応手順を文書化
- ✅ エスカレーションパスを明確にする
- ✅ 過去のインシデントから学ぶ

### 4. 継続的な改善

- ✅ アラートの発火頻度を監視
- ✅ 誤検知が多い場合は閾値を調整
- ✅ 新しいメトリクスに基づいてアラートを追加

## 📚 関連ドキュメント

- **ALERTING_GUIDE.md** - 基本的なアラート設定ガイド
- **ALERT_STATUS.md** - アラートの現在の状態
- **GRAFANA_ALERTS_GUIDE.md** - Grafanaアラート設定ガイド
- **DASHBOARD_CUSTOMER_EVALUATION.md** - ダッシュボード評価

## ✅ チェックリスト

### ローカル版

- [ ] アラートルールファイルを確認
- [ ] Prometheusを再起動
- [ ] アラートが読み込まれたことを確認
- [ ] 負荷テストでアラートをテスト
- [ ] （オプション）通知設定を構成

### OpenShift版

- [ ] アラートルールConfigMapを適用
- [ ] Prometheus DeploymentにConfigMapをマウント
- [ ] Prometheus ConfigMapを更新
- [ ] Prometheusを再起動
- [ ] アラートが読み込まれたことを確認
- [ ] （オプション）Alertmanagerを設定
- [ ] （オプション）通知設定を構成

## 🎉 完了！

本番環境向けのアラート設定が完了しました。これで、アプリケーションの問題を早期に検出し、迅速に対応できます！

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

