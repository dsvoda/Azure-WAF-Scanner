
function Ensure-PSWriteWord {
  if (-not (Get-Module PSWriteWord -ListAvailable)) {
    try { Install-Module PSWriteWord -Scope CurrentUser -Force -ErrorAction Stop } catch { Write-Warning "PSWriteWord not installed and could not be auto-installed. DOCX output will be skipped."; return $false }
  }
  Import-Module PSWriteWord -ErrorAction Stop
  return $true
}

. $PSScriptRoot\Build-WafNarrative.ps1
. $PSScriptRoot\..\Core\HtmlEngine.ps1

function New-WafDocx {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][array]$Results,
    [Parameter(Mandatory)][object]$Subscription,
    [Parameter(Mandatory)][string]$OutputPath
  )

  if (-not (Ensure-PSWriteWord)) { return $null }

  $data = Build-WafNarrativePlus -Results $Results -Subscription $Subscription
  $narr = $data.Base

  New-WordDocument -FilePath $OutputPath -Overwrite | Out-Null
  $brand = Get-Branding

  # Executive Summary
  Add-WordText -FilePath $OutputPath -Text "Executive Summary" -HeadingType Heading1
  $intro = "This review evaluates your Azure environment against the Microsoft Well-Architected Framework. It is generated automatically from Azure APIs using read-only access and includes prioritized recommendations with estimated ROI where available."
  Add-WordText -FilePath $OutputPath -Text $intro
  Add-WordText -FilePath $OutputPath -Text "Current Infrastructure Overview" -HeadingType Heading2
  $ov = @(
    ("Current Month Cost (to date): ${0:N2}" -f $narr.CurrentMonthCost),
    ("Last Full Month Cost: ${0:N2}" -f $narr.LastMonthCost),
    ("Security Secure Score: {0}/100" -f $narr.SecurityScore),
    ("VMs: {0}, Storage Accounts: {1}, App Gateways: {2}, CDN Profiles: {3}" -f $narr.Infra.VMCount,$narr.Infra.StorageAccounts,$narr.Infra.ApplicationGateways,$narr.Infra.CdnProfiles),
    ("Recovery Services Vaults: {0}, ASR Protected Items: {1}, Backup Policies: {2}" -f $narr.Infra.RSVaults,$narr.Infra.ASRProtectedItems,$narr.Infra.BackupPolicies),
    ("Log Analytics: {0} workspaces / {1} tables" -f $narr.Infra.Workspaces,$narr.Infra.WorkspaceTables)
  ) -join "`n"
  Add-WordText -FilePath $OutputPath -Text $ov

  Add-WordText -FilePath $OutputPath -Text "Critical Findings" -HeadingType Heading2
  if ($narr.CriticalFindings.Count -gt 0) { foreach($c in $narr.CriticalFindings){ Add-WordText -FilePath $OutputPath -Text ("• " + $c) } } else { Add-WordText -FilePath $OutputPath -Text "No critical findings were detected by automated checks." }

  # 1. Cost Optimization
  Add-WordText -FilePath $OutputPath -Text "1. Cost Optimization" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "1.1 Current Cost Analysis" -HeadingType Heading2
  $rows = @()
  $rows += ,@('Metric','Value')
  $rows += ,@('Current Month (to date)', ("${0:N2}" -f $narr.CurrentMonthCost))
  $rows += ,@('Last Full Month', ("${0:N2}" -f $narr.LastMonthCost))
  $rows += ,@('Advisor Est. Monthly Savings', ("${0:N0}" -f ($data.Base.Actions | Where-Object {$_.Action -like '*Reservations*'} | ForEach-Object {$_.ROI})))
  Add-WordTable -FilePath $OutputPath -DataTable $rows -Design LightListAccent3

  Add-WordText -FilePath $OutputPath -Text "1.2 Resource Utilization Assessment" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Virtual Machines" -HeadingType Heading3
  Add-WordText -FilePath $OutputPath -Text ("Count: {0}" -f $narr.Infra.VMCount)
  Add-WordText -FilePath $OutputPath -Text "Storage Accounts" -HeadingType Heading3
  Add-WordText -FilePath $OutputPath -Text ("Count: {0}" -f $narr.Infra.StorageAccounts)
  Add-WordText -FilePath $OutputPath -Text "Backup & Disaster Recovery" -HeadingType Heading3
  Add-WordText -FilePath $OutputPath -Text ("RS Vaults: {0}, ASR Protected Items: {1}, Backup Policies: {2}" -f $narr.Infra.RSVaults,$narr.Infra.ASRProtectedItems,$narr.Infra.BackupPolicies)

  Add-WordText -FilePath $OutputPath -Text "1.3 Unused & Orphaned Resources" -HeadingType Heading2
  $or = @()
  $or += ,@('Type','Count')
  $or += ,@('Unattached Disks', $data.OrphanCounts.UnattachedDisks)
  $or += ,@('Unattached NICs' , $data.OrphanCounts.UnattachedNics)
  $or += ,@('Unassociated Public IPs', $data.OrphanCounts.FreePublicIPs)
  $or += ,@('Empty NSGs', $data.OrphanCounts.EmptyNsgs)
  $or += ,@('Idle App Service Plans', $data.OrphanCounts.IdlePlans)
  Add-WordTable -FilePath $OutputPath -DataTable $or -Design LightListAccent3

  Add-WordText -FilePath $OutputPath -Text "1.4 Cost Visibility & Governance" -HeadingType Heading2
  $gov = @()
  $gov += ,@('Budgets', $data.Governance.Budgets)
  $gov += ,@('Policy Assignments', $data.Governance.PolicyAssignments)
  $gov += ,@('Environment Tag Coverage (%)', $data.Governance.TagCoverage)
  Add-WordTable -FilePath $OutputPath -DataTable $gov -Design LightListAccent3

  Add-WordText -FilePath $OutputPath -Text "1.5 Cost Optimization Recommendations" -HeadingType Heading2
  $rec = $Results | Where-Object { $_.Pillar -eq 'Cost Optimization' } | Sort-Object Score
  foreach($r in $rec){ Add-WordText -FilePath $OutputPath -Text ("• [{0}] {1} — {2}" -f $r.ControlId,$r.ControlName,$r.Recommendation) }

  # 2. Operational Excellence
  Add-WordText -FilePath $OutputPath -Text "2. Operational Excellence" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "2.1 Infrastructure as Code (IaC)" -HeadingType Heading2
  $oe5 = $Results | Where-Object { $_.ControlId -eq 'OE:05' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Status: {0}. {1}" -f $oe5.Status,$oe5.Recommendation)
  Add-WordText -FilePath $OutputPath -Text "Recommendations for IaC Maturity" -HeadingType Heading3
  Add-WordText -FilePath $OutputPath -Text "Adopt Bicep/ARM pipelines with validation and policy compliance gates."

  Add-WordText -FilePath $OutputPath -Text "2.2 Automation & Orchestration" -HeadingType Heading2
  $oe2 = $Results | Where-Object { $_.ControlId -eq 'OE:02' } | Select-Object -First 1
  $oe9 = $Results | Where-Object { $_.ControlId -eq 'OE:09' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Runbooks: {0}; Schedules: see OE:09 ({1})" -f $oe2.Evidence,$oe9.Evidence)

  Add-WordText -FilePath $OutputPath -Text "2.3 Monitoring & Observability" -HeadingType Heading2
  $oe7 = $Results | Where-Object { $_.ControlId -eq 'OE:07' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Diagnostic settings and App Insights presence: {0}" -f $oe7.Evidence)

  Add-WordText -FilePath $OutputPath -Text "2.4 Release Engineering Practices" -HeadingType Heading2
  $oe11 = $Results | Where-Object { $_.ControlId -eq 'OE:11' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Deployment slots and gates: {0}" -f $oe11.Evidence)

  # 3. Performance Efficiency
  Add-WordText -FilePath $OutputPath -Text "3. Performance Efficiency" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "3.1 Performance Targets & SLOs" -HeadingType Heading2
  $pe1 = $Results | Where-Object { $_.ControlId -eq 'PE:01' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Target alerts in place: {0}" -f $pe1.Status)

  Add-WordText -FilePath $OutputPath -Text "3.2 Capacity Planning & Right-Sizing" -HeadingType Heading2
  $pe2 = $Results | Where-Object { $_.ControlId -eq 'PE:02' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Advisor performance recommendations: {0}" -f $pe2.Evidence)

  Add-WordText -FilePath $OutputPath -Text "3.3 Service & Tier Selection" -HeadingType Heading2
  $pe3 = $Results | Where-Object { $_.ControlId -eq 'PE:03' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Tier recommendations present: {0}" -f $pe3.Status)

  Add-WordText -FilePath $OutputPath -Text "3.4 Data Collection & Telemetry" -HeadingType Heading2
  $pe4 = $Results | Where-Object { $_.ControlId -eq 'PE:04' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Diagnostics + App Insights: {0}" -f $pe4.Status)

  Add-WordText -FilePath $OutputPath -Text "3.5 Scaling & Partitioning" -HeadingType Heading2
  $pe5 = $Results | Where-Object { $_.ControlId -eq 'PE:05' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Autoscale settings: {0}" -f $pe5.Evidence)

  Add-WordText -FilePath $OutputPath -Text "3.6 Performance Testing" -HeadingType Heading2
  $pe6 = $Results | Where-Object { $_.ControlId -eq 'PE:06' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Load tests present: {0}" -f $pe6.Evidence)

  # 4. Reliability
  Add-WordText -FilePath $OutputPath -Text "4. Reliability" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "4.1 Simplicity & Failure Modes" -HeadingType Heading2
  $re1 = $Results | Where-Object { $_.ControlId -eq 'RE:01' } | Select-Object -First 1
  $re3 = $Results | Where-Object { $_.ControlId -eq 'RE:03' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Complexity snapshot: {0}" -f $re1.Evidence)
  Add-WordText -FilePath $OutputPath -Text ("Single points of failure: {0}" -f $re3.Evidence)

  Add-WordText -FilePath $OutputPath -Text "4.2 Targets, Scaling & Self-healing" -HeadingType Heading2
  $re4 = $Results | Where-Object { $_.ControlId -eq 'RE:04' } | Select-Object -First 1
  $re6 = $Results | Where-Object { $_.ControlId -eq 'RE:06' } | Select-Object -First 1
  $re7 = $Results | Where-Object { $_.ControlId -eq 'RE:07' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Alerts to SLOs: {0}; Autoscale: {1}; Self-healing: {2}" -f $re4.Status,$re6.Status,$re7.Status)

  Add-WordText -FilePath $OutputPath -Text "4.3 Chaos, BCDR & Health" -HeadingType Heading2
  $re8 = $Results | Where-Object { $_.ControlId -eq 'RE:08' } | Select-Object -First 1
  $re9 = $Results | Where-Object { $_.ControlId -eq 'RE:09' } | Select-Object -First 1
  $re10= $Results | Where-Object { $_.ControlId -eq 'RE:10' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Chaos experiments: {0}; ASR coverage: {1}; Health metrics: {2}" -f $re8.Status,$re9.Evidence,$re10.Status)

  # 5. Security
  Add-WordText -FilePath $OutputPath -Text "5. Security" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "5.1 Security Baseline & Identity" -HeadingType Heading2
  $se1 = $Results | Where-Object { $_.ControlId -eq 'SE:01' } | Select-Object -First 1
  $se5 = $Results | Where-Object { $_.ControlId -eq 'SE:05' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Baseline posture: {0}; Strict IAM: {1}" -f $se1.Status,$se5.Evidence)

  Add-WordText -FilePath $OutputPath -Text "5.2 Network Segmentation & Perimeters" -HeadingType Heading2
  $se4 = $Results | Where-Object { $_.ControlId -eq 'SE:04' } | Select-Object -First 1
  $se6 = $Results | Where-Object { $_.ControlId -eq 'SE:06' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("NSG/Firewall coverage: {0} | {1}" -f $se4.Evidence,$se6.Evidence)

  Add-WordText -FilePath $OutputPath -Text "5.3 Monitoring & Threat Detection" -HeadingType Heading2
  $se10 = $Results | Where-Object { $_.ControlId -eq 'SE:10' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Defender plans + alerts: {0}" -f $se10.Evidence)

  Add-WordText -FilePath $OutputPath -Text "5.4 Data Protection" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Encryption" -HeadingType Heading3
  $se7 = $Results | Where-Object { $_.ControlId -eq 'SE:07' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Encryption status: {0}" -f $se7.Evidence)
  Add-WordText -FilePath $OutputPath -Text "Key Vault Management" -HeadingType Heading3
  $se9 = $Results | Where-Object { $_.ControlId -eq 'SE:09' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("KV hardening: {0}" -f $se9.Evidence)

  Add-WordText -FilePath $OutputPath -Text "5.5 Threat Detection & Response" -HeadingType Heading2
  $se11 = $Results | Where-Object { $_.ControlId -eq 'SE:11' } | Select-Object -First 1
  $se12 = $Results | Where-Object { $_.ControlId -eq 'SE:12' } | Select-Object -First 1
  Add-WordText -FilePath $OutputPath -Text ("Testing regimen: {0}; Incident response automation: {1}" -f $se11.Status,$se12.Status)

  Add-WordText -FilePath $OutputPath -Text "5.6 Compliance & Governance" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text ("Policy Assignments: {0}; Tag Coverage (env): {1}%" -f $data.Governance.PolicyAssignments, $data.Governance.TagCoverage)

  # 6. Prioritized Action Items
  Add-WordText -FilePath $OutputPath -Text "6. Prioritized Action Items" -HeadingType Heading1
  foreach($prio in @('CRITICAL','HIGH','MEDIUM')){
    $label = switch ($prio){ 'CRITICAL'{'Critical Priority (Implement Within 30 Days)'} 'HIGH'{'High Priority (Implement Within 90 Days)'} default {'Medium Priority (Implement Within 6 Months)'} }
    Add-WordText -FilePath $OutputPath -Text $label -HeadingType Heading2
    $rows = @(); $rows += ,@('Action','ROI / Impact')
    $items = $data.Base.Actions | Where-Object { $_.Priority -eq $prio }
    if ($items.Count -gt 0){
      foreach($a in $items){ $rows += ,@($a.Action,$a.ROI) }
      Add-WordTable -FilePath $OutputPath -DataTable $rows -Design LightListAccent3
    } else {
      Add-WordText -FilePath $OutputPath -Text "No items identified in this category."
    }
  }
  Add-WordText -FilePath $OutputPath -Text "Ongoing Operational Improvements" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Continue to monitor, patch, and iterate on telemetry-informed improvements."

  # 7. Conclusion
  Add-WordText -FilePath $OutputPath -Text "7. Conclusion" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "Key Takeaways" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Your environment shows strengths in native Azure capabilities. Address the prioritized findings to raise reliability and security while lowering cost."
  Add-WordText -FilePath $OutputPath -Text "Return on Investment" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Advisor-aligned savings and rightsizing typically pay back in weeks; automation and policy reduce toil and misconfig risk."
  Add-WordText -FilePath $OutputPath -Text "Next Steps" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "Agree on owners and timelines for the Critical/High actions; schedule the next WAF checkpoint in 30–90 days."

  # Appendix
  Add-WordText -FilePath $OutputPath -Text "Appendix" -HeadingType Heading1
  Add-WordText -FilePath $OutputPath -Text "Diagrams" -HeadingType Heading2
  Add-WordText -FilePath $OutputPath -Text "(Optional) Insert exported topology diagrams here."

  return $OutputPath
}
