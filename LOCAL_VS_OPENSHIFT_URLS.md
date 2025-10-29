# 🔄 ローカル版 ⇔ OpenShift版 URL対応表

## 📋 概要

ローカル環境とOpenShift環境でのURL対応表です。

---

## 🎯 Prometheus アラート関連

### アラート画面

| 環境 | URL | 説明 |
|-----|-----|------|
| **ローカル版** | `http://localhost:9090/alerts` | すべてのアラートの状態を確認 |
| **OpenShift版** | `https://prometheus-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/alerts` | すべてのアラートの状態を確認 |

**現在の状態（OpenShift版）:**
```
✅ 18個のアラートすべて読み込み済み
🟢 17個が inactive（正常）
🔴 1個が firing（ApplicationRestarted - 再起動検出）
```

### Prometheus メインUI

| 環境 | URL | 用途 |
|-----|-----|------|
| **ローカル版** | `http://localhost:9090` | メトリクス確認、クエリ実行 |
| **OpenShift版** | `https://prometheus-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io` | メトリクス確認、クエリ実行 |

### Prometheus API

| 環境 | URL | 用途 |
|-----|-----|------|
| **ローカル版** | `http://localhost:9090/api/v1/rules` | アラートルールAPI |
| **OpenShift版** | `https://prometheus-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/api/v1/rules` | アラートルールAPI |

---

## 📊 Grafana 関連

### Grafana メインUI

| 環境 | URL | 認証 |
|-----|-----|------|
| **ローカル版** | `http://localhost:3000` | admin/admin |
| **OpenShift版** | `https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io` | OpenShift認証 |

### Grafanaダッシュボード

| 環境 | URL | 説明 |
|-----|-----|------|
| **ローカル版** | `http://localhost:3000/d/camel-comprehensive` | 統合ダッシュボード |
| **OpenShift版** | `https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/d/camel-comprehensive` | 統合ダッシュボード |

### Grafana Alerting

| 環境 | URL | 説明 |
|-----|-----|------|
| **ローカル版** | `http://localhost:3000/alerting/list` | Grafanaアラート一覧 |
| **OpenShift版** | `https://grafana-camel-observability-demo.apps.cluster-2mcrz.dynamic.redhatworkshops.io/alerting/list` | Grafanaアラート一覧 |

---

## 🔍 その他のコンポーネント

### Loki（ログ）

| 環境 | URL | アクセス |
|-----|-----|----------|
| **ローカル版** | `http://localhost:3100` | 外部アクセス可 |
| **OpenShift版** | `http://loki:3100` | 内部のみ（Grafana経由） |

**Loki API確認:**
```bash
# ローカル版
curl http://localhost:3100/ready

# OpenShift版（Pod内から）
oc exec -it $(oc get pods -l app=loki -o name) -- curl http://localhost:3100/ready
```

### Tempo（トレース）

| 環境 | URL | アクセス |
|-----|-----|----------|
| **ローカル版** | `http://localhost:3200` | 外部アクセス可 |
| **OpenShift版** | `http://tempo:3200` | 内部のみ（Grafana経由） |

### Camelアプリケーション

| 環境 | URL | 説明 |
|-----|-----|------|
| **ローカル版** | `http://localhost:8080` | アプリケーション |
| **ローカル版** | `http://localhost:8080/actuator/prometheus` | メトリクスエンドポイント |
| **OpenShift版** | `http://camel-app:8080` | 内部アクセス |
| **OpenShift版** | `https://camel-app-route.apps.cluster...` | 外部アクセス（Route経由） |

---

## 🚀 アクセス方法

### ブラウザで開く

#### ローカル版
```bash
# Prometheusアラート
open http://localhost:9090/alerts

# Grafana
open http://localhost:3000

# Prometheus Graph
open http://localhost:9090/graph
```

#### OpenShift版
```bash
# Prometheus URL取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

# Prometheusアラート
open "https://$PROMETHEUS_URL/alerts"

# Grafana URL取得
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')

# Grafana
open "https://$GRAFANA_URL"
```

### コマンドラインで確認

#### ローカル版
```bash
# アラート状態確認
curl -s http://localhost:9090/api/v1/rules | \
  jq '.data.groups[].rules[] | {alert: .name, state: .state}'

# アラート数カウント
curl -s http://localhost:9090/api/v1/rules | \
  jq '.data.groups[].rules | length' | \
  awk '{s+=$1} END {print "Total alerts: " s}'

# 発火中のアラート
curl -s http://localhost:9090/api/v1/rules | \
  jq -r '.data.groups[].rules[] | select(.state == "firing") | .name'
```

#### OpenShift版
```bash
# Prometheus URL取得
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')

# アラート状態確認
curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | \
  jq '.data.groups[].rules[] | {alert: .name, state: .state}'

# アラート数カウント
curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | \
  jq '.data.groups[].rules | length' | \
  awk '{s+=$1} END {print "Total alerts: " s}'

# アラートサマリー
curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | \
  jq -r '.data.groups[].rules[] | select(.type == "alerting") | "\(.state)\t\(.name)"' | \
  sort | uniq -c
```

