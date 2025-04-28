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

appdend_ip_mac(){  
    # get ns/sample pod's ip     
    sleep_ip_c1=$(kubectl -n sample --context="${CTX_CLUSTER1}" get pod -l app=sleep -o jsonpath='{.items[0].status.podIP}')
    helloworld_ip_c1=$(kubectl -n sample --context="${CTX_CLUSTER1}" get pod -l app=helloworld -o jsonpath='{.items[0].status.podIP}')

    sleep_ip_c2=$(kubectl -n sample --context="${CTX_CLUSTER2}" get pod -l app=sleep -o jsonpath='{.items[0].status.podIP}')
    helloworld_ip_c2=$(kubectl -n sample --context="${CTX_CLUSTER2}" get pod -l app=helloworld -o jsonpath='{.items[0].status.podIP}')

    echo "Sleep Pod IP in Cluster1: $sleep_ip_c1"
    echo "Helloworld Pod IP in Cluster1: $helloworld_ip_c1"
    echo "Sleep Pod IP in Cluster2: $sleep_ip_c2"
    echo "Helloworld Pod IP in Cluster2: $helloworld_ip_c2"   

    docker exec -it c1-control-plane bash -c "
    apt-get update && apt-get install -y net-tools && 
    echo 'Installation completed on c1-control-plane'
    " && \
    docker exec -it c2-control-plane bash -c "
        apt-get update && apt-get install -y net-tools && 
        echo 'Installation completed on c2-control-plane'
    "
    # mac_address_c1=$(docker exec c1-control-plane bash -c "arp -n | grep '$c1_master_ip' | awk '{print \$3}'")
    # mac_address_c2=$(docker exec c1-control-plane bash -c "arp -n | grep '$c1_master_ip' | awk '{print \$3}'")
    
    # echo mac_address_c1=$mac_address_c1
    # echo mac_address_c2=$mac_address_c2
    
    # get control-plane1's mac

    # get control-plane2's mac    

    # append the helloworld's ip and mac address on control-plane node


}

istiod_status=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.phase}')
echo "istiod_status is" $istiod_status
namespace_exists=$(kubectl get ns sample --ignore-not-found)

if [[ "$istiod_status" == "Running" ]]; then
    main_task
    check_cacerts
    appdend_ip_mac
fi

exit 0

