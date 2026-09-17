#!/usr/bin/env bash
# Universal Video Studio - Test All (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================="
echo "       Universal Video Studio - Comprehensive Test Suite"
echo "========================================================="

echo -e "\n>>> [1/4] Running Rust Core Tests..."
(cd "${ROOT_DIR}/core/rust" && cargo test --all-targets)

echo -e "\n>>> [2/4] Running Flutter Tests in Container..."
podman run --rm -v "${ROOT_DIR}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter test"

echo -e "\n>>> [3/4] Running End-to-End Media Tests..."
python3 "${ROOT_DIR}/tests/e2e_media_tests.py"

echo -e "\n>>> [4/4] Running Performance Benchmarks..."
python3 "${ROOT_DIR}/tests/benchmarks.py"

echo -e "\n========================================================="
echo "  ALL TESTS PASSED SUCCESSFULLY (100% Pass Rate)"
echo "========================================================="
