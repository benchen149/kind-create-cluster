#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

istio(){
    echo "start istio() .." 
    if [[ -f "$FILE_PATH_istio" && -f "$FILE_PATH_istio_2" ]]; then
        echo "文件" $FILE_PATH_istio "and" $FILE_PATH_istio_2 "存在..."
        cd $FOLDER_PATH_download/istio-$istio_version
        export PATH=$FOLDER_PATH_download/istio-$istio_version/bin:$PATH
        pushd $FOLDER_PATH_certs

        if [[ "$cluster_mode" == "multi" ]]; then   
            # 創建多集群模式下Istio
            kubectl --context=$CTX_CLUSTER1 create namespace istio-system
            kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
                --from-file=cluster1/ca-cert.pem \
                --from-file=cluster1/ca-key.pem \
                --from-file=cluster1/root-cert.pem \
                --from-file=cluster1/cert-chain.pem
            echo $FILE_PATH_istio
            istioctl install --context="${CTX_CLUSTER1}"  -y -f $FILE_PATH_istio

            kubectl --context=$CTX_CLUSTER2 create namespace istio-system
            kubectl --context=$CTX_CLUSTER2 create secret generic cacerts -n istio-system \
                --from-file=cluster2/ca-cert.pem \
                --from-file=cluster2/ca-key.pem \
                --from-file=cluster2/root-cert.pem \
                --from-file=cluster2/cert-chain.pem
            echo $FILE_PATH_istio_2
            istioctl install --context="${CTX_CLUSTER2}"  -y -f $FILE_PATH_istio_2
            
        elif [[ "$cluster_mode" == "single" ]]; then
            # 單集群模式Istio
            export CTX_CLUSTER1=kind-c1
            kubectl --context=$CTX_CLUSTER1 create namespace istio-system
            kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
                --from-file=cluster1/ca-cert.pem \
                --from-file=cluster1/ca-key.pem \
                --from-file=cluster1/root-cert.pem \
                --from-file=cluster1/cert-chain.pem
            echo $FILE_PATH_istio
            istioctl install --context="${CTX_CLUSTER1}"  -y -f $FILE_PATH_istio                
        else
            echo "please check agin : $cluster_mode 。"
            exit 1
        fi
    else
      echo "文件 $FILE_PATH_istio or $FILE_PATH_istio_2 不存在，终止。"
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
