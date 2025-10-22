# OpenShift テストスクリプト - 完全ガイド 📚

OpenShift上のCamel Appをテストする2つのスクリプトの完全ガイドです。

---

## 📋 スクリプト一覧

### テストスクリプト

### 1. **test_camel_app.sh** - 機能テスト
正常動作を確認する包括的なテストスクリプト

### 2. **stress_test.sh** - 基本ストレステスト
シンプルな負荷テストでパフォーマンスを測定

### 3. **stress_test_advanced.sh** - 高度なストレステスト ⭐️ 新機能
段階的負荷増加、複数設定テスト、結果比較などの高度な機能を搭載

### デプロイメント・管理スクリプト

### 4. **UPDATE_DASHBOARD.sh** - Grafanaダッシュボード更新 ⭐️ 新機能
ローカル版の統合ダッシュボードをOpenShiftに自動デプロイ

---

## 🎯 使い分け

### テストスクリプト

| スクリプト | 目的 | 実行タイミング | 所要時間 |
|---|---|---|---|
| `test_camel_app.sh` | 機能確認・動作確認 | デプロイ直後、定期チェック | 1-2分 |
| `stress_test.sh` | クイック負荷テスト | 単発のパフォーマンス確認 | 1-5分 |
| `stress_test_advanced.sh` | 詳細パフォーマンス分析 | リリース前、最適化、ベンチマーク | 2-10分 |

### デプロイメント・管理スクリプト

| スクリプト | 目的 | 実行タイミング | 所要時間 |
|---|---|---|---|
| `UPDATE_DASHBOARD.sh` | Grafanaダッシュボード更新 | ダッシュボード変更後 | 30秒-1分 |

---

## 1️⃣ test_camel_app.sh - 機能テスト

### 📊 テスト項目（12項目）

1. ✅ 前提条件の確認
2. ✅ Pod状態確認
3. ✅ Route確認
4. ✅ ヘルスチェック
5. ✅ アプリ情報
6. ✅ REST API テスト
7. ✅ メトリクス確認
8. ✅ TraceID確認
9. ✅ エラーログ確認
10. ✅ Kafka接続確認
11. ✅ 処理完了確認
12. ✅ リソース使用状況

### 🚀 基本的な使い方

```bash
# デフォルト設定で実行
./test_camel_app.sh
```

### 📖 詳細ドキュメント
- **TEST_SCRIPT_GUIDE.md** - 詳細な使い方
- **README_TEST_SCRIPT.md** - クイックスタート

---

## 2️⃣ stress_test.sh - ストレステスト

### 📊 測定項目

- ✅ 総リクエスト数
- ✅ 成功/失敗数
- ✅ エラー率
- ✅ スループット（req/sec）
- ✅ 平均レスポンスタイム
- ✅ 95/99パーセンタイル
- ✅ 最小/最大レスポンスタイム

### 🚀 基本的な使い方

```bash
# デフォルト設定（軽負荷）
./stress_test.sh

# 中負荷テスト
./stress_test.sh -c 20 -d 120

# 高負荷テスト
./stress_test.sh -c 50 -d 180

# ストレステスト（限界確認）
./stress_test.sh -c 100 -d 300
```

### 📊 オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `-c <num>` | 並列接続数 | 10 |
| `-d <sec>` | 継続時間（秒） | 60 |
| `-r <num>` | 総リクエスト数 | 0 (無制限) |
| `-w <sec>` | ウォームアップ（秒） | 5 |

### 📖 詳細ドキュメント
- **STRESS_TEST_GUIDE.md** - 詳細な使い方
- **README_STRESS_TEST.md** - クイックスタート

---

## 3️⃣ stress_test_advanced.sh - 高度なストレステスト ⭐️

### 🎯 新機能

1. **🚀 段階的負荷増加（ランプアップ）**
   - 徐々に負荷を上げてボトルネックを発見
   - 例: 5並列 → 50並列（5ずつ増加）

2. **📊 複数設定の連続テスト**
   - 異なる並列数で連続実行して比較
   - 例: 10, 20, 50, 100並列で各テスト

3. **⚡ プリセット設定**
   - light, medium, heavy, extreme の4つのプリセット
   - すぐに使える最適化された設定

4. **📈 結果比較**
   - 複数テスト結果を自動比較
   - 最適な並列数を自動提案

5. **💾 CSV出力**
   - Excelで分析可能な形式で結果を保存
   - グラフ化して可視化

### 🚀 基本的な使い方

