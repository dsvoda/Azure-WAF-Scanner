
$script:WafChecks = @{}; $script:WafPillars = @{}

function Register-WafCheck {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $Pillar,
    [Parameter(Mandatory)] [string] $Id,
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [string] $Description,
    [Parameter(Mandatory)] [scriptblock] $InvokeScript
  )
  $key = "$Pillar/$Id"
  $script:WafChecks[$key] = [pscustomobject]@{
    Pillar=$Pillar; Id=$Id; Name=$Name; Description=$Description; InvokeScript=$InvokeScript
  }
  if (-not $script:WafPillars.ContainsKey($Pillar)) { $script:WafPillars[$Pillar] = New-Object System.Collections.ArrayList }
  [void]$script:WafPillars[$Pillar].Add($Id)
}

function Load-WafChecks {
  [CmdletBinding()]
  param([string]$Root = (Join-Path $PSScriptRoot '..\Pillars'))
  $files = Get-ChildItem -Path $Root -Recurse -Filter 'Invoke.ps1'
  foreach ($f in $files) { try { . $f.FullName } catch { Write-Warning "Failed to load $($f.FullName): $_" } }
}

function Invoke-WafChecksForSubscription {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$SubscriptionId,[string[]]$Pillars,[string[]]$Ids)
  $results = @()
  $targets = if ($Pillars -or $Ids) {
    $script:WafChecks.GetEnumerator() | Where-Object {
      ($Pillars -and $_.Value.Pillar -in $Pillars) -or ($Ids -and $_.Value.Id -in $Ids)
    }
  } else { $script:WafChecks.GetEnumerator() }
  foreach ($kv in $targets) {
    $meta = $kv.Value
    try {
      $res = & $meta.InvokeScript $SubscriptionId
      if ($res) { $results += $res }
    } catch {
      $results += New-WafResult -Pillar $meta.Pillar -Id $meta.Id -Name $meta.Name -Description $meta.Description `
        -SubscriptionId $SubscriptionId -TestMethod 'Error' -Status 'Manual' -Score (Convert-StatusToScore 'Manual') `
        -Evidence ("Execution error: " + $_.ToString()) -Recommendation 'Re-run with required permissions/modules'
    }
  }
  return $results
}
