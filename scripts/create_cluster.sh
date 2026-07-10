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

    # download kubectl
    if [ "$filter_kubectl_version" != "$kubectl_version" ]; then
        echo "start kubectl download"
        [ $(uname -m) = x86_64 ] && curl -Lo ./kubectl "https://dl.k8s.io/release/$kubectl_version/bin/linux/amd64/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
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
    sudo rm -rf "$HOME/.kind/etcd-c1" && mkdir -p "$HOME/.kind/etcd-c1"
    echo "end delete_kind_cluster() .."
}

get_node_image(){
    # 若 config.env 明確指定 node_image，優先使用（k8s 版本與 kind binary 解耦）。
    # 同一個 kind binary 可支援多個 node image，例如 kind v0.30.0 支援
    # v1.34.0 / v1.33.4 / v1.32.8 / v1.31.12。
    if [[ -n "$node_image" ]]; then
        echo "$node_image"
        return
    fi
    # 未指定時 fall back 回 kind_version 對應的預設 node image。
    case "$kind_version" in
        v0.14.0) echo "kindest/node:v1.24.0" ;;
        v0.23.0) echo "kindest/node:v1.27.3" ;;
        v0.26.0) echo "kindest/node:v1.29.2" ;;
        v0.30.0) echo "kindest/node:v1.34.0" ;;
        v0.32.0) echo "kindest/node:v1.36.1" ;;
        *) echo "" ;;
    esac
}

build_kind_config(){
    local base_config="$1"
    local tmp_config
    tmp_config=$(mktemp /tmp/kind-config.XXXXXX.yaml)
    cp "$base_config" "$tmp_config"
    # extraMounts on /var/lib/etcd only works on kind v0.26.0+
    if [[ "$kind_version" == "v0.26.0" ]]; then
        mkdir -p "$HOME/.kind/etcd-c1"
        cat >> "$tmp_config" << EOF
    extraMounts:
      - hostPath: $HOME/.kind/etcd-c1
        containerPath: /var/lib/etcd
EOF
    fi
    echo "$tmp_config"
}

create_kind_cluster(){
    echo "start create_kind_cluster() .."
    local resolved_image=$(get_node_image)
    local image_flag=""
    [[ -n "$resolved_image" ]] && image_flag="--image=$resolved_image"

    if [[ "$cluster_mode" == "multi" ]]; then
        echo "創建集群 c1 和 c2"
        kind create cluster --name=c1 $image_flag --config="$(build_kind_config $FILE_PATH_kind)"
        kind create cluster --name=c2 $image_flag --config="$FILE_PATH_kind_2"
    elif [[ "$cluster_mode" == "single" ]]; then
        echo "創建集群 c1"
        kind create cluster --name=c1 $image_flag --config="$(build_kind_config $FILE_PATH_kind)"
    else
        echo "please check agin :  $cluster_mode 。"
        exit 1
    fi
    echo "end create_kind_cluster() .."
}

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
