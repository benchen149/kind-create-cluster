#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){
  context_count=$(kubectl config get-contexts --no-headers | wc -l)
  echo "context_count="$context_count

  if [[ "$cluster_mode" == "multi" ]]; then
      kubectl --context="${CTX_CLUSTER1}" create namespace istio-validation 2>/dev/null || true
      kubectl --context="${CTX_CLUSTER1}" label namespace istio-validation istio.io/rev=$istio_label --overwrite
      kubectl --context="${CTX_CLUSTER1}" -n istio-validation apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml
      kubectl --context="${CTX_CLUSTER1}" -n istio-validation apply -f $FOLDER_PATH_metallb/nginx-deployment-2.yaml

      kubectl --context="${CTX_CLUSTER2}" create namespace istio-validation 2>/dev/null || true
      kubectl --context="${CTX_CLUSTER2}" label namespace istio-validation istio.io/rev=$istio_label --overwrite
      kubectl --context="${CTX_CLUSTER2}" -n istio-validation apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml

  elif [[ "$cluster_mode" == "single" ]]; then
      kubectl --context="${CTX_CLUSTER1}" create namespace istio-validation 2>/dev/null || true
      kubectl --context="${CTX_CLUSTER1}" label namespace istio-validation istio.io/rev=$istio_label --overwrite
      kubectl --context="${CTX_CLUSTER1}" -n istio-validation apply -f $FOLDER_PATH_metallb/nginx-deployment.yaml
      kubectl --context="${CTX_CLUSTER1}" -n istio-validation apply -f $FOLDER_PATH_metallb/nginx-deployment-2.yaml

  else
      echo "please check agin :  $cluster_mode 。"
      exit 1
  fi
}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status

if [[ "$istiod_status" == "Running" ]]; then
    main_task
else
    echo "Waiting for istiod Pod to be Running in the istio-system namespace..."
fi

exit 0
