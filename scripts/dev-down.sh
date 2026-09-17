#!/usr/bin/env bash
# Universal Video Studio - Dev Down (POSIX)
set +e
echo ">>> Stopping and removing Podman development container..."
podman stop uvs_dev 2>/dev/null || true
podman rm uvs_dev 2>/dev/null || true
echo ">>> Dev environment stopped."
