
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE11' -Name 'Respond to live performance issues' -Description 'Service Health alerts + action groups' -InvokeScript {
  param([string]$SubscriptionId)

  $ag = Get-AzActionGroup -ErrorAction SilentlyContinue
  $sha = Get-AzActivityLogAlert -ErrorAction SilentlyContinue | Where-Object { $_.Condition.AllOf.AnyOf -match 'ServiceHealth' -or $_.Description -match 'health' }
  $status = ($ag.Count -gt 0 -and $sha.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE11' -Name 'Respond to live performance issues' -Description 'Service Health alerts wired to action groups' `
    -SubscriptionId $SubscriptionId -TestMethod 'Monitor alerts' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("ActionGroups={0}; HealthAlerts={1}" -f $ag.Count,$sha.Count) -Recommendation 'Define paging/ownership; integrate with Logic Apps for triage'

}
