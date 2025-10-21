
Register-WafCheck -Pillar 'Reliability' -Id 'RE:02' -Name 'Identify & rate flows' -Description 'Application Insights map and criticality tags' -InvokeScript {
  param([string]$SubscriptionId)

  $ai = Get-AzApplicationInsights -ErrorAction SilentlyContinue
  $kql = "resources | where isnotempty(tags.['criticality']) | summarize criticalTagged=count()"
  $tag = Invoke-Arg -Kql $kql -Subscriptions $SubscriptionId
  $status = ($ai.Count -gt 0 -and $tag[0].criticalTagged -gt 0) ? 'Pass' : 'Manual'
  New-WafResult -Pillar 'Reliability' -Id 'RE:02' -Name 'Identify & rate flows' -Description 'App Insights present + criticality tags' `
    -SubscriptionId $SubscriptionId -TestMethod 'AppInsights+ARG tags' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AppInsightsApps={0}; CriticalityTagged={1}" -f $ai.Count,$tag[0].criticalTagged) `
    -Recommendation 'Instrument flows with App Insights; tag resources with criticality (high/med/low)'

}
