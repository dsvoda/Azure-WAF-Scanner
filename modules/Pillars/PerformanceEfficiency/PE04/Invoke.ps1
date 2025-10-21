
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE04' -Name 'Collect performance data' -Description 'Diagnostics + App Insights presence' -InvokeScript {
  param([string]$SubscriptionId)

  $diag = Invoke-Arg -Kql "resources | where type =~ 'microsoft.insights/diagnosticSettings' | summarize c=count()" -Subscriptions $SubscriptionId
  $ai = Get-AzApplicationInsights -ErrorAction SilentlyContinue
  $status = ($diag[0].c -gt 0 -and $ai.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE04' -Name 'Collect performance data' -Description 'Diagnostics + App Insights' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG+AppInsights' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DiagSettings={0}; AppInsights={1}" -f $diag[0].c,$ai.Count) -Recommendation 'Enable telemetry across app, platform, data, OS'

}
