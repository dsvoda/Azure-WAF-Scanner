
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:10' -Name 'Automation for lifecycle & governance' -Description 'Policy assignments as governance automation' -InvokeScript {
  param([string]$SubscriptionId)

  $assign = Get-AzPolicyAssignment -ErrorAction SilentlyContinue
  $status = ($assign.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:10' -Name 'Automation for lifecycle & governance' -Description 'Policy assignments present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Policy assignments' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("PolicyAssignments={0}" -f $assign.Count) -Recommendation 'Automate bootstrap/governance with Policy (and IaC) from the start'

}
