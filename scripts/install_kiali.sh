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

kiali(){
    echo "start kiali() .."
    if [ -f "$FILE_PATH_kiali" ]; then
        # docker pull quay.io/kiali/kiali/kiali-operator:$kiali_version
        # docker pull quay.io/kiali/kiali:$kiali_version
        if [[ "$cluster_mode" == "multi" ]]; then
            kind load docker-image quay.io/kiali/kiali-operator:$kiali_version --name c1
            kind load docker-image quay.io/kiali/kiali:$kiali_version --name c1
            helm install --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  $FOLDER_PATH_kiali

            kind load docker-image quay.io/kiali/kiali-operator:$kiali_version --name c2
            kind load docker-image quay.io/kiali/kiali:$kiali_version --name c2
            helm install --kube-context=kind-c2  --namespace=istio-system --create-namespace kiali-operator-2  $FOLDER_PATH_kiali
        elif [[ "$cluster_mode" == "single" ]]; then
            kind load docker-image quay.io/kiali/kiali-operator:$kiali_version --name c1
            kind load docker-image quay.io/kiali/kiali:$kiali_version --name c1
            helm install --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  $FOLDER_PATH_kiali           
        else
            echo "please check agin : $cluster_mode 。"
            exit 1
        fi
    else
      echo "文件 $FILE_PATH_kiali 不存在，终止。"
    fi
    echo "end kiali() .."
}

main(){    
    kiali    
}

# if [[ $# -eq 0 ]]; then
#     echo "Usage: $0 <process_name>"
#     echo "Available processes: ${available_processes[*]}"
#     exit 1
# fi

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
