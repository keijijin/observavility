# Grafanaの使い方 - 初心者向けガイド

## 🎯 この資料について

Grafanaを初めて使う方向けに、基本的な操作方法を**詳しく**説明します。

---

## 📊 Prometheusクエリの実行方法

### ステップ1: Grafanaにアクセス

1. ブラウザを開く
2. アドレスバーに以下を入力して Enter:
   ```
   http://localhost:3000
   ```
3. ログイン画面が表示される

### ステップ2: ログイン

1. **Username** に `admin` と入力
2. **Password** に `admin` と入力
3. 「Log in」ボタンをクリック

**初回ログイン時:**
- 「Change Password」画面が表示される
- 「Skip」をクリック（パスワード変更をスキップ）

### ステップ3: Exploreモードを開く

**画面左側に縦長のメニューバーがあります**

1. 左側のメニューから **「Explore」** を探す
   - 🔍 虫眼鏡のようなアイコン
   - または「🧭 コンパス」のようなアイコン
   - 「Explore」という文字が表示されている

2. **「Explore」をクリック**

### ステップ4: データソースを選択

画面上部（左上あたり）に **データソースを選ぶドロップダウン** があります

1. **現在選択されているデータソース名** をクリック
   - 「-- select --」
   - または既に何か選択されている（例：「Prometheus」「Loki」など）

2. ドロップダウンメニューが開く

3. **「Prometheus」** を選択
   - クリックするとドロップダウンが閉じる

### ステップ5: クエリを入力

**画面中央に大きな入力エリアがあります**

#### 方法A: メトリクスブラウザを使う（初心者向け）

1. **「Metrics browser」** または **「Metric」** というボタンを探す
   - 入力エリアの右側にある
   - 「Code」と「Builder」というタブがある場合は「Builder」タブを選択

2. クリックすると **メトリクス一覧** が表示される

3. **スクロールして以下を探す:**
   ```
   http_server_requests_seconds_count
   ```

4. クリックして選択

5. **ラベルフィルター** を追加:
   - 「Label filters」セクションで
   - `application` = `camel-observability-demo` を設定

6. **Rateを適用:**
   - 「Operations」または「Functions」セクションで
   - 「Rate」を選択
   - Range: `1m` を入力

#### 方法B: 直接入力する（推奨）

1. **大きなテキスト入力エリア** をクリック
   - 「Enter a PromQL query...」と表示されている
   - または既に何か入力されている

2. **以下のクエリをコピー&ペースト:**
   ```promql
   rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
   ```

3. クエリが入力される

### ステップ6: クエリを実行

**入力エリアの右側に青いボタンがあります**

1. **「Run query」** ボタンを探す
   - 青色のボタン
   - 右上の方にある
   - ▶️（再生マーク）のようなアイコンがついている場合もある

2. **「Run query」をクリック**

### ステップ7: 結果を確認

**クエリ実行後:**

1. **グラフが表示される**
   - 入力エリアの下に
   - 時系列グラフとして表示

2. **グラフの見方:**
   - 横軸: 時間
   - 縦軸: リクエストレート（req/s）
   - 線がデータを表示

3. **データがない場合:**
   - グラフが平坦（ゼロ）
   - 「No data」と表示される
   - → アプリケーションにリクエストを送る必要あり

---

## 🎨 画面の配置（参考）

```
┌─────────────────────────────────────────────────────┐
│ Grafana ロゴ                           アカウント    │ ← ヘッダー
├──────┬──────────────────────────────────────────────┤
│      │ Explore                                       │
│ 左   │ ┌────────────────────────────────────────┐   │
│ メ   │ │ Prometheus ▼          [Run query] ボタン│   │
│ ニ   │ └────────────────────────────────────────┘   │
│ ュ   │                                               │
│ │   │ ┌────────────────────────────────────────┐   │
│ │   │ │ rate(http_server_requests_seconds...   │ ← クエリ入力
│ │   │ └────────────────────────────────────────┘   │
│ │   │                                               │
│ Explore│ ┌────────────────────────────────────────┐   │
│ │   │ │                                         │   │
│ │   │ │      📈 グラフがここに表示            │   │
│ │   │ │                                         │   │
│ Dashboards └────────────────────────────────────────┘   │
│ │   │                                               │
│ ▼   │                                               │
└──────┴──────────────────────────────────────────────┘
```

---

## 💡 よくある質問

### Q1: 「Run query」ボタンが見つからない

**確認すること:**
1. クエリ入力エリアの右側を見る
2. 画面を横にスクロール（ウィンドウが小さい場合）
3. 青い「▶ Run query」のようなボタンを探す

**代替方法:**
- クエリを入力後、**Shift + Enter** を押す
- 自動的にクエリが実行される

### Q2: 「Prometheus」が選択肢にない

**原因:**
- データソースが設定されていない

**解決方法:**
1. 左メニュー → 「Connections」→「Data sources」
2. 「Add data source」をクリック
3. 「Prometheus」を選択
4. URL: `http://prometheus:9090` を入力
5. 「Save & test」をクリック

### Q3: グラフに何も表示されない

**原因1: データがまだない**
```bash
# ターミナルでリクエストを送る
curl -X POST http://localhost:8080/camel/api/orders
```

