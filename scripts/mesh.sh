#!/bin/bash

set -e
abspath=$(cd "$(dirname "$0")/.."; pwd)
source $abspath/config/config.env

main_task(){  
  if [[ "$cluster_mode" == "multi"  ]]; then
    # generate secret yaml
    echo "debug"
    cd $FOLDER_PATH_download/istio-$istio_version
    export PATH=$FOLDER_PATH_download/istio-$istio_version/bin:$PATH
    istioctl create-remote-secret --context="${CTX_CLUSTER1}"  --name=cluster1  > /tmp/secret1.yaml
    istioctl create-remote-secret --context="${CTX_CLUSTER2}"  --name=cluster2  > /tmp/secret2.yaml

    # istioctl create-remote-secret --context="${CTX_CLUSTER1}" --name=cluster1 --server=https://172.18.0.2:6443 > secret1.yaml
    # istioctl create-remote-secret --context="${CTX_CLUSTER2}" --name=cluster2 --server=https://172.18.0.3:6443 > secret2.yaml
    
    # get c1 and c2 control-plane ip
    c1_master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c1-control-plane)
    c2_master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c2-control-plane)
    echo "c1_master_ip="$c1_master_ip
    echo "c2_master_ip="$c2_master_ip

    # replace new ip 
    sed -i "s|server: https://127.0.0.1:[0-9]\+|server: https://$c1_master_ip:6443|g" /tmp/secret1.yaml
    sed -i "s|server: https://127.0.0.1:[0-9]\+|server: https://$c2_master_ip:6443|g" /tmp/secret2.yaml

    # apply remote secret on each cluster
    cat  /tmp/secret1.yaml | kubectl apply -f - --context="${CTX_CLUSTER2}"
    cat  /tmp/secret2.yaml | kubectl apply -f - --context="${CTX_CLUSTER1}" 
  else
      echo "please check agin :  $cluster_mode 。"
      exit 1
  fi
}

check_cacerts(){      
    kubectl --context="${CTX_CLUSTER1}" -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}' > /tmp/cacerts1
    kubectl --context="${CTX_CLUSTER2}" -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}' > /tmp/cacerts2

    # 檢查兩個文件是否相同
    if ! cmp -s /tmp/cacerts1 /tmp/cacerts2; then
        echo "Error: cacerts1 and cacerts2 are different!"
        exit 1
    else
        echo "Success: cacerts1 and cacerts2 are identical."
    fi
}

add_cross_cluster_routes(){
    c1_master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c1-control-plane)
    c2_master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' c2-control-plane)

    c1_pod_subnet=$(kubectl --context="${CTX_CLUSTER1}" get node c1-control-plane -o jsonpath='{.spec.podCIDR}')
    c2_pod_subnet=$(kubectl --context="${CTX_CLUSTER2}" get node c2-control-plane -o jsonpath='{.spec.podCIDR}')

    echo "Adding route: c1 → $c2_pod_subnet via $c2_master_ip"
    docker exec c1-control-plane ip route add "$c2_pod_subnet" via "$c2_master_ip" 2>/dev/null || echo "route already exists"

    echo "Adding route: c2 → $c1_pod_subnet via $c1_master_ip"
    docker exec c2-control-plane ip route add "$c1_pod_subnet" via "$c1_master_ip" 2>/dev/null || echo "route already exists"
}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status
namespace_exists=$(kubectl get ns sample --ignore-not-found)

if [[ "$istiod_status" == "Running" ]]; then
    main_task
    check_cacerts
    add_cross_cluster_routes
fi

exit 0

