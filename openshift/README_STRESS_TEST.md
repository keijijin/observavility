# ストレステスト - クイックスタート 🚀

## すぐに使える！

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./stress_test.sh
```

---

## 📊 テスト設定

### デフォルト設定（軽負荷）
```bash
./stress_test.sh
```
- 並列: 10
- 継続: 60秒

### 中負荷テスト
```bash
./stress_test.sh -c 20 -d 120
```
- 並列: 20
- 継続: 2分

### 高負荷テスト
```bash
./stress_test.sh -c 50 -d 180
```
- 並列: 50
- 継続: 3分

### ストレステスト（限界確認）
```bash
./stress_test.sh -c 100 -d 300
```
- 並列: 100
- 継続: 5分

---

## 🎯 オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `-c <num>` | 並列接続数 | 10 |
| `-d <sec>` | 継続時間（秒） | 60 |
| `-r <num>` | 総リクエスト数 | 無制限 |
| `-w <sec>` | ウォームアップ（秒） | 5 |
| `-h` | ヘルプ | - |

---

## 📈 出力例

```
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

=== パフォーマンス評価 ===
✅ エラー率: 優秀 (0.85% < 1%)
✅ 平均レスポンスタイム: 優秀 (156.23ms < 100ms)
✅ 95パーセンタイル: 優秀 (345ms < 200ms)
⚠️  スループット: 許容範囲 (9.82 req/sec > 5)
```

---

## 📊 Grafana監視

### テスト前にGrafanaを開く

1. **Camel Comprehensive Dashboard** を開く
2. 時間範囲を **"Last 5 minutes"** に設定
3. Auto-refresh を **"5s"** に設定
4. 以下のパネルを監視:
   - HTTP Request Rate
   - HTTP Response Time (95th)
   - HTTP Error Rate
   - JVM Memory Usage
   - GC Pause Time

---

## 🔧 よくある問題と対処

### エラー率が高い（> 5%）

```bash
# Podログを確認
oc logs -l deployment=camel-app --tail=100

# リソースを確認
oc adm top pod -l deployment=camel-app

# Podを再起動
oc rollout restart deployment/camel-app
```

### レスポンスが遅い（> 500ms）

```bash
# レプリカ数を増やす
oc scale deployment/camel-app --replicas=3

# リソース制限を緩和（Deploymentを編集）
oc edit deployment camel-app
```

### スループットが低い（< 5 req/sec）

```bash
# 水平スケーリング
oc scale deployment/camel-app --replicas=5

# 自動スケーリング
oc autoscale deployment/camel-app --min=2 --max=10 --cpu-percent=70
```

---

## 📚 詳細ドキュメント

詳しい使い方は **STRESS_TEST_GUIDE.md** をご覧ください：

- パフォーマンス評価基準
- トラブルシューティング
- チューニング方法
- ベストプラクティス

---

## ✅ 準備完了！

早速ストレステストを実行してみてください！

```bash
./stress_test.sh -c 20 -d 60
```

🎊 **Grafanaでリアルタイムにメトリクスを監視しながらテストしましょう！**