**原因2: 時間範囲が間違っている**
- 右上の時間範囲を「Last 5 minutes」に変更

**原因3: アプリケーションが起動していない**
```bash
# Camelアプリの確認
ps aux | grep spring-boot:run
```

### Q4: エラーメッセージが表示される

**「Bad Gateway」や「Connection refused」:**
- Prometheusが起動しているか確認:
  ```bash
  podman ps | grep prometheus
  ```

**「No data」:**
- メトリクスがまだ収集されていない
- 少し待ってから再度「Run query」

---

## 📖 実践練習

### 練習1: 基本的なクエリ

1. Exploreを開く
2. データソース: Prometheus
3. 以下のクエリを実行:

```promql
up
```

**結果:** 
- すべての監視対象の稼働状態が表示される
- `1` = 稼働中、`0` = 停止

### 練習2: JVMメモリを確認

```promql
jvm_memory_used_bytes{application="camel-observability-demo"}
```

**結果:**
- JVMのメモリ使用量がバイト単位で表示
- 複数の線（heap、non-heap など）

### 練習3: リクエストレートを確認

```promql
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
```

**結果:**
- 過去1分間のリクエストレート
- req/s（リクエスト/秒）で表示

### 練習4: 応用 - 平均レスポンスタイム

```promql
rate(http_server_requests_seconds_sum{application="camel-observability-demo"}[1m]) / 
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
```

**結果:**
- 平均レスポンスタイム（秒）
- 数値が大きいほど遅い

---

## 🎯 便利な機能

### 時間範囲の変更

**右上の時計アイコンまたは時間表示をクリック:**
- Last 5 minutes
- Last 15 minutes
- Last 1 hour
- カスタム範囲も設定可能

### 自動更新

**右上の「🔄」アイコンをクリック:**
- Off（自動更新なし）
- 5s（5秒ごと）
- 10s（10秒ごと）
- 30s（30秒ごと）

### グラフの拡大・縮小

**グラフ上でマウス操作:**
- ドラッグで範囲選択 → その範囲にズーム
- ダブルクリック → ズームアウト

### クエリの保存

**右上の「💾」アイコンまたは「Save」:**
1. クリック
2. 名前を入力
3. 「Save」をクリック
4. 後で「Open」から呼び出せる

---

## 🔍 トラブルシューティング

### 問題: ログインできない

**確認:**
1. URL が `http://localhost:3000` か確認
2. Grafanaコンテナが起動しているか:
   ```bash
   podman ps | grep grafana
   ```
3. デフォルト認証情報を使用:
   - Username: `admin`
   - Password: `admin`

### 問題: クエリがエラーになる

**よくあるエラー:**

1. **構文エラー:**
   ```
   parse error: ...
   ```
   → クエリの構文を確認（括弧、引用符など）

2. **メトリクスが見つからない:**
   ```
   no data
   ```
   → メトリクス名を確認
   → アプリケーションが稼働しているか確認

3. **タイムアウト:**
   ```
   timeout
   ```
   → クエリが重すぎる
   → 時間範囲を短くする

### 問題: グラフが見づらい

**対処法:**
1. 右側の「Options」パネルを開く
2. 「Legend」を調整
3. 「Graph styles」で線の太さを変更
4. 「Axis」で軸のラベルを調整

---

## 📚 次のステップ

### さらに学ぶ

1. **PromQL（Prometheus Query Language）:**
   - [Prometheus公式ドキュメント](https://prometheus.io/docs/prometheus/latest/querying/basics/)

2. **Grafanaの高度な機能:**
   - ダッシュボードの作成
   - アラートの設定
   - 変数の使用

3. **実践:**
   - [OBSERVABILITY_EXPERIENCE.md](OBSERVABILITY_EXPERIENCE.md) で体験

### おすすめクエリ集

```promql
# CPU使用率
process_cpu_usage{application="camel-observability-demo"}

# 稼働時間（秒）
process_uptime_seconds{application="camel-observability-demo"}

# スレッド数
jvm_threads_live_threads{application="camel-observability-demo"}

# GC回数
rate(jvm_gc_pause_seconds_count[1m])

# HTTPリクエスト（ステータスコード別）
http_server_requests_seconds_count{application="camel-observability-demo"}
```

---

## 🎉 まとめ

### 基本的な流れ

```
1. Grafanaにアクセス (http://localhost:3000)
   ↓
2. ログイン (admin/admin)
   ↓
3. Exploreを開く（左メニュー）
   ↓
4. データソースを選択（Prometheus）
   ↓
5. クエリを入力
   ↓
6. Run query をクリック
   ↓
7. グラフを確認
```

### 重要なポイント

- ✅ データソースは必ず「Prometheus」を選択
- ✅ クエリは大文字小文字を区別する
- ✅ 時間範囲を適切に設定
- ✅ データがない場合は負荷テストを実行

### ヘルプ

困ったときは:
1. このドキュメントの「よくある質問」を確認
2. [README.md](README.md) のトラブルシューティング
3. Prometheusで直接確認: http://localhost:9090

---

**これでGrafanaの基本的な使い方がわかりました！** 🎊

実際にクエリを実行して、オブザーバビリティを体験してください。




