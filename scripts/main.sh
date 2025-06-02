#!/bin/bash

set -e
# abspath=$(cd "$(dirname "$0")";pwd)
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){
    bash $abspath/scripts/create_cluster.sh
    bash $abspath/scripts/create_istio.sh
    # bash $abspath/scripts/install_kiali.sh
    # bash $abspath/scripts/install_prom.sh
    # bash $abspath/scripts/istio_create_sample.sh
    # bash $abspath/scripts/deploy-nginx.sh
    # bash $abspath/scripts/istio_consistent_hash.sh
    # bash $abspath/scripts/metallb.sh
    # bash $abspath/scripts/mesh.sh
}

clear(){
    echo "start clear() .."
    rm -rf $FOLDER_PATH_download/*    
    echo "end clear() .."
}

if [[ -n "$istio_version" && -n "$kiali_version" ]]; then    
    main_task
    clear
else
    echo "Error: istio_version and kiali_version must be set."
fi

exit 0
