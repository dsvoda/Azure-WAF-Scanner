
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO11' -Name 'Optimize code costs' -Description 'Advisor perf/cost signals (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Performance','Cost')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO11' -Name 'Optimize code costs' -Description 'Advisor perf/cost items exist' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorItems={0}" -f $adv.Count) -Recommendation 'Profile app (App Insights), fix inefficient calls; right-size infra accordingly'

}
