# 🎉 OpenShift デプロイメント成功！

## ✅ デプロイ完了

すべてのコンポーネントがOpenShift上で正常に動作しています。

---

## 📊 デプロイされたコンポーネント

| コンポーネント | 状態 | 用途 |
|--------------|------|------|
| **Kafka** | ✅ Running | メッセージキュー（KRaftモード） |
| **Camel App** | ✅ Running | Spring Boot + Camel統合アプリ |
| **Prometheus** | ✅ Running | メトリクス収集 |
| **Grafana** | ✅ Running | 可視化ダッシュボード |
| **Tempo** | ✅ Running | 分散トレーシング |
| **Loki** | ✅ Running | ログ集約 |
| **Zookeeper** | ✅ Running | （レガシー・削除可能） |

---

## 🔧 解決した問題

### 1. Kafka CrashLoopBackOff

**問題**:
- Confluentイメージ: OpenShift SCC非対応
- Red Hat AMQ Streams: Operator必須
- PVC `lost+found` ディレクトリとの競合
- ブローカー⇔コントローラー接続設定ミス

**解決策**:
- ✅ Strimziイメージを使用 (`quay.io/strimzi/kafka`)
- ✅ KRaftモード（Zookeeper不要）
- ✅ `lost+found` 自動削除
- ✅ Controller接続先を `localhost:9093` に変更
- ✅ `fsGroup` を削除（OpenShift自動設定）

### 2. Camel App ImagePullBackOff

**解決方法**: Binary Buildを使用してローカルJARをアップロード

---

## 🚀 アクセス方法

### Grafana（可視化）

```bash
# URLを取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana: https://${GRAFANA_URL}"

# ブラウザでアクセス
# デフォルト認証: admin / admin
```

### Camel App（REST API）

```bash
# URLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
echo "Camel App: https://${CAMEL_URL}"

# ヘルスチェック
curl -k "https://${CAMEL_URL}/actuator/health"

# 注文作成（Kafkaへメッセージ送信）
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","product":"商品A","quantity":10}'
```

### Prometheus（メトリクス）

```bash
# URLを取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
echo "Prometheus: https://${PROMETHEUS_URL}"
```

---

## 📋 動作確認

### 1. すべてのPodが正常か

```bash
oc get pods

# 期待される出力:
# NAME                          READY   STATUS    RESTARTS   AGE
# camel-app-xxx                 1/1     Running   0          Xm
# grafana-xxx                   1/1     Running   0          Xm
# kafka-xxx                     1/1     Running   0          Xm
# loki-xxx                      1/1     Running   0          Xm
# prometheus-xxx                1/1     Running   0          Xm
# tempo-xxx                     1/1     Running   0          Xm
```

### 2. Kafkaが正常に動作しているか

```bash
# Kafkaコンテナに入る
oc exec -it deployment/kafka -- bash

# トピック一覧を確認
kafka-topics.sh --bootstrap-server localhost:9092 --list

# "orders" トピックが自動作成されているはず
```

### 3. Camel AppからKafkaにメッセージ送信

```bash
# Camel AppのURLを取得
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')

# 注文を作成
curl -k -X POST "https://${CAMEL_URL}/camel/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","product":"商品A","quantity":10}'
```

### 4. Grafanaでメトリクス確認

```bash
# Grafanaにアクセス
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
open "https://${GRAFANA_URL}"

# Explore > Prometheus で以下のクエリを実行:
rate(http_server_requests_seconds_count{application="camel-observability-demo"}[1m])
```

### 5. Tempoでトレース確認

```bash
# Grafana > Explore > Tempo
# Search でトレース一覧を表示
```

### 6. Lokiでログ確認

```bash
# Grafana > Explore > Loki
# 以下のクエリでログを表示:
{app="camel-observability-demo"}
```

---

## 🗑️ Zookeeperの削除（オプション）

KafkaがKRaftモードで動作しているため、Zookeeperは不要です。

```bash
# Zookeeperを削除
oc delete deployment zookeeper
oc delete service zookeeper
oc delete pvc zookeeper-data

# 削除後も問題なく動作します
```

---

## 📚 参考ドキュメント

| ドキュメント | 説明 |
|------------|------|
| **QUICKSTART.md** | クイックスタートガイド |
| **FIX_DEPLOYMENT.md** | デプロイメント修正ガイド |
| **KAFKA_FIX.md** | Kafka問題の修正履歴 |
| **S2I_BUILD_GUIDE.md** | S2Iビルドガイド |
| **BUILD_FOR_OPENSHIFT.md** | OpenShift用ビルドガイド |

---

## 🔄 メンテナンス

### アプリケーションの更新

```bash
# ソースコードを更新後、再ビルド
cd /Users/kjin/mobills/observability/demo/camel-app
mvn clean package -DskipTests

# OpenShiftで再ビルド
oc start-build camel-app --from-file=target/camel-observability-demo-1.0.0.jar --follow

# デプロイメントを再起動
oc rollout restart deployment/camel-app
```

### ログの確認

```bash
# 特定のコンポーネントのログ
oc logs -f deployment/camel-app
oc logs -f deployment/kafka
oc logs -f deployment/grafana

# すべてのログ
oc logs -f -l app=camel-observability-demo
```

### リソースのスケーリング

```bash
# Kafkaのリソースを増やす
oc set resources deployment/kafka \
  --requests=memory=2Gi,cpu=1000m \
  --limits=memory=4Gi,cpu=2000m

# Camel Appをスケールアウト
oc scale deployment/camel-app --replicas=3
```

---

## 🚨 トラブルシューティング

### Podが起動しない

```bash
# Podの詳細を確認
oc describe pod <POD_NAME>

# ログを確認
oc logs <POD_NAME>

# 前回のログを確認（クラッシュした場合）
oc logs <POD_NAME> --previous
```

### Kafkaに接続できない

```bash
# Kafkaのログを確認
oc logs deployment/kafka --tail=100

# Kafkaサービスを確認
oc get svc kafka

# Kafkaに接続テスト
oc exec -it deployment/camel-app -- curl -v telnet://kafka:9092
```

### Grafanaでデータが表示されない

```bash
# Prometheusが正常にスクレイプしているか確認
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
curl -k "https://${PROMETHEUS_URL}/api/v1/targets"

# Camel Appのメトリクスエンドポイントを確認
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}')
curl -k "https://${CAMEL_URL}/actuator/prometheus"
```

---

## 🎯 次のステップ

1. ✅ **カスタムダッシュボードの作成**: Grafanaで独自のダッシュボードを作成
2. ✅ **アラート設定**: Prometheusのアラートルールを追加
3. ✅ **本番環境への展開**: リソース制限、永続化、バックアップ設定
4. ✅ **CI/CDパイプラインの構築**: Jenkins/Tektonでの自動デプロイ
5. ✅ **セキュリティ強化**: TLS、認証、ネットワークポリシー

---

**OpenShiftへのデプロイ完了！オブザーバビリティを体験してください！** 🎉




