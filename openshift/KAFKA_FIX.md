# 🔧 Kafka CrashLoopBackOff 修正ガイド

## 🔍 問題の診断

### 現象

```bash
$ oc get pods
NAME                          READY   STATUS             RESTARTS       AGE
kafka-5d6697878c-mn4nq        0/1     CrashLoopBackOff   11 (2m ago)    34m
```

### ログ

```bash
$ oc logs kafka-5d6697878c-mn4nq
===> User
uid=1000770000(1000770000) gid=0(root) groups=0(root),1000770000
===> Configuring ...
Running in Zookeeper mode...
port is deprecated. Please use KAFKA_ADVERTISED_LISTENERS instead.
```

### 原因

**Confluentの `cp-kafka` イメージがOpenShiftのセキュリティ制約と互換性がない**

| 問題 | 詳細 |
|-----|------|
| **Security Context Constraints (SCC)** | OpenShiftの`restricted-v2` SCCでランダムUID (1000770000) が割り当てられる |
| **イメージの期待** | cp-kafkaイメージは特定のUID (通常1000)で動作することを期待 |
| **ファイル権限** | `/var/lib/kafka/data` への書き込み権限がない |
| **起動失敗** | Kafkaプロセスが起動直後にクラッシュ |

---

## ✅ 解決策: Bitnamiイメージを使用

Bitnami KafkaイメージはOpenShiftの厳しいセキュリティ制約に対応しています。

### 特徴

- ✅ **非rootユーザーで動作**
- ✅ **ランダムUIDに対応**
- ✅ **KRaftモード対応**（Zookeeper不要）
- ✅ **OpenShift認定イメージ**

---

## 🚀 修正手順

### 方法1: 自動修正スクリプト（推奨）

```bash
# スクリプトを実行
bash /tmp/fix_kafka.sh
```

### 方法2: 手動修正

#### ステップ1: 既存のKafkaを削除

```bash
# Deploymentを削除
oc delete deployment kafka

# PVCを削除（データは失われます）
oc delete pvc kafka-data

# 完全に削除されるまで待つ
oc get pods -l app=kafka --watch
```

#### ステップ2: Bitnami版Kafkaをデプロイ

```bash
# 新しいマニフェストを適用
oc apply -f /Users/kjin/mobills/observability/demo/openshift/kafka/kafka-deployment-bitnami.yaml
```

#### ステップ3: 起動を確認

```bash
# Podが起動するまで待つ
oc get pods -l app=kafka --watch

# ログを確認
oc logs -f -l app=kafka
```

**期待されるログ**:
```
[2025-10-16 XX:XX:XX,XXX] INFO Kafka Server started (kafka.server.KafkaServer)
```

---

## 📋 新しいKafka設定の詳細

### Bitnami版の主な変更点

| 項目 | Confluent版 | Bitnami版 |
|-----|-------------|-----------|
| **イメージ** | `confluentinc/cp-kafka:7.5.0` | `bitnami/kafka:3.6.0` |
| **動作モード** | Zookeeperモード | KRaftモード（Zookeeper不要） |
| **データディレクトリ** | `/var/lib/kafka/data` | `/bitnami/kafka/data` |
| **実行ユーザー** | UID 1000（固定） | 任意のUID（OpenShift対応） |
| **OpenShift互換性** | ❌ | ✅ |

### KRaftモードとは？

**Kafka 3.0以降の新しいアーキテクチャ**

- Zookeeper不要で動作
- シンプルな構成
- より高速な起動
- 運用が容易

### 環境変数の説明

```yaml
# KRaftモード設定
KAFKA_CFG_NODE_ID: "1"                           # ノードID
KAFKA_CFG_PROCESS_ROLES: "broker,controller"    # ブローカー＋コントローラー
KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: "1@kafka:9093"  # クォーラム設定

# リスナー設定
KAFKA_CFG_LISTENERS: "PLAINTEXT://:9092,CONTROLLER://:9093"
KAFKA_CFG_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"

# 自動トピック作成
KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE: "true"

# レプリケーション（シングルノード用）
KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR: "1"
KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: "1"

# JVMヒープ
KAFKA_HEAP_OPTS: "-Xmx1024m -Xms512m"
```

---

## 🔍 トラブルシューティング

### Podが起動しない

```bash
# Podの詳細を確認
oc describe pod -l app=kafka

# ログを確認
oc logs -l app=kafka --tail=100

# イベントを確認
oc get events --sort-by='.lastTimestamp' | grep kafka
```

### メモリ不足

```bash
# リソースを確認
oc top pod -l app=kafka

# リソース制限を調整
oc set resources deployment/kafka \
  --requests=memory=1Gi,cpu=500m \
  --limits=memory=3Gi,cpu=2000m
```

### ストレージの問題

```bash
# PVCの状態を確認
oc get pvc kafka-data
oc describe pvc kafka-data

# PVの状態を確認
oc get pv
```

---

## ✅ 確認手順

### 1. Podが正常に起動しているか

```bash
oc get pods -l app=kafka

# 期待される出力:
# NAME                     READY   STATUS    RESTARTS   AGE
# kafka-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### 2. Kafkaが正常に動作しているか

```bash
# ログを確認
oc logs -l app=kafka --tail=50

# "Kafka Server started" が表示されればOK
```

### 3. トピックが作成されるか

```bash
# Kafkaコンテナに入る
oc exec -it deployment/kafka -- bash

# トピック一覧を確認
kafka-topics.sh --bootstrap-server localhost:9092 --list

# テストトピックを作成
kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test-topic --partitions 1 --replication-factor 1

# メッセージを送信
echo "test message" | kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test-topic

# メッセージを受信
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --max-messages 1
```

---

## 🔄 Zookeeperについて

### Zookeeperは削除可能？

**はい、削除可能です。** Bitnami版KafkaはKRaftモードで動作し、Zookeeperを必要としません。

```bash
# Zookeeperを削除する場合
oc delete deployment zookeeper
oc delete service zookeeper
oc delete pvc zookeeper-data
```

### Zookeeperを残す場合

特に問題はありませんが、使用されていないリソースとして残ります。

---

## 📊 Camel Appの設定更新

Kafkaの接続先は変更不要です（サービス名が同じため）。

```yaml
# application.yml
spring:
  kafka:
    bootstrap-servers: kafka:9092  # ← 変更不要
```

ただし、Camel Appが既にデプロイされている場合は、再起動が必要です。

```bash
# Camel Appを再起動
oc rollout restart deployment/camel-app

# 起動を確認
oc logs -f deployment/camel-app
```

---

## 🎯 まとめ

### 問題

- ❌ Confluentの `cp-kafka` イメージがOpenShiftのSCCと互換性がない
- ❌ ランダムUIDでの実行に失敗
- ❌ CrashLoopBackOff

### 解決策

- ✅ Bitnamiの `kafka:3.6.0` イメージに変更
- ✅ KRaftモードで動作（Zookeeper不要）
- ✅ OpenShiftの厳しいセキュリティ制約に対応

### 次のステップ

1. **修正スクリプトを実行**: `bash /tmp/fix_kafka.sh`
2. **Podの起動を確認**: `oc get pods -l app=kafka`
3. **Camel Appを再起動**: `oc rollout restart deployment/camel-app`
4. **動作確認**: トピックの作成とメッセージ送受信テスト

---

**これでKafkaが正常に動作するはずです！** 🎉


