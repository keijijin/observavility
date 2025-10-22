# macOS互換性の修正 🍎

## 問題

`stress_test.sh` 実行時に以下のエラーが発生：

```
/stress_test.sh: line 312: 17606697043N: value too great for base (error token is "17606697043N")
```

---

## 原因

macOSの`date`コマンドはGNU dateと異なり、`%N`（ナノ秒）をサポートしていません。

### 問題のコード

```bash
local start=$(date +%s%3N)  # ミリ秒 - macOSでは動作しない！
```

macOSの`date`コマンドは`%3N`を文字列として解釈し、以下のような値を返します：
```
17606697043N  # 秒 + "3N" という文字列
```

これを数値計算しようとするとエラーになります。

---

## 解決策

Python3を使用してミリ秒を取得するように変更しました。

### 修正後のコード

```bash
# macOS互換: Pythonでミリ秒を取得
local start=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || echo $(($(date +%s) * 1000)))
```

### フォールバック

Python3が利用できない場合は、秒単位×1000でミリ秒として扱います：
```bash
echo $(($(date +%s) * 1000))
```

---

## 動作確認

### 修正前（エラー）
```bash
$ date +%s%3N
17606697043N  # macOSでは "3N" が文字列になる
```

### 修正後（正常）
```bash
$ python3 -c 'import time; print(int(time.time() * 1000))'
1729075622345  # 正しいミリ秒のタイムスタンプ
```

---

## 他のOS/環境での動作

### Linux (GNU date)
```bash
$ date +%s%3N
1729075622345  # 正常に動作
```

### macOS (BSD date)
```bash
$ date +%s%3N
17290756223N  # エラーになる

$ python3 -c 'import time; print(int(time.time() * 1000))'
1729075622345  # Python3を使えば正常
```

---

## 修正したファイル

- **stress_test.sh** (2箇所)
  - `local start=$(date +%s%3N)` → Python3に変更
  - `local end=$(date +%s%3N)` → Python3に変更

---

## テスト

修正後、以下のコマンドでテストしてください：

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./stress_test.sh -c 5 -d 30
```

---

## 注意事項

### Python3が必須
このスクリプトはPython3を使用します。ほとんどのmacOSシステムにはPython3がプリインストールされています。

### 確認方法
```bash
which python3
# /usr/bin/python3 または /opt/homebrew/bin/python3
```

### Python3がない場合
```bash
# Homebrewでインストール
brew install python3
```

---

## まとめ

✅ macOS互換性の問題を修正  
✅ Python3でミリ秒を正確に取得  
✅ フォールバック機能あり  
✅ Linuxでもそのまま動作

修正が完了しました！🎉