```bash
# プリセットテスト（最も簡単）
./stress_test_advanced.sh -m preset -p light      # 軽負荷（約2分）
./stress_test_advanced.sh -m preset -p medium     # 中負荷（約5分）⭐️ おすすめ
./stress_test_advanced.sh -m preset -p heavy      # 高負荷（約6分）
./stress_test_advanced.sh -m preset -p extreme    # 極限（約8分）

# ランプアップテスト（段階的負荷増加）
./stress_test_advanced.sh -m rampup -s 5 -e 50 -i 5 -d 30

# 複数設定テスト（比較分析）
./stress_test_advanced.sh -m multi -l "10,20,50" -d 60

# 結果をCSVに保存
./stress_test_advanced.sh -m preset -p medium -o results.csv
```

### 📊 オプション

#### 共通オプション
| オプション | 説明 | デフォルト |
|---|---|---|
| `-m <mode>` | テストモード（single/rampup/multi/preset） | single |
| `-d <sec>` | 各テストの継続時間（秒） | 60 |
| `-w <sec>` | ウォームアップ時間（秒） | 5 |
| `-o <file>` | 結果をCSVファイルに出力 | なし |

#### Rampup Mode専用
| オプション | 説明 | デフォルト |
|---|---|---|
| `-s <num>` | 開始並列数 | 5 |
| `-e <num>` | 終了並列数 | 50 |
| `-i <num>` | 増加ステップ | 5 |

#### Multi Mode専用
| オプション | 説明 | 例 |
|---|---|---|
| `-l <nums>` | 並列数リスト（カンマ区切り） | "10,20,50,100" |

#### Preset Mode専用
| オプション | 説明 | 選択肢 |
|---|---|---|
| `-p <name>` | プリセット名 | light/medium/heavy/extreme |

### 🎨 プリセット詳細

| プリセット | 並列数範囲 | ステップ | 各テスト時間 | 総テスト時間 |
|-----------|-----------|---------|------------|------------|
| light     | 5 → 20    | 5       | 30秒       | 約2分      |
| medium    | 10 → 50   | 10      | 60秒       | 約5分      |
| heavy     | 20 → 100  | 20      | 90秒       | 約6分      |
| extreme   | 50 → 200  | 50      | 120秒      | 約8分      |

### 📈 使用例

#### 例1: 初回パフォーマンス確認
```bash
# ステップ1: 軽負荷で動作確認
./stress_test_advanced.sh -m preset -p light -o test1_light.csv

# ステップ2: 中負荷でパフォーマンス確認
./stress_test_advanced.sh -m preset -p medium -o test2_medium.csv

# ステップ3: 最適範囲を詳細テスト（例: 30-60並列）
./stress_test_advanced.sh -m rampup -s 30 -e 60 -i 5 -d 120 -o test3_detailed.csv
```

#### 例2: パフォーマンス改善の比較
```bash
# 改善前
./stress_test_advanced.sh -m multi -l "10,20,30,40,50" -d 90 -o before.csv

# チューニング実施（レプリカ数増加、リソース増強など）

# 改善後
./stress_test_advanced.sh -m multi -l "10,20,30,40,50" -d 90 -o after.csv

# 2つのCSVファイルをExcelで比較分析
```

#### 例3: 定期的なパフォーマンスチェック
```bash
# 毎日の定期チェック
./stress_test_advanced.sh -m preset -p medium -o daily_$(date +%Y%m%d).csv
```

### 📊 結果の見方

#### コンソール出力
```
=== テスト結果 ===
並列数:             20
継続時間:           60 秒
総リクエスト数:     2145
成功:               2145
失敗:               0
エラー率:           0.00%
スループット:       35.75 req/sec
平均レスポンス:     55.89 ms
95パーセンタイル:  145 ms
```

#### 最終サマリー
```
=== すべてのテスト結果 ===

並列数       リクエスト    成功率       エラー率     RPS          平均応答時間
--------------------------------------------------------------------------------
10          1234        100.00%      0.00%        20.57        48.23ms
20          2145        100.00%      0.00%        35.75        55.89ms
30          2830        99.86%       0.14%        47.23        63.12ms
40          3187        99.56%       0.44%        53.35        75.34ms
50          3398        98.32%       1.68%        57.60        86.45ms

✅ 最適な並列数: 40 (スループット: 53.35 req/sec)
```

### 📖 詳細ドキュメント
- **STRESS_TEST_ADVANCED_GUIDE.md** - 完全ガイド
- **STRESS_TEST_QUICK_REFERENCE.md** - クイックリファレンス

---

## 🎯 推奨ワークフロー

### ステップ1: デプロイ直後の確認
```bash
# 機能テストで正常動作を確認
./test_camel_app.sh
```

