# OpenShift テストスクリプト - 完全ガイド 📚

OpenShift上のCamel Appをテストする2つのスクリプトの完全ガイドです。

---

## 📋 スクリプト一覧

### 1. **test_camel_app.sh** - 機能テスト
正常動作を確認する包括的なテストスクリプト

### 2. **stress_test.sh** - ストレステスト（負荷テスト）
パフォーマンスと限界を測定するストレステストスクリプト

---

## 🎯 使い分け

| スクリプト | 目的 | 実行タイミング |
|---|---|---|
| `test_camel_app.sh` | 機能確認・動作確認 | デプロイ直後、定期チェック |
| `stress_test.sh` | 性能測定・負荷テスト | リリース前、スケーリング検証 |

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

## 📚 すべてのドキュメント

| ファイル | 内容 |
|---|---|
| `test_camel_app.sh` | 機能テストスクリプト |
| `stress_test.sh` | ストレステストスクリプト |
| `TEST_SCRIPT_GUIDE.md` | 機能テストの詳細ガイド |
| `STRESS_TEST_GUIDE.md` | ストレステストの詳細ガイド |
| `README_TEST_SCRIPT.md` | 機能テストのクイックスタート |
| `README_STRESS_TEST.md` | ストレステストのクイックスタート |
| `ALL_SCRIPTS_SUMMARY.md` | このファイル（完全ガイド） |
| `QUICKTEST.md` | 手動5分テスト |
| `TEST_GUIDE.md` | 手動詳細テスト |
| `FINAL_STATUS.md` | 環境の最終ステータス |

---

## 🎊 まとめ

2つのテストスクリプトを活用して、OpenShift上のCamel Appの品質とパフォーマンスを保証しましょう！

### 機能テスト: test_camel_app.sh
- ✅ デプロイ後の確認
- ✅ 定期的な健全性チェック
- ✅ 12項目の包括的なテスト

### ストレステスト: stress_test.sh
- ✅ パフォーマンス測定
- ✅ 限界確認
- ✅ スケーリング検証

お疲れ様でした！ 🚀


