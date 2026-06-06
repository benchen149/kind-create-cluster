#!/bin/bash
# 動態產生 ingress demo 用的自簽 TLS 憑證並建立 kubernetes secret。
# 私鑰不入 repo,每次執行重新產生(產物 tls.key / tls.crt 已被 .gitignore 排除)。
#
# 用法: bash samples/ingress/gen-tls.sh [host] [namespace] [secret-name]
#   預設: host=ngx-service.app.c3.dev.com  namespace=test  secret=ngx-service-tls
set -e

DIR="$(cd "$(dirname "$0")"; pwd)"
HOST="${1:-ngx-service.app.c3.dev.com}"
NS="${2:-test}"
SECRET="${3:-ngx-service-tls}"

echo "產生自簽憑證: host=$HOST"
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "$DIR/tls.key" \
  -out "$DIR/tls.crt" \
  -subj "/CN=$HOST/O=MyOrganization"

echo "建立 secret: $SECRET (namespace=$NS)"
kubectl -n "$NS" create secret tls "$SECRET" \
  --cert="$DIR/tls.crt" \
  --key="$DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ secret $SECRET 已套用於 namespace $NS"
