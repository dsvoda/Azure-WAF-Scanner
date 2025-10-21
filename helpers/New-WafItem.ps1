
param(
  [Parameter(Mandatory)][ValidateSet('Reliability','Security','CostOptimization','OperationalExcellence','PerformanceEfficiency')] [string] $PillarFolder,
  [Parameter(Mandatory)] [string] $ControlId,
  [Parameter(Mandatory)] [string] $ControlName,
  [Parameter(Mandatory)] [string] $Description
)

$root = Join-Path $PSScriptRoot "..\modules\Pillars\$PillarFolder\$($ControlId.Replace(':',''))"
New-Item -ItemType Directory -Force -Path $root | Out-Null
@"
# $ControlId — $ControlName

**Description:** $Description

**Automated Test(s):**
- TBD
"@ | Out-File (Join-Path $root 'README.md') -Encoding utf8

@"
Register-WafCheck -Pillar '$($PillarFolder -replace 'CostOptimization','Cost Optimization' -replace 'OperationalExcellence','Operational Excellence' -replace 'PerformanceEfficiency','Performance Efficiency')' `
  -Id '$ControlId' `
  -Name '$ControlName' `
  -Description '$($Description.Replace("`"","'').Replace("'","''"))' `
  -InvokeScript {
    param([string]$SubscriptionId)
    # TODO: Implement test and return New-WafResult
    $status = 'Manual'
    New-WafResult -Pillar '$($PillarFolder -replace 'CostOptimization','Cost Optimization' -replace 'OperationalExcellence','Operational Excellence' -replace 'PerformanceEfficiency','Performance Efficiency')' `
      -Id '$ControlId' -Name '$ControlName' -Description '$($Description.Replace("`"","'').Replace("'","''"))' `
      -SubscriptionId $SubscriptionId -TestMethod 'Template' -Status $status -Score (Convert-StatusToScore $status) `
      -Evidence 'Scaffolded item' -Recommendation 'Fill in remediation' -EstimatedROI $null
  }
"@ | Out-File (Join-Path $root 'Invoke.ps1') -Encoding utf8

Write-Host "Scaffolded $ControlId at $root"
