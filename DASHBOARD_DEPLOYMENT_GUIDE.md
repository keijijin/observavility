# 📊 統合ダッシュボード デプロイガイド

統合版Grafanaダッシュボードをローカル環境とOpenShift環境にデプロイする手順です。

## 📁 ダッシュボードファイルの場所

統合ダッシュボードは以下の場所に配置されています：

```
demo/docker/grafana/provisioning/dashboards/
├── camel-comprehensive-dashboard.json  # 統合版ダッシュボード（メイン）
├── DASHBOARD_README.md                 # ダッシュボード詳細ドキュメント
├── DASHBOARD_QUICKSTART.md             # クイックスタートガイド
├── alerts-overview-dashboard.json      # アラート監視用
├── camel-dashboard.json                # シンプル版（参考）
└── undertow-monitoring-panels.json     # Undertow専用（参考）
```

## 🏠 ローカル版へのデプロイ

### 前提条件

- Docker Composeが起動している
- `docker-compose.yml`でGrafanaが設定されている

### デプロイ手順

ダッシュボードファイルは既に適切な場所に配置されているため、Grafanaを再起動するだけで自動的に反映されます。

#### 方法1: Grafanaコンテナのみ再起動（推奨）

```bash
cd demo
# podman-composeを使用
podman-compose restart grafana
# または podman compose プラグインを使用
podman compose restart grafana
```

#### 方法2: 全コンテナを再起動（推奨）

```bash
cd demo
./stop-demo.sh
./start-demo.sh
```

### 確認方法

1. ブラウザでGrafanaにアクセス
   ```
   http://localhost:3000
   ```

2. ログイン
   - ユーザー名: `admin`
   - パスワード: `admin`

3. ダッシュボード一覧を確認
   - 左メニューの「Dashboards」をクリック
   - **「Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード」** が表示されることを確認

4. ダッシュボードを開いて各セクションを確認
   - ✅ システム概要
   - ⚡ パフォーマンス指標
   - 📊 Camel Routes
   - 🔍 分散トレーシング
   - 📝 ログ分析
   - 🚀 Undertow Webサーバー
   - 📨 Kafka メッセージング
   - 📊 メッセージフロー全体

### トラブルシューティング

**ダッシュボードが表示されない場合：**

```bash
# Grafanaコンテナのログを確認
podman logs grafana

# ダッシュボードファイルが正しくマウントされているか確認
podman exec grafana ls -la /etc/grafana/provisioning/dashboards/

# Grafanaコンテナを完全に再作成
podman-compose stop grafana
podman-compose rm -f grafana
podman-compose up -d grafana
```

## ☁️ OpenShift版へのデプロイ

### 前提条件

- OpenShiftクラスターに接続されている
- `camel-observability-demo`プロジェクトが存在する
- Grafanaがデプロイされている

### デプロイ手順

#### 自動デプロイ（推奨）

専用のスクリプトを使用して自動的にデプロイします：

```bash
cd demo/openshift
./UPDATE_DASHBOARD.sh
```

このスクリプトは以下の処理を実行します：
1. ローカルのダッシュボードファイルを読み込み
2. ConfigMapを作成/更新
3. Grafana Podを再起動
4. Grafana URLを表示

#### 手動デプロイ

手動でデプロイする場合：

```bash
cd demo/openshift

# 1. ConfigMapを作成/更新（openshiftディレクトリから実行）
oc create configmap grafana-dashboards \
    --from-file=camel-comprehensive-dashboard.json=../docker/grafana/provisioning/dashboards/camel-comprehensive-dashboard.json \
    --dry-run=client -o yaml | oc apply -f -

# 2. Grafana Podを再起動
oc rollout restart deployment/grafana

# 3. 再起動の完了を待機
oc rollout status deployment/grafana

# 4. Grafana URLを取得
echo "Grafana URL: https://$(oc get route grafana -o jsonpath='{.spec.host}')"
```

### 確認方法

1. Grafana URLを取得
   ```bash
   oc get route grafana -o jsonpath='{.spec.host}'
   ```

2. ブラウザでGrafanaにアクセス
   ```
   https://<grafana-route-host>
   ```

3. OpenShiftの認証情報でログイン

4. ダッシュボード一覧を確認
   - 左メニューの「Dashboards」をクリック
   - **「Camel + Kafka + SpringBoot 分散アプリケーション ダッシュボード」** が表示されることを確認

### トラブルシューティング

**ConfigMapが反映されない場合：**

```bash
# ConfigMapの内容を確認
oc get configmap grafana-dashboards -o yaml

# Grafana Podのログを確認
oc logs deployment/grafana

# Grafana Podを強制再起動
oc delete pod -l app=grafana
```

**ダッシュボードが空の場合：**

```bash
# データソースの接続を確認
oc get pods -l app=prometheus
oc get pods -l app=loki
oc get pods -l app=tempo

# Grafana内でデータソースの設定を確認
# Configuration > Data sources > Prometheus/Loki/Tempo
```

## 📚 関連ドキュメント

- **ダッシュボード詳細**: `docker/grafana/provisioning/dashboards/DASHBOARD_README.md`
- **クイックスタート**: `docker/grafana/provisioning/dashboards/DASHBOARD_QUICKSTART.md`
- **お客様向けパッケージ**: `GRAFANA_DASHBOARD_PACKAGE.md`
- **Grafana設定ガイド**: `GRAFANA_SETUP.md`
- **アラート設定**: `GRAFANA_ALERTS_GUIDE.md`

## 🎯 次のステップ

1. **ダッシュボードのカスタマイズ**
   - パネルの配置を調整
   - しきい値の変更
   - 新しいパネルの追加

2. **アラートの設定**
   - 重要なメトリクスにアラートルールを追加
   - 通知チャネルの設定

3. **チームへの共有**
   - ダッシュボードURLを共有
   - 操作方法のトレーニング

## 💡 ヒント

- **バックアップ**: ダッシュボードを変更する前に、JSONファイルをバックアップしておくことをおすすめします
- **バージョン管理**: ダッシュボードのJSONファイルをGitで管理することで、変更履歴を追跡できます
- **テンプレート変数**: ダッシュボードにテンプレート変数を追加することで、複数の環境やアプリケーションに対応できます

## ❓ よくある質問

**Q: ダッシュボードを更新したのに変更が反映されない**

A: ブラウザのキャッシュをクリアするか、Grafanaを再起動してください。

**Q: 一部のパネルにデータが表示されない**

A: データソース（Prometheus/Loki/Tempo）が正しく動作しているか、アプリケーションがメトリクス/ログ/トレースを送信しているか確認してください。

**Q: OpenShift版とローカル版でメトリクス名が異なる**

A: アプリケーションの設定（`application.yml`）で`management.metrics.tags.application`が正しく設定されているか確認してください。

---

**作成日**: 2025-10-22
**最終更新**: 2025-10-22

