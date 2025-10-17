# 🚨 Grafanaでアラートを確認・管理するガイド

## 📋 概要

PrometheusのアラートをGrafanaで確認・可視化する方法を説明します。

---

## 🎯 Grafanaでアラートを見る3つの方法

### 1️⃣ **アラート監視ダッシュボード**（推奨✨）

#### アクセス方法
```
http://localhost:3000/d/alerts-overview
```

または:
1. Grafana → Dashboards
2. 「🚨 アラート監視ダッシュボード」を選択

#### 表示内容

**Row 1: アラート概要**
- 🔴 発火中のアラート数
- 🟡 保留中のアラート数
- 📋 総アラート数

**Row 2: クリティカルアラート**
- クリティカルアラート一覧（テーブル形式）
- アラート名、状態、重要度、コンポーネント

**Row 3: 警告アラート**
- 警告アラート一覧（テーブル形式）

**Row 4: アラート履歴**
- 時系列でアラート発火履歴を表示

**Row 5: メトリクス詳細**
- ヒープメモリ使用率（閾値線付き）
- エラー率（閾値線付き）

#### 特徴
✅ リアルタイム更新（10秒ごと）  
✅ アラート状態を色分け表示  
✅ 閾値線でアラート発火タイミングを視覚化  
✅ テーブルで詳細情報を一覧表示  

---

### 2️⃣ **Grafana Alertingページ**

#### アクセス方法
```
http://localhost:3000/alerting/list
```

または:
1. 左メニュー → **「Alerting」** アイコン（ベルマーク）
2. **「Alert rules」** を選択

#### 現在の状態
⚠️ **Grafana Alertingは未設定**

Prometheusのアラートルールは動作していますが、Grafana独自のアラート機能は設定していません。

#### Prometheusアラートを表示する方法

**方法A: Prometheusデータソースから取得**
1. Alerting → Alert rules
2. 「New alert rule」をクリック
3. クエリに以下を入力:
   ```promql
   ALERTS{alertstate="firing"}
   ```
4. 条件を設定して保存

**方法B: 統合アラート（Unified Alerting）**
- Grafana 8以降の機能
- Prometheusアラートと統合可能
- 設定が必要

---

### 3️⃣ **既存ダッシュボードでの視覚化**

#### 包括的ダッシュボード
```
http://localhost:3000/d/camel-comprehensive
```

**現在の機能:**
- ✅ 色分けによる閾値表示（緑/黄/橙/赤）
- ✅ ゲージによる視覚的な警告
- ✅ グラフ上での閾値超えの確認

**制限:**
- アラート発火情報は表示されない（メトリクス値のみ）
- アラートルールの状態は確認できない

---

## 📊 ALERTSメトリクスの使い方

Prometheusは、アラートルールを評価すると `ALERTS` という特別なメトリクスを生成します。

### ALERTSメトリクスの構造

```promql
ALERTS{
  alertname="HighMemoryUsage",
  alertstate="firing",
  severity="critical",
  component="jvm"
}
```

### 利用可能なラベル

| ラベル | 説明 | 値の例 |
|--------|------|--------|
| `alertname` | アラート名 | `HighMemoryUsage` |
| `alertstate` | アラート状態 | `firing`, `pending`, `inactive` |
| `severity` | 重要度 | `critical`, `warning`, `info` |
| `component` | コンポーネント | `jvm`, `camel`, `http` |

### 便利なクエリ

#### 1. 発火中のアラート数
```promql
count(ALERTS{alertstate="firing"})
```

#### 2. 保留中のアラート数
```promql
count(ALERTS{alertstate="pending"})
```

#### 3. クリティカルアラート一覧
```promql
ALERTS{severity="critical"}
```

#### 4. 特定のアラートが発火しているか
```promql
ALERTS{alertname="HighMemoryUsage", alertstate="firing"}
```

#### 5. コンポーネント別のアラート数
```promql
count by (component) (ALERTS{alertstate="firing"})
```

---

## 🎨 ダッシュボードの見方

### アラート監視ダッシュボード

