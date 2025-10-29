# ストレステスト（負荷テスト）ガイド

## 📋 概要

`stress_test.sh` は、OpenShift上のCamel Appに対して負荷テストを実行し、パフォーマンスを測定するスクリプトです。

## 🎯 目的

- アプリケーションの最大処理能力を測定
- レスポンスタイムの傾向を把握
- エラー率の確認
- ボトルネックの特定
- スケーリングの必要性を判断

---

## 🚀 基本的な使い方

### 1. デフォルト設定で実行

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./stress_test.sh
```

**デフォルト設定**:
- 並列接続数: 10
- テスト継続時間: 60秒
- ウォームアップ: 5秒

### 2. カスタム設定で実行

```bash
# 20並列、2分間
./stress_test.sh -c 20 -d 120

# 50並列、1000リクエスト
./stress_test.sh -c 50 -r 1000

# 5並列、5分間、10秒ウォームアップ
./stress_test.sh -c 5 -d 300 -w 10
```

---

## 📊 オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `-c`, `--concurrent <num>` | 並列接続数 | 10 |
| `-d`, `--duration <seconds>` | テスト継続時間（秒） | 60 |
| `-r`, `--requests <num>` | 総リクエスト数 | 0 (無制限) |
| `-w`, `--warmup <seconds>` | ウォームアップ時間（秒） | 5 |
| `-h`, `--help` | ヘルプを表示 | - |

---

## 🎨 推奨設定

### 軽負荷テスト（開発環境）
```bash
./stress_test.sh -c 5 -d 60
```
- 並列: 5
- 継続: 60秒
- 目的: 基本的な動作確認

### 中負荷テスト（ステージング環境）
```bash
./stress_test.sh -c 20 -d 120
```
- 並列: 20
- 継続: 2分
- 目的: 通常運用時の性能確認

### 高負荷テスト（本番想定）
```bash
./stress_test.sh -c 50 -d 180
```
- 並列: 50
- 継続: 3分
- 目的: ピーク時の性能確認

### ストレステスト（限界確認）
```bash
./stress_test.sh -c 100 -d 300
```
- 並列: 100
- 継続: 5分
- 目的: システムの限界を把握

---

## 📊 出力例

### テスト実行中

```
========================================
1. 前提条件の確認
========================================
✅ ocコマンド: 利用可能
✅ curlコマンド: 利用可能
✅ OpenShift接続: admin
✅ 現在のプロジェクト: camel-observability-demo

========================================
2. テスト対象の確認
========================================
✅ Camel App URL: https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io
✅ ヘルスチェック: OK (HTTP 200)

========================================
3. テスト設定
========================================
並列接続数:       10
テスト継続時間:   60 秒
最大リクエスト数: 無制限（継続時間で制御）
ウォームアップ:   5 秒
テストURL:        https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/camel/api/orders

========================================
6. ストレステスト実行
========================================
⏳ テスト開始...

ℹ️  テスト実行中... (Ctrl+C で中断)

進捗: 450 リクエスト送信 | 45秒経過 | 残り15秒
```

### テスト完了後

```
========================================
8. 詳細レポート
========================================

=== テスト概要 ===
テスト継続時間:     60 秒
並列接続数:         10

=== リクエスト統計 ===
総リクエスト数:     589
成功:               584
失敗:               5
成功率:             99.15%
エラー率:           0.85%
スループット:       9.82 req/sec

=== レスポンスタイム (ms) ===
平均:               156.23 ms
最小:               45 ms
最大:               1234 ms
95パーセンタイル:  345 ms
99パーセンタイル:  678 ms

========================================
9. パフォーマンス評価
========================================

✅ エラー率: 優秀 (0.85% < 1%)
✅ 平均レスポンスタイム: 優秀 (156.23ms < 100ms)
✅ 95パーセンタイル: 優秀 (345ms < 200ms)
⚠️  スループット: 許容範囲 (9.82 req/sec > 5)
```

---

## 📈 Grafanaでの監視

### 推奨ダッシュボード

**Camel Comprehensive Dashboard** を開いて、以下のパネルを監視してください：

### 1. HTTP Request Rate
- リクエスト率のピークを確認
- 並列数とリクエスト率の関係を把握

### 2. HTTP Response Time (95th percentile)
- レスポンスタイムの推移
- 負荷増加時の変化を観察

### 3. HTTP Error Rate
- エラー率の推移
- どのタイミングでエラーが発生するか確認

### 4. JVM Memory Usage
- メモリ使用量の推移
- メモリリークの兆候を確認

### 5. GC Pause Time
- ガベージコレクションの頻度と時間
- パフォーマンスへの影響を確認

### 6. Camel Exchanges Total
- Camelルートの処理数
- ボトルネックの特定

---

## 🔍 パフォーマンス評価基準

### エラー率

| 範囲 | 評価 | 対応 |
|---|---|---|
| < 1% | ✅ 優秀 | 問題なし |
| 1-5% | ⚠️ 許容範囲 | 監視継続 |
| > 5% | ❌ 高い | 調査・改善が必要 |

### 平均レスポンスタイム

| 範囲 | 評価 | 対応 |
|---|---|---|
| < 100ms | ✅ 優秀 | 問題なし |
| 100-500ms | ⚠️ 許容範囲 | 監視継続 |
| > 500ms | ❌ 遅い | チューニングが必要 |

### 95パーセンタイル

| 範囲 | 評価 | 対応 |
|---|---|---|
| < 200ms | ✅ 優秀 | 問題なし |
| 200-1000ms | ⚠️ 許容範囲 | 監視継続 |
| > 1000ms | ❌ 遅い | チューニングが必要 |

### スループット

| 範囲 | 評価 | 対応 |
|---|---|---|
| > 10 req/sec | ✅ 優秀 | 問題なし |
| 5-10 req/sec | ⚠️ 許容範囲 | スケーリング検討 |
| < 5 req/sec | ❌ 低い | スケーリングが必要 |

---

## 🔧 トラブルシューティング

### 問題1: エラー率が高い（> 5%）

**考えられる原因**:
- リソース不足（CPU/メモリ）
- データベース接続エラー
- Kafka接続エラー

**対処方法**:
```bash
# Podログを確認
oc logs -l deployment=camel-app --tail=100

