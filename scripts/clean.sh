#!/usr/bin/env bash
# Universal Video Studio - Clean (POSIX)
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ">>> Cleaning temporary build artifacts..."
rm -rf "${ROOT_DIR}/core/rust/target"
rm -rf "${ROOT_DIR}/apps/flutter_app/.dart_tool"
rm -rf "${ROOT_DIR}/apps/flutter_app/build"
rm -rf "${ROOT_DIR}/tests/output"
rm -rf "${ROOT_DIR}/dist"
echo ">>> Clean complete."