### ステップ2: 軽負荷テスト
```bash
# 基本的なパフォーマンスを確認
./stress_test.sh -c 5 -d 60
```

### ステップ3: Grafanaで結果確認
```
# Grafanaで以下を確認:
- HTTP Request Rate
- HTTP Response Time
- HTTP Error Rate
- JVM Memory Usage
```

### ステップ4: 段階的に負荷を増やす
```bash
# 中負荷テスト
./stress_test.sh -c 20 -d 120

# 5分待機してメトリクスを確認

# 高負荷テスト
./stress_test.sh -c 50 -d 180
```

### ステップ5: 結果分析とチューニング
```bash
# 必要に応じてスケーリング
oc scale deployment/camel-app --replicas=3

# 再度テスト
./stress_test.sh -c 50 -d 180
```

---

## 📊 パフォーマンス評価基準

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

### スループット

| 範囲 | 評価 | 対応 |
|---|---|---|
| > 10 req/sec | ✅ 優秀 | 問題なし |
| 5-10 req/sec | ⚠️ 許容範囲 | スケーリング検討 |
| < 5 req/sec | ❌ 低い | スケーリングが必要 |

---

## 🔧 トラブルシューティング

### エラー率が高い

```bash
# Podログを確認
oc logs -l deployment=camel-app --tail=100

# Podリソースを確認
oc adm top pod -l deployment=camel-app

# Podを再起動
oc rollout restart deployment/camel-app
```

### レスポンスタイムが遅い

```bash
# 水平スケーリング
oc scale deployment/camel-app --replicas=3

# 垂直スケーリング（リソース増加）
oc edit deployment camel-app
# resources.limits.cpu: "2000m"
# resources.limits.memory: "4Gi"
```

### スループットが低い

```bash
# 自動スケーリング
oc autoscale deployment/camel-app --min=2 --max=10 --cpu-percent=70

# リソースを確認
oc adm top pod -l deployment=camel-app
```

---

## 📈 Grafana監視

### 推奨ダッシュボード

**Camel Comprehensive Dashboard**

### 監視すべきパネル

1. **HTTP Request Rate** - リクエスト率
2. **HTTP Response Time (95th)** - レスポンスタイム
3. **HTTP Error Rate** - エラー率
4. **JVM Memory Usage** - メモリ使用量
5. **GC Pause Time** - GC時間
6. **Camel Exchanges Total** - 処理数

### 設定

- 時間範囲: **"Last 5 minutes"**
- Auto-refresh: **"5s"**

---

## 🎨 使用例

### 例1: デプロイ後の完全チェック

```bash
# 1. 機能テスト
./test_camel_app.sh

# 2. 軽負荷テスト
./stress_test.sh -c 10 -d 60

# 3. Grafanaで確認
# 4. 問題なければリリース
```

### 例2: スケーリング検証

```bash
# 現在の性能を測定
./stress_test.sh -c 50 -d 180

# スケールアップ
oc scale deployment/camel-app --replicas=3

# 再度測定
./stress_test.sh -c 50 -d 180

# 結果を比較
```

### 例3: 定期的な健全性チェック

```bash
# 毎日午前9時に実行（Cron）
0 9 * * * cd /path/to/openshift && ./test_camel_app.sh >> /var/log/camel-test.log 2>&1
```

### 例4: CI/CDパイプライン統合

```groovy
stage('Deploy') {
    steps {
        sh 'oc apply -f openshift/'
        sh 'oc rollout status deployment/camel-app'
    }
}

stage('Test') {
    steps {
        sh './test_camel_app.sh'
        sh './stress_test.sh -c 20 -d 60'
    }
}
```

---

## 4️⃣ UPDATE_DASHBOARD.sh - Grafanaダッシュボード更新 ⭐️

### 📊 機能

ローカル版の統合Grafanaダッシュボードを自動的にOpenShiftに反映します。

- ✅ ダッシュボードファイルの自動読み込み
- ✅ ConfigMapの作成/更新
- ✅ Grafana Podの自動再起動
- ✅ デプロイ結果の確認

### 🚀 基本的な使い方

```bash
# 統合ダッシュボードをOpenShiftに反映
./UPDATE_DASHBOARD.sh
```

### 📋 実行内容

1. **前提条件の確認**
   - ダッシュボードファイルの存在確認
   - OpenShift接続確認
   - プロジェクト確認

2. **ConfigMapの作成/更新**
   - ローカルの`camel-comprehensive-dashboard.json`を読み込み
   - ConfigMap `grafana-dashboards`を作成/更新

