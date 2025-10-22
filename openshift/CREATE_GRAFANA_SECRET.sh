#!/bin/bash

###############################################################################
# Grafana認証情報シークレット作成スクリプト
#
# 機能:
#   OpenShiftでGrafana管理者認証情報のシークレットを作成
#
# 使い方:
#   ./CREATE_GRAFANA_SECRET.sh [username] [password]
#   または
#   ./CREATE_GRAFANA_SECRET.sh  (対話式)
###############################################################################

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

###############################################################################
# 前提条件の確認
###############################################################################
print_header "1. 前提条件の確認"

# OpenShift接続確認
if ! command -v oc &> /dev/null; then
    print_error "ocコマンドが見つかりません。"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    print_error "OpenShiftに接続できません。oc loginを実行してください。"
    exit 1
fi
print_success "OpenShift接続: $(oc whoami)"

# プロジェクト確認
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    print_error "プロジェクトが選択されていません。"
    exit 1
fi
print_success "現在のプロジェクト: $CURRENT_PROJECT"

###############################################################################
# 認証情報の取得
###############################################################################
print_header "2. Grafana認証情報の設定"

# コマンドライン引数から取得
GRAFANA_USER="$1"
GRAFANA_PASS="$2"

# 対話式入力
if [ -z "$GRAFANA_USER" ]; then
    echo -n "Grafana管理者ユーザー名 (デフォルト: admin): "
    read GRAFANA_USER
    GRAFANA_USER="${GRAFANA_USER:-admin}"
fi

if [ -z "$GRAFANA_PASS" ]; then
    echo -n "Grafana管理者パスワード (デフォルト: admin): "
    read -s GRAFANA_PASS
    echo ""
    GRAFANA_PASS="${GRAFANA_PASS:-admin}"
fi

print_info "ユーザー名: $GRAFANA_USER"
print_info "パスワード: ******** (${#GRAFANA_PASS}文字)"

###############################################################################
# パスワード強度チェック
###############################################################################
print_header "3. パスワード強度チェック"

if [ ${#GRAFANA_PASS} -lt 8 ]; then
    print_warning "パスワードが短すぎます（8文字以上推奨）"
fi

if [[ ! "$GRAFANA_PASS" =~ [A-Z] ]]; then
    print_warning "大文字を含めることを推奨します"
fi

if [[ ! "$GRAFANA_PASS" =~ [0-9] ]]; then
    print_warning "数字を含めることを推奨します"
fi

if [ "$GRAFANA_PASS" == "admin" ]; then
    print_warning "デフォルトパスワードは本番環境では使用しないでください"
fi

###############################################################################
# シークレットの削除（既存の場合）
###############################################################################
print_header "4. 既存シークレットの確認"

if oc get secret grafana-admin-credentials &> /dev/null; then
    print_warning "既存のシークレットが見つかりました"
    echo -n "上書きしますか? (y/N): "
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "キャンセルしました"
        exit 0
    fi
    
    oc delete secret grafana-admin-credentials
    print_success "既存のシークレットを削除しました"
else
    print_info "新規作成します"
fi

###############################################################################
# シークレットの作成
###############################################################################
print_header "5. シークレットの作成"

oc create secret generic grafana-admin-credentials \
    --from-literal=GF_SECURITY_ADMIN_USER="$GRAFANA_USER" \
    --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_PASS"

if [ $? -eq 0 ]; then
    print_success "シークレットを作成しました"
else
    print_error "シークレットの作成に失敗しました"
    exit 1
fi

###############################################################################
# シークレットの確認
###############################################################################
print_header "6. シークレットの確認"

echo "シークレット情報:"
oc get secret grafana-admin-credentials -o yaml | grep -A 2 "data:"

echo ""
echo "ユーザー名（デコード）:"
oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d
echo ""

echo "パスワード長: $(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d | wc -c | xargs) 文字"

###############################################################################
# Grafana Deploymentへの適用（オプション）
###############################################################################
print_header "7. Grafana Deploymentへの適用（オプション）"

if oc get deployment grafana &> /dev/null; then
    echo -n "Grafana Deploymentに環境変数として設定しますか? (y/N): "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "環境変数を設定しています..."
        
        # 既存の環境変数を削除（存在する場合）
        oc set env deployment/grafana \
            GF_SECURITY_ADMIN_USER- \
            GF_SECURITY_ADMIN_PASSWORD- 2>/dev/null || true
        
        # シークレットから環境変数を設定
        oc set env deployment/grafana \
            --from=secret/grafana-admin-credentials
        
        if [ $? -eq 0 ]; then
            print_success "環境変数を設定しました"
            print_info "Grafana Podが再起動されます..."
            oc rollout status deployment/grafana --timeout=2m
            print_success "Grafana再起動完了"
        else
            print_error "環境変数の設定に失敗しました"
        fi
    fi
else
    print_warning "Grafana Deploymentが見つかりません"
fi

###############################################################################
# 完了
###############################################################################
print_header "8. 完了"

echo ""
print_success "Grafana認証情報シークレットの作成が完了しました！"
echo ""

echo "📋 作成されたシークレット:"
echo "  名前: grafana-admin-credentials"
echo "  プロジェクト: $CURRENT_PROJECT"
echo "  ユーザー名: $GRAFANA_USER"
echo ""

echo "🔐 シークレットの使用方法:"
echo ""
echo "  # シークレットから値を取得"
echo "  \$(oc get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d)"
echo ""
echo "  # Deploymentで環境変数として使用"
echo "  oc set env deployment/grafana --from=secret/grafana-admin-credentials"
echo ""
echo "  # Podで環境変数として使用 (YAML)"
echo "  env:"
echo "    - name: GF_SECURITY_ADMIN_USER"
echo "      valueFrom:"
echo "        secretKeyRef:"
echo "          name: grafana-admin-credentials"
echo "          key: GF_SECURITY_ADMIN_USER"
echo ""

echo "⚠️  セキュリティのヒント:"
echo "  - パスワードはgitにコミットしないでください"
echo "  - 定期的にパスワードを変更してください"
echo "  - 本番環境では強力なパスワードを使用してください"
echo ""

exit 0

