param(
    [switch]$Tail = $true
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $root "logs"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
Get-ChildItem -Path $logsDir -Filter "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force

$backendOut = Join-Path $logsDir "backend.log"
$backendErr = Join-Path $logsDir "backend.err.log"
$frontendOut = Join-Path $logsDir "frontend.log"
$frontendErr = Join-Path $logsDir "frontend.err.log"

Write-Host "Starting backend (Spring Boot :8080) and frontend (Vite :3002)..." -ForegroundColor Cyan

Start-Process -FilePath "node.exe" -ArgumentList @("scripts/run-backend.js") `
    -WorkingDirectory $root `
    -RedirectStandardOutput $backendOut `
    -RedirectStandardError $backendErr `
    -WindowStyle Hidden

Start-Process -FilePath "node.exe" -ArgumentList @("scripts/run-frontend.js") `
    -WorkingDirectory $root `
    -RedirectStandardOutput $frontendOut `
    -RedirectStandardError $frontendErr `
    -WindowStyle Hidden

Write-Host "Both servers started in background. Logs:" -ForegroundColor Green
Write-Host "  backend : logs\backend.log"
Write-Host "  frontend: logs\frontend.log"

if ($Tail) {
    Write-Host "Trailing both logs... (Ctrl+C stops trailing, servers keep running)" -ForegroundColor Cyan
    Get-Content -Path $backendOut, $frontendOut -Wait -Tail 20
}
