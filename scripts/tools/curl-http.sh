#!/bin/bash

SUCCESS_COUNT=0
TOTAL_REQUESTS=2
domain="ngx-service.app.c3.dev.com"

#for ((i=1; i<=TOTAL_REQUESTS; i++))
for i in $(seq 1 $TOTAL_REQUESTS); do
  # 執行 curl 並檢查 HTTP 狀態碼是否是 2xx
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $domain)
  if [ $RESPONSE -ge 200 ] && [ $RESPONSE -lt 300 ]; then
    ((SUCCESS_COUNT++))        
  fi
  echo "Request $i: HTTP $RESPONSE , web=$domain"
  
  # 間隔 1 秒
  sleep 1
done

echo "Total Successful Requests: $SUCCESS_COUNT/$TOTAL_REQUESTS"
