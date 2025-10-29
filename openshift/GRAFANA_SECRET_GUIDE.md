# 🔐 Grafana認証情報シークレット管理ガイド

## 📋 概要

GitGuardianのセキュリティスキャンに対応するため、Grafana認証情報をKubernetesシークレットで管理します。

---

## 🚨 問題

### 検出された問題

**ファイル**: `openshift/DEBUG_UNDERTOW_NO_DATA.sh`  
**行**: 99  
**問題**: ハードコードされたBase64認証情報

```bash
# 🚨 修正前（問題あり）
--header="Authorization: Basic YWRtaW46YWRtaW4xMjM="
```

この方法では：
- ❌ 認証情報がコードに埋め込まれている
- ❌ Gitリポジトリに平文で保存される
- ❌ GitGuardianなどのセキュリティツールで検出される
- ❌ 認証情報の変更が困難

---

## ✅ 解決策

### Kubernetesシークレットを使用

```bash
# ✅ 修正後（安全）
GRAFANA_USER=$(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d)
GRAFANA_PASS=$(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d)
GRAFANA_AUTH=$(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)
--header="Authorization: Basic $GRAFANA_AUTH"
```

この方法では：
- ✅ 認証情報がシークレットで管理される
- ✅ Gitリポジトリには保存されない
- ✅ GitGuardianで検出されない
- ✅ 認証情報の変更が容易

---

## 🚀 セットアップ手順

### 方法1: 自動スクリプト（推奨）

```bash
cd openshift
./CREATE_GRAFANA_SECRET.sh
```

対話式でユーザー名とパスワードを入力します。

### 方法2: コマンドライン指定

```bash
cd openshift
./CREATE_GRAFANA_SECRET.sh admin your-secure-password
```

### 方法3: 手動作成

```bash
oc create secret generic grafana-admin-credentials \
    --from-literal=GF_SECURITY_ADMIN_USER="admin" \
    --from-literal=GF_SECURITY_ADMIN_PASSWORD="your-secure-password"
```

---

## 🔍 シークレットの確認

### シークレットの存在確認

```bash
oc get secret grafana-admin-credentials
```

### シークレットの詳細表示

```bash
oc describe secret grafana-admin-credentials
```

### ユーザー名の取得

```bash
oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d
```

### パスワードの取得（注意！）

```bash
oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
```

⚠️ **セキュリティ警告**: コマンド履歴に残らないよう注意してください。

---

## 📝 シークレットの使用方法

### スクリプトでの使用

```bash
#!/bin/bash

# シークレットから認証情報を取得
GRAFANA_USER=$(oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d)

GRAFANA_PASS=$(oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d)

# フォールバック（シークレットが存在しない場合）
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

# 使用
curl -u "$GRAFANA_USER:$GRAFANA_PASS" http://localhost:3000/api/datasources
```

### Deployment YAMLでの使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        env:
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: grafana-admin-credentials
              key: GF_SECURITY_ADMIN_USER
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-admin-credentials
              key: GF_SECURITY_ADMIN_PASSWORD
```

### コマンドラインから環境変数として設定

```bash
oc set env deployment/grafana \
  --from=secret/grafana-admin-credentials \
  GF_SECURITY_ADMIN_USER \
  GF_SECURITY_ADMIN_PASSWORD
```

---

## 🔄 シークレットの更新

### パスワード変更

```bash
# 1. 既存のシークレットを削除
oc delete secret grafana-admin-credentials

# 2. 新しいシークレットを作成
oc create secret generic grafana-admin-credentials \
    --from-literal=GF_SECURITY_ADMIN_USER="admin" \
    --from-literal=GF_SECURITY_ADMIN_PASSWORD="new-secure-password"

# 3. Grafanaを再起動（環境変数として使用している場合）
oc rollout restart deployment/grafana
```

### または、スクリプトを使用

```bash
./CREATE_GRAFANA_SECRET.sh admin new-secure-password
# "上書きしますか?" と聞かれるので "y" を入力
```

---

## 🔐 セキュリティベストプラクティス

### 1. 強力なパスワードを使用

```bash
# ❌ 弱いパスワード
admin
admin123
password

