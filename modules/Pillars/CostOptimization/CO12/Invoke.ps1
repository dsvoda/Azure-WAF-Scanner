
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:12' -Name 'Optimize scaling costs' -Description 'Autoscale & rightsizing' -InvokeScript {
  param([string]$SubscriptionId)

  $auto = Get-AzAutoScaleSetting -ErrorAction SilentlyContinue
  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Cost')
  $status = ($auto.Count -gt 0) ? 'Pass' : ( $adv.Count -gt 0 ? 'Warn' : 'Manual' )
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:12' -Name 'Optimize scaling costs' -Description 'Autoscale presence + Advisor rightsizing' `
    -SubscriptionId $SubscriptionId -TestMethod 'Autoscale+Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AutoscaleSettings={0}; AdvisorCost={1}" -f $auto.Count,$adv.Count) -Recommendation 'Implement autoscale and adopt reservations/savings for baseline load'

}
