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

prometheus(){
    echo "start prometheus() .."
    if [ -f "$FILE_PATH_prometheus" ]; then 
        echo "文件 $FILE_PATH_prometheus 存在..."
        if [[ "$cluster_mode" == "multi" ]]; then
            kubectl --context=$CTX_CLUSTER1 apply  -f $FILE_PATH_prometheus  
            kubectl --context=$CTX_CLUSTER2 apply  -f $FILE_PATH_prometheus  
        elif [[ "$cluster_mode" == "single" ]]; then    
            kubectl --context=$CTX_CLUSTER1 apply  -f $FILE_PATH_prometheus            
        else
            echo "please check agin : $cluster_mode 。"
            exit 1
        fi
    else
      echo "文件 $FILE_PATH_prometheus 不存在，终止。"
    fi
    echo "end prometheus() .."
}

main(){    
    prometheus
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
