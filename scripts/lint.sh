#!/usr/bin/env bash
# Universal Video Studio - Lint (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ">>> [1/2] Checking Rust linter..."
(cd "${ROOT_DIR}/core/rust" && cargo clippy -- -D warnings)

echo ">>> [2/2] Checking Flutter linter in Container..."
podman run --rm -v "${ROOT_DIR}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter analyze"

echo "[PASS] Lint checks passed."
