
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE07' -Name 'Monitoring & telemetry' -Description 'Diag settings + App Insights presence' -InvokeScript {
  param([string]$SubscriptionId)

  $diag = Invoke-Arg -Kql "resources | where type =~ 'microsoft.insights/diagnosticSettings' | summarize c=count()" -Subscriptions $SubscriptionId
  $aiCount = @(Get-AzApplicationInsights -ErrorAction SilentlyContinue).Count
  $status = ($diag[0].c -gt 0 -and $aiCount -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE07' -Name 'Monitoring & telemetry' -Description 'Diag settings + App Insights' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG+AppInsights' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DiagSettings={0}; AppInsightsApps={1}" -f $diag[0].c,$aiCount) -Recommendation 'Send diagnostics to Log Analytics; define KPI dashboards; add alert rules'

}
