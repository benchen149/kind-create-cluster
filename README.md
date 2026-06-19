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

   Current recommended versions:

   | Component | Version | Kubernetes |
   |---|---|---|
   | kind | v0.30.0 | v1.34.0 |
   | Istio | 1.29.4 | 1.31 – 1.35 |
   | Kiali | v1.49.0 | — |

   **Version matrix — how `kind_version` / `node_image` / `istio_version` / `kubectl_version` fit together**

   The four version knobs in `config/config.env` are independent but constrained by each
   other. The rules:

   - `kind_version` selects only the kind **binary**; it does *not* fix the cluster
     Kubernetes version.
   - `node_image` fixes the cluster Kubernetes version. It must be an image the installed
     kind binary supports — kind v0.30.0 ships `v1.34.0` / `v1.33.4` / `v1.32.8` /
     `v1.31.12`. Leave it empty to fall back to the kind binary's default (see fall-back
     table below).
   - `node_image`'s Kubernetes version must sit inside the target Istio's
     [supported range](https://istio.io/latest/docs/releases/supported-releases/).
   - `istio_label` **must equal** `istio_version` (dots → dashes, e.g. `1.29.4` →
     `1-29-4`); always change the two together.
   - `kubectl_version` should track `node_image`'s Kubernetes minor (skew tolerates ±1).

   Vetted combinations (all on kind v0.30.0):

   | kind_version | istio_version | istio_label | node_image (K8s) | Istio-supported K8s | kubectl_version |
   |---|---|---|---|---|---|
   | v0.30.0 | 1.29.4 | 1-29-4 | `kindest/node:v1.34.0` | 1.31 – 1.35 | v1.34.8 |
   | v0.30.0 | 1.24.0 | 1-24-0 | `kindest/node:v1.31.12` | 1.28 – 1.31 | v1.31.x |

   Fall-back default `node_image` when `node_image` is left empty (`scripts/create_cluster.sh`):

   | kind_version | default node_image |
   |---|---|
   | v0.30.0 | `kindest/node:v1.34.0` |
   | v0.26.0 | `kindest/node:v1.29.2` |
   | v0.23.0 | `kindest/node:v1.27.3` |
   | v0.14.0 | `kindest/node:v1.24.0` |

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

#### Claude Commands — Development Workflow

此專案提供 Claude Code slash commands，讓任何新的開發環境都能快速完成環境設定並遵循統一的開發流程。

| Command | 說明 |
|---|---|
| `/setup-github-ssh` | 新環境一次性設定：SSH key 產生、GitHub 綁定、gh CLI 登入（含安全規範） |
| `/github-flow` | 完整開發流程：issue → branch → commit → PR → merge |

**建議順序（新環境第一次）：**
```
1. /setup-github-ssh   # 完成 SSH + gh CLI 認證設定
2. /github-flow        # 開始功能開發
```

詳細步驟請參考 `.claude/commands/` 目錄下的對應 `.md` 檔案。

---

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

**5. Verify cross-cluster traffic (c1 → helloworld, expect v1/v2 alternating)**

依 Istio 官方 [Verifying Cross-Cluster Traffic](https://istio.io/latest/docs/setup/install/multicluster/verify/)：從 `sleep` pod 重複呼叫 `helloworld:5000/hello`，請求會被負載平衡到 **兩個 cluster** 的 `helloworld` 實例，回應的 `version` 應在 `v1`（c1）與 `v2`（c2）之間交替。

```bash
for i in $(seq 1 10); do
  kubectl --context kind-c1 exec -n istio-validation deploy/sleep -- curl -s helloworld.istio-validation.svc.cluster.local:5000/hello
done
```
Expected（v1 / v2 交替出現，instance 為各 cluster 的 pod 名）：
```
Hello version: v1, instance: helloworld-v1-xxxxxxxxxx-xxxxx
Hello version: v2, instance: helloworld-v2-xxxxxxxxxx-xxxxx
...
```

**6. Reverse test (c2 → helloworld, expect v1/v2 alternating)**
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

#### Graceful Drain Test — long-lived connection behavior (issue #30)

Verify that existing connections persist through port 15443 after removing the topology label,
and that restarting the ewgw pod forcefully breaks them.

**Deploy test resources**
```bash
# c2 — MySQL server
kubectl --context kind-c2 apply -n istio-validation -f samples/ewgw/mysql-server.yaml

# c1 — mysql client pod + Service stub (enables cross-cluster DNS resolution)
kubectl --context kind-c1 apply -n istio-validation -f samples/ewgw/mysql-client.yaml
kubectl --context kind-c1 apply -n istio-validation -f samples/ewgw/mysql-service-c1.yaml

kubectl --context kind-c2 rollout status deployment/mysql -n istio-validation --timeout=120s
kubectl --context kind-c1 rollout status deployment/mysql-client -n istio-validation --timeout=120s
```

**Check how many connections are active through ewgw**
```bash
kubectl --context kind-c2 exec -n istio-system deploy/istio-eastwestgateway -c istio-proxy -- \
  ss -tn state established | grep ':15443' | wc -l
```

**Phase 1 — establish long-lived connection and confirm routing via 15443**

Terminal A (tcpdump):
```bash
docker exec -it c2-control-plane tcpdump -i any port 15443 -nn
```

Terminal B (long-running query):
```bash
kubectl --context kind-c1 exec -n istio-validation deploy/mysql-client -c client -- \
  mysql -h mysql.istio-validation.svc.cluster.local -uroot -proot \
  -e "SELECT '=== start ==='; SELECT SLEEP(120); SELECT '=== end ===';"
```

**Phase 2 — remove topology label (graceful drain step 1)**
```bash
# Stop new connections from entering ewgw
kubectl --context kind-c2 label service istio-eastwestgateway \
  -n istio-system topology.istio.io/network-

# Confirm new endpoint is now direct pod IP
kubectl --context kind-c1 exec -n istio-validation deploy/mysql-client -c client -- \
  curl -s localhost:15000/clusters | grep mysql | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' | sort -u
```

| Observation | Expected |
|---|---|
| Terminal A tcpdump | Existing connection still shows 15443 packets |
| Envoy cluster stats | New endpoint changed to `pod-ip:3306` |
| MySQL PROCESSLIST | SLEEP query still running |
| `ss \| grep 15443 \| wc -l` | Still > 0 until SLEEP ends |

**Phase 3 — restart ewgw pod (force disconnect)**
```bash
# Re-add label first so reconnection goes through ewgw (for test purposes)
kubectl --context kind-c2 label service istio-eastwestgateway \
  -n istio-system topology.istio.io/network=network2

# Start another SLEEP, then restart pod
kubectl --context kind-c2 rollout restart deployment/istio-eastwestgateway -n istio-system
```

| Observation | Expected |
|---|---|
| MySQL PROCESSLIST | SLEEP session disappears within 5s (TCP RST after terminationDrainDuration) |
| Terminal B | `ERROR 2013: Lost connection to MySQL server` |

**Key findings**

| Action | Effect on existing connections |
|---|---|
| Remove topology label | Connections persist until naturally closed (safe for graceful drain) |
| `rollout restart` ewgw pod | Connections broken within `terminationDrainDuration` (default 5s) |

**Correct graceful drain sequence**
```
1. Remove topology label      → stop new traffic entering ewgw
2. Wait: ss | grep 15443 | wc -l == 0   → all connections drained
3. rollout restart / scale 0  → safe to remove pod, no active connections
```

#### Frequently used commands
```
# kind version is defined in config/config.env (kind_version)
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-amd64
wget "https://github.com/istio/istio/releases/download/1.29.4/istio-1.29.4-linux-amd64.tar.gz" -O - | tar -xz 
cp tools/istio/operator/cluster.yaml  .
# 統一檔需帶入 cluster 差異參數再 envsubst（c1 範例：cluster1 / network1）
istio_label=1-29-4 CLUSTER_NAME=cluster1 NETWORK_NAME=network1 \
  envsubst '$istio_label $CLUSTER_NAME $NETWORK_NAME' < cluster.yaml | istioctl install -y -f -

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

#### 產生 tls secret(私鑰不入 repo,動態產生)
demo 憑證改由腳本動態產生,私鑰不再保存於 repo:
```
# 一鍵產生自簽憑證並建立 secret
# 預設 host=ngx-service.app.c3.dev.com, namespace=test, secret=ngx-service-tls
bash samples/ingress/gen-tls.sh

# 自訂參數: bash samples/ingress/gen-tls.sh <host> <namespace> <secret-name>
```

#### others
```
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec": {"type": "LoadBalancer"}}'
istioctl x uninstall --revision=1-17-3
code --no-sandbox --user-data-dir="/path/to/your/directory"
```
