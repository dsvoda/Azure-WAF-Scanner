
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:09' -Name 'Optimize flow costs' -Description 'Tags for flows/priorities (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $flow = Invoke-Arg -Kql "resources | where isnotempty(tags.['flow']) or isnotempty(tags.['criticality']) | summarize c=count()" -Subscriptions $SubscriptionId
  $status = ($flow[0].c -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:09' -Name 'Optimize flow costs' -Description 'Flow/criticality tags present' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG tags' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("TaggedResources={0}" -f $flow[0].c) -Recommendation 'Tag flows & priorities; align spend to flow importance'

}
