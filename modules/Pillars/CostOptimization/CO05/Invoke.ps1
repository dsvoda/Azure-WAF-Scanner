
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:05' -Name 'Use best rates' -Description 'Advisor: reservations/savings opportunities' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Cost')
  $savings = 0
  foreach($a in $adv){ if ($a.ExtendedProperties.estimatedSavingsAmount) { $savings += [decimal]$a.ExtendedProperties.estimatedSavingsAmount } }
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:05' -Name 'Use best rates' -Description 'Advisor cost savings' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AdvisorCostRecs={0}; EstSavings={1}" -f $adv.Count,$savings) -Recommendation 'Purchase reservations/savings plans where applicable; review regional pricing regularly' `
    -EstimatedROI (Estimate-ROI -EstimatedMonthlySavings $savings)

}
