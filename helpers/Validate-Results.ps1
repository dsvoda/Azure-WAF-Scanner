
param([Parameter(Mandatory)][string]$Path)
$items = Get-Content $Path | ConvertFrom-Json
$missing = @()
foreach($i in $items){
  foreach($k in 'Timestamp','Pillar','ControlId','ControlName','SubscriptionId','Status','Score'){
    if (-not $i.$k){ $missing += "$k missing for $($i.ControlId)" }
  }
}
if ($missing){ Write-Error ($missing -join "`n") } else { Write-Host "Schema sanity check passed." -ForegroundColor Green }
