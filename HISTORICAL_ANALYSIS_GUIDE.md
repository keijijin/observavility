# 📊 履歴分析ガイド

## 🎯 履歴分析とは

**履歴分析**とは、過去のメトリクスデータを時系列で分析し、システムの振る舞いのパターンや異常を発見することです。

### 従来ツール（jconsole等）の問題

```
❌ リアルタイムの値しか見えない
   → 「今、メモリ使用率が60%」しかわからない
   
❌ 過去のデータが残らない
   → 「昨日の同じ時間は何%だったか」不明
   
❌ トレンドが見えない
   → 「徐々にメモリ使用率が上がっている」ことに気づけない
```

### Prometheus + Grafana の履歴分析

```
✅ 過去のデータを保存（デフォルト15日間）
   → 2週間前のデータと比較可能
   
✅ 任意の時間範囲で分析
   → 「過去24時間」「先週」「先月」など自由に選択
   
✅ トレンドの可視化
   → グラフで上昇・下降傾向を一目で把握
   
✅ 異常パターンの発見
   → 「通常は1%なのに、15時に15%まで急増」を発見
```

---

## 🚀 実践: 履歴分析の方法

### 方法1: Grafanaで時間範囲を変更

#### ステップ1: ダッシュボードを開く

```
http://localhost:3000/d/camel-comprehensive
```

#### ステップ2: 時間範囲を選択

画面右上の時間範囲セレクタをクリック:

**クイック選択:**
- Last 5 minutes（直近5分）
- Last 15 minutes（直近15分）
- Last 1 hour（直近1時間）
- Last 6 hours（直近6時間）
- Last 24 hours（直近24時間）⭐
- Last 7 days（直近7日間）⭐
- Last 30 days（直近30日間）

**カスタム範囲:**
```
From: 2025-10-14 00:00:00
To:   2025-10-14 23:59:59
```

#### ステップ3: グラフを確認

時間範囲を変更すると、すべてのグラフが自動的に更新されます。

**例: メモリ使用率の1週間トレンド**
1. 時間範囲を「Last 7 days」に変更
2. ヒープメモリ使用率のグラフを確認
3. 週末と平日でパターンが違うか？
4. 徐々に増加傾向にあるか？

---

### 方法2: Grafana Exploreで履歴クエリ

#### ステップ1: Exploreを開く

```
http://localhost:3000/explore
```

左メニュー → 「Explore」（羅針盤アイコン）

#### ステップ2: データソースを選択

上部のドロップダウンから **「Prometheus」** を選択

#### ステップ3: 時間範囲を設定

右上で任意の時間範囲を設定:
```
例: Last 24 hours
```

#### ステップ4: クエリを入力

**例1: 過去24時間のメモリ使用率**
```promql
(jvm_memory_used_bytes{application="camel-observability-demo",area="heap"} / 
 jvm_memory_max_bytes{application="camel-observability-demo",area="heap"}) * 100
```

**例2: 過去1週間のエラー率**
```promql
(rate(camel_exchanges_failed_total{application="camel-observability-demo"}[5m]) / 
 rate(camel_exchanges_total{application="camel-observability-demo"}[5m])) * 100
```

**例3: 過去24時間のHTTPリクエストレート**
```promql
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
```

#### ステップ5: 「Run query」をクリック

グラフが表示され、指定した時間範囲のデータが可視化されます。

---

### 方法3: Prometheusで範囲クエリ（コマンドライン）

#### 基本構文

```bash
# 範囲クエリ
curl -G 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=<PromQLクエリ>' \
  --data-urlencode 'start=<開始時刻>' \
  --data-urlencode 'end=<終了時刻>' \
  --data-urlencode 'step=15s'
```

#### 例1: 過去1時間のメモリ使用率

```bash
# 開始時刻: 1時間前
START=$(date -u -v-1H '+%s')
# 終了時刻: 現在
END=$(date -u '+%s')

curl -G 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=(jvm_memory_used_bytes{area="heap"}/jvm_memory_max_bytes{area="heap"})*100' \
  --data-urlencode "start=${START}" \
  --data-urlencode "end=${END}" \
  --data-urlencode 'step=60s' | jq '.data.result[0].values[-10:]'
```

**出力例:**
```json
[
  [1697356800, "45.2"],
  [1697356860, "46.1"],
  [1697356920, "44.8"],
  [1697356980, "47.3"],
  ...
]
```

各行: `[タイムスタンプ, 値]`

#### 例2: 過去24時間のエラー率

