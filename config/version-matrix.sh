#!/usr/bin/env bash
# Returns space-separated: kind_version node_image kubectl_version
# Exits 1 for unknown versions.

resolve_istio_versions() {
    case "$1" in
        1.13.5)  echo "v0.14.0 kindest/node:v1.23.6 v1.23.17"   ;;
        1.24.0)  echo "v0.30.0 kindest/node:v1.31.12 v1.31.6"   ;;
        1.29.4)  echo "v0.32.0 kindest/node:v1.34.8 v1.34.8"    ;;
        # Candidate — derived from Istio's supported-K8s table, not yet cluster-tested
        # in this repo. See README.md "Extending the matrix" for how these were picked.
        1.25.5)  echo "v0.30.0 kindest/node:v1.31.12 v1.31.12"  ;;
        1.26.8)  echo "v0.30.0 kindest/node:v1.32.8 v1.32.8"    ;;
        1.27.9)  echo "v0.30.0 kindest/node:v1.32.8 v1.32.8"    ;;
        1.28.10) echo "v0.30.0 kindest/node:v1.32.8 v1.32.8"    ;;
        *)       return 1 ;;
    esac
}

supported_istio_versions() {
    echo "1.13.5  1.24.0  1.29.4  1.25.5  1.26.8  1.27.9  1.28.10"
}
