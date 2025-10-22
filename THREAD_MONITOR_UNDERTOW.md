# thread_monitor.sh Undertow対応完了

## ✅ 拡張内容

`thread_monitor.sh`をTomcat/Undertow両対応に拡張しました。

---

## 🎯 新機能

### 1. **自動検出機能**

起動時にTomcat/Undertowメトリクスの有無を自動検出します。

```bash
✅ アプリケーション接続成功

検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  - Tomcatメトリクス: 有効 ✅
```

または

```bash
✅ アプリケーション接続成功

検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  - Undertowメトリクス: 有効 ✅（キューサイズ含む）
```

### 2. **Tomcatメトリクス表示**

Tomcatメトリクスが有効な場合：

```
[10:44:30]
  JVMスレッド:
    Live: 38 | Daemon: 34 | Non-Daemon: 4 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Tomcat Threads:
    Current: 10 | Busy: 2 | Idle: 8 | Max: 200 | Usage: 1.0%
```

### 3. **Undertowメトリクス表示（キューサイズ含む）** ✅

Undertowメトリクスが有効な場合：

```
[10:44:30]
  JVMスレッド:
    Live: 38 | Daemon: 34 | Non-Daemon: 4 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Undertow:
    Workers: 200 | Active: 5 | Queue: 10 | Usage: 2.5%
```

**表示項目**:
- **Workers**: ワーカースレッド数
- **Active**: 現在処理中のリクエスト数
- **Queue**: キューに入っているリクエスト数 ⭐ 新機能
- **Usage**: ワーカースレッド使用率

---

## 📊 監視できるメトリクス

### 常に表示（すべての環境）

| カテゴリ | メトリクス | 説明 |
|---|---|---|
| **JVMスレッド** | Live | 稼働中のスレッド総数 |
| | Daemon | デーモンスレッド数 |
| | Non-Daemon | アプリケーションスレッド数 |
| | Peak | 起動以降の最大スレッド数 |
| **Executor** | Active | 処理中のタスク数 |
| | Pool Size | 現在のプールサイズ |
| | Max | 最大スレッド数 |
| | Core | コアスレッド数 |
| | Usage | 使用率 |

### Tomcatメトリクス（有効な場合のみ）

| メトリクス | 説明 |
|---|---|
| **Current** | 現在のスレッド数 |
| **Busy** | ビジー（処理中）スレッド数 |
| **Idle** | アイドル（待機中）スレッド数 |
| **Max** | 最大スレッド数 |
| **Usage** | 使用率（Busy/Max） |

### Undertowメトリクス（有効な場合のみ）⭐

| メトリクス | 説明 | 重要度 |
|---|---|---|
| **Workers** | ワーカースレッド数 | 🔵 通常 |
| **Active** | 処理中のリクエスト数 | 🔵 通常 |
| **Queue** | キューに入っているリクエスト数 | ⭐ **重要** |
| **Usage** | ワーカースレッド使用率 | 🔵 通常 |

---

## 🚀 使い方

### 基本

```bash
cd /Users/kjin/mobills/observability/demo

# デフォルト（5秒間隔）
./thread_monitor.sh

# 2秒間隔
./thread_monitor.sh 2
```

### 出力例（Undertow環境）

```
=== JVM & Webサーバー スレッド監視 ===
測定間隔: 2秒
Ctrl+C で終了

✅ アプリケーション接続成功

検出されたメトリクス:
  - JVMスレッド: 有効
  - Executor: 有効
  - Undertowメトリクス: 有効 ✅（キューサイズ含む）

[10:44:30]
  JVMスレッド:
    Live: 45 | Daemon: 38 | Non-Daemon: 7 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Undertow:
    Workers: 200 | Active: 15 | Queue: 8 | Usage: 7.5%

[10:44:32]
  JVMスレッド:
    Live: 47 | Daemon: 40 | Non-Daemon: 7 | Peak: 129
  Executor（Spring Task Executor）:
    Active: 0 | Pool Size: 0 | Max: 200 | Core: 8 | Usage: 0%
  Undertow:
    Workers: 200 | Active: 20 | Queue: 15 | Usage: 10.0%
```

