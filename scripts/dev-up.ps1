# Universal Video Studio - Dev Up (PowerShell)
$ErrorActionPreference = "Stop"

Write-Host ">>> Starting Podman development container environment..." -ForegroundColor Cyan

# Check if container is already running
$running = podman ps -q --filter "name=uvs_dev"
if ($running) {
    Write-Host "Container 'uvs_dev' is already running." -ForegroundColor Green
} else {
    $exists = podman ps -a -q --filter "name=uvs_dev"
    if ($exists) {
        podman start uvs_dev
    } else {
        $root = (Get-Item -Path "$PSScriptRoot\..").FullName
        podman run -d --name uvs_dev -v "${root}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" ghcr.io/cirruslabs/flutter:3.24.3 sleep infinity
    }
    Write-Host "Container 'uvs_dev' started successfully." -ForegroundColor Green
}
