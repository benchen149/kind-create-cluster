#!/usr/bin/env bash
# Returns space-separated: kind_version node_image kubectl_version
# Exits 1 for unknown versions.

resolve_istio_versions() {
    case "$1" in
        1.13.5) echo "v0.14.0 kindest/node:v1.23.6 v1.23.17"   ;;
        1.24.0) echo "v0.30.0 kindest/node:v1.31.12 v1.31.6"   ;;
        1.29.4) echo "v0.30.0 kindest/node:v1.34.0 v1.34.8"    ;;
        *)      return 1 ;;
    esac
}

supported_istio_versions() {
    echo "1.13.5  1.24.0  1.29.4"
}
