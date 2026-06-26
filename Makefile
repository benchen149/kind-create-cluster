.PHONY: help c1-sidecar c1c2-singlenet c1c2-install-ewgw clean

help:
	@echo "Usage:"
	@echo "  make c1-sidecar          Create single cluster (c1) with sidecar mode Istio"
	@echo "  make c1c2-singlenet      Create dual clusters (c1 + c2) with sidecar mode Istio multi-primary mesh (single network)"
	@echo "  make c1c2-install-ewgw   Install istio-eastwestgateway on c1 and c2 clusters"
	@echo "  make clean               Delete all kind clusters and clear download cache"

c1-sidecar:
	@sed -i 's/^cluster_mode=.*/cluster_mode=single/' config/config.env
	@bash scripts/apply_version_override.sh "$(istio)"
	bash scripts/main.sh

c1c2-singlenet:
	@sed -i 's/^cluster_mode=.*/cluster_mode=multi/' config/config.env
	@bash scripts/apply_version_override.sh "$(istio)"
	bash scripts/main.sh

c1c2-install-ewgw: c1c2-singlenet
	bash scripts/install_eastwestgateway.sh

clean:
	kind delete cluster --name c1 2>/dev/null || true
	kind delete cluster --name c2 2>/dev/null || true
	rm -rf /tmp/download/*
