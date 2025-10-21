
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO07' -Name 'Optimize component costs' -Description 'Advisor rightsizing + unused resources' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Cost')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO07' -Name 'Optimize component costs' -Description 'Advisor cost recommendations' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorCostRecs={0}" -f $adv.Count) -Recommendation 'Remove idle components and right-size underutilized resources per Advisor'

}