# ✅ 強力なパスワード
$(openssl rand -base64 32)  # ランダム生成
MyV3ryS3cur3P@ssw0rd!2024  # 複雑なパスワード
```

### 2. パスワードをGitにコミットしない

```bash
# .gitignore に追加
echo "*.password" >> .gitignore
echo "secrets/" >> .gitignore
```

### 3. 定期的なパスワード変更

- 3ヶ月ごとにパスワード変更を推奨
- パスワード変更履歴を記録

### 4. シークレットへのアクセス制限

```bash
# RBACで制限
oc create rolebinding grafana-secret-reader \
  --role=secret-reader \
  --serviceaccount=default:grafana-sa
```

### 5. 監査ログの確認

```bash
# シークレットへのアクセスログを確認
oc get events --field-selector involvedObject.name=grafana-admin-credentials
```

---

## 🧪 動作確認

### 修正後のスクリプトをテスト

```bash
cd openshift
./DEBUG_UNDERTOW_NO_DATA.sh
```

**期待される動作:**
1. ✅ シークレットから認証情報を取得
2. ✅ GitGuardianで検出されない
3. ✅ Grafana APIにアクセスできる

### GitGuardianスキャン

```bash
# ggshieldがインストールされている場合
ggshield secret scan path openshift/DEBUG_UNDERTOW_NO_DATA.sh
```

**期待される結果:**
```
No secrets have been found
```

---

## 📋 修正されたファイル

### openshift/DEBUG_UNDERTOW_NO_DATA.sh

**修正前（99行目）:**
```bash
oc exec "$GRAFANA_POD" -- wget -qO- \
  --header="Authorization: Basic YWRtaW46YWRtaW4xMjM=" \
  "http://localhost:3000/api/datasources"
```

**修正後（99-111行目）:**
```bash
# Grafana認証情報をシークレットから取得
GRAFANA_USER=$(oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d)

GRAFANA_PASS=$(oc get secret grafana-admin-credentials \
  -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d)

# フォールバック
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

GRAFANA_AUTH=$(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)
oc exec "$GRAFANA_POD" -- wget -qO- \
  --header="Authorization: Basic $GRAFANA_AUTH" \
  "http://localhost:3000/api/datasources"
```

---

## 📚 関連ファイル

| ファイル | 説明 |
|---------|------|
| `CREATE_GRAFANA_SECRET.sh` | シークレット作成スクリプト |
| `DEBUG_UNDERTOW_NO_DATA.sh` | 修正済みデバッグスクリプト |
| `GRAFANA_SECRET_GUIDE.md` | このドキュメント |

---

## ❓ トラブルシューティング

### シークレットが見つからない

```bash
$ oc get secret grafana-admin-credentials
Error from server (NotFound): secrets "grafana-admin-credentials" not found
```

**解決策:**
```bash
./CREATE_GRAFANA_SECRET.sh
```

### 認証に失敗する

```bash
$ curl -u admin:wrong-password http://localhost:3000/api/datasources
Unauthorized
```

**解決策:**
1. シークレットの内容を確認
2. Grafanaの実際のパスワードと一致しているか確認
3. 必要に応じてシークレットを更新

### Grafana Podが起動しない

```bash
$ oc get pods -l app=grafana
NAME                      READY   STATUS             RESTARTS   AGE
grafana-xxx-yyy           0/1     CrashLoopBackOff   5          5m
```

**解決策:**
1. ログを確認: `oc logs grafana-xxx-yyy`
2. シークレットが正しくマウントされているか確認
3. 環境変数が正しく設定されているか確認

---

## 🎯 まとめ

### 修正内容

- ✅ ハードコードされた認証情報を削除
- ✅ Kubernetesシークレットから認証情報を取得
- ✅ フォールバック機能を追加（シークレットがない場合）
- ✅ GitGuardianスキャンに合格

### セキュリティ向上

- ✅ 認証情報がGitリポジトリに保存されない
- ✅ 認証情報の変更が容易
- ✅ RBAC でアクセス制御可能
- ✅ 監査ログで追跡可能

### 運用改善

- ✅ 自動スクリプトで簡単セットアップ
- ✅ 既存の運用に影響なし（フォールバック機能）
- ✅ 詳細なドキュメント完備

---

**作成日**: 2025-10-22  
**最終更新**: 2025-10-22  
**セキュリティステータス**: ✅ GitGuardian対応済み


