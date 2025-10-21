
function New-WafResult {
  param(
    [string]$Pillar,[string]$Id,[string]$Name,[string]$Description,[string]$SubscriptionId,
    [string]$ResourceId,[string]$TestMethod,[ValidateSet('Pass','Fail','Warn','Manual')] [string]$Status,
    [int]$Score,[string]$Evidence,[string]$Recommendation,[string]$EstimatedROI
  )
  [pscustomobject]@{
    Timestamp      = (Get-Date).ToString('o')
    Pillar         = $Pillar
    ControlId      = $Id
    ControlName    = $Name
    Description    = $Description
    SubscriptionId = $SubscriptionId
    ResourceId     = $ResourceId
    TestMethod     = $TestMethod
    Status         = $Status
    Score          = $Score
    Evidence       = $Evidence
    Recommendation = $Recommendation
    EstimatedROI   = $EstimatedROI
  }
}
function Convert-StatusToScore { param([string]$Status) switch ($Status) { 'Pass'{100} 'Warn'{60} 'Fail'{0} default {50} } }
function Estimate-ROI { param([decimal]$EstimatedMonthlySavings,[int]$EffortHours=8,[decimal]$HourlyRate=150)
  if ($EstimatedMonthlySavings -le 0) { return $null }
  $paybackDays = [math]::Round((($EffortHours*$HourlyRate)/$EstimatedMonthlySavings)*30,1)
  "Est. monthly savings: ${EstimatedMonthlySavings:C0}; Payback ~ $paybackDays days"
}
function Get-WafWeights {
  $path = Join-Path $PSScriptRoot '..\..\config\weights.json'
  if (Test-Path $path) { return Get-Content $path -Raw | ConvertFrom-Json }
  [pscustomobject]@{ 'Reliability'=1; 'Security'=1; 'Cost Optimization'=1; 'Operational Excellence'=1; 'Performance Efficiency'=1; Controls=@{} }
}
function New-WafPortfolioSummary {
  param([array]$Results)
  $weights = Get-WafWeights
  $bySub = $Results | Group-Object SubscriptionId
  $subs = foreach($s in $bySub){
    $byP = $s.Group | Group-Object Pillar
    $pillarScores = @{}; $sum=0; $den=0
    foreach($p in $byP){
      $scores = foreach($r in $p.Group){
        $ctrlWeight = $weights.Controls.($r.ControlId); if (-not $ctrlWeight) { $ctrlWeight = 1.0 }
        [double]$r.Score * [double]$ctrlWeight
      }
      $pillarAvg = if ($scores.Count){ [math]::Round(($scores | Measure-Object -Sum).Sum / $scores.Count,0) } else { 0 }
      $pillarScores[$p.Name] = $pillarAvg
      $sum += $pillarAvg * [double]($weights.($p.Name))
      $den += [double]($weights.($p.Name))
    }
    [pscustomobject]@{ SubscriptionId=$s.Name; PillarScores=$pillarScores; OverallScore=([math]::Round($sum/$den,0)); Timestamp=(Get-Date).ToString('o') }
  }
  $overall = if ($subs.Count) { [math]::Round(($subs | Measure-Object -Property OverallScore -Average).Average,0) } else { 0 }
  [pscustomobject]@{ PortfolioScore=$overall; Subscriptions=$subs; Generated=(Get-Date).ToString('o') }
}
function Get-AzurePortalLink { param([string]$ResourceId) if (-not $ResourceId) { return $null } "https://portal.azure.com/#@/resource/$($ResourceId)" }