#### 📊 概要パネル

**🔴 発火中のアラート**
- 値が0: すべて正常 ✅
- 値が1以上: 即座の対応が必要 🚨
- 背景色が赤: 3件以上発火中（深刻）

**🟡 保留中のアラート**
- 閾値を超えたが、まだ発火していない
- 監視を強化する必要あり
- 持続時間に達すると発火に変わる

#### 📋 アラート一覧テーブル

**列の説明:**
- `alertname`: アラート名
- `alertstate`: 
  - 🔴 FIRING: 発火中
  - 🟡 PENDING: 保留中
  - 🟢 INACTIVE: 正常
- `severity`: critical / warning / info
- `component`: jvm / camel / http / system

**ソート:**
- デフォルトで `alertstate` で降順ソート
- FIRING → PENDING → INACTIVE の順

#### 📈 アラート履歴グラフ

- 時系列でアラート発火を表示
- 積み上げグラフでアラート別に色分け
- パターンを把握するのに有用

#### 📊 メトリクス詳細（閾値線付き）

**ヒープメモリ使用率:**
- 実線: 実際の使用率
- 黄色点線: 警告閾値（70%）
- 赤色点線: クリティカル閾値（90%）

**エラー率:**
- 実線: 実際のエラー率
- 赤色点線: クリティカル閾値（10%）

---

## 🔍 実践例

### 例1: 発火中のアラートを確認

#### ステップ1: アラート監視ダッシュボードを開く
```
http://localhost:3000/d/alerts-overview
```

#### ステップ2: 「発火中のアラート」パネルを確認
- 値が1以上なら、アラートが発火中
- 背景色で深刻度を判断

#### ステップ3: アラート一覧テーブルで詳細を確認
- どのアラートが発火しているか
- コンポーネントを特定
- 重要度を確認

#### ステップ4: メトリクス詳細グラフで原因を分析
- ヒープメモリ使用率が閾値を超えているか
- エラー率が急増しているか

#### ステップ5: Prometheusで詳細を確認
```
http://localhost:9090/alerts
```

#### ステップ6: トレースとログで根本原因を調査
- Tempo: どのルートでエラーが発生しているか
- Loki: エラーメッセージの詳細

---

### 例2: アラートが発火する前に検知

#### ステップ1: 「保留中のアラート」パネルを監視
- 値が1以上なら、まもなく発火する可能性

#### ステップ2: メトリクス詳細グラフで傾向を確認
- メモリ使用率が上昇傾向か
- エラー率が増加しているか

#### ステップ3: 予防的な対応
- メモリ使用率が上昇中 → JVMヒープサイズの増加を検討
- エラー率が増加中 → ログで原因を調査

---

## 🚀 アラートテスト

### テスト1: アラート監視ダッシュボードでリアルタイム監視

```bash
# ターミナル1: 負荷テスト
cd /Users/kjin/mobills/observability/demo
./load-test-concurrent.sh -r 200 -c 30 -d 120

# ブラウザ: アラート監視ダッシュボードを開く
open http://localhost:3000/d/alerts-overview

# 観察ポイント:
# 1. 「保留中のアラート」が増加
# 2. 2-3分後、「発火中のアラート」が増加
# 3. テーブルでどのアラートが発火したか確認
# 4. メトリクスグラフで閾値超えを確認
```

### テスト2: アラート履歴の確認

```bash
# 負荷テストを複数回実行
./load-test-concurrent.sh -r 100 -c 20 -d 60
sleep 60
./load-test-concurrent.sh -r 200 -c 30 -d 60

# アラート監視ダッシュボードの「アラート履歴」グラフを確認
# どのアラートがいつ発火したかパターンを把握
```

---

## 🔧 カスタマイズ

### アラート監視ダッシュボードのカスタマイズ

#### 1. パネルの追加

**例: 特定のアラートだけ表示**

1. パネル編集（右上の「...」→「Edit」）
2. クエリを変更:
   ```promql
   ALERTS{alertname="HighMemoryUsage"}
   ```
