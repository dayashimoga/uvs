#!/usr/bin/env bash
# Universal Video Studio - Package (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "${DIST_DIR}"
echo ">>> Packaging Linux & Cross-platform archives..."

LINUX_PKG="${DIST_DIR}/universal_video_studio_linux_x64.tar.gz"
tar -czf "${LINUX_PKG}" -C "${ROOT_DIR}" README.md core/rust/Cargo.toml apps/flutter_app/pubspec.yaml

sha256sum "${LINUX_PKG}" > "${DIST_DIR}/SHA256SUMS_linux"
echo "[SUCCESS] Created: ${LINUX_PKG}"
