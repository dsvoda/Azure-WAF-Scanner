
Register-WafCheck -Pillar 'Reliability' -Id 'RE:01' -Name 'Simplicity & efficiency' -Description 'Advisor simplification & resource graph complexity' -InvokeScript {
  param([string]$SubscriptionId)

  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('Cost','HighAvailability','Performance')
  $kql = @"
resources | summarize total=count(), types=dcount(type), rg=dcount(resourceGroup)
"@
  $agg = Invoke-Arg -Kql $kql -Subscriptions $SubscriptionId
  $status = ($adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Reliability' -Id 'RE:01' -Name 'Simplicity & efficiency' -Description 'Advisor + complexity snapshot' `
    -SubscriptionId $SubscriptionId -TestMethod 'Advisor+ARG' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("Advisor={0}; Total={1}; Types={2}; RGs={3}" -f ($adv.Count), $agg[0].total, $agg[0].types, $agg[0].rg) `
    -Recommendation 'Address Advisor items; reduce unnecessary resource types/duplicate services'

}
