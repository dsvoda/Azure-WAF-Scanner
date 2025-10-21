
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE12' -Name 'Continuously optimize performance' -Description 'Advisor items trending (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Performance')
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE12' -Name 'Continuously optimize performance' -Description 'Open Advisor perf items' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorPerfRecs={0}" -f $adv.Count) -Recommendation 'Track trends; remediate degrading components first (DB, networking)'

}
