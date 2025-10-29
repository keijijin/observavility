# ストレステスト クイックリファレンス

## 🚀 すぐに使えるコマンド集

### 基本テスト（stress_test.sh）

```bash
# 10並列、60秒
./stress_test.sh

# 20並列、120秒
./stress_test.sh -c 20 -d 120

# 50並列、180秒
./stress_test.sh -c 50 -d 180
```

---

## ⚡ プリセットテスト（stress_test_advanced.sh）

### 軽負荷テスト（約2分）
```bash
./stress_test_advanced.sh -m preset -p light
```
- 5 → 20並列（5ずつ増加）
- 各30秒

### 中負荷テスト（約5分）⭐️ おすすめ
```bash
./stress_test_advanced.sh -m preset -p medium
```
- 10 → 50並列（10ずつ増加）
- 各60秒

### 高負荷テスト（約6分）
```bash
./stress_test_advanced.sh -m preset -p heavy
```
- 20 → 100並列（20ずつ増加）
- 各90秒

### 極限テスト（約8分）
```bash
./stress_test_advanced.sh -m preset -p extreme
```
- 50 → 200並列（50ずつ増加）
- 各120秒

---

## 📊 カスタムテスト

### ランプアップテスト

```bash
# 基本（5→50並列、5ずつ、各30秒）
./stress_test_advanced.sh -m rampup -s 5 -e 50 -i 5 -d 30

# 短時間確認（5→25並列、5ずつ、各20秒）
./stress_test_advanced.sh -m rampup -s 5 -e 25 -i 5 -d 20

# 詳細テスト（10→100並列、10ずつ、各120秒）
./stress_test_advanced.sh -m rampup -s 10 -e 100 -i 10 -d 120
```

### 複数設定テスト

```bash
# 3パターン比較（10, 20, 50並列）
./stress_test_advanced.sh -m multi -l "10,20,50" -d 60

# 5パターン比較
./stress_test_advanced.sh -m multi -l "5,10,20,50,100" -d 90
```

### 単一集中テスト

```bash
# 30並列で5分間
./stress_test_advanced.sh -m single -c 30 -d 300
```

---

## 💾 結果をCSVに保存

```bash
# プリセット + CSV出力
./stress_test_advanced.sh -m preset -p medium -o results_medium.csv

# ランプアップ + CSV出力
./stress_test_advanced.sh -m rampup -s 10 -e 50 -i 10 -d 60 -o results_rampup.csv

# 複数設定 + CSV出力
./stress_test_advanced.sh -m multi -l "10,20,30,40,50" -d 60 -o results_multi.csv
```

---

## 📈 推奨テストフロー

### フロー1: 段階的確認（初回）

```bash
# ステップ1: 軽負荷で動作確認
./stress_test_advanced.sh -m preset -p light -o step1_light.csv

# ステップ2: 中負荷でパフォーマンス確認
./stress_test_advanced.sh -m preset -p medium -o step2_medium.csv

# ステップ3: 結果に基づいて最適範囲を詳細テスト
# 例: 30-60並列が最適と判明した場合
./stress_test_advanced.sh -m rampup -s 30 -e 60 -i 5 -d 120 -o step3_detailed.csv
```

### フロー2: クイック確認（定期チェック）

```bash
# 中負荷プリセットで5分確認
./stress_test_advanced.sh -m preset -p medium -o daily_check_$(date +%Y%m%d).csv
```

### フロー3: パフォーマンス比較（改善前後）

```bash
# 改善前
./stress_test_advanced.sh -m multi -l "10,20,30,40,50" -d 90 -o before_tuning.csv

# チューニング実施（例: レプリカ数増加、リソース増強）

# 改善後
./stress_test_advanced.sh -m multi -l "10,20,30,40,50" -d 90 -o after_tuning.csv

# 2つのCSVファイルを比較分析
```

---

## 🔍 結果の見方

