
[CmdletBinding()]
param(
  [string[]] $Subscriptions,
  [string]   $OutputDir = (Join-Path (Get-Location) 'waf-output'),
  [switch]   $EmitHtml,
  [switch]   $EmitCsv,
  [switch]   $EmitJson = $true,
  [switch]   $EmitDocx,
  [int]      $MaxParallel = 4
)

$ErrorActionPreference = 'Stop'

# Ensure modules
$req = 'Az.Accounts','Az.Resources','Az.ResourceGraph','Az.Advisor','Az.PolicyInsights','Az.Security','Az.Monitor','Az.CostManagement','Az.Consumption','Az.Network','Az.RecoveryServices','Az.OperationalInsights','Az.Cdn','Az.Websites','Az.Compute','Az.Sql','Az.LogicApp','Az.AppConfiguration'
foreach($m in $req){ if(-not (Get-Module $m -ListAvailable)){ Write-Host "Installing $m..." -ForegroundColor DarkGray; Install-Module $m -Scope CurrentUser -Force -ErrorAction Stop } }

# Ensure login
try { $ctx = Get-AzContext -ErrorAction Stop } catch { Connect-AzAccount | Out-Null; $ctx = Get-AzContext }

# Resolve subscriptions
$allSubs = Get-AzSubscription | Sort-Object Name
if (-not $Subscriptions -or $Subscriptions.Count -eq 0) {
  $targetSubs = @($ctx.Subscription)
} else {
  $targetSubs = foreach($s in $Subscriptions){
    $match = $allSubs | Where-Object { $_.Id -eq $s -or $_.Name -eq $s }
    if (-not $match){ Write-Warning "Subscription not found: $s"; continue }
    $match
  }
}

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

Import-Module "$PSScriptRoot\..\modules\WafScanner.psm1" -Force

function Add-WafDeltaAnnotationsLocal {
  param([array]$Results,[string]$OutputDir)
  try {
    $subId = $Results[0].SubscriptionId
    $prev = Get-ChildItem -Path $OutputDir -Filter "$subId-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $prev) { return $Results }
    $prevRows = Get-Content $prev.FullName | ConvertFrom-Json
    $byKey = @{}; foreach($p in $prevRows){ $byKey["$($p.ControlId)|$($p.Pillar)"] = $p }
    foreach($r in $Results){
      $k = "$($r.ControlId)|$($r.Pillar)"
      if ($byKey.ContainsKey($k)){
        $old = $byKey[$k]
        if ($old.Status -ne $r.Status -or $old.Score -ne $r.Score){
          $r.Evidence = "[DELTA: Prev=$($old.Status)/$($old.Score)] " + $r.Evidence
        }
      }
    }
  } catch {}
  return $Results
}

$throttle = [Math]::Max([Math]::Min($MaxParallel,[Environment]::ProcessorCount),1)
$jobs = $targetSubs | ForEach-Object -Parallel {
  param($OutputDir,$EmitHtml,$EmitCsv,$EmitJson)

  try {
    Select-AzSubscription -SubscriptionId $_.Id | Out-Null
    Initialize-WafSubscriptionCache -SubscriptionId $_.Id

    $results = Invoke-WafChecksForSubscription -SubscriptionId $_.Id
    $results = Add-WafDeltaAnnotationsLocal -Results $results -OutputDir $OutputDir

    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $base  = "$($_.Id)-$stamp"
    $jsonPath = Join-Path $OutputDir "$base.json"
    $csvPath  = Join-Path $OutputDir "$base.csv"
    $htmlPath = Join-Path $OutputDir "$base.html"

    if ($EmitJson) { $results | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8 }
    if ($EmitCsv ) { $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8 }
    if ($EmitHtml) { ($results | New-WafHtml -Subscription $_) | Out-File -FilePath $htmlPath -Encoding utf8 }
    if ($EmitDocx) { $docxPath = Join-Path $OutputDir ("$base.docx"); New-WafDocx -Results $results -Subscription $_ -OutputPath $docxPath | Out-Null }

    $summary = New-WafPortfolioSummary -Results $results
    $sumPath = Join-Path $OutputDir "$($_.Id)-$stamp-summary.json"
    $summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $sumPath -Encoding utf8

    [pscustomobject]@{ SubscriptionId=$_.Id; Name=$_.Name; Json=$jsonPath; Csv=$csvPath; Html=$htmlPath }
  }
  catch {
    [pscustomobject]@{ SubscriptionId=$_.Id; Error=$_.ToString() }
  }

} -ThrottleLimit $throttle -ArgumentList $OutputDir,$EmitHtml,$EmitCsv,$EmitJson

$ok = $jobs | Where-Object { -not $_.Error }
$bad= $jobs | Where-Object { $_.Error }
Write-Host ""
Write-Host "WAF scan complete." -ForegroundColor Green
foreach($r in $ok){
  Write-Host (" - {0} ({1})" -f $r.Name,$r.SubscriptionId)
  if (Test-Path $r.Json) { Write-Host ("   JSON: {0}" -f $r.Json) -ForegroundColor DarkGray }
  if (Test-Path $r.Csv ) { Write-Host ("   CSV : {0}" -f $r.Csv ) -ForegroundColor DarkGray }
  if (Test-Path $r.Html) { Write-Host ("   HTML: {0}" -f $r.Html) -ForegroundColor DarkGray }
}
if ($bad){
  Write-Warning "Some subscriptions failed:"
  $bad | ForEach-Object { Write-Host (" - {0}: {1}" -f $_.SubscriptionId, $_.Error) }
}
