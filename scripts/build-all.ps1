# Universal Video Studio - Build All (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "          Universal Video Studio - Build All" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Compile Rust Core Release Library
Write-Host "`n>>> [1/2] Compiling Rust Core (Release)..." -ForegroundColor Yellow
Push-Location "$root\core\rust"
try {
    cargo build --release
} finally {
    Pop-Location
}
Write-Host "[PASS] Rust Core compiled to target/release." -ForegroundColor Green

# 2. Build Flutter Asset Bundle in Container
Write-Host "`n>>> [2/2] Building Flutter App Bundle..." -ForegroundColor Yellow
podman run --rm -v "${root}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter build bundle"
Write-Host "[PASS] Flutter Asset Bundle built." -ForegroundColor Green

Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host "  ALL BUILDS COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
