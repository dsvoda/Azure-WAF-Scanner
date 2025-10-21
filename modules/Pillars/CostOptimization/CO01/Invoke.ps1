
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO01' -Name 'Culture of financial responsibility' -Description 'Budgets and alerts present' -InvokeScript {
  param([string]$SubscriptionId)

  $budgets = Get-AzConsumptionBudget -ErrorAction SilentlyContinue
  $status = ($budgets.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO01' -Name 'Culture of financial responsibility' -Description 'Budgets present (proxy)' `
    -SubscriptionId $SubscriptionId -TestMethod 'Budgets' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("Budgets={0}" -f $budgets.Count) -Recommendation 'Create budgets with 50/80/100% alerts; share with owners monthly'

}
