#!/usr/bin/env bash
# Universal Video Studio - Build All (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================="
echo "          Universal Video Studio - Build All"
echo "========================================================="

echo -e "\n>>> [1/2] Compiling Rust Core (Release)..."
(cd "${ROOT_DIR}/core/rust" && cargo build --release)

echo -e "\n>>> [2/2] Building Flutter App Bundle in Container..."
podman run --rm -v "${ROOT_DIR}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter build bundle"

echo -e "\n========================================================="
echo "  ALL BUILDS COMPLETED SUCCESSFULLY"
echo "========================================================="
