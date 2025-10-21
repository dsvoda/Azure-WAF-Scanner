
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE:03' -Name 'Select the right services' -Description 'Advisor tier/SKU hints (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Performance','HighAvailability')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE:03' -Name 'Select the right services' -Description 'Advisor signals' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorItems={0}" -f $adv.Count) -Recommendation 'Choose service tiers meeting SLOs; leverage managed features over custom'

}
