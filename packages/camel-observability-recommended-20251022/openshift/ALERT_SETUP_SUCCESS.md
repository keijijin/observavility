# ✅ OpenShift アラート設定完了

OpenShift環境へのPrometheusアラート設定が正常に完了しました。

## 📊 セットアップ結果

### ✅ 動作確認済み

- **日時**: 2025-10-22
- **環境**: camel-observability-demo プロジェクト
- **アラート数**: 18個（すべて正常に読み込み）
- **状態**: すべて `inactive`（正常）

### 📋 アラート詳細

#### 🔴 クリティカルアラート（6個）

1. **HighMemoryUsage** - ヒープメモリ > 90% (2分)
2. **HighErrorRate** - Camelエラー率 > 10% (2分)
3. **HighHTTPErrorRate** - HTTP 5xxエラー > 5% (2分)
4. **HighGCOverhead** - GCオーバーヘッド > 20% (5分)
5. **ApplicationDown** - アプリケーションダウン (1分)
6. **UndertowRequestQueueFull** - リクエストキュー > 100 (2分)

#### 🟡 警告アラート（9個）

1. **ModerateMemoryUsage** - メモリ使用率 > 70% (5分)
2. **HighCPUUsage** - CPU使用率 > 80% (5分)
3. **SlowResponseTime** - レスポンスタイム > 1秒 (3分)
4. **HighRunningRoutes** - 実行中ルート > 20 (5分)
5. **HighThreadCount** - スレッド数 > 100 (5分)
6. **ModerateGCOverhead** - GCオーバーヘッド > 10% (5分)
7. **UndertowHighRequestLoad** - リクエスト負荷 > 60% (5分)
8. **UndertowModerateQueueSize** - キューサイズ > 50 (3分)
9. **SlowCamelRouteProcessing** - ルート処理 > 5秒 (3分)

#### ℹ️ 情報アラート（3個）

1. **FrequentGarbageCollection** - GC頻度 > 30回/分 (5分)
2. **ApplicationRestarted** - アプリケーション再起動検出 (1分)
3. **HighMemoryAllocationRate** - メモリ割り当て > 10MB/s (5分)

## 🔧 実施した手順

### 問題とその解決

#### 問題1: ボリュームマウント競合

**症状**: 
- Prometheus Podのロールアウトがタイムアウト
- "Multi-Attach error" が発生

**原因**: 
- 新旧両方のPodが同じPVCに同時アクセスしようとした
- ConfigMapをサブパスで `/etc/prometheus/alert_rules.yml` にマウントしようとしたが、`/etc/prometheus` は既に別のConfigMapでマウントされていた

**解決策**:
- アラートルールを `prometheus-config` ConfigMapに直接統合
- 追加のボリュームマウントを削除
- 安全にスケールダウン→設定更新→スケールアップ

### 最終的な設定

#### ConfigMap構成

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "alert_rules.yml"  # 同じConfigMap内のファイル
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'camel-app'
        metrics_path: '/actuator/prometheus'
        static_configs:
          - targets: ['camel-app:8080']
            labels:
              application: 'camel-observability-demo'
  
  alert_rules.yml: |
    # 18個のアラートルールがここに含まれる
    groups:
      - name: camel_application_alerts
        interval: 30s
        rules:
          # ... 省略 ...
```

#### Deployment設定

- **ボリュームマウント**: `prometheus-config` のみ（追加のボリュームなし）
- **レプリカ数**: 1（PVCのため）
- **リソース**: 既存設定を維持

## 📊 確認方法

### Prometheus Alerts UI

```
https://prometheus-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/alerts
```

### API経由での確認

```bash
# アラート数の確認
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | jq '.data.groups[].rules | length' | awk '{s+=$1} END {print "Total: " s}'

# アラート一覧の確認
curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | jq '.data.groups[].rules[] | {alert: .name, state: .state}'
```

### Grafana Dashboard

```
https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io
```

## 🚀 セットアップスクリプト

### 修正版スクリプト（推奨）

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./SETUP_ALERTS_FIXED.sh
```

