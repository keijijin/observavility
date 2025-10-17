# Camel App テストスクリプト 利用ガイド

## 📋 概要

`test_camel_app.sh` は、OpenShift上にデプロイされたCamel Appの動作を包括的にテストする自動化スクリプトです。

## 🎯 テスト項目

このスクリプトは以下の12項目をテストします：

1. **前提条件の確認**
   - `oc` コマンドの存在確認
   - `curl` コマンドの存在確認
   - `jq` コマンドの存在確認（オプション）
   - OpenShift接続確認
   - プロジェクト確認

2. **Pod状態の確認**
   - camel-app Podの存在確認
   - Pod状態（Running）
   - Ready状態
   - 起動時間

3. **Routeの確認**
   - camel-app RouteのURL取得

4. **ヘルスチェック**
   - `/actuator/health` エンドポイント
   - アプリケーションステータス（UP/DOWN）

5. **アプリケーション情報の確認**
   - `/actuator/info` エンドポイント
   - バージョン情報（App, Camel, Spring Boot）

6. **REST API テスト**
   - `/camel/api/orders` (POST) エンドポイント
   - 3件の注文を作成して動作確認

7. **メトリクス確認**
   - `/actuator/prometheus` エンドポイント
   - メトリクス数の確認
   - 主要メトリクスのサンプル表示

8. **トレースID確認**
   - ログからTraceIDの生成を確認

9. **エラーログ確認**
   - 最近のエラーログをチェック

10. **Kafka接続確認**
    - Kafka送信ログの確認
    - Kafka受信ログの確認

11. **処理完了確認**
    - オーダー処理完了ログの確認

12. **リソース使用状況**
    - Pod CPU/メモリ使用量（メトリクスサーバーが必要）

---

## 🚀 使い方

### 基本的な使い方

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./test_camel_app.sh
```

### 事前準備

1. **OpenShiftにログイン**
   ```bash
   oc login <your-openshift-cluster>
   ```

2. **プロジェクトを選択**
   ```bash
   oc project camel-observability-demo
   ```

3. **テストスクリプトを実行**
   ```bash
   ./test_camel_app.sh
   ```

---

## 📊 出力例

### 成功時の出力

```
========================================
1. 前提条件の確認
========================================
✅ ocコマンド: 利用可能
✅ curlコマンド: 利用可能
✅ jqコマンド: 利用可能
✅ OpenShift接続: your-user
✅ 現在のプロジェクト: camel-observability-demo

========================================
2. Pod状態の確認
========================================
✅ camel-app Pod: camel-app-c58cb68dd-6q9d8
✅ Pod状態: Running
✅ Pod Ready: true
ℹ️  起動時間: 2025-10-16T09:04:29Z

========================================
3. Routeの確認
========================================
✅ Camel App URL: https://camel-app-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io

========================================
4. ヘルスチェック
========================================
✅ ヘルスチェック: HTTP 200
✅ アプリケーションステータス: UP
{
  "status": "UP",
  "components": {
    "camelHealth": {
      "status": "UP"
    }
  }
}

...

========================================
テスト結果サマリー
========================================

合計テスト数: 15
成功: 15
失敗: 0

🎉 すべてのテストが成功しました！

次のステップ:
  1. Grafana でダッシュボードを確認
     https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io

  2. Grafana Explore でトレースを確認
     データソース: Tempo

  3. Grafana Explore でログを確認
     データソース: Loki
     クエリ: {app="camel-observability-demo"}
```

### 失敗時の出力

```
========================================
4. ヘルスチェック
========================================
❌ ヘルスチェック失敗: HTTP 503
{
  "status": "DOWN"
}

========================================
テスト結果サマリー
========================================

合計テスト数: 15
成功: 12
失敗: 3

❌ いくつかのテストが失敗しました。

トラブルシューティング:
  1. Podログを確認: oc logs camel-app-xxx
  2. Pod詳細を確認: oc describe pod camel-app-xxx
  3. イベントを確認: oc get events --sort-by='.lastTimestamp'
```

---

## 🎨 色付き出力

スクリプトは以下の色分けで結果を表示します：

- 🟢 **緑色** (`✅`): 成功
- 🔴 **赤色** (`❌`): 失敗
- 🟡 **黄色** (`⚠️`): 警告
- 🔵 **青色** (`ℹ️`): 情報

---

## 🔧 トラブルシューティング

### エラー: `ocコマンドが見つかりません`

**原因**: OpenShift CLIがインストールされていない

**解決方法**:
```bash
# macOS
brew install openshift-cli

