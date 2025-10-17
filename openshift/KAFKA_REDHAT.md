# 🎩 Red Hat Kafka (AMQ Streams) デプロイメントガイド

## 🔍 Red Hat AMQ Streamsとは

**Red HatのエンタープライズKafkaディストリビューション**

- ✅ **OpenShift完全対応**: OpenShiftの厳しいセキュリティ要件に準拠
- ✅ **商用サポート**: Red Hatの24/7サポート
- ✅ **Strimziベース**: Cloud Native Kafkaオペレーター
- ✅ **KRaftモード対応**: Zookeeper不要
- ✅ **エンタープライズ認定**: 本番環境での使用が保証

---

## 🆚 イメージの比較

| イメージ | OpenShift対応 | 商用サポート | KRaft対応 | 推奨度 |
|---------|--------------|------------|----------|--------|
| **Red Hat AMQ Streams** | ✅ 完全対応 | ✅ あり | ✅ | ⭐⭐⭐⭐⭐ |
| Bitnami Kafka | ✅ 対応 | ❌ なし | ✅ | ⭐⭐⭐⭐ |
| Confluent cp-kafka | ❌ 非対応 | ⚠️ 別途契約 | ✅ | ⭐⭐ |

---

## 🚀 デプロイ手順

### 方法1: 自動スクリプト（推奨）

```bash
# スクリプトを実行
bash /tmp/fix_kafka_redhat.sh
```

このスクリプトは以下を自動実行します：

1. ✅ 既存のKafkaとPVCを削除
2. ✅ Red Hat AMQ Streams Kafkaをデプロイ
3. ✅ 起動を確認
4. ✅ ログを表示

---

### 方法2: 手動デプロイ

#### ステップ1: 既存リソースを削除

```bash
# 既存のKafkaを削除
oc delete deployment kafka
oc delete pvc kafka-data

# 完全に削除されるまで待つ
oc get pods -l app=kafka --watch
```

#### ステップ2: Red Hat版をデプロイ

```bash
# マニフェストを適用
oc apply -f /Users/kjin/mobills/observability/demo/openshift/kafka/kafka-deployment-redhat.yaml
```

#### ステップ3: 起動を確認

```bash
# Podの状態を監視
oc get pods -l app=kafka --watch

# ログをリアルタイム表示
oc logs -f -l app=kafka
```

**期待されるログ**:
```
[2025-10-16 XX:XX:XX,XXX] INFO [KafkaServer id=1] started (kafka.server.KafkaServer)
```

---

## 📋 イメージの詳細

### Red Hat AMQ Streams Kafka

```yaml
image: registry.redhat.io/amq-streams/kafka-36-rhel8:2.6.0
```

**バージョン情報**:
- **AMQ Streams**: 2.6.0
- **Kafka**: 3.6.x
- **ベースOS**: Red Hat Enterprise Linux 8

### 主な機能

| 機能 | 説明 |
|------|------|
| **KRaftモード** | Zookeeper不要の軽量アーキテクチャ |
| **非rootコンテナ** | OpenShiftのSCC準拠 |
| **ランダムUID対応** | 任意のUIDで実行可能 |
| **FIPS対応** | 政府機関・金融機関での使用可能 |
| **CVE対応** | セキュリティパッチの迅速な提供 |

---

## 🔧 設定の詳細

### 環境変数

```yaml
# KRaftモード（必須）
KAFKA_NODE_ID: "1"
KAFKA_PROCESS_ROLES: "broker,controller"
KAFKA_CONTROLLER_QUORUM_VOTERS: "1@kafka:9093"
KAFKA_CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"  # 固定のクラスターID

# リスナー
KAFKA_LISTENERS: "PLAINTEXT://:9092,CONTROLLER://:9093"
KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"

# レプリケーション（シングルノード用）
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: "1"
KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: "1"
KAFKA_DEFAULT_REPLICATION_FACTOR: "1"

# 自動トピック作成
KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"

# JVMヒープ
KAFKA_HEAP_OPTS: "-Xmx1g -Xms512m"
```

### リソース設定

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### ストレージ

```yaml
volumeMounts:
  - name: kafka-data
    mountPath: /var/lib/kafka/data  # Red Hat標準のデータディレクトリ

persistentVolumeClaim:
  claimName: kafka-data
  storage: 10Gi
```

---

## ✅ 動作確認

### 1. Podが正常に起動しているか

```bash
oc get pods -l app=kafka

# 期待される出力:
# NAME                     READY   STATUS    RESTARTS   AGE
# kafka-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### 2. ログを確認

```bash
oc logs -l app=kafka --tail=50