このスクリプトは以下を自動実行します：
1. ✅ 前提条件の確認
2. ✅ アラートルールConfigMapの作成
3. ✅ Prometheus設定の取得
4. ✅ ConfigMapの統合（アラートルール組み込み）
5. ✅ 不要なボリュームマウント削除
6. ✅ 安全な再起動（スケールダウン→アップ）
7. ✅ アラートルールの確認

### 手動セットアップ手順

```bash
# 1. ConfigMapを作成
oc apply -f prometheus/alert-rules-configmap.yaml

# 2. 既存設定を取得
oc get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}' > /tmp/prometheus.yml
oc get configmap prometheus-alert-rules -o jsonpath='{.data.alert_rules\.yml}' > /tmp/alert_rules.yml

# 3. ConfigMapを統合
oc create configmap prometheus-config \
  --from-file=prometheus.yml=/tmp/prometheus.yml \
  --from-file=alert_rules.yml=/tmp/alert_rules.yml \
  --dry-run=client -o yaml | oc apply -f -

# 4. 不要なボリュームを削除
oc set volume deployment/prometheus --remove --name=prometheus-alert-rules || true

# 5. Prometheusを再起動
oc scale deployment/prometheus --replicas=0
sleep 5
oc scale deployment/prometheus --replicas=1

# 6. 起動を待機
oc wait --for=condition=ready pod -l app=prometheus --timeout=120s
```

## 🎯 ベストプラクティス

### OpenShift特有の考慮事項

1. **PVC共有の制限**
   - ReadWriteOnce PVCは1つのPodしか使用できない
   - ローリングアップデート時は一時的に古いPodを削除する必要がある

2. **ConfigMap統合**
   - 複数のConfigMapをマウントするより、1つに統合する方が安全
   - サブパスマウントは既存のマウントポイントと競合する可能性がある

3. **安全な再起動**
   - スケールダウン→設定更新→スケールアップ
   - `oc rollout restart` はPVC競合を引き起こす可能性がある

4. **アラートテスト**
   - ストレステストで実際にアラートが発火するか確認
   - `./stress_test_advanced.sh --preset extreme`

## 📚 関連ドキュメント

### アラート関連

- **ALERT_SETUP_PRODUCTION.md** - 本番環境向けアラート設定ガイド
- **ALERT_PRODUCTION_SUMMARY.md** - アラート設定サマリー（ローカル版含む）
- **ALERTING_GUIDE.md** - 基本的なアラート設定ガイド

### OpenShift関連

- **OPENSHIFT_DEPLOYMENT_GUIDE.md** - OpenShiftデプロイメントガイド
- **STRESS_TEST_ADVANCED_GUIDE.md** - 高度なストレステストガイド
- **ALL_SCRIPTS_SUMMARY.md** - すべてのスクリプト概要

## 🎉 次のステップ

### 1. アラートのテスト

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./stress_test_advanced.sh --preset extreme
```

### 2. 通知設定（オプション）

- Prometheus Alertmanager の設定
- Grafana通知チャネルの設定
- 詳細は `ALERT_SETUP_PRODUCTION.md` を参照

### 3. ダッシュボード確認

Grafanaで以下を確認：
- Camel総合監視ダッシュボード
- アラート監視ダッシュボード
- Undertowメトリクス
- Camelルートメトリクス

## ✅ チェックリスト

- [x] アラートルールConfigMapを作成
- [x] Prometheus ConfigMapに統合
- [x] 不要なボリュームマウントを削除
- [x] Prometheusを再起動
- [x] アラートルールの読み込みを確認（18個）
- [x] すべてのアラートが `inactive` であることを確認
- [x] Prometheus Alerts UIで確認
- [ ] ストレステストでアラートをテスト
- [ ] （オプション）通知設定

## 🎊 完了！

OpenShift環境への本番環境向けアラート設定が完全に完了しました！

### 提供可能なパッケージ

✅ **完全な監視ソリューション**:
- 統合Grafanaダッシュボード
- 18個の本番向けアラートルール
- ローカル版とOpenShift版の両対応
- 自動セットアップスクリプト
- 包括的なドキュメント

お客様に自信を持って提供できる完璧な監視システムです！🚀

---

**セットアップ日時**: 2025-10-22
**環境**: camel-observability-demo (OpenShift)
**ステータス**: ✅ 完了・動作確認済み
**アラート数**: 18個 (すべて正常)

