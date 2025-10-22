# macOS grep 互換性の修正 🍎

## 問題

macOSで以下のコマンドを実行するとエラーが発生：

```bash
grep -oP '\d+\.\d+$'
# エラー: grep: invalid option -- P
```

---

## 原因

macOSの`grep`はBSD版で、`-P`オプション（Perl正規表現）をサポートしていません。

### システムによる違い

| システム | grep種類 | `-P`オプション |
|---|---|---|
| Linux | GNU grep | ✅ サポート |
| macOS | BSD grep | ❌ サポートなし |

---

## 解決策

### 方法1: `awk` を使用（推奨・最もシンプル）

`grep -oP '\d+\.\d+$'` の代わりに：

```bash
awk '{print $NF}'
```

`$NF` は最後のフィールド（Number of Fields）を意味します。

#### 完全な例

**修正前（エラー）**:
```bash
BEFORE=$(curl -s http://localhost:8080/actuator/prometheus | \
  grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | \
  grep -oP '\d+\.\d+$')
```

**修正後（macOS互換）**:
```bash
BEFORE=$(curl -s http://localhost:8080/actuator/prometheus | \
  grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | \
  awk '{print $NF}')
```

---

### 方法2: `awk` を使用

```bash
awk '{print $NF}'
```

#### 例

```bash
curl -s http://localhost:8080/actuator/prometheus | \
  grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | \
  awk '{print $NF}'
```

---

### 方法3: `perl` を使用

```bash
perl -ne 'print $1 if /(\d+\.\d+)$/'
```

#### 例

```bash
curl -s http://localhost:8080/actuator/prometheus | \
  grep 'http_server_requests_seconds_count.*uri="/camel/api/orders"' | \
  perl -ne 'print $1 if /(\d+\.\d+)$/'
```

---

### 方法4: GNU grep をインストール

Homebrewで GNU grep をインストール：

```bash
# GNU grepをインストール
brew install grep

# GNU grepを使用（ggrep）
ggrep -oP '\d+\.\d+$'

# またはPATHに追加
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
# これでgrepがGNU grepになる
```

---

## 修正したファイル

以下のファイルをmacOS互換に修正しました：

### 1. rps_monitor.sh

**修正箇所**:
```bash
# 修正前
grep -oP '\d+\.\d+$'

# 修正後
sed -E 's/.*([0-9]+\.[0-9]+)$/\1/'
```

### 2. thread_monitor.sh

**修正箇所**:
```bash
# Tomcatメトリクス（3箇所）
CURRENT=$(curl -s "$ACTUATOR_URL" | grep "tomcat_threads_current_threads" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)
MAX=$(curl -s "$ACTUATOR_URL" | grep "tomcat_threads_config_max_threads" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)
BUSY=$(curl -s "$ACTUATOR_URL" | grep "tomcat_threads_busy_threads" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)

# Undertowメトリクス（3箇所）
WORKER=$(curl -s "$ACTUATOR_URL" | grep "undertow_worker_threads" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)
ACTIVE=$(curl -s "$ACTUATOR_URL" | grep "undertow_active_requests" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)
QUEUE=$(curl -s "$ACTUATOR_URL" | grep "undertow_request_queue_size" | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/' | head -1)
```

### 3. ACTUATOR_METRICS_GUIDE.md

ドキュメント内のコマンド例を修正

---

## 動作確認

### テスト1: 数値抽出

```bash
# テストデータ
echo 'http_server_requests_seconds_count{uri="/camel/api/orders"} 1234.56' | sed -E 's/.*([0-9]+\.[0-9]+)$/\1/'
# 出力: 1234.56
```

### テスト2: RPSスクリプト

```bash
# RPSモニタリングスクリプトを実行
cd /Users/kjin/mobills/observability/demo
./rps_monitor.sh 5 "/camel/api/orders"
```

### テスト3: スレッド監視スクリプト

```bash
# スレッド監視スクリプトを実行
cd /Users/kjin/mobills/observability/demo
./thread_monitor.sh 5
```

---

## sed 正規表現の説明

### パターン: `sed -E 's/.*([0-9]+\.[0-9]+)$/\1/'`

| 部分 | 説明 |
|---|---|
| `-E` | 拡張正規表現を使用 |
| `s/` | 置換コマンド |
| `.*` | 任意の文字を0回以上（最長一致） |
| `([0-9]+\.[0-9]+)` | 数字.数字のパターンをキャプチャ |
| `$` | 行末 |
| `/\1/` | キャプチャした内容（\1）に置換 |

### マッチング例

```
入力: http_server_requests_seconds_count{uri="/camel/api/orders"} 1234.56
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^^^
      .*（これらは削除される）                                    \1（これが残る）
出力: 1234.56
```

---

## 互換性マトリクス

### コマンド比較

| コマンド | Linux | macOS | 説明 |
|---|---|---|---|
| `grep -oP '\d+\.\d+$'` | ✅ | ❌ | Perl正規表現（GNU grep） |
| `sed -E 's/.*([0-9]+\.[0-9]+)$/\1/'` | ✅ | ✅ | 拡張正規表現（BSD/GNU sed両対応） |
| `awk '{print $NF}'` | ✅ | ✅ | 最後のフィールドを抽出 |
| `perl -ne 'print $1 if /(\d+\.\d+)$/'` | ✅ | ✅ | Perl（両方にインストール必要） |

---

## まとめ

### 修正内容

- ✅ `grep -oP` → `sed -E` に変更
- ✅ macOS/Linux両対応
- ✅ 3ファイルを修正（rps_monitor.sh, thread_monitor.sh, ACTUATOR_METRICS_GUIDE.md）

### 推奨される方法

1. **`sed -E`**: 最も互換性が高い（推奨）
2. **`awk`**: シンプルだが柔軟性が低い
3. **`perl`**: 強力だが追加インストールが必要な場合あり
4. **GNU grep**: Linux環境と完全互換だがインストールが必要

---

## 参考

### macOSでGNU grepを使いたい場合

```bash
# インストール
brew install grep

# 使用方法1: ggrepコマンド
ggrep -oP '\d+\.\d+$'

# 使用方法2: PATHを優先
echo 'export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"' >> ~/.zshrc
source ~/.zshrc
# これでgrepがGNU grepになる
```

---

修正が完了しました！🎉