# "Kafka Server started" が表示されればOK
```

### 3. トピックの作成とテスト

```bash
# Kafkaコンテナに入る
oc exec -it deployment/kafka -- bash

# トピック一覧を確認
kafka-topics.sh --bootstrap-server localhost:9092 --list

# テストトピックを作成
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create \
  --topic test-topic \
  --partitions 1 \
  --replication-factor 1

# メッセージを送信
echo "Hello from Red Hat Kafka" | kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# メッセージを受信
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning \
  --max-messages 1
```

---

## 🔐 セキュリティ

### Security Context Constraints (SCC)

Red Hat Kafkaは `restricted-v2` SCCで動作します：

```yaml
# 自動的に適用される設定
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

### ネットワークポリシー（オプション）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kafka-network-policy
spec:
  podSelector:
    matchLabels:
      app: kafka
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: camel-app
      ports:
        - protocol: TCP
          port: 9092
```

---

## 🚨 トラブルシューティング

### イメージのPullに失敗する

```bash
# エラー:
Failed to pull image "registry.redhat.io/...": unauthorized
```

**原因**: Red Hatレジストリの認証が必要

**解決策**:

```bash
# Red Hatアカウントでログイン
podman login registry.redhat.io
Username: YOUR_RED_HAT_USERNAME
Password: YOUR_RED_HAT_PASSWORD

# シークレットを作成
oc create secret docker-registry redhat-registry \
  --docker-server=registry.redhat.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=YOUR_EMAIL

# サービスアカウントにシークレットをリンク
oc secrets link default redhat-registry --for=pull
```

### Podが起動しない

```bash
# Podの詳細を確認
oc describe pod -l app=kafka

# ログを確認
oc logs -l app=kafka --tail=100

# イベントを確認
oc get events --sort-by='.lastTimestamp' | grep kafka
```

### メモリ不足（OOMKilled）

```bash
# リソースを増やす
oc set resources deployment/kafka \
  --requests=memory=2Gi,cpu=1000m \
  --limits=memory=4Gi,cpu=2000m

# JVMヒープも調整
oc set env deployment/kafka KAFKA_HEAP_OPTS="-Xmx2g -Xms1g"
```

---

## 📊 Camel Appとの統合

### 接続設定

Kafkaの接続先は変更不要です（サービス名が同じため）：

```yaml
# application.yml
spring:
  kafka:
    bootstrap-servers: kafka:9092  # ← 変更不要
```

### Camel Appの再起動

Kafkaを再デプロイした後、Camel Appを再起動します：

```bash
# Camel Appを再起動
oc rollout restart deployment/camel-app

# 起動を確認
oc logs -f deployment/camel-app

# "orders" トピックが自動作成されることを確認
oc exec deployment/kafka -- kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

---

## 🔄 Strimzi Operatorの使用（推奨・本番環境）

より高度な管理が必要な場合、**Strimzi Operator**の使用を推奨します。

### Operatorのインストール

```bash
# OpenShift OperatorHub から AMQ Streams をインストール
# Web UI: Operators > OperatorHub > "Red Hat Integration - AMQ Streams"
```

### Kafka CRでのデプロイ

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: camel-kafka-cluster
spec:
  kafka:
    version: 3.6.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
    storage:
      type: persistent-claim
      size: 10Gi
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

**メリット**:
- 自動スケーリング
- ローリングアップデート
- トピック・ユーザー管理の自動化
- メトリクス自動収集

---

## 🎯 まとめ

### Red Hat AMQ Streamsの利点

| 項目 | 利点 |
|------|------|
| **OpenShift統合** | 完全なネイティブサポート |
| **セキュリティ** | FIPS対応、CVE対応 |
| **サポート** | Red Hatの24/7商用サポート |
| **安定性** | エンタープライズグレードの品質 |
| **コンプライアンス** | 各種認証取得済み |

### 次のステップ

1. **デプロイ**: `bash /tmp/fix_kafka_redhat.sh`
2. **確認**: `oc get pods -l app=kafka`
3. **テスト**: トピック作成とメッセージ送受信
4. **統合**: Camel Appを再起動

---

## 📚 参考リンク

- [Red Hat AMQ Streams Documentation](https://access.redhat.com/documentation/en-us/red_hat_amq_streams/)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [Kafka on OpenShift Best Practices](https://www.redhat.com/en/topics/integration/what-is-apache-kafka)

---

**Red Hat Kafkaで安全で信頼性の高いメッセージング環境を構築しましょう！** 🎩🚀