### コンソール出力（各テスト後）

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
最小レスポンス:     15 ms
最大レスポンス:     312 ms
95パーセンタイル:  145 ms
99パーセンタイル:  245 ms
```

### 最終サマリー（すべてのテスト後）

```
並列数       リクエスト    成功率       エラー率     RPS          平均応答時間
--------------------------------------------------------------------------------
10          1234        100.00%      0.00%        20.57        48.23ms
20          2145        100.00%      0.00%        35.75        55.89ms
30          2830        99.86%       0.14%        47.23        63.12ms
40          3187        99.56%       0.44%        53.35        75.34ms
50          3398        98.32%       1.68%        57.60        86.45ms

✅ 最適な並列数: 40 (スループット: 53.35 req/sec)
```

---

## 🎯 評価基準

### ✅ 優秀
- エラー率: < 1%
- 平均レスポンス: < 100ms
- 95パーセンタイル: < 200ms
- スループット: > 10 req/sec

### ⚠️ 許容範囲
- エラー率: 1-5%
- 平均レスポンス: 100-500ms
- 95パーセンタイル: 200-1000ms
- スループット: 5-10 req/sec

### ❌ 要改善
- エラー率: > 5%
- 平均レスポンス: > 500ms
- 95パーセンタイル: > 1000ms
- スループット: < 5 req/sec

---

## 🛠️ トラブル時のコマンド

### Pod状態確認
```bash
# Pod一覧
oc get pods

# リソース使用量
oc adm top pod -l app=camel-app

# ログ確認
oc logs -l app=camel-app --tail=100
```

### スケーリング
```bash
# レプリカ数増加
oc scale deployment/camel-app --replicas=3

# 垂直スケーリング（リソース増強）
oc set resources deployment/camel-app \
  --limits=cpu=2,memory=2Gi \
  --requests=cpu=1,memory=1Gi
```

### 再起動
```bash
# Deployment再起動
oc rollout restart deployment/camel-app

# 状態確認
oc rollout status deployment/camel-app
```

---

## 📊 Grafana監視

### URL取得
```bash
oc get route grafana -o jsonpath='{.spec.host}'
```

### 確認すべきパネル
1. HTTP Request Rate
2. HTTP Response Time (95th percentile)
3. HTTP Error Rate
4. JVM Heap Memory Usage
5. Undertow Worker Threads Busy
6. Camel Exchanges Total

---

## 💡 Tips

### ウォームアップ時間を短縮
```bash
./stress_test_advanced.sh -m preset -p light -w 3
```

### テスト時間を短縮（クイックチェック）
```bash
./stress_test_advanced.sh -m rampup -s 10 -e 50 -i 10 -d 30
```

### テスト時間を延長（精密測定）
```bash
./stress_test_advanced.sh -m single -c 30 -d 300
```

### バックグラウンド実行
```bash
nohup ./stress_test_advanced.sh -m preset -p medium -o results.csv > stress_test.log 2>&1 &
```

### テスト中断
```bash
# Ctrl+C で安全に中断
# 一時ファイルは自動クリーンアップ
```

---

## 📚 関連コマンド

### テストスクリプト実行
```bash
# 基本テスト
./test_camel_app.sh

# ストレステスト（基本）
./stress_test.sh

# ストレステスト（高度）
./stress_test_advanced.sh
```

### デプロイ関連
```bash
# デプロイ
./deploy.sh

# クリーンアップ
./cleanup.sh

# 状態確認
./CHECK_CAMEL_APP_STATUS.sh
```

---

## 🔗 詳細ドキュメント

- **詳細ガイド**: [STRESS_TEST_ADVANCED_GUIDE.md](STRESS_TEST_ADVANCED_GUIDE.md)
- **基本ストレステスト**: [STRESS_TEST_GUIDE.md](STRESS_TEST_GUIDE.md)
- **テストスクリプト**: [TEST_GUIDE.md](TEST_GUIDE.md)
- **デプロイガイド**: [OPENSHIFT_DEPLOYMENT_GUIDE.md](OPENSHIFT_DEPLOYMENT_GUIDE.md)


