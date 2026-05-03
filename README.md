# kind-create-cluster

---

#### Directory Structure

```
kind-create-cluster/
├── Docker/   # Resources related to Docker
├── config/   # Kubernetes configuration files
├── samples/  # Example YAML files
├── scripts/  # Automation scripts
├── tools/    # Utilities or helper programs
└── README.md # Project documentation
```

#### Getting Started

1. **Update Configurations**  
   Modify `config/config.env` to set the required versions for **Kind**, **Istio**, **Kiali**, and other components.

2. **Run via Makefile** (recommended)

   | Command | Description |
   |---|---|
   | `make c1-sidecar` | Single cluster (c1) with sidecar mode Istio |
   | `make c1c2-singlenet` | Dual clusters (c1 + c2) with sidecar mode Istio multi-primary mesh (single network) |
   | `make c1c2-install-ewgw` | Build dual clusters and install istio-eastwestgateway (includes c1c2-singlenet) |
   | `make clean` | Delete all kind clusters and clear download cache |

3. **Or run the script directly**
   ```
   # single cluster
   ./scripts/main.sh

   # dual cluster single network — set cluster_mode=multi in config/config.env first
   ./scripts/main.sh
   ```

#### Cluster Architecture

**c1c2-singlenet** (single network, direct pod-to-pod routing)
```
c1 (kind-c1)                        c2 (kind-c2)
podSubnet: 172.18.10.0/24           podSubnet: 172.18.11.0/24
meshID: mesh1                       meshID: mesh1
clusterName: cluster1               clusterName: cluster2
network: network1                   network: network1
          ↕  cross-cluster remote secret (mesh.sh)
          ↕  static pod-subnet routes → direct pod-to-pod
```

**c1c2-install-ewgw** (multi-network, traffic via east-west gateway)
```
c1 (kind-c1)                        c2 (kind-c2)
podSubnet: 172.18.10.0/24           podSubnet: 172.18.11.0/24
meshID: mesh1                       meshID: mesh1
clusterName: cluster1               clusterName: cluster2
network: network1                   network: network2
          ↕  cross-cluster remote secret (mesh.sh)
          ↕  cross-cluster traffic → east-west gateway:15443
```

#### Verify Istio Mesh (c1/c2)

**1. Check istiod status**
```bash
kubectl --context kind-c1 get pod -n istio-system -l app=istiod
kubectl --context kind-c2 get pod -n istio-system -l app=istiod
```

**2. Check sidecar injection (pods should be 2/2)**
```bash
kubectl --context kind-c1 get pod -n istio-validation
kubectl --context kind-c2 get pod -n istio-validation
```

**3. Check remote secrets (cross-cluster discovery)**
```bash
kubectl --context kind-c1 get secret -n istio-system istio-remote-secret-cluster2
kubectl --context kind-c2 get secret -n istio-system istio-remote-secret-cluster1
```

**4. Verify shared root CA**
```bash
kubectl --context kind-c1 -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}' > /tmp/c1-root.pem
kubectl --context kind-c2 -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}' > /tmp/c2-root.pem
cmp /tmp/c1-root.pem /tmp/c2-root.pem && echo "OK: cacerts identical" || echo "FAIL: cacerts differ"
```

**5. Cross-cluster routing test (c1 → helloworld, expect v1/v2 alternating)**
```bash
for i in $(seq 1 10); do
  kubectl --context kind-c1 exec -n istio-validation deploy/sleep -- curl -s helloworld.istio-validation.svc.cluster.local:5000/hello
done
```

**6. Reverse test (c2 → helloworld)**
```bash
for i in $(seq 1 10); do
  kubectl --context kind-c2 exec -n istio-validation deploy/sleep -- curl -s helloworld.istio-validation.svc.cluster.local:5000/hello
done
```

#### Verify East-West Gateway — c1c2-install-ewgw only

**1. Confirm Envoy routes c2 traffic through port 15443 (no installation required)**
```bash
kubectl --context kind-c1 exec -n istio-validation deploy/sleep -c istio-proxy -- \
  curl -s localhost:15000/clusters | grep helloworld | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' | sort -u
```
Expected: one entry at `<pod-ip>:5000` (c1 local) and one at `<ewgw-ip>:15443` (c2 via east-west gateway).

**2. tcpdump — Method A: install on kind node**

Terminal 1 (start capture on c2 node):
```bash
docker exec c2-control-plane bash -c "apt-get update -qq && apt-get install -y tcpdump -qq"
docker exec -it c2-control-plane tcpdump -i any port 15443 -nn
```

Terminal 2 (generate traffic):
```bash
for i in $(seq 1 20); do
  kubectl --context kind-c1 exec -n istio-validation deploy/sleep -- \
    curl -s helloworld.istio-validation.svc.cluster.local:5000/hello
done
```

