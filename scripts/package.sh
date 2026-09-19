#!/usr/bin/env bash
# Universal Video Studio - Canonical Linux Packaging & Release Verifier
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "${DIST_DIR}"

echo "=================================================================="
echo "   Universal Video Studio - Linux Canonical Packaging Pipeline"
echo "=================================================================="

# 1. Locate Flutter Linux Release Bundle
BUNDLE_DIR=""
for cand in "${ROOT_DIR}/apps/flutter_app/build/linux/x64/release/bundle" "${ROOT_DIR}/apps/flutter_app/build/linux/release/bundle"; do
    if [ -d "${cand}" ] && ([ -f "${cand}/uvs" ] || [ -f "${cand}/universal_video_studio" ]); then
        BUNDLE_DIR="${cand}"
        break
    fi
done

if [ -z "${BUNDLE_DIR}" ]; then
    echo ">>> Flutter Linux release bundle not found. Attempting build..."
    (cd "${ROOT_DIR}/apps/flutter_app" && flutter build linux --release) || true
    for cand in "${ROOT_DIR}/apps/flutter_app/build/linux/x64/release/bundle" "${ROOT_DIR}/apps/flutter_app/build/linux/release/bundle"; do
        if [ -d "${cand}" ] && ([ -f "${cand}/uvs" ] || [ -f "${cand}/universal_video_studio" ]); then
            BUNDLE_DIR="${cand}"
            break
        fi
    done
fi

if [ -z "${BUNDLE_DIR}" ] || ([ ! -f "${BUNDLE_DIR}/uvs" ] && [ ! -f "${BUNDLE_DIR}/universal_video_studio" ]); then
    echo -e "\n[FAIL / HARDWARE-REQUIRED] Canonical Linux Flutter executable (uvs / universal_video_studio) not found."
    echo "Linux desktop Flutter development requires clang, cmake, ninja, and GTK3 libraries."
    echo "This step compiles and packages automatically on GitHub Actions 'ubuntu-latest' runner."
    echo "Refusing to create a fake or truncated archive."
    exit 1
fi

echo "[OK] Found Flutter Linux Release bundle: ${BUNDLE_DIR}"

# 2. Stage complete package
STAGING_DIR="${DIST_DIR}/linux_pkg_staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo ">>> Staging canonical application bundle..."
cp -r "${BUNDLE_DIR}/"* "${STAGING_DIR}/"

# Ensure both binary aliases exist
if [ -f "${STAGING_DIR}/universal_video_studio" ] && [ ! -f "${STAGING_DIR}/uvs" ]; then
    cp "${STAGING_DIR}/universal_video_studio" "${STAGING_DIR}/uvs"
elif [ -f "${STAGING_DIR}/uvs" ] && [ ! -f "${STAGING_DIR}/universal_video_studio" ]; then
    cp "${STAGING_DIR}/uvs" "${STAGING_DIR}/universal_video_studio"
fi

# Copy Rust native core engine
mkdir -p "${STAGING_DIR}/lib"
RUST_SO="${ROOT_DIR}/core/rust/target/release/libuvs_core.so"
if [ ! -f "${RUST_SO}" ]; then
    echo ">>> Compiling Rust core release shared object..."
    (cd "${ROOT_DIR}/core/rust" && cargo build --release)
fi

if [ -f "${RUST_SO}" ]; then
    cp "${RUST_SO}" "${STAGING_DIR}/lib/"
    echo "[OK] Bundled libuvs_core.so into lib/ directory."
else
    echo "[FAIL] libuvs_core.so could not be found or built!"
    exit 1
fi

# Copy metadata
[ -f "${DIST_DIR}/uvs_sbom.json" ] && cp "${DIST_DIR}/uvs_sbom.json" "${STAGING_DIR}/"
[ -f "${ROOT_DIR}/README.md" ] && cp "${ROOT_DIR}/README.md" "${STAGING_DIR}/"
[ -f "${ROOT_DIR}/LICENSE" ] && cp "${ROOT_DIR}/LICENSE" "${STAGING_DIR}/"

# 3. Mandatory assertions
MANDATORY_ITEMS=("uvs" "lib/libflutter_linux_gtk.so" "lib/libuvs_core.so" "data")
for item in "${MANDATORY_ITEMS[@]}"; do
    if [ ! -e "${STAGING_DIR}/${item}" ]; then
        echo "[FATAL] Mandatory release component missing: ${item}"
        rm -rf "${STAGING_DIR}"
        exit 1
    fi
done
echo "[PASS] All mandatory Linux runtime components verified."

# 4. Generate Manifest with SHA-256
echo ">>> Generating MANIFEST.txt..."
(cd "${STAGING_DIR}" && find . -type f -exec sha256sum {} + | sort > MANIFEST.txt)

# 5. Compress Archive
LINUX_PKG="${DIST_DIR}/universal_video_studio_linux_x64.tar.gz"
rm -f "${LINUX_PKG}"
echo ">>> Compressing archive to ${LINUX_PKG}..."
tar -czf "${LINUX_PKG}" -C "${DIST_DIR}" linux_pkg_staging
rm -rf "${STAGING_DIR}"

# 6. Validate Archive Size
ARCHIVE_SIZE=$(stat -c %s "${LINUX_PKG}" 2>/dev/null || stat -f %z "${LINUX_PKG}")
echo "[OK] Created: ${LINUX_PKG} ($((ARCHIVE_SIZE / 1048576)) MB)"

if [ "${ARCHIVE_SIZE}" -lt 15000000 ]; then
    echo "[FATAL] Archive size is suspicious (${ARCHIVE_SIZE} bytes < 15 MB). Packaging rejected!"
    exit 1
fi

sha256sum "${LINUX_PKG}" > "${DIST_DIR}/SHA256SUMS_linux"
echo "[CERTIFIED PASS] Linux Release Package Built & Verified Successfully."
