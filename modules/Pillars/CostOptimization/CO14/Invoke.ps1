
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO14' -Name 'Consolidate resources & responsibility' -Description 'Identify single-resource RGs (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $one = Invoke-Arg -Kql "resources | summarize c=count() by resourceGroup | where c==1 | summarize rg=count()" -Subscriptions $SubscriptionId
  $status = ($one[0].rg -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO14' -Name 'Consolidate resources & responsibility' -Description 'RGs with a single resource' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("SingleResourceRGs={0}" -f $one[0].rg) -Recommendation 'Consolidate where appropriate; centralize shared services to increase density'

}
