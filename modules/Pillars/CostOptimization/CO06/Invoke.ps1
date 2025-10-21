
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO06' -Name 'Align usage to billing increments' -Description 'Manual validation of meters vs usage' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO06' -Name 'Align usage to billing increments' -Description 'Billing meter alignment requires workload-specific review' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Review meter granularity and adjust service configs/usage patterns' -Recommendation 'Use cost analysis by meter and tune instance sizes/durations'

}
