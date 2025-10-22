#!/bin/bash

# Undertowワーカースレッド数変更スクリプト
# キューサイズテスト用

echo "========================================="
echo "🔧 Undertowワーカースレッド数変更"
echo "========================================="
echo ""

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="camel-app/src/main/resources/application.yml"

# 現在の設定を確認
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_WORKER=$(grep -A 3 "undertow:" "$CONFIG_FILE" | grep "worker:" | awk '{print $2}')
    echo "現在のワーカースレッド数: ${CURRENT_WORKER:-不明}"
else
    echo -e "${RED}エラー: $CONFIG_FILE が見つかりません${NC}"
    exit 1
fi

echo ""
echo "変更オプション:"
echo "  1) 1スレッド   (キューテスト用 - 確実にキュー発生)"
echo "  2) 5スレッド   (キューテスト用 - 推奨)"
echo "  3) 10スレッド  (キューテスト用)"
echo "  4) 20スレッド  (中負荷テスト用)"
echo "  5) 50スレッド  (通常負荷)"
echo "  6) 200スレッド (デフォルト - 本番用)"
echo "  7) カスタム値"
echo "  0) キャンセル"
echo ""
read -p "選択してください [1-7, 0]: " choice

case $choice in
    1)
        NEW_WORKER=1
        ;;
    2)
        NEW_WORKER=5
        ;;
    3)
        NEW_WORKER=10
        ;;
    4)
        NEW_WORKER=20
        ;;
    5)
        NEW_WORKER=50
        ;;
    6)
        NEW_WORKER=200
        ;;
    7)
        read -p "ワーカースレッド数を入力 [1-1000]: " NEW_WORKER
        if ! [[ "$NEW_WORKER" =~ ^[0-9]+$ ]] || [ "$NEW_WORKER" -lt 1 ] || [ "$NEW_WORKER" -gt 1000 ]; then
            echo -e "${RED}エラー: 無効な値です${NC}"
            exit 1
        fi
        ;;
    0)
        echo "キャンセルしました"
        exit 0
        ;;
    *)
        echo -e "${RED}エラー: 無効な選択です${NC}"
        exit 1
        ;;
esac

echo ""
echo "変更内容:"
echo "  変更前: $CURRENT_WORKER スレッド"
echo "  変更後: $NEW_WORKER スレッド"
echo ""

if [ "$NEW_WORKER" -eq 1 ]; then
    echo -e "${RED}⚠⚠⚠ 警告 - ワーカースレッド1 ⚠⚠⚠${NC}"
    echo "  ワーカースレッドが1つだけのため、以下の影響があります:"
    echo "  - レスポンスタイムが極端に長くなります"
    echo "  - スループットが極めて低下します"
    echo "  - キューイングが常時発生します"
    echo "  - アプリケーションがほぼ応答不能になります"
    echo ""
    echo -e "${GREEN}✓ キューサイズテスト専用です${NC}"
    echo -e "${GREEN}✓ テスト後は必ず元に戻してください${NC}"
    echo ""
elif [ "$NEW_WORKER" -lt 10 ]; then
    echo -e "${YELLOW}⚠ 警告${NC}"
    echo "  ワーカースレッド数が非常に少ないため、以下の影響があります:"
    echo "  - レスポンスタイムが大幅に増加します"
    echo "  - スループットが低下します"
    echo "  - キューイングが頻繁に発生します"
    echo ""
    echo -e "${GREEN}✓ テスト環境でのみ使用してください${NC}"
    echo ""
fi

read -p "変更を適用しますか? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "変更をキャンセルしました"
    exit 0
fi

echo ""
echo "📝 設定ファイルを更新中..."

# バックアップを作成
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "  バックアップ作成: $BACKUP_FILE"

# 設定を変更
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/worker: [0-9]*/worker: $NEW_WORKER/" "$CONFIG_FILE"
else
    # Linux
    sed -i "s/worker: [0-9]*/worker: $NEW_WORKER/" "$CONFIG_FILE"
fi

# 変更を確認
NEW_VALUE=$(grep -A 3 "undertow:" "$CONFIG_FILE" | grep "worker:" | awk '{print $2}')
if [ "$NEW_VALUE" = "$NEW_WORKER" ]; then
    echo -e "  ${GREEN}✓ 設定ファイルを更新しました${NC}"
else
    echo -e "  ${RED}✗ 更新に失敗しました${NC}"
    echo "  バックアップから復元します..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