# Podリソースを確認
oc adm top pod -l deployment=camel-app

# イベントを確認
oc get events --sort-by='.lastTimestamp' | grep camel-app
```

### 問題2: レスポンスタイムが遅い（> 500ms）

**考えられる原因**:
- CPU/メモリ不足
- ガベージコレクションの影響
- データベースクエリが遅い
- Kafkaプロデューサーの遅延

**対処方法**:
```bash
# レプリカ数を増やす
oc scale deployment/camel-app --replicas=3

# リソース制限を緩和（Deploymentを編集）
oc edit deployment camel-app
# resources.limits.cpu: "2000m"
# resources.limits.memory: "2Gi"

# Tempoでトレース分析
# Grafana > Explore > Tempo
# Duration > 500ms でフィルタしてボトルネックを特定
```

### 問題3: スループットが低い（< 5 req/sec）

**考えられる原因**:
- アプリケーションのボトルネック
- 水平スケーリング不足
- ネットワーク遅延

**対処方法**:
```bash
# 水平スケーリング
oc scale deployment/camel-app --replicas=5

# HPA（Horizontal Pod Autoscaler）を設定
oc autoscale deployment/camel-app --min=2 --max=10 --cpu-percent=70

# Podのパフォーマンスを確認
oc adm top pod -l deployment=camel-app
```

---

## 📚 ベストプラクティス

### 1. テスト前の準備

```bash
# 1. Grafanaを開く
# 2. Camel Comprehensive Dashboard に移動
# 3. 時間範囲を "Last 5 minutes" に設定
# 4. Auto-refresh を "5s" に設定
```

### 2. 段階的な負荷増加

```bash
# ステップ1: 軽負荷
./stress_test.sh -c 5 -d 60

# 5分待機してメトリクスを確認

# ステップ2: 中負荷
./stress_test.sh -c 20 -d 120

# 5分待機してメトリクスを確認

# ステップ3: 高負荷
./stress_test.sh -c 50 -d 180
```

### 3. 複数回実行して平均を取る

```bash
for i in {1..3}; do
  echo "テスト $i 回目"
  ./stress_test.sh -c 20 -d 60
  echo "5分待機..."
  sleep 300
done
```

### 4. 結果をログに保存

```bash
./stress_test.sh -c 20 -d 120 | tee stress-test-$(date +%Y%m%d-%H%M%S).log
```

### 5. テスト後のクリーンアップ

```bash
# メモリ使用量を確認
oc adm top pod -l deployment=camel-app

# 必要に応じてPodを再起動
oc rollout restart deployment/camel-app
```

---

## 🎯 パフォーマンスチューニング

### 1. 水平スケーリング

```bash
# レプリカ数を増やす
oc scale deployment/camel-app --replicas=3

# HPA（自動スケーリング）を設定
oc autoscale deployment/camel-app --min=2 --max=10 --cpu-percent=70
```

### 2. 垂直スケーリング

```yaml
# camel-app-deployment.yaml を編集
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"     # 2Gi → 4Gi に増加
    cpu: "2000m"      # 1000m → 2000m に増加
```

### 3. JVMチューニング

```yaml
# Deployment に環境変数を追加
env:
  - name: JAVA_OPTS
    value: "-Xmx2g -Xms1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### 4. Kafkaチューニング

```yaml
# application.yml
spring:
  kafka:
    producer:
      batch-size: 32768
      linger-ms: 10
      buffer-memory: 67108864
```

---

## 📊 レポート例

### 軽負荷テスト結果

```
並列接続数: 5
継続時間: 60秒
総リクエスト: 289
成功率: 100%
平均レスポンス: 98ms
95パーセンタイル: 145ms
スループット: 4.82 req/sec
評価: ✅ 優秀
```

### 高負荷テスト結果

```
並列接続数: 50
継続時間: 180秒
総リクエスト: 3456
成功率: 97.8%
平均レスポンス: 456ms
95パーセンタイル: 1023ms
スループット: 19.20 req/sec
評価: ⚠️ チューニング推奨
```

---

## 🎊 まとめ

`stress_test.sh` は、OpenShift上のCamel Appのパフォーマンスを包括的にテストするツールです。

**主な利点**:
- ✅ 詳細なパフォーマンスレポート
- ✅ リアルタイム進捗表示
- ✅ 自動評価とフィードバック
- ✅ Grafana監視との連携
- ✅ カスタマイズ可能な設定

**推奨される使用タイミング**:
- 新機能リリース前
- スケーリング設定の検証
- パフォーマンスベースラインの確立
- 定期的な性能確認

お疲れ様でした！ 🚀




