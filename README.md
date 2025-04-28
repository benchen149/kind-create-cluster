# kind-create-cluster

---

## kiali/prometheus
```
kubectl --context kind-c1 port-forward svc/kiali -n istio-system 20001:20001
http://localhost:20001/kiali
istioctl  --context kind-c1 dashboard prometheus
```

## List all prometheuse metrics
```
http://localhost:9090/api/v1/label/__name__/values
```

## helm install/upgrade/uninstall
```
helm install    --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  kiali-operator/
helm upgrade    --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  kiali-operator/
helm uninstall  --kube-context=kind-c1  --namespace istio-system  kiali-operator-1 
```

## docker build
```
docker build -t quay.io/kiali/kiali:v1.49.0-2 .
```

## kind load image to node
```
kind load docker-image quay.io/kiali/kiali-operator:v1.87.0 --name c1
kind load docker-image quay.io/kiali/kiali:v1.87.0 --name c1
```

## start vscode
```
sudo code --no-sandbox --user-data-dir="/path/to/your/directory"
```

## force delete namespace
```
k1 get namespace istio-system -o json | jq '.spec.finalizers=[]' | k1 replace --raw "/api/v1/namespaces/istio-system/finalize" -f -
```

## test/istio consistent hash
```
k1 -n sample exec -it helloworld-v1-77cb56d4b4-svsnl -- curl -s helloworld.sample3.svc.cluster.local:5000/hello
k1 -n sample exec -it helloworld-v1-77cb56d4b4-svsnl -- curl -s -H "X-User: abc" helloworld.sample3.svc.cluster.local:5000/hello
```

## metallb 
```
docker network inspect -f '{{.IPAM.Config}}' kind
curl 172.18.0.100
```

## perf-tests/clusterloader2
install gvm
```
sudo apt-get install bison
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
gvm install go1.15.12
gvm use go1.15.12
go run cmd/clusterloader.go --testconfig=config.yaml --provider=kind --kubeconfig=${HOME}/.kube/config --v=2
```
remove gvm
```
rm -rf ~/.gvm
vim ~/.bashrc 
search keywords(gvm) and remove [[ -s "$GVM_ROOT/scripts/gvm" ]] && source "$GVM_ROOT/scripts/gvm"
source ~/.bashrc  
```

## switch mode (sidecar/ambient)
開啟 ambient mode (namespace level)
```
k1 label ns sample istio.io/dataplane-mode=ambient
k1 label ns sample istio.io/use-waypoint=waypoint
k1 -n sample apply -f waypoint-gateway.yaml
```
關閉 ambient mode (namespace level)
```
k1 label ns sample istio.io/dataplane-mode-
k1 label ns sample istio.io/use-waypoint-
k1 -n sample delete -f waypoint-gateway.yaml
k1 -n sample delete po --all
```
開啟 sidecar mode (namespace level)
```
k1 label ns sample istio.io/rev=1-24-0
k1 -n sample delete po --all
```
關閉 sidecar mode (namespace level)
```
k1 label ns sample istio.io/rev-
k1 -n sample delete po --all
```

## Show Git branch
```
function git_branch {
   branch="`git branch 2>/dev/null | grep "^\*" | sed -e "s/^\*\ //"`"
   if [ "${branch}" != "" ];then
       if [ "${branch}" = "(no branch)" ];then
           branch="(`git rev-parse --short HEAD`...)"
       fi
       echo " ($branch)"
   fi
}

export PS1='\u@\h \[\033[01;36m\]\W\[\033[01;32m\]$(git_branch)\[\033[00m\] \$ '
```

## 產生tls secret
```
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=ngx-service.app.c3.dev.com/O=MyOrganization

ls -l tls.crt tls.key

openssl x509 -in tls.crt -text -noout

kubectl -n test create secret tls ngx-service-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n test 
```

## others
```
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec": {"type": "LoadBalancer"}}'
istioctl x uninstall --revision=1-17-3
code --no-sandbox --user-data-dir="/path/to/your/directory"
git push -u origin 12-feat-develop
```