```bash
START=$(date -u -v-24H '+%s')
END=$(date -u '+%s')

curl -G 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=rate(camel_exchanges_failed_total[5m])/rate(camel_exchanges_total[5m])*100' \
  --data-urlencode "start=${START}" \
  --data-urlencode "end=${END}" \
  --data-urlencode 'step=300s' | jq '.'
```

---

## 📈 実践例: トレンド分析

### 例1: メモリリークの検知

#### シナリオ
「メモリ使用率が徐々に上昇している気がする」

#### 分析手順

**1. Grafanaで長期トレンドを確認**
```
http://localhost:3000/d/camel-comprehensive
```

- 時間範囲: **Last 7 days**
- パネル: ヒープメモリ使用率

**2. パターンを観察**

✅ **正常なパターン:**
```
鋸歯状のグラフ（上下を繰り返す）
  ↑ メモリ使用
  ↓ GC実行
  ↑ メモリ使用
  ↓ GC実行
```

❌ **異常なパターン（メモリリーク）:**
```
右肩上がりのグラフ（継続的に上昇）
  ↑ メモリ使用
  ↗ GC実行後も高いまま
  ↑ メモリ使用
  ↗ GC実行後もさらに高い
```

**3. 詳細調査**

メモリリークの疑いがある場合:
```promql
# GC後のメモリ使用量の推移
jvm_gc_memory_allocated_bytes_total
```

---

### 例2: 定期的な異常の発見

#### シナリオ
「特定の時間帯にエラーが増える」

#### 分析手順

**1. 24時間のエラー率を表示**

Grafana Explore:
```promql
rate(camel_exchanges_failed_total[5m]) / rate(camel_exchanges_total[5m]) * 100
```

時間範囲: **Last 24 hours**

**2. パターンを観察**

```
例:
00:00-06:00 → エラー率 1%（正常）
06:00-09:00 → エラー率 1%（正常）
09:00-10:00 → エラー率 15%（異常！）← 毎日9時に発生
10:00-24:00 → エラー率 1%（正常）
```

**3. 原因の特定**

- 9時に何かバッチ処理が走っている？
- 9時に外部APIが重くなる？
- 9時にデータベースのバックアップが走る？

**4. 複数日で確認**

時間範囲を「Last 7 days」に変更:
```
毎日9時に同じパターン → 定期的な問題
```

---

### 例3: キャパシティプランニング

#### シナリオ
「メモリを増やすべきか判断したい」

#### 分析手順

**1. 長期トレンドを確認**

時間範囲: **Last 30 days**

**2. ピーク使用率を確認**

```promql
max_over_time(
  (jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100)[30d:1h]
)
```

**3. 判断基準**

```
ピーク使用率 < 70% → 現状で問題なし
ピーク使用率 70-85% → 監視強化
ピーク使用率 > 85% → メモリ増量を検討
```

**4. 成長率の計算**

先月の平均 vs 今月の平均:
```promql
# 先月の平均（30日前〜31日前の1日間）
avg_over_time(jvm_memory_used_bytes[1d] offset 30d)

# 今週の平均（直近1日間）
avg_over_time(jvm_memory_used_bytes[1d])
```

成長率が月5%以上なら要注意。

---

## 🔍 比較分析

### Before/After 比較

#### シナリオ
「コード変更後、パフォーマンスが改善したか確認したい」

#### 手順

**1. デプロイ時刻を記録**
```
デプロイ: 2025-10-15 14:00
```

**2. デプロイ前のメトリクスを取得**

Grafana Explore:
```promql
rate(camel_route_policy_seconds_sum[5m]) / rate(camel_route_policy_seconds_count[5m])
```

カスタム時間範囲:
```
From: 2025-10-15 13:00
To:   2025-10-15 14:00
```

**3. デプロイ後のメトリクスを取得**

同じクエリで時間範囲を変更:
```
From: 2025-10-15 14:00
To:   2025-10-15 15:00
```

**4. 比較**

```
Before: 平均 450ms
After:  平均 250ms
改善率: 44% 改善 ✅
```

---

## 📊 便利な時間範囲クエリ

### Prometheus PromQLでの時間操作

#### 1. 範囲ベクトル

```promql
# 直近5分間の平均
avg_over_time(metric[5m])

# 直近1時間の最大値
max_over_time(metric[1h])

# 直近24時間の最小値
min_over_time(metric[24h])
```

#### 2. オフセット（過去のデータ）

```promql
# 現在の値
metric

# 1時間前の値
metric offset 1h

# 1日前の値
metric offset 1d

# 1週間前の値
metric offset 7d
```

#### 3. 増減の計算

```promql
# 1時間前と比較
metric - (metric offset 1h)

# 昨日の同時刻と比較
metric - (metric offset 24h)

# 変化率（%）
((metric - (metric offset 1h)) / (metric offset 1h)) * 100
```

