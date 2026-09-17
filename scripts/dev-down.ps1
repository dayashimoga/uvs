# Universal Video Studio - Dev Down (PowerShell)
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Stopping and removing Podman development container..." -ForegroundColor Cyan
podman stop uvs_dev
podman rm uvs_dev
Write-Host ">>> Dev environment stopped cleanly." -ForegroundColor Green