echo ""
echo "🔄 アプリケーションの再起動が必要です"
echo ""
read -p "今すぐ再起動しますか? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📦 アプリケーションを再ビルド中..."
    cd camel-app
    
    # 既存プロセスを停止
    echo "  既存プロセスを停止中..."
    PID=$(ps aux | grep -i "spring-boot:run" | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        kill $PID 2>/dev/null
        sleep 3
        echo -e "  ${GREEN}✓ 既存プロセスを停止しました (PID: $PID)${NC}"
    else
        echo "  既存プロセスはありません"
    fi
    
    # 再ビルド
    echo ""
    echo "  Maven ビルド中..."
    mvn clean package -DskipTests -q
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ビルドに失敗しました${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓ ビルド完了${NC}"
    
    # 起動
    echo ""
    echo "  アプリケーションを起動中..."
    nohup mvn spring-boot:run > ../camel-app-worker-${NEW_WORKER}.log 2>&1 &
    NEW_PID=$!
    echo "  PID: $NEW_PID"
    echo "  ログファイル: camel-app-worker-${NEW_WORKER}.log"
    
    cd ..
    
    echo ""
    echo "⏳ 起動を待機中（20秒）..."
    sleep 20
    
    # 起動確認
    if curl -s -f -m 3 "http://localhost:8080/actuator/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ アプリケーションが起動しました${NC}"
        
        # ワーカースレッド数を確認
        echo ""
        echo "📊 現在のUndertow設定:"
        ACTUAL_WORKER=$(curl -s http://localhost:8080/actuator/prometheus | grep "^undertow_worker_threads" | awk '{print $2}')
        echo "  ワーカースレッド数: ${ACTUAL_WORKER:-確認中...}"
        
        if [[ -n "$ACTUAL_WORKER" ]]; then
            ACTUAL_INT=$(echo "$ACTUAL_WORKER" | cut -d. -f1)
            if [ "$ACTUAL_INT" = "$NEW_WORKER" ]; then
                echo -e "  ${GREEN}✓ 設定が正しく適用されています${NC}"
            else
                echo -e "  ${YELLOW}⚠ 設定値と実際の値が異なります (期待: $NEW_WORKER, 実際: $ACTUAL_INT)${NC}"
            fi
        fi
        
    else
        echo -e "${RED}✗ アプリケーションの起動に失敗しました${NC}"
        echo "  ログを確認してください: tail -f camel-app-worker-${NEW_WORKER}.log"
        exit 1
    fi
    
    echo ""
    echo "========================================="
    echo "✅ 変更完了"
    echo "========================================="
    echo ""
    echo "次のステップ:"
    echo "  1. 負荷テストを実行:"
    echo "     ./load-test-stress.sh"
    echo "     または"
    echo "     ./load-test-extreme-queue.sh"
    echo ""
    echo "  2. メトリクスを確認:"
    echo "     curl -s http://localhost:8080/actuator/prometheus | grep undertow"
    echo ""
    echo "  3. Grafanaで監視:"
    echo "     http://localhost:3000"
    echo ""
    echo "  4. リアルタイム監視:"
    echo "     ./thread_monitor.sh"
    echo ""
    
    if [ "$NEW_WORKER" -eq 1 ]; then
        echo -e "${RED}⚠⚠⚠ 重要 ⚠⚠⚠${NC}"
        echo -e "${RED}ワーカースレッド数が1のため、アプリケーションが非常に遅くなっています${NC}"
        echo -e "${RED}必ずテスト後に元の設定（200）に戻してください！${NC}"
        echo ""
        echo "元に戻すコマンド:"
        echo "  ./change-worker-threads.sh  # → 6を選択"
        echo ""
    elif [ "$NEW_WORKER" -lt 10 ]; then
        echo -e "${YELLOW}注意: ワーカースレッド数が少ないため、キューイングが発生しやすくなっています${NC}"
        echo "      テスト後は元の設定（200）に戻すことを推奨します"
        echo ""
    fi
    
else
    echo ""
    echo "設定ファイルは更新されましたが、アプリケーションは再起動されていません"
    echo ""
    echo "手動で再起動するには:"
    echo "  1. 既存プロセスを停止:"
    echo "     ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print \$2}' | xargs kill"
    echo ""
    echo "  2. アプリケーションを起動:"
    echo "     cd camel-app"
    echo "     mvn clean package -DskipTests"
    echo "     nohup mvn spring-boot:run > ../camel-app-worker-${NEW_WORKER}.log 2>&1 &"
    echo ""
fi

echo ""
echo "バックアップファイル:"
echo "  $BACKUP_FILE"
echo ""
echo "元に戻すには:"
echo "  cp $BACKUP_FILE $CONFIG_FILE"
echo ""

