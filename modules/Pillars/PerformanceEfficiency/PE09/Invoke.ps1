
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE09' -Name 'Prioritize critical flows' -Description 'Criticality tags present (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $tag = Invoke-Arg -Kql "resources | where isnotempty(tags.['criticality']) | summarize tagged=count()" -Subscriptions $SubscriptionId
  $status = ($tag[0].tagged -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE09' -Name 'Prioritize critical flows' -Description 'Criticality tags' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG tags' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("CriticalityTagged={0}" -f $tag[0].tagged) -Recommendation 'Tag flows; allocate resources/optimization to most critical paths'

}
