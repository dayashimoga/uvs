# Universal Video Studio - Lint (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
Write-Host ">>> [1/2] Checking Rust code style & clippy..." -ForegroundColor Yellow
Push-Location "$root\core\rust"
try {
    cargo clippy -- -D warnings
} finally {
    Pop-Location
}
Write-Host "[PASS] Rust linter clean." -ForegroundColor Green

Write-Host "`n>>> [2/2] Checking Flutter/Dart analysis..." -ForegroundColor Yellow
podman run --rm -v "${root}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter analyze"
Write-Host "[PASS] Flutter analyze clean." -ForegroundColor Green
