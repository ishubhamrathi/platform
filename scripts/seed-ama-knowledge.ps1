param(
  [string]$ApiBase = $env:API_BASE ?? "http://localhost:8080",
  [string]$Email = $env:ADMIN_EMAIL,
  [string]$Password = $env:ADMIN_PASSWORD
)
# PowerShell variant for Windows (uses Invoke-RestMethod with session)
# Usage: .\seed-ama-knowledge.ps1 -Email admin@example.com -Password secret -ApiBase http://localhost:8080
# Requires: Make user ADMIN first: psql -> UPDATE users SET role='ADMIN' WHERE email='admin@example.com';

if (-not $Email -or -not $Password) {
  Write-Error "Missing -Email / -Password (or ADMIN_EMAIL/ADMIN_PASSWORD env). Create account via POST /api/auth/register then set role to ADMIN in DB."
  exit 1
}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$knowledgeFile = Join-Path $scriptDir "ama-seed-data.json"
$suggestionsFile = Join-Path $scriptDir "ama-suggestions.json"
if (-not (Test-Path $knowledgeFile)) { Write-Error "Missing $knowledgeFile"; exit 1 }

$entries = Get-Content $knowledgeFile -Raw | ConvertFrom-Json
$suggestions = @()
if (Test-Path $suggestionsFile) { $suggestions = Get-Content $suggestionsFile -Raw | ConvertFrom-Json }

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

Write-Host "Logging in as $Email @ $ApiBase ..."
try {
  $login = Invoke-RestMethod -Uri "$ApiBase/api/auth/login" -Method Post -ContentType "application/json" -Body (@{email=$Email;password=$Password}|ConvertTo-Json) -WebSession $session
  Write-Host "Logged in: $($login.email) role $($login.role)"
} catch {
  Write-Error "Login failed: $($_.Exception.Message) $_"
  if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
  exit 1
}

Write-Host "Fetching existing knowledge..."
$existing = Invoke-RestMethod -Uri "$ApiBase/api/ama/admin/knowledge" -Method Get -WebSession $session
$existingSet = @{}
foreach ($e in $existing) { $existingSet[($e.question.Trim().ToLower())] = $true }
Write-Host "Existing: $($existing.Count)  Seed: $($entries.Count)"

$created=0; $skipped=0; $failed=0
foreach ($e in $entries) {
  $k = $e.question.Trim().ToLower()
  if ($existingSet.ContainsKey($k)) { $skipped++; continue }
  try {
    $body = @{ category=$e.category; question=$e.question; answer=$e.answer; keywords=$e.keywords; confidence=$e.confidence; active=$e.active } | ConvertTo-Json -Depth 4
    Invoke-RestMethod -Uri "$ApiBase/api/ama/admin/knowledge" -Method Post -ContentType "application/json" -Body $body -WebSession $session | Out-Null
    $created++
    $existingSet[$k] = $true
    if ($created % 25 -eq 0) { Write-Host "  ... $created created" }
    Start-Sleep -Milliseconds 40
  } catch {
    $failed++
    Write-Warning "FAIL '$($e.question.Substring(0, [Math]::Min(60,$e.question.Length)))': $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
  }
}
Write-Host "Knowledge: created=$created skipped=$skipped failed=$failed"

if ($suggestions.Count -gt 0) {
  Write-Host "Seeding suggestions..."
  $existingSug = @{}
  try {
    $s = Invoke-RestMethod -Uri "$ApiBase/api/admin/ama/suggestions" -Method Get -WebSession $session
    foreach ($it in ($s.items ?? $s)) { $existingSug[($it.question.Trim().ToLower())] = $true }
  } catch {}
  $sCreated=0; $sSkipped=0
  foreach ($s in $suggestions) {
    $k = $s.question.Trim().ToLower()
    if ($existingSug.ContainsKey($k)) { $sSkipped++; continue }
    try {
      $body = @{ question=$s.question; category=$s.category; displayOrder=$s.displayOrder; active=$true } | ConvertTo-Json
      Invoke-RestMethod -Uri "$ApiBase/api/admin/ama/suggestions" -Method Post -ContentType "application/json" -Body $body -WebSession $session | Out-Null
      $sCreated++
    } catch { Write-Warning "sug FAIL $($s.question): $($_.Exception.Message)" }
  }
  Write-Host "Suggestions: created=$sCreated skipped=$sSkipped"
}

Write-Host "Done. Test: Invoke-RestMethod -Uri ""$ApiBase/api/ama/ask"" -Method Post -Headers @{""X-API-Key""=""<portfolio-key>""} -Body (@{question=""more"";mode=""KNOWLEDGE_FIRST""}|ConvertTo-Json) -ContentType ""application/json"""
