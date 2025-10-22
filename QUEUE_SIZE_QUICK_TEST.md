# Undertowキューサイズ増加テスト - クイックスタート

## 🎯 **最も簡単な方法**

### ステップ1: ワーカースレッド数を変更 (1分)

```bash
cd /Users/kjin/mobills/observability/demo

# 対話型スクリプトで変更
./change-worker-threads.sh
```

**選択肢:**
- **1を選択（1スレッド）** ← 確実にキュー発生！⭐⭐⭐
- **2を選択（5スレッド）** ← 推奨

**手順:**
```
# → 1 または 2 を選択
# → y で変更を適用
# → y で自動再起動
```

**これだけで準備完了！**

---

### ステップ2: 負荷テストを実行 (30秒)

```bash
# 既存のストレステストでOK
./load-test-stress.sh
# → y で開始
```

**または極限テスト:**

```bash
# より強力な負荷テスト
./load-test-extreme-queue.sh
# → y で開始
```

---

### ステップ3: リアルタイム監視 (別ターミナル)

```bash
# 別のターミナルで実行
cd /Users/kjin/mobills/observability/demo
./watch-queue-size.sh
```

**期待される表示:**

```
時刻       | Queue Size   | Active Req   | Workers      | Usage %     
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
11:30:01   | 0.0          | 0.0          | 5.0          | 0.0         
11:30:02   | 42.0         | 5.0          | 5.0          | 100.0       ← キューが発生！
11:30:03   | 68.0         | 5.0          | 5.0          | 100.0       
11:30:04   | 35.0         | 5.0          | 5.0          | 100.0       
11:30:05   | 12.0         | 5.0          | 5.0          | 100.0       
11:30:06   | 0.0          | 2.0          | 5.0          | 40.0        ← 処理完了
```

---

### ステップ4: Grafanaで確認

```
http://localhost:3000
→ Undertow Monitoring Dashboard
→ "⭐ Undertow Queue Size" パネルを確認
```

---

## 📊 **期待される結果**

### 変更前（ワーカー: 200）

```
Queue Size: 0（常に0）
Active Requests: 0-50
Worker Usage: 0-25%
```

### 変更後（ワーカー: 1）⭐ 確実

```
Queue Size: 10-99（確実に増加！）
Active Requests: 1（常に1）
Worker Usage: 100%
レスポンスタイム: 5-30秒（非常に遅い）
```

### 変更後（ワーカー: 5）推奨

```
Queue Size: 10-95（増加する！）
Active Requests: 5（常に満杯）
Worker Usage: 100%
レスポンスタイム: 1-5秒
```

---

## 🔄 **元に戻す方法**

### ⚠️ テスト完了後は必ず実行

### 方法1: スクリプトで戻す（推奨）

```bash
./change-worker-threads.sh
# → 6 を選択（200スレッド - デフォルト）
# → y で変更を適用
# → y で自動再起動
```

### 方法2: 手動で戻す

```bash
cd /Users/kjin/mobills/observability/demo/camel-app

# バックアップから復元
ls -lt src/main/resources/application.yml.backup* | head -1
cp src/main/resources/application.yml.backup.YYYYMMDD_HHMMSS src/main/resources/application.yml

# 再起動
mvn clean package -DskipTests
ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print $2}' | xargs kill
nohup mvn spring-boot:run > ../camel-app.log 2>&1 &
```

---

## 🧪 **追加テストシナリオ**

### シナリオA: 段階的な負荷増加

```bash
# 1. ワーカー: 20
./change-worker-threads.sh  # → 3を選択

# 2. 中負荷テスト
./load-test-stress.sh

# 3. 結果: Queue Size 0-20（軽度のキューイング）
```

### シナリオB: 極端な負荷

```bash
# 1. ワーカー: 5
./change-worker-threads.sh  # → 1を選択

# 2. 極限テスト
./load-test-extreme-queue.sh

# 3. 結果: Queue Size 50-200（大量キューイング）
```

---

## 📈 **他の監視方法**

### Prometheusダイレクトクエリ

```bash
# ワンライナー
curl -s http://localhost:8080/actuator/prometheus | grep "^undertow"
```

### リアルタイムwatch

```bash
watch -n 1 'curl -s http://localhost:8080/actuator/prometheus | grep undertow'
```

### スレッド監視（包括的）

```bash
./thread_monitor.sh
```

---

## ⚠️ **注意事項**

### ワーカー数を減らす影響

| ワーカー数 | 影響 | 用途 |
|---|---|---|
| **1** | 🔴 極めて遅い | キューテスト専用（確実） |
| **5** | 🚨 非常に遅い | キューテスト専用 |
| **10** | 🟠 遅い | キューテスト |
| **20** | 🟡 やや遅い | 中負荷テスト |
| **50** | ✅ 通常 | 通常負荷 |
| **200** | ✅ 高速 | 本番環境（推奨） |

### ⚠️ 警告

- **ワーカー数を1に設定すると、アプリケーションがほぼ応答不能になります**
- **ワーカー数を5に設定すると、アプリケーションが非常に遅くなります**
- **テスト環境でのみ使用してください**
- **テスト後は必ず元の設定（200）に戻してください**
- **本番環境では絶対に使用禁止**

---

## 🎉 **成功の確認方法**

### ✅ キューサイズが増加した場合

```bash
undertow_request_queue_size: 42.0  ← 0以外の値
```

**表示される場所:**
- Prometheus: `/actuator/prometheus`
- Grafana: Undertow Monitoring Dashboard
- スクリプト: `./watch-queue-size.sh`
- スクリプト: `./thread_monitor.sh`

### ❌ キューサイズが0のまま

**原因:**
1. ワーカースレッド数が多すぎる
2. 負荷が不十分
3. アプリケーションが再起動されていない

**対策:**
1. ワーカー数を5に変更して再起動
2. より強い負荷テストを実行（`load-test-extreme-queue.sh`）
3. `watch-queue-size.sh`でリアルタイム確認

---

## 🚀 **今すぐ試す - ワンライナー**

### 最速テスト（全自動）

```bash
cd /Users/kjin/mobills/observability/demo && \
echo "1
y
y" | ./change-worker-threads.sh && \
sleep 25 && \
./load-test-extreme-queue.sh
```

**このコマンドは:**
1. ワーカースレッドを5に変更
2. アプリケーションを自動再起動
3. 極限負荷テストを実行

**実行時間:** 約2-3分

---

## 📚 **詳細情報**

- **包括的ガイド**: `QUEUE_SIZE_TESTING_GUIDE.md`
- **理論的説明**: `UNDERTOW_QUEUE_EXPLANATION.md`
- **ダッシュボード設定**: `GRAFANA_UNDERTOW_MONITORING.md`

---

## 💡 **トラブルシューティング**

### 問題: スクリプトが実行できない

```bash
# 実行権限を付与
chmod +x *.sh
```

### 問題: アプリケーションが起動しない

```bash
# ログを確認
tail -f camel-app-worker-*.log

# プロセスを確認
ps aux | grep spring-boot
```

### 問題: メトリクスが取得できない

```bash
# アプリケーションの状態を確認
curl http://localhost:8080/actuator/health

# Prometheusエンドポイントを確認
curl http://localhost:8080/actuator/prometheus | head -20
```

---

**作成日**: 2025-10-20  
**トピック**: Undertowキューサイズ増加テスト - クイックスタート  
**推奨時間**: 5分以内で完了