---

## 📊 現在の状態（2025-10-22）

### ローカル版

```bash
$ curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules | length' | awk '{s+=$1} END {print s}'
18

$ curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[] | .state' | sort | uniq -c
     18 inactive
```

**結果**: ✅ 18個のアラートすべて正常（inactive）

### OpenShift版

```bash
$ curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | jq '.data.groups[].rules | length' | awk '{s+=$1} END {print s}'
18

$ curl -k -s "https://$PROMETHEUS_URL/api/v1/rules" | jq -r '.data.groups[].rules[] | "\(.state)\t\(.name)"' | sort | uniq -c
   1 firing	ApplicationRestarted
  17 inactive	(その他)
```

**結果**: ✅ 18個のアラート読み込み済み、17個正常、1個情報アラート発火中

---

## 🔧 URL取得スクリプト

### すべてのURLを一度に取得

#### ローカル版
```bash
#!/bin/bash

echo "📊 ローカル版 URL一覧"
echo ""
echo "Prometheus:"
echo "  - UI:      http://localhost:9090"
echo "  - Alerts:  http://localhost:9090/alerts"
echo "  - Graph:   http://localhost:9090/graph"
echo ""
echo "Grafana:"
echo "  - UI:      http://localhost:3000"
echo "  - Dashboard: http://localhost:3000/d/camel-comprehensive"
echo ""
echo "Application:"
echo "  - App:     http://localhost:8080"
echo "  - Metrics: http://localhost:8080/actuator/prometheus"
```

#### OpenShift版
```bash
#!/bin/bash

echo "📊 OpenShift版 URL一覧"
echo ""

# Prometheus URL
PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
echo "Prometheus:"
echo "  - UI:      https://$PROMETHEUS_URL"
echo "  - Alerts:  https://$PROMETHEUS_URL/alerts"
echo "  - Graph:   https://$PROMETHEUS_URL/graph"
echo ""

# Grafana URL
GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
echo "Grafana:"
echo "  - UI:      https://$GRAFANA_URL"
echo "  - Dashboard: https://$GRAFANA_URL/d/camel-comprehensive"
echo ""

# Camel App URL
CAMEL_URL=$(oc get route camel-app -o jsonpath='{.spec.host}' 2>/dev/null || echo "未設定")
if [ "$CAMEL_URL" != "未設定" ]; then
    echo "Application:"
    echo "  - App:     https://$CAMEL_URL"
fi
```

---

## 🎯 クイックアクセスコマンド

### ローカル版

```bash
# すべてのサービスを開く
alias local-prometheus='open http://localhost:9090/alerts'
alias local-grafana='open http://localhost:3000'
alias local-app='open http://localhost:8080'

# まとめて開く
local-all() {
    open http://localhost:9090/alerts
    open http://localhost:3000
}
```

### OpenShift版

```bash
# すべてのサービスを開く
alias ocp-prometheus='open "https://$(oc get route prometheus -o jsonpath=\"{.spec.host}\")/alerts"'
alias ocp-grafana='open "https://$(oc get route grafana -o jsonpath=\"{.spec.host}\")"'

# まとめて開く
ocp-all() {
    PROMETHEUS_URL=$(oc get route prometheus -o jsonpath='{.spec.host}')
    GRAFANA_URL=$(oc get route grafana -o jsonpath='{.spec.host}')
    
    open "https://$PROMETHEUS_URL/alerts"
    open "https://$GRAFANA_URL"
}
```

---

## 📋 環境切り替え

### 環境変数で管理

```bash
# .bashrc または .zshrc に追加

# ローカル環境
export PROMETHEUS_URL_LOCAL="http://localhost:9090"
export GRAFANA_URL_LOCAL="http://localhost:3000"

# OpenShift環境（動的取得）
get_openshift_urls() {
    export PROMETHEUS_URL_OCP="https://$(oc get route prometheus -o jsonpath='{.spec.host}')"
    export GRAFANA_URL_OCP="https://$(oc get route grafana -o jsonpath='{.spec.host}')"
    
    echo "✅ OpenShift URLを設定しました"
    echo "  Prometheus: $PROMETHEUS_URL_OCP"
    echo "  Grafana:    $GRAFANA_URL_OCP"
}

# 使い方
# get_openshift_urls
# open "$PROMETHEUS_URL_OCP/alerts"
```

---

## 🎉 まとめ

### ローカル版の特徴
- ✅ シンプルなURL（localhost）
- ✅ 認証不要（開発用）
- ✅ 高速アクセス
- ✅ すべてのポートが外部公開

### OpenShift版の特徴
- ✅ HTTPS（セキュア）
- ✅ OpenShift認証統合
- ✅ 本番環境対応
- ✅ Route経由の外部アクセス

### 共通点
- ✅ 同じダッシュボード
- ✅ 同じアラートルール（18個）
- ✅ 同じメトリクス収集
- ✅ 同じ機能セット

---

**作成日**: 2025-10-22  
**最終更新**: 2025-10-22  
**バージョン**: 1.0


