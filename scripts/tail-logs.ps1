$root = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $root "logs"

$backendOut = Join-Path $logsDir "backend.log"
$frontendOut = Join-Path $logsDir "frontend.log"

if (-not (Test-Path $backendOut) -and -not (Test-Path $frontendOut)) {
    Write-Host "No logs found. Run 'npm run dev:logs' first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Trailing logs: backend.log + frontend.log (Ctrl+C to stop)" -ForegroundColor Cyan
Get-Content -Path $backendOut, $frontendOut -Wait -Tail 20 -ErrorAction SilentlyContinue
