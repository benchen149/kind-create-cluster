#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

FILE_PATH_ewgw=$abspath/tools/istio/eastwestgateway/ewgw.yaml
FILE_PATH_expose=$abspath/tools/istio/eastwestgateway/expose-services.yaml

install_eastwestgateway(){
    export PATH=$FOLDER_PATH_istio/bin:$PATH

    echo "Installing eastwestgateway on ${CTX_CLUSTER1} ..."
    envsubst '$istio_label' < $FILE_PATH_ewgw | istioctl install --context="${CTX_CLUSTER1}" -y -f -

    echo "Installing eastwestgateway on ${CTX_CLUSTER2} ..."
    envsubst '$istio_label' < $FILE_PATH_ewgw | istioctl install --context="${CTX_CLUSTER2}" -y -f -

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER1} ..."
    kubectl --context="${CTX_CLUSTER1}" apply -f $FILE_PATH_expose

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER2} ..."
    kubectl --context="${CTX_CLUSTER2}" apply -f $FILE_PATH_expose

    echo "Eastwestgateway installation complete."
}

install_eastwestgateway

exit 0
