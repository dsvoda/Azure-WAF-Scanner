
Register-WafCheck -Pillar 'Security' -Id 'SE12' -Name 'Incident response' -Description 'Sentinel/Playbooks presence (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $la = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
  $logic = Get-AzLogicApp -ErrorAction SilentlyContinue
  $status = ($la.Count -gt 0 -and $logic.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Security' -Id 'SE12' -Name 'Incident response' -Description 'LA workspaces + Logic Apps' `
    -SubscriptionId $SubscriptionId -TestMethod 'LA+LogicApps presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("Workspaces={0}; LogicApps={1}" -f $la.Count,$logic.Count) -Recommendation 'Deploy Sentinel in a workspace and create playbooks/runbooks; test IR procedures'

}
