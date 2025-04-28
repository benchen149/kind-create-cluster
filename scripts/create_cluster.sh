#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

echo "start pretask() .."
echo "kind version="$kind_version
echo "istio version="$istio_version
echo "istio label="$istio_label
echo "kiali version="$kiali_version
echo "filtered_version_kiali version="$filtered_version_kiali
echo "cluster_mode="$cluster_mode

pretask(){
    echo "start pretask() .."
    echo $FOLDER_PATH_download
    mkdir -p $FOLDER_PATH_download
    # download istio
    if [ -z "$(ls -A "$FOLDER_PATH_download" 2>/dev/null)" ]; then
        echo "start istio download"
        cd $FOLDER_PATH_download        
        wget "https://github.com/istio/istio/releases/download/$istio_version/istio-$istio_version-linux-amd64.tar.gz" -O - | tar -xz
    fi 

    # download kind
    if [ "$filter_kind_version" != "$kind_version" ]; then
        echo "start kind download"
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/$kind_version/kind-linux-amd64    
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    echo "end pretask() .."
}

delete_kind_cluster(){
    echo "start delete_kind_cluster() .."
    CLUSTERS=$(kind get clusters)
        if [ -n "$kind_version" ] ; then       
            if [ -n "$CLUSTERS" ]; then     
            echo "存在的 Kind 集群如下："
            echo "$CLUSTERS"
            # 如果想删除所有集群，可以使用以下循环：
            for cluster in $CLUSTERS; do
                kind delete cluster --name "$cluster"
                echo "已删除集群: $cluster"
            done
            fi
        fi
    echo "end delete_kind_cluster() .."
}

create_kind_cluster(){
    echo "start create_kind_cluster() .."
    if [[ "$cluster_mode" == "multi" ]]; then
        # 創建多集群模式下的集群
        echo "創建集群 c1 和 c2"
        kind create cluster --name=c1 --config="$FILE_PATH_kind"
        kind create cluster --name=c2 --config="$FILE_PATH_kind_2"
    elif [[ "$cluster_mode" == "single" ]]; then
        # 單集群模式
        echo "創建集群 c1"
        kind create cluster --name=c1 --config=$FILE_PATH_kind
    else
        echo "please check agin :  $cluster_mode 。"
        exit 1
    fi
    echo "end create_kind_cluster() .."
}

# istio(){
#     echo "start istio() .." 
#     if [[ -f "$FILE_PATH_istio" && -f "$FILE_PATH_istio_2" ]]; then
#         echo "文件" $FILE_PATH_istio "and" $FILE_PATH_istio_2 "存在..."
#         cd $FOLDER_PATH_download/istio-$istio_version
#         export PATH=$FOLDER_PATH_download/istio-$istio_version/bin:$PATH
#         pushd $FOLDER_PATH_certs

#         if [[ "$cluster_mode" == "multi" ]]; then   
#             # 創建多集群模式下Istio
#             kubectl --context=$CTX_CLUSTER1 create namespace istio-system
#             kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
#                 --from-file=cluster1/ca-cert.pem \
#                 --from-file=cluster1/ca-key.pem \
#                 --from-file=cluster1/root-cert.pem \
#                 --from-file=cluster1/cert-chain.pem
#             echo $FILE_PATH_istio
#             istioctl install --context="${CTX_CLUSTER1}"  -y -f $FILE_PATH_istio

#             kubectl --context=$CTX_CLUSTER2 create namespace istio-system
#             kubectl --context=$CTX_CLUSTER2 create secret generic cacerts -n istio-system \
#                 --from-file=cluster2/ca-cert.pem \
#                 --from-file=cluster2/ca-key.pem \
#                 --from-file=cluster2/root-cert.pem \
#                 --from-file=cluster2/cert-chain.pem
#             echo $FILE_PATH_istio_2
#             istioctl install --context="${CTX_CLUSTER2}"  -y -f $FILE_PATH_istio_2
            
#         elif [[ "$cluster_mode" == "single" ]]; then
#             # 單集群模式Istio
#             export CTX_CLUSTER1=kind-c1
#             kubectl --context=$CTX_CLUSTER1 create namespace istio-system
#             kubectl --context=$CTX_CLUSTER1 create secret generic cacerts -n istio-system \
#                 --from-file=cluster1/ca-cert.pem \
#                 --from-file=cluster1/ca-key.pem \
#                 --from-file=cluster1/root-cert.pem \
#                 --from-file=cluster1/cert-chain.pem
#             echo $FILE_PATH_istio
#             istioctl install --context="${CTX_CLUSTER1}"  -y -f $FILE_PATH_istio                
#         else
#             echo "please check agin : $cluster_mode 。"
#             exit 1
#         fi
#     else
#       echo "文件 $FILE_PATH_istio or $FILE_PATH_istio_2 不存在，终止。"
#       exit 1
#     fi
# }

main(){
    pretask
    delete_kind_cluster
    create_kind_cluster    
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