3. 保存

#### 2. 閾値の変更

**例: メモリ使用率の警告閾値を60%に変更**

1. 「ヒープメモリ使用率」パネルを編集
2. クエリBを変更:
   ```promql
   60  # 70から60に変更
   ```
3. レジェンドも変更:
   ```
   Warning Threshold (60%)
   ```

#### 3. 通知の設定

1. パネル編集 → 「Alert」タブ
2. 「Create alert rule from this panel」
3. 条件を設定
4. Contact pointを選択
5. 保存

---

## 📊 Grafana Alerting vs Prometheus Alerting

### 比較表

| 項目 | Prometheus Alerting | Grafana Alerting |
|-----|---------------------|------------------|
| **アラートルール定義** | prometheus.yml | Grafana UI |
| **評価場所** | Prometheus | Grafana |
| **通知管理** | Alertmanager | Grafana内蔵 |
| **データソース** | Prometheusのみ | 複数（Loki, Tempo等） |
| **設定の容易さ** | YAML編集 | GUI操作 |
| **柔軟性** | 高い | 中程度 |

### 推奨使い分け

**Prometheus Alertingを使う場合:**
- ✅ Prometheusメトリクスのみを監視
- ✅ YAMLでアラートルールを管理したい
- ✅ Alertmanagerで高度な通知管理が必要
- ✅ 既存のPrometheusアラートルールがある

**Grafana Alertingを使う場合:**
- ✅ 複数のデータソースを組み合わせたい（Loki、Tempo等）
- ✅ GUIで簡単にアラートを設定したい
- ✅ Grafana内で通知も管理したい
- ✅ ダッシュボードパネルから直接アラートを作成したい

**本デモの構成:**
- **Prometheus Alerting** を使用（既に設定済み）
- Grafanaでは **表示・可視化** のみ
- 通知機能は未実装（Alertmanagerで追加可能）

---

## 🎯 まとめ

### ✅ Grafanaでアラートを確認する方法

| 方法 | URL | 機能 | 推奨度 |
|-----|-----|------|--------|
| **アラート監視ダッシュボード** | `/d/alerts-overview` | 発火中/保留中のアラートを一覧表示 | ⭐⭐⭐ |
| **Grafana Alertingページ** | `/alerting/list` | アラートルールの管理（未設定） | ⭐⭐ |
| **包括的ダッシュボード** | `/d/camel-comprehensive` | 色分けで閾値を視覚化 | ⭐⭐ |
| **Prometheus Web UI** | `http://localhost:9090/alerts` | 最も詳細な情報 | ⭐⭐⭐ |

### 📊 現在の構成

```
Prometheus
  ↓
  アラートルール評価（15秒ごと）
  ↓
  ALERTSメトリクス生成
  ↓
  Grafana（アラート監視ダッシュボード）
  ↓
  視覚化（テーブル、グラフ、Stat）
```

### 🚀 次のステップ

1. **アラート監視ダッシュボードを開く**
   ```
   http://localhost:3000/d/alerts-overview
   ```

2. **負荷テストでアラートを発火させる**
   ```bash
   ./load-test-stress.sh
   ```

3. **リアルタイムで監視**
   - 保留中のアラートが増加
   - 発火中のアラートが増加
   - メトリクスグラフで閾値超えを確認

4. **通知が必要な場合**
   - Alertmanagerを追加（[ALERTING_GUIDE.md](ALERTING_GUIDE.md)参照）
   - または Grafana Alertingを設定

---

## 📚 関連ドキュメント

- **[ALERTING_GUIDE.md](ALERTING_GUIDE.md)** - Prometheusアラート設定ガイド
- **[ALERT_STATUS.md](ALERT_STATUS.md)** - アラート機能の現在の状態
- **[DASHBOARD_GUIDE.md](DASHBOARD_GUIDE.md)** - ダッシュボード利用ガイド
- **[GRAFANA_HOWTO.md](GRAFANA_HOWTO.md)** - Grafana基本操作

---

**最終更新:** 2025年10月15日


