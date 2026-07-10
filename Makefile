SHELL := /bin/bash
LOG_DIR ?= /tmp/kind-create-cluster-logs

.PHONY: help c1-sidecar c1c2-singlenet c1c2-install-ewgw clean \
	_c1-sidecar _c1c2-singlenet _c1c2-install-ewgw

# Wrap $(2) (the real target) with tee-to-timestamped-log-file, preserving
# real-time terminal output and the underlying command's exit code.
define run_logged
	@mkdir -p "$(LOG_DIR)"
	@_f="$(LOG_DIR)/$(1)-$(if $(istio),$(istio),default)-$(shell date +%Y%m%d-%H%M%S).log"; \
	 printf "[log] $$_f\n"; \
	 $(MAKE) --no-print-directory $(2) istio=$(istio) 2>&1 | tee "$$_f"; \
	 _rc=$${PIPESTATUS[0]}; printf "[log saved] $$_f\n"; exit $$_rc
endef

help:
	@echo "Usage:"
	@echo "  make c1-sidecar          Create single cluster (c1) with sidecar mode Istio"
	@echo "  make c1c2-singlenet      Create dual clusters (c1 + c2) with sidecar mode Istio multi-primary mesh (single network)"
	@echo "  make c1c2-install-ewgw   Install istio-eastwestgateway on c1 and c2 clusters"
	@echo "  make clean               Delete all kind clusters and clear download cache"
	@echo ""
	@echo "Each run is teed to a timestamped log file under $(LOG_DIR) (override with LOG_DIR=...)."

c1-sidecar:
	$(call run_logged,c1-sidecar,_c1-sidecar)

c1c2-singlenet:
	$(call run_logged,c1c2-singlenet,_c1c2-singlenet)

c1c2-install-ewgw:
	$(call run_logged,c1c2-install-ewgw,_c1c2-install-ewgw)

_c1-sidecar:
	@bash scripts/apply_version_override.sh "$(istio)" single
	bash scripts/main.sh

_c1c2-singlenet:
	@bash scripts/apply_version_override.sh "$(istio)" multi
	bash scripts/main.sh

_c1c2-install-ewgw: _c1c2-singlenet
	bash scripts/install_eastwestgateway.sh

clean:
	kind delete cluster --name c1 2>/dev/null || true
	kind delete cluster --name c2 2>/dev/null || true
	rm -rf /tmp/download/*
