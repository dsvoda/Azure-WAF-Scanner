
. $PSScriptRoot\..\Core\Invoke-Arg.ps1
. $PSScriptRoot\..\Core\Get-DefenderAssessments.ps1
. $PSScriptRoot\..\Core\Get-Advisor.ps1
. $PSScriptRoot\..\Core\Get-CostMonthly.ps1

function Get-InfraSnapshot {
  param([string]$SubscriptionId)

  $vms = Get-AzVM -Status -ErrorAction SilentlyContinue
  $stor = Get-AzStorageAccount -ErrorAction SilentlyContinue
  $agw  = Get-AzApplicationGateway -ErrorAction SilentlyContinue
  $cdnp = try { Get-AzCdnProfile -ErrorAction Stop } catch { @() }
  $rsv  = Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue
  $asrProtected = 0
  foreach($v in $rsv){
    try {
      Set-AzRecoveryServicesAsrVaultContext -VaultId $v.Id -ErrorAction SilentlyContinue
      $asrProtected += (Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue).Count
    } catch {}
  }
  $bkPolicies = 0
  foreach($v in $rsv){
    try {
      Set-AzRecoveryServicesVaultContext -VaultId $v.Id -ErrorAction SilentlyContinue
      $bkPolicies += (Get-AzRecoveryServicesBackupProtectionPolicy -ErrorAction SilentlyContinue).Count
    } catch {}
  }
  $la = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
  $laTables = 0
  foreach($w in $la){
    try {
      $t = Get-AzOperationalInsightsTable -ResourceGroupName $w.ResourceGroupName -WorkspaceName $w.Name -ErrorAction SilentlyContinue
      $laTables += ($t | Measure-Object).Count
    } catch {}
  }
  [pscustomobject]@{
    VMCount = ($vms | Measure-Object).Count
    StorageAccounts = ($stor | Measure-Object).Count
    ApplicationGateways = ($agw | Measure-Object).Count
    CdnProfiles = ($cdnp | Measure-Object).Count
    RSVaults = ($rsv | Measure-Object).Count
    ASRProtectedItems = $asrProtected
    BackupPolicies = $bkPolicies
    Workspaces = ($la | Measure-Object).Count
    WorkspaceTables = $laTables
    NamedExamples = @{
      VMs = ($vms | Select-Object -First 5 -ExpandProperty Name)
      Storage = ($stor | Select-Object -First 5 -ExpandProperty StorageAccountName)
      AppGateway = ($agw | Select-Object -First 3 -ExpandProperty Name)
      CDN = ($cdnp | Select-Object -First 3 -ExpandProperty Name)
    }
  }
}

function Build-WafNarrative {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][array]$Results,
    [Parameter(Mandatory)][object]$Subscription
  )
  $subId = $Subscription.Id

  $secureScore = Get-SecureScore -SubscriptionId $subId
  $advisorCost = Get-Advisor -SubscriptionId $subId -Category @('Cost')
  $costSavings = 0
  foreach($a in $advisorCost){ if ($a.ExtendedProperties.estimatedSavingsAmount){ $costSavings += [decimal]$a.ExtendedProperties.estimatedSavingsAmount } }

  $lastMonth = Get-LastFullMonthCost -SubscriptionId $subId
  $thisMonth = Get-CurrentMonthCost -SubscriptionId $subId
  $lmVal = try { [decimal]$lastMonth.Rows[0][0] } catch { 0 }
  $tmVal = try { [decimal]$thisMonth.Rows[0][0] } catch { 0 }

  $snap = Get-InfraSnapshot -SubscriptionId $subId

  $ha = $Results | Where-Object { $_.ControlId -eq 'RE:05' } | Select-Object -First 1
  $monAlerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue
  $crit = @()
  if ($secureScore.SecureScore -lt 70) { $crit += "Security Score: $($secureScore.SecureScore)/100 (target ≥ 70)" }
  if ($ha -and $ha.Status -ne 'Pass') { $crit += "High Availability: redundancy gaps detected (control RE:05 $($ha.Status))" }
  if ($advisorCost.Count -gt 0) { $crit += ("Cost: Advisor savings opportunities detected (~${0:N0}/mo)" -f $costSavings) }
  if (($monAlerts | Measure-Object).Count -lt [math]::Max(5,$snap.VMCount)) { $crit += "Monitoring: limited alert coverage across critical resources" }

  $actions = @()
  if ($secureScore.SecureScore -lt 70) { $actions += [pscustomobject]@{ Priority='CRITICAL'; Action='Improve Secure Score to ≥70 via Defender for Cloud'; ROI='Risk reduction'; Notes='' } }
  if ($ha -and $ha.Status -ne 'Pass') { $actions += [pscustomobject]@{ Priority='CRITICAL'; Action='Deploy across Availability Zones / VMSS'; ROI='SLA ↑'; Notes='' } }
  if ($advisorCost.Count -gt 0) { $actions += [pscustomobject]@{ Priority='HIGH'; Action='Purchase Reservations/Savings Plans where eligible'; ROI=("~${0:N0}/mo" -f $costSavings); Notes='' } }
  if ($snap.ASRProtectedItems -lt $snap.VMCount) { $actions += [pscustomobject]@{ Priority='HIGH'; Action='Complete ASR coverage for all prod VMs'; ROI='RPO/RTO ↓'; Notes='' } }

  [pscustomobject]@{
    SubscriptionId = $subId
    SubscriptionName = $Subscription.Name
    CurrentMonthCost = $tmVal
    LastMonthCost    = $lmVal
    SecurityScore    = $secureScore.SecureScore
    Infra            = $snap
    CriticalFindings = $crit
    Actions          = $actions
  }
}


function Get-GovernanceSnapshot {
  param([string]$SubscriptionId)
  $budgets = Get-AzConsumptionBudget -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
  $policyAssignments = Get-AzPolicyAssignment -ErrorAction SilentlyContinue
  $tagged = Invoke-Arg -Kql "resources | extend env=tostring(tags.['environment']) | summarize withTag=countif(isnotempty(env)), total=count()" -Subscriptions $SubscriptionId
  [pscustomobject]@{
    Budgets = ($budgets | Measure-Object).Count
    PolicyAssignments = ($policyAssignments | Measure-Object).Count
    TagCoverage = if ($tagged[0].total -gt 0) { [math]::Round(($tagged[0].withTag*100.0)/$tagged[0].total,1) } else { 0 }
  }
}

function Build-WafNarrativePlus {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][array]$Results,
    [Parameter(Mandatory)][object]$Subscription
  )
  $n = Build-WafNarrative -Results $Results -Subscription $Subscription
  $orph = Get-OrphanedResources -SubscriptionId $Subscription.Id
  $gov  = Get-GovernanceSnapshot -SubscriptionId $Subscription.Id

  # counts
  $orphanCounts = @{
    UnattachedDisks = ($orph.Disks | Measure-Object).Count
    UnattachedNics  = ($orph.Nics | Measure-Object).Count
    FreePublicIPs   = ($orph.PublicIPs | Measure-Object).Count
    EmptyNsgs       = ($orph.Nsgs | Measure-Object).Count
    IdlePlans       = ($orph.AppServicePlans | Measure-Object).Count
  }

  [pscustomobject]@{
    Base          = $n
    Orphans       = $orph
    OrphanCounts  = $orphanCounts
    Governance    = $gov
  }
}
