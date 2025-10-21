
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE02' -Name 'Capacity planning' -Description 'Advisor performance recommendations' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Performance')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE02' -Name 'Capacity planning' -Description 'Advisor performance recommendations' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorPerfRecs={0}" -f $adv.Count) -Recommendation 'Review historical usage and plan for seasonal peaks; apply Advisor guidance'

}