---

## 🔧 Undertowへの切り替え方法

現在Tomcatを使用している場合、以下の手順でUndertowに切り替えられます。

### 1. pom.xml の変更

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <!-- Tomcatを除外 -->
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<!-- Undertowを追加 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-undertow</artifactId>
</dependency>
```

### 2. application.yml の設定

```yaml
server:
  undertow:
    threads:
      io: 4                    # I/Oスレッド数（通常はCPUコア数）
      worker: 200              # ワーカースレッド数（最大）
    buffer-size: 1024          # バッファサイズ（バイト）
    direct-buffers: true       # ダイレクトバッファを使用
```

### 3. 再起動

```bash
# アプリケーションを再起動
mvn clean spring-boot:run
```

### 4. 確認

```bash
# thread_monitor.shを実行
./thread_monitor.sh

# Undertowメトリクスが表示されることを確認
```

---

## 💡 Undertowキューサイズの重要性

### キューサイズとは？

**キューサイズ**は、ワーカースレッドがすべてビジーで、新しいリクエストを即座に処理できない場合に、**待機しているリクエストの数**を示します。

### 正常な状態

```
Workers: 200 | Active: 150 | Queue: 0 | Usage: 75.0%
```
- ✅ キュー: 0
- ✅ すべてのリクエストが即座に処理されている

### 注意が必要な状態

```
Workers: 200 | Active: 195 | Queue: 50 | Usage: 97.5%
```
- ⚠️ キュー: 50
- ⚠️ ワーカースレッドが不足
- ⚠️ レスポンスタイムが遅延している可能性

### 危険な状態

```
Workers: 200 | Active: 200 | Queue: 500 | Usage: 100%
```
- 🚨 キュー: 500
- 🚨 すべてのワーカーがビジー
- 🚨 大量のリクエストが待機中
- 🚨 即座の対応が必要

### 対策

#### 短期的対策
```yaml
# application.yml
server:
  undertow:
    threads:
      worker: 400  # ワーカースレッドを増やす
```

#### 長期的対策
- スケールアウト（アプリケーションインスタンスを増やす）
- ボトルネック特定（DBクエリ、外部API呼び出しなど）
- キャッシュの活用
- 非同期処理の導入

---

## 📊 閾値の目安

### Undertowキューサイズ

| 状態 | Queue | 対応 |
|---|---|---|
| **正常** | 0-10 | 監視継続 |
| **注意** | 11-50 | 原因調査を開始 |
| **警告** | 51-100 | スレッド数増加を検討 |
| **危険** | 101+ | 即座の対応が必要 |

### Undertow使用率

| 状態 | Usage | 対応 |
|---|---|---|
| **正常** | 0-70% | 問題なし |
| **注意** | 71-85% | 監視強化 |
| **警告** | 86-95% | キャパシティ増強を検討 |
| **危険** | 96-100% | 即座の対応が必要 |

---

## 🎯 まとめ

| 項目 | 状態 |
|---|---|
| **Tomcat対応** | ✅ 完了（自動検出） |
| **Undertow対応** | ✅ 完了（キューサイズ含む） |
| **自動検出** | ✅ 有効 |
| **macOS互換性** | ✅ 完全対応 |
| **パフォーマンス** | ✅ 最適化（1回のcurl実行） |

---

## 📚 関連ファイル

- `thread_monitor.sh` (6.4K) - メインスクリプト
- `THREAD_MONITOR_VERIFICATION.md` (5.8K) - 動作検証レポート
- `ACTUATOR_METRICS_GUIDE.md` (22K) - メトリクスガイド

---

**作成日**: 2025-10-20  
**対応バージョン**: Tomcat/Undertow両対応  
**新機能**: Undertowキューサイズ監視 ⭐