# Linux
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
```

### エラー: `OpenShiftに接続できません`

**原因**: OpenShiftにログインしていない

**解決方法**:
```bash
oc login <your-openshift-cluster>
```

### エラー: `camel-app Podが見つかりません`

**原因**: Podが起動していない、またはプロジェクトが間違っている

**解決方法**:
```bash
# プロジェクトを確認
oc project

# 正しいプロジェクトに切り替え
oc project camel-observability-demo

# Podの状態を確認
oc get pods
```

### 警告: `jqコマンドがありません`

**影響**: JSON出力の整形ができない（機能的な問題はない）

**解決方法（オプション）**:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # RHEL/CentOS
```

### エラー: `メトリクスサーバーが利用できません`

**影響**: リソース使用状況が表示されない（テストは続行される）

**原因**: OpenShiftのメトリクスサーバーが無効または利用できない

**対処**: 管理者に確認するか、このテスト項目はスキップ

---

## 🔄 自動化・CI/CD統合

### Jenkins統合

```groovy
stage('Test Camel App') {
    steps {
        sh '''
            oc login --token=${OPENSHIFT_TOKEN} --server=${OPENSHIFT_SERVER}
            oc project camel-observability-demo
            cd openshift
            ./test_camel_app.sh
        '''
    }
}
```

### GitLab CI統合

```yaml
test-camel-app:
  stage: test
  script:
    - oc login --token=${OPENSHIFT_TOKEN} --server=${OPENSHIFT_SERVER}
    - oc project camel-observability-demo
    - cd openshift
    - ./test_camel_app.sh
  only:
    - main
```

### Cron定期実行

```bash
# 毎日午前9時に実行
0 9 * * * cd /path/to/observability/demo/openshift && ./test_camel_app.sh >> /var/log/camel-app-test.log 2>&1
```

---

## 📝 カスタマイズ

### テスト項目の追加

スクリプトの最後に新しいテスト項目を追加できます：

```bash
###############################################################################
# 13. カスタムテスト
###############################################################################
print_header "13. カスタムテスト"

# ここにカスタムテストロジックを追加
if [ "条件" ]; then
    print_success "カスタムテスト成功"
else
    print_error "カスタムテスト失敗"
fi
```

### 注文作成数の変更

デフォルトでは3件の注文を作成しますが、変更可能です：

```bash
# 6行目: REST API テストのforループを変更
for i in {1..10}; do  # 3から10に変更
    # ...
done
```

### タイムアウトの設定

curlコマンドにタイムアウトを追加：

```bash
HEALTH_RESPONSE=$(curl -k -s -w "\n%{http_code}" --max-time 10 \
    "https://$CAMEL_URL/actuator/health" 2>/dev/null || echo "")
```

---

## 📚 関連ドキュメント

- **QUICKTEST.md** - 5分クイックテスト（手動）
- **TEST_GUIDE.md** - 詳細テスト手順（手動）
- **OPENSHIFT_DEPLOYMENT_GUIDE.md** - デプロイ手順
- **FINAL_STATUS.md** - 最終ステータス・完全版

---

## 🎯 ベストプラクティス

### 1. デプロイ後の確認

新しいバージョンをデプロイした後、必ずテストスクリプトを実行：

```bash
oc rollout status deployment/camel-app
./test_camel_app.sh
```

### 2. 定期的な健全性チェック

定期的（毎日/毎週）にテストを実行してシステムの健全性を確認

### 3. CI/CDパイプラインに統合

デプロイパイプラインの一部としてテストスクリプトを実行

### 4. ログの保存

テスト結果をログファイルに保存して履歴管理：

```bash
./test_camel_app.sh | tee test-results-$(date +%Y%m%d-%H%M%S).log
```

### 5. アラート連携

テストが失敗した場合、Slackやメールで通知：

```bash
./test_camel_app.sh || send_alert "Camel App テスト失敗"
```

---

## 🎊 まとめ

`test_camel_app.sh` は、OpenShift上のCamel Appの動作を包括的にテストする強力なツールです。

**主な利点**:
- ✅ 12項目の包括的なテスト
- ✅ 色付きの分かりやすい出力
- ✅ 自動化・CI/CD統合が容易
- ✅ カスタマイズ可能
- ✅ トラブルシューティング情報を提供

**推奨される使用タイミング**:
- デプロイ直後の確認
- 定期的な健全性チェック
- 問題発生時の診断
- CI/CDパイプラインの一部として

お疲れ様でした！ 🎉


