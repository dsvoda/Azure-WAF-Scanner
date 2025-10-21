
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE08' -Name 'Emergency operations practice' -Description 'Manual; Sentinel recommended' -InvokeScript {
  param([string]$SubscriptionId)

  $sentinelHint = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
  $status = ($sentinelHint.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE08' -Name 'Emergency operations practice' -Description 'IR plan & drills; Sentinel suggested' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual+Workspace presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("LAWorkspaces={0}" -f $sentinelHint.Count) -Recommendation 'Document IR roles/runbooks; integrate Sentinel and test regularly'

}