3. **Grafana Podの再起動**
   - Deploymentをロールアウト
   - 再起動完了を待機

4. **確認**
   - Grafana URLを表示
   - アクセス方法を案内

### 📊 実行例

```bash
$ ./UPDATE_DASHBOARD.sh

========================================
1. 前提条件の確認
========================================
✅ スクリプトディレクトリ: /path/to/openshift
✅ ダッシュボードファイル: camel-comprehensive-dashboard.json
✅ OpenShift接続: admin
✅ 現在のプロジェクト: camel-observability-demo

========================================
2. ConfigMapの作成/更新
========================================
ℹ️  既存のConfigMapを更新します...
✅ ConfigMap 更新成功

========================================
3. Grafana Podの再起動
========================================
ℹ️  Grafana Podを再起動して設定を反映します...
✅ Grafana再起動を開始しました
ℹ️  再起動の完了を待機中...
✅ Grafana再起動完了

========================================
4. 確認
========================================
✅ Grafana URL: https://grafana-camel-observability-demo.apps.example.com

ダッシュボードにアクセスして確認してください:
  https://grafana-camel-observability-demo.apps.example.com/dashboards

ダッシュボード名:
  Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード

✅ ダッシュボードの更新が完了しました！
```

### 🛠️ トラブルシューティング

**ConfigMapが反映されない場合:**
```bash
# ConfigMapの内容を確認
oc get configmap grafana-dashboards -o yaml

# Grafana Podを強制再起動
oc delete pod -l app=grafana
```

**ダッシュボードが表示されない場合:**
```bash
# Grafana Podのログを確認
oc logs deployment/grafana

# データソースの接続を確認
oc get pods -l app=prometheus
oc get pods -l app=loki
oc get pods -l app=tempo
```

### 📖 関連ドキュメント
- **DASHBOARD_DEPLOYMENT_GUIDE.md** - 詳細なデプロイガイド
- **DASHBOARD_README.md** - ダッシュボード詳細説明
- **DASHBOARD_QUICKSTART.md** - クイックスタートガイド

---

## 📚 すべてのドキュメント

| ファイル | 内容 |
|---|---|
| **テストスクリプト** | |
| `test_camel_app.sh` | 機能テストスクリプト |
| `stress_test.sh` | 基本ストレステストスクリプト |
| `stress_test_advanced.sh` | 高度なストレステストスクリプト ⭐️ |
| **デプロイメント・管理** | |
| `UPDATE_DASHBOARD.sh` | Grafanaダッシュボード更新スクリプト ⭐️ |
| **ドキュメント** | |
| `TEST_SCRIPT_GUIDE.md` | 機能テストの詳細ガイド |
| `STRESS_TEST_GUIDE.md` | ストレステストの詳細ガイド |
| `STRESS_TEST_ADVANCED_GUIDE.md` | 高度なストレステストの詳細ガイド ⭐️ |
| `README_TEST_SCRIPT.md` | 機能テストのクイックスタート |
| `README_STRESS_TEST.md` | ストレステストのクイックスタート |
| `STRESS_TEST_QUICK_REFERENCE.md` | 高度なストレステストのクイックリファレンス ⭐️ |
| `ALL_SCRIPTS_SUMMARY.md` | このファイル（完全ガイド） |
| `QUICKTEST.md` | 手動5分テスト |
| `TEST_GUIDE.md` | 手動詳細テスト |
| `FINAL_STATUS.md` | 環境の最終ステータス |

---

## 🎊 まとめ

4つのスクリプトを活用して、OpenShift上のCamel Appの品質、パフォーマンス、可視化を完全にカバーしましょう！

### テストスクリプト

#### 機能テスト: test_camel_app.sh
- ✅ デプロイ後の確認
- ✅ 定期的な健全性チェック
- ✅ 12項目の包括的なテスト

#### 基本ストレステスト: stress_test.sh
- ✅ パフォーマンス測定
- ✅ 限界確認
- ✅ スケーリング検証

#### 高度なストレステスト: stress_test_advanced.sh ⭐️
- ✅ 段階的負荷増加（ランプアップ）
- ✅ 複数設定の自動テスト
- ✅ プリセットモード（light/medium/heavy/extreme）
- ✅ 結果比較とCSV出力

### デプロイメント・管理スクリプト

#### ダッシュボード更新: UPDATE_DASHBOARD.sh ⭐️
- ✅ 統合ダッシュボードの自動デプロイ
- ✅ ConfigMapの作成/更新
- ✅ Grafanaの自動再起動

お疲れ様でした！ 🚀



