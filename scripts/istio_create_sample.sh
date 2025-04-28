#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){  
  context_count=$(kubectl config get-contexts --no-headers | wc -l)
  echo "context_count="$context_count


  if [[ "$cluster_mode" == "multi"  ]]; then
      kubectl create --context="${CTX_CLUSTER1}" namespace sample
      kubectl label --context="${CTX_CLUSTER1}" namespace sample \
           istio.io/rev=$istio_label
      kubectl apply --context="${CTX_CLUSTER1}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l service=helloworld -n sample
      kubectl apply --context="${CTX_CLUSTER1}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l version=v1 -n sample
      kubectl apply --context="${CTX_CLUSTER1}" \
        -f $FOLDER_PATH_istio/samples/sleep/sleep.yaml -n sample


      kubectl create --context="${CTX_CLUSTER2}" namespace sample
      kubectl label --context="${CTX_CLUSTER2}" namespace sample \
           istio.io/rev=$istio_label
      kubectl apply --context="${CTX_CLUSTER2}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l service=helloworld -n sample
      kubectl apply --context="${CTX_CLUSTER2}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l version=v2 -n sample 
      kubectl apply --context="${CTX_CLUSTER2}" \
        -f $FOLDER_PATH_istio/samples/sleep/sleep.yaml -n sample   

    #   echo "sleep 60"
    #   sleep 60

    #   kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=helloworld
    #   kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=sleep 
    #   kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=helloworld
    #   kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=sleep    
    # Verifying Cross-Cluster Traffic
    #   for i in $(seq 1 10); do
    #     kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
    #         "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
    #         app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    #         -- curl -sS helloworld.sample:5000/hello
    #   done
    #   for i in $(seq 1 10); do
    #     kubectl exec --context="${CTX_CLUSTER2}" -n sample -c sleep \
    #         "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
    #         app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    #         -- curl -sS helloworld.sample:5000/hello
    #   done
  elif [[ "$cluster_mode" == "single" ]]; then
      kubectl create --context="${CTX_CLUSTER1}" namespace sample
      kubectl label --context="${CTX_CLUSTER1}" namespace sample \
           istio.io/rev=$istio_label
      kubectl apply --context="${CTX_CLUSTER1}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l service=helloworld -n sample
      kubectl apply --context="${CTX_CLUSTER1}" \
          -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
          -l version=v1 -n sample   
      kubectl apply --context="${CTX_CLUSTER1}" \
        -f $FOLDER_PATH_istio/samples/sleep/sleep.yaml -n sample 

    #   echo "sleep 60"
    #   sleep 60
      
    #   kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=helloworld
    #   kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=sleep

    # Verifying Cross-Cluster Traffic
    #   for i in $(seq 1 10); do
    #     kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
    #         "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
    #         app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    #         -- curl -sS helloworld.sample:5000/hello
    #   done
  else
      echo "please check agin :  $cluster_mode 。"
      exit 1
  fi
}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status
namespace_exists=$(kubectl get ns sample --ignore-not-found)

if [[ "$istiod_status" == "Running" && -z "$namespace_exists" ]]; then
    main_task
else
    if [[ "$istiod_status" != "Running" ]]; then
        echo "Waiting for istiod Pod to be Running in the istio-system namespace..."
    fi
    if [[ -n "$namespace_exists" ]]; then
        echo "Namespace 'sample' already exists."
    fi
fi

exit 0

