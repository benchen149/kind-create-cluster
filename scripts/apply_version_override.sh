#!/usr/bin/env bash
set -e

abspath=$(cd "$(dirname "$0")/.."; pwd)
OVERRIDE_FILE="$abspath/config/.override.env"
cluster_mode="$2"

# Always wipe stale override first (next bare `make` restores defaults)
rm -f "$OVERRIDE_FILE"

# No istio override requested: still record cluster_mode (if any) so the
# Makefile never has to mutate the git-tracked config.env.
if [[ -z "$1" ]]; then
    [[ -n "$cluster_mode" ]] && echo "cluster_mode=$cluster_mode" > "$OVERRIDE_FILE"
    exit 0
fi

source "$abspath/config/version-matrix.sh"

resolved=$(resolve_istio_versions "$1") || {
    echo "Error: unsupported Istio version '$1'"
    echo "Supported versions: $(supported_istio_versions)"
    exit 1
}

read -r kind_ver node_img kubectl_ver <<< "$resolved"
istio_label="${1//./-}"

# Auto-clean when switching away from the current default
current_istio=$(sed -n 's/^istio_version=\([^[:space:]#]*\).*/\1/p' \
    "$abspath/config/config.env" | head -1)
if [[ -n "$current_istio" && "$current_istio" != "$1" ]]; then
    echo "Istio version changed ($current_istio → $1), running make clean …"
    make -C "$abspath" clean
fi

cat > "$OVERRIDE_FILE" <<EOF
istio_version=$1
export istio_label=$istio_label
kind_version=$kind_ver
node_image="$node_img"
kubectl_version=$kubectl_ver
EOF
[[ -n "$cluster_mode" ]] && echo "cluster_mode=$cluster_mode" >> "$OVERRIDE_FILE"

echo "Version override: Istio $1 / kind $kind_ver / K8s ${node_img##*:} / kubectl $kubectl_ver"
