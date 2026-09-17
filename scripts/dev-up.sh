#!/usr/bin/env bash
# Universal Video Studio - Dev Up (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ">>> Starting Podman development container..."
if podman ps -q --filter "name=uvs_dev" | grep -q .; then
    echo "Container 'uvs_dev' is already running."
else
    if podman ps -a -q --filter "name=uvs_dev" | grep -q .; then
        podman start uvs_dev
    else
        podman run -d --name uvs_dev -v "${ROOT_DIR}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" ghcr.io/cirruslabs/flutter:3.24.3 sleep infinity
    fi
    echo "Container 'uvs_dev' started."
fi
