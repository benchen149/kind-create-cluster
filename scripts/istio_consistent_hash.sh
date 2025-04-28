#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){   
    kubectl create --context="${CTX_CLUSTER1}" namespace sample3
    kubectl label --context="${CTX_CLUSTER1}" namespace sample3 \
        istio.io/rev=$istio_label
    kubectl apply --context="${CTX_CLUSTER1}" \
        -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
        -l service=helloworld -n sample3
    kubectl apply --context="${CTX_CLUSTER1}" \
        -f $FOLDER_PATH_istio/samples/helloworld/helloworld.yaml \
        -l version=v1 -n sample3   
    kubectl apply --context="${CTX_CLUSTER1}" \
    -f $FOLDER_PATH_istio/samples/sleep/sleep.yaml -n sample3 

    kubectl --context="${CTX_CLUSTER1}"  scale deployment helloworld-v1 --replicas=2 -n sample3
    
    if [[ "$istio_version" == "1.13.5" ]]; then
        kubectl --context=$CTX_CLUSTER1 -n sample3 apply -f  $FOLDER_PATH_samples/network/consistent_dr_v1_13_5.yaml
    else
        kubectl --context=$CTX_CLUSTER1 -n sample3 apply -f  $FOLDER_PATH_samples/network/consistent_dr_v1_23_0.yaml
    fi
}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status
namespace_exists=$(kubectl get ns sample3 --ignore-not-found)

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

