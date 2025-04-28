#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){  
  context_count=$(kubectl config get-contexts --no-headers | wc -l)
  echo "context_count="$context_count

  if [[ "$cluster_mode" == "multi" ]]; then
      kubectl --context="${CTX_CLUSTER1}" create namespace test
      kubectl --context="${CTX_CLUSTER1}" label namespace test istio.io/rev=$istio_label      
      kubectl --context="${CTX_CLUSTER1}" -n test apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml
      kubectl --context="${CTX_CLUSTER1}" -n test apply -f $FOLDER_PATH_metallb/nginx-deployment-2.yaml   

      kubectl --context="${CTX_CLUSTER2}" create namespace test  
      kubectl --context="${CTX_CLUSTER2}" label namespace test istio.io/rev=$istio_label      
      kubectl --context="${CTX_CLUSTER2}" -n test apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml

  elif [[ "$cluster_mode" == "single" ]]; then
      kubectl --context="${CTX_CLUSTER1}" create namespace test
      kubectl --context="${CTX_CLUSTER1}" label namespace test istio.io/rev=$istio_label        
      kubectl --context="${CTX_CLUSTER1}" -n test apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml
      kubectl --context="${CTX_CLUSTER1}" -n test apply -f $FOLDER_PATH_metallb/nginx-deployment-2.yaml 
        
  else
      echo "please check agin :  $cluster_mode 。"
      exit 1
  fi
}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status
namespace_exists=$(kubectl get ns test --ignore-not-found)

if [[ "$istiod_status" == "Running" && -z "$namespace_exists" ]]; then
    main_task
else
    if [[ "$istiod_status" != "Running" ]]; then
        echo "Waiting for istiod Pod to be Running in the istio-system namespace..."
    fi
    if [[ -n "$namespace_exists" ]]; then
        echo "Namespace 'test' already exists."
    fi
fi

exit 0

