#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

FILE_PATH_ewgw=$abspath/tools/istio/eastwestgateway/ewgw.yaml
FILE_PATH_expose=$abspath/tools/istio/eastwestgateway/expose-services.yaml

label_cluster(){
    local ctx=$1
    local network=$2

    echo "Labeling nodes and istio-system namespace on ${ctx} with network=${network} ..."
    kubectl --context="${ctx}" label node \
        $(kubectl --context="${ctx}" get nodes -o jsonpath='{.items[*].metadata.name}') \
        topology.istio.io/network=${network} --overwrite

    kubectl --context="${ctx}" label namespace istio-system \
        topology.istio.io/network=${network} --overwrite
}

install_eastwestgateway(){
    export PATH=$FOLDER_PATH_istio/bin:$PATH
    export NETWORK_CLUSTER2=network2

    echo "Reconfiguring istiod on ${CTX_CLUSTER2} for network=${NETWORK_CLUSTER2} ..."
    CLUSTER_NAME=cluster2 NETWORK_NAME=$NETWORK_CLUSTER2 \
        envsubst '$istio_label $CLUSTER_NAME $NETWORK_NAME' < $FILE_PATH_istio \
        | istioctl install --context="${CTX_CLUSTER2}" -y -f -
    kubectl --context="${CTX_CLUSTER2}" -n istio-system \
        rollout status deployment/istiod-${istio_label} --timeout=120s

    label_cluster "${CTX_CLUSTER1}" "${NETWORK_CLUSTER1}"
    label_cluster "${CTX_CLUSTER2}" "${NETWORK_CLUSTER2}"

    echo "Installing eastwestgateway on ${CTX_CLUSTER1} ..."
    network_id=${NETWORK_CLUSTER1} envsubst '$istio_label $network_id' < $FILE_PATH_ewgw \
        | istioctl install --context="${CTX_CLUSTER1}" -y -f -

    echo "Installing eastwestgateway on ${CTX_CLUSTER2} ..."
    network_id=${NETWORK_CLUSTER2} envsubst '$istio_label $network_id' < $FILE_PATH_ewgw \
        | istioctl install --context="${CTX_CLUSTER2}" -y -f -

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER1} ..."
    kubectl --context="${CTX_CLUSTER1}" apply -f $FILE_PATH_expose

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER2} ..."
    kubectl --context="${CTX_CLUSTER2}" apply -f $FILE_PATH_expose

    echo "Restarting workloads to pick up network labels ..."
    for ns in $(kubectl --context="${CTX_CLUSTER1}" get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^kube-\|^istio-system$\|^metallb-system$"); do
        kubectl --context="${CTX_CLUSTER1}" rollout restart deployment -n "$ns" 2>/dev/null || true
    done
    for ns in $(kubectl --context="${CTX_CLUSTER2}" get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^kube-\|^istio-system$\|^metallb-system$"); do
        kubectl --context="${CTX_CLUSTER2}" rollout restart deployment -n "$ns" 2>/dev/null || true
    done

    echo "Eastwestgateway installation complete."
}

install_eastwestgateway

exit 0