---

## 🛠️ 実践スクリプト

### スクリプト1: 過去24時間のレポート生成

```bash
#!/bin/bash
# historical_report.sh

echo "=== 過去24時間のシステムレポート ==="
echo ""

# メモリ使用率の最大値
echo "📊 メモリ使用率（最大）:"
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=max_over_time((jvm_memory_used_bytes{area="heap"}/jvm_memory_max_bytes{area="heap"}*100)[24h:1m])' | \
  jq -r '.data.result[0].value[1]' | \
  awk '{printf "  %.2f%%\n", $1}'

# エラー率の平均
echo ""
echo "❌ エラー率（平均）:"
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((rate(camel_exchanges_failed_total[5m])/rate(camel_exchanges_total[5m])*100)[24h:5m])' | \
  jq -r '.data.result[0].value[1]' | \
  awk '{printf "  %.2f%%\n", $1}'

# リクエスト総数
echo ""
echo "📈 HTTPリクエスト総数:"
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=increase(http_server_requests_seconds_count[24h])' | \
  jq -r '.data.result[] | "  \(.metric.uri): \(.value[1])"'
```

**実行:**
```bash
chmod +x historical_report.sh
./historical_report.sh
```

---

### スクリプト2: トレンド比較（今週 vs 先週）

```bash
#!/bin/bash
# trend_comparison.sh

echo "=== トレンド比較: 今週 vs 先週 ==="
echo ""

# 今週の平均メモリ使用率
THIS_WEEK=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((jvm_memory_used_bytes{area="heap"}/jvm_memory_max_bytes{area="heap"}*100)[7d:1h])' | \
  jq -r '.data.result[0].value[1]')

# 先週の平均メモリ使用率
LAST_WEEK=$(curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=avg_over_time((jvm_memory_used_bytes{area="heap"}/jvm_memory_max_bytes{area="heap"}*100)[7d:1h] offset 7d)' | \
  jq -r '.data.result[0].value[1]')

echo "📊 メモリ使用率:"
echo "  今週: ${THIS_WEEK}%"
echo "  先週: ${LAST_WEEK}%"
echo ""

# 変化率を計算
CHANGE=$(echo "scale=2; (${THIS_WEEK} - ${LAST_WEEK}) / ${LAST_WEEK} * 100" | bc)
echo "  変化: ${CHANGE}%"

if (( $(echo "$CHANGE > 5" | bc -l) )); then
    echo "  ⚠️  メモリ使用率が増加傾向にあります"
elif (( $(echo "$CHANGE < -5" | bc -l) )); then
    echo "  ✅ メモリ使用率が減少傾向にあります"
else
    echo "  ✅ 安定しています"
fi
```

---

## 📚 まとめ

### 履歴分析でできること

| 分析タイプ | できること | ツール |
|----------|----------|--------|
| **トレンド分析** | 長期的な上昇・下降傾向の把握 | Grafana（時間範囲変更） |
| **パターン発見** | 定期的な異常の検知 | Grafana Explore |
| **Before/After比較** | 変更の効果測定 | カスタム時間範囲 |
| **キャパシティプランニング** | リソース増強の判断 | 長期メトリクス |
| **異常検知** | 通常とは異なる挙動の発見 | アラートルール + 履歴 |

### jconsole vs Prometheus + Grafana

| 項目 | jconsole | Prometheus + Grafana |
|-----|----------|---------------------|
| **データ保存** | なし | 15日間（設定可能） |
| **時間範囲** | 「今」のみ | 任意の過去範囲 |
| **トレンド** | 見えない | グラフで一目瞭然 |
| **比較** | できない | Before/After可能 |
| **レポート** | 手動記録 | API経由で自動化 |

---

## 🎯 次のステップ

1. **Grafanaで時間範囲を変更してみる**
   ```
   http://localhost:3000/d/camel-comprehensive
   ```
   右上の時間範囲を「Last 24 hours」→「Last 7 days」に変更

2. **過去のデータを確認**
   ```bash
   # 負荷テストを実行
   cd /Users/kjin/mobills/observability/demo
   ./load-test-concurrent.sh -r 100 -c 20 -d 60
   
   # 30分後、Grafanaで「Last 1 hour」を表示
   # 負荷テスト中のスパイクが見えるはず
   ```

3. **定期的なレポート生成**
   - 上記のスクリプトを cron で毎日実行
   - 週次レポートを作成

---

**履歴分析により、「今」だけでなく「過去との比較」ができ、トレンドやパターンを発見できます！**🚀




