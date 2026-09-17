#!/usr/bin/env bash
# Universal Video Studio - Benchmark (POSIX)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 "${ROOT_DIR}/tests/benchmarks.py"
