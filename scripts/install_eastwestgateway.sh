#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

FILE_PATH_ewgw_c1=$abspath/tools/istio/eastwestgateway/cluster1-ewgw-$istio_version.yaml
FILE_PATH_ewgw_c2=$abspath/tools/istio/eastwestgateway/cluster2-ewgw-$istio_version.yaml
FILE_PATH_expose=$abspath/tools/istio/eastwestgateway/expose-services.yaml

install_eastwestgateway(){
    export PATH=$FOLDER_PATH_istio/bin:$PATH

    echo "Installing eastwestgateway on ${CTX_CLUSTER1} ..."
    istioctl install --context="${CTX_CLUSTER1}" -y -f $FILE_PATH_ewgw_c1

    echo "Installing eastwestgateway on ${CTX_CLUSTER2} ..."
    istioctl install --context="${CTX_CLUSTER2}" -y -f $FILE_PATH_ewgw_c2

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER1} ..."
    kubectl --context="${CTX_CLUSTER1}" apply -f $FILE_PATH_expose

    echo "Exposing services via cross-network-gateway on ${CTX_CLUSTER2} ..."
    kubectl --context="${CTX_CLUSTER2}" apply -f $FILE_PATH_expose

    echo "Eastwestgateway installation complete."
}

install_eastwestgateway

exit 0
