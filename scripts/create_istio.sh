#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

# 使用 Istio 發行包內建的 Makefile.selfsigned.mk 動態產生 cacerts（共用同一 root CA）
# 用法：gen_cacerts cluster1 [cluster2 ...]，已存在則快取重用
gen_cacerts(){
    local CERT_MAKEFILE="$FOLDER_PATH_istio/tools/certs/Makefile.selfsigned.mk"
    if [[ ! -f "$CERT_MAKEFILE" ]]; then
        echo "Error: cert Makefile 不存在: $CERT_MAKEFILE（請先執行 pretask 下載 Istio）"
        exit 1
    fi
    mkdir -p "$FOLDER_PATH_cacerts"
    (
        cd "$FOLDER_PATH_cacerts"
        local c
        for c in "$@"; do
            if [[ -f "$c/cert-chain.pem" ]]; then
                echo "cacerts for $c 已存在，快取重用。"
            else
                echo "產生 cacerts for $c .."
                make -f "$CERT_MAKEFILE" root-ca
                make -f "$CERT_MAKEFILE" "$c-cacerts"
            fi
        done
    )
}

istio(){
    echo "start istio() .."
    if [[ -f "$FILE_PATH_istio" ]]; then
        echo "文件" $FILE_PATH_istio "存在..."
        cd $FOLDER_PATH_download/istio-$istio_version
        export PATH=$FOLDER_PATH_download/istio-$istio_version/bin:$PATH

        if [[ "$cluster_mode" == "multi" ]]; then
            # 創建多集群模式下Istio
            gen_cacerts cluster1 cluster2
            pushd $FOLDER_PATH_cacerts
            kubectl --context=$CTX_CLUSTER1 create namespace istio-system
            kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
                --from-file=cluster1/ca-cert.pem \
                --from-file=cluster1/ca-key.pem \
                --from-file=cluster1/root-cert.pem \
                --from-file=cluster1/cert-chain.pem
            echo $FILE_PATH_istio "(cluster1 / $NETWORK_CLUSTER1)"
            CLUSTER_NAME=cluster1 NETWORK_NAME=$NETWORK_CLUSTER1 \
                envsubst '$istio_label $CLUSTER_NAME $NETWORK_NAME' < $FILE_PATH_istio \
                | istioctl install --context="${CTX_CLUSTER1}" -y -f -

            kubectl --context=$CTX_CLUSTER2 create namespace istio-system
            kubectl --context=$CTX_CLUSTER2 create secret generic cacerts -n istio-system \
                --from-file=cluster2/ca-cert.pem \
                --from-file=cluster2/ca-key.pem \
                --from-file=cluster2/root-cert.pem \
                --from-file=cluster2/cert-chain.pem
            echo $FILE_PATH_istio "(cluster2 / $NETWORK_CLUSTER2)"
            CLUSTER_NAME=cluster2 NETWORK_NAME=$NETWORK_CLUSTER2 \
                envsubst '$istio_label $CLUSTER_NAME $NETWORK_NAME' < $FILE_PATH_istio \
                | istioctl install --context="${CTX_CLUSTER2}" -y -f -

        elif [[ "$cluster_mode" == "single" ]]; then
            # 單集群模式Istio
            export CTX_CLUSTER1=kind-c1
            gen_cacerts cluster1
            pushd $FOLDER_PATH_cacerts
            kubectl --context=$CTX_CLUSTER1 create namespace istio-system
            kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
                --from-file=cluster1/ca-cert.pem \
                --from-file=cluster1/ca-key.pem \
                --from-file=cluster1/root-cert.pem \
                --from-file=cluster1/cert-chain.pem
            echo $FILE_PATH_istio "(cluster1 / $NETWORK_CLUSTER1)"
            CLUSTER_NAME=cluster1 NETWORK_NAME=$NETWORK_CLUSTER1 \
                envsubst '$istio_label $CLUSTER_NAME $NETWORK_NAME' < $FILE_PATH_istio \
                | istioctl install --context="${CTX_CLUSTER1}" -y -f -
        else
            echo "please check agin : $cluster_mode 。"
            exit 1
        fi
    else
      echo "文件 $FILE_PATH_istio 不存在，终止。"
      exit 1
    fi
}

main(){    
    istio    
}

input_process="$1"
input_process=${input_process:-main}
echo "Available processes: ${available_processes[*]}"
echo "input_process:"$input_process

if [[ " ${available_processes[*]} " == *" $input_process "* ]]; then
    if [[ -n "$istio_version" && -n "$kiali_version" ]]; then
        "$input_process"
    else
        echo "Error: istio_version and kiali_version must be set."
    fi
else
    echo "Error: Invalid process name '$input_process'."
    echo "Available processes: ${available_processes[*]}"
    exit 1
fi

exit 0