**3. tcpdump — Method B: kubectl debug node (no installation required)**
```bash
kubectl --context kind-c2 debug node/c2-control-plane \
  -it --image=nicolaka/netshoot \
  -- tcpdump -i any port 15443 -nn
```

Expected tcpdump output:
```
IP 172.18.10.x.xxxxx > 172.18.0.x.15443: Flags [S]    ← SYN (c1 pod → c2 ewgw)
IP 172.18.0.x.15443 > 172.18.10.x.xxxxx: Flags [S.]   ← SYN-ACK
IP 172.18.10.x.xxxxx > 172.18.0.x.15443: Flags [.]    ← ACK (mTLS handshake)
```

> **Note**: run tcpdump on **c2 node**, not c1 — the destination of cross-cluster traffic is c2's east-west gateway.

#### Graceful Drain Test — long-lived connection behavior

See [issue #30](https://github.com/benchen149/kind-create-cluster/issues/30) for the full graceful drain test procedure (MySQL long-lived connection, Phase 1/2/3 steps, and key findings).

#### Frequently used commands
```
# kind version is defined in config/config.env (kind_version)
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-amd64
wget "https://github.com/istio/istio/releases/download/1.25.5/istio-1.25.5-linux-amd64.tar.gz" -O - | tar -xz 
cp tools/istio/certs/cluster1-1.24.0.yaml  .
mv cluster1-1.24.0.yaml cluster-1.24.0.yaml
istioctl install -y -f cluster-1.24.0.yaml

```

#### kiali/prometheus
```
kubectl --context kind-c1 port-forward svc/kiali -n istio-system 20001:20001
http://localhost:20001/kiali
istioctl  --context kind-c1 dashboard prometheus
```

#### List all prometheuse metrics
```
http://localhost:9090/api/v1/label/__name__/values
```

#### helm install/upgrade/uninstall
```
helm install    --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  kiali-operator/
helm upgrade    --kube-context=kind-c1  --namespace=istio-system --create-namespace kiali-operator-1  kiali-operator/
helm uninstall  --kube-context=kind-c1  --namespace istio-system  kiali-operator-1 
```

#### docker build
```
docker build -t quay.io/kiali/kiali:v1.49.0-2 .
```

#### kind load image to node
```
kind load docker-image quay.io/kiali/kiali-operator:v1.87.0 --name c1
kind load docker-image quay.io/kiali/kiali:v1.87.0 --name c1
```

#### start vscode
```
sudo code --no-sandbox --user-data-dir="/path/to/your/directory"
```

#### force delete namespace
```
k1 get namespace istio-system -o json | jq '.spec.finalizers=[]' | k1 replace --raw "/api/v1/namespaces/istio-system/finalize" -f -
```

#### test/istio consistent hash
```
k1 -n istio-validation exec -it helloworld-v1-77cb56d4b4-svsnl -- curl -s helloworld.sample3.svc.cluster.local:5000/hello
k1 -n istio-validation exec -it helloworld-v1-77cb56d4b4-svsnl -- curl -s -H "X-User: abc" helloworld.sample3.svc.cluster.local:5000/hello
```

#### metallb 
```
docker network inspect -f '{{.IPAM.Config}}' kind
curl 172.18.0.100
```

#### perf-tests/clusterloader2
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

#### switch mode (sidecar/ambient)
開啟 ambient mode (namespace level)
```
k1 label ns istio-validation istio.io/dataplane-mode=ambient
k1 label ns istio-validation istio.io/use-waypoint=waypoint
k1 -n istio-validation apply -f waypoint-gateway.yaml
```
關閉 ambient mode (namespace level)
```
k1 label ns istio-validation istio.io/dataplane-mode-
k1 label ns istio-validation istio.io/use-waypoint-
k1 -n istio-validation delete -f waypoint-gateway.yaml
k1 -n istio-validation delete po --all
```
開啟 sidecar mode (namespace level)
```
k1 label ns istio-validation istio.io/rev=1-24-0
k1 -n istio-validation delete po --all
```
關閉 sidecar mode (namespace level)
```
k1 label ns istio-validation istio.io/rev-
k1 -n istio-validation delete po --all
```

#### Show Git branch
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

#### 產生tls secret
```
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=ngx-service.app.c3.dev.com/O=MyOrganization

ls -l tls.crt tls.key

openssl x509 -in tls.crt -text -noout

kubectl -n istio-validation create secret tls ngx-service-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n istio-validation 
```

#### others
```
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec": {"type": "LoadBalancer"}}'
istioctl x uninstall --revision=1-17-3
code --no-sandbox --user-data-dir="/path/to/your/directory"
```
