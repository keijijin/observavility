# Camel App テストスクリプト - クイックスタート

## 🚀 すぐに使える！

```bash
cd /Users/kjin/mobills/observability/demo/openshift
./test_camel_app.sh
```

## 📋 スクリプトの概要

`test_camel_app.sh` は、OpenShift上のCamel Appを**12項目**で包括的にテストします。

### テスト項目

1. ✅ 前提条件の確認（oc, curl, jq）
2. ✅ Pod状態確認（Running, Ready）
3. ✅ Route確認（URL取得）
4. ✅ ヘルスチェック（/actuator/health）
5. ✅ アプリ情報（バージョン確認）
6. ✅ REST API テスト（3件の注文作成）
7. ✅ メトリクス確認（Prometheus）
8. ✅ TraceID確認（分散トレーシング）
9. ✅ エラーログ確認
10. ✅ Kafka接続確認（送受信）
11. ✅ 処理完了確認
12. ✅ リソース使用状況

---

## 🎨 出力例

```
========================================
1. 前提条件の確認
========================================
✅ ocコマンド: 利用可能
✅ curlコマンド: 利用可能
✅ jqコマンド: 利用可能
✅ OpenShift接続: admin
✅ 現在のプロジェクト: camel-observability-demo

========================================
2. Pod状態の確認
========================================
✅ camel-app Pod: camel-app-c58cb68dd-6q9d8
✅ Pod状態: Running
✅ Pod Ready: true
ℹ️  起動時間: 2025-10-16T09:05:16Z

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
  2. Grafana Explore でトレースを確認
  3. Grafana Explore でログを確認
```

---

## 📚 詳細ドキュメント

詳しい使い方は **TEST_SCRIPT_GUIDE.md** をご覧ください。

- カスタマイズ方法
- トラブルシューティング
- CI/CD統合
- ベストプラクティス

---

## 🎯 よくある使い方

### デプロイ後の確認

```bash
oc rollout status deployment/camel-app
./test_camel_app.sh
```

### 定期的な健全性チェック

```bash
# Cronで毎日実行
0 9 * * * cd /path/to/openshift && ./test_camel_app.sh >> /var/log/camel-test.log 2>&1
```

### ログファイルに保存

```bash
./test_camel_app.sh | tee test-results-$(date +%Y%m%d).log
```

---

## ✅ 作成完了！

テストスクリプトが準備できました。早速実行してみてください！

```bash
./test_camel_app.sh
```




