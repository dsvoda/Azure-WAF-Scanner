
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE:07' -Name 'Optimize code & infrastructure' -Description 'Advisor performance items' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Performance')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE:07' -Name 'Optimize code & infrastructure' -Description 'Advisor performance items' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorPerfRecs={0}" -f $adv.Count) -Recommendation 'Use platform features; remove unnecessary work from app code'

}
