
Register-WafCheck -Pillar 'Reliability' -Id 'RE:10' -Name 'Measure & model health' -Description 'Uptime/health metrics via Monitor/App Insights' -InvokeScript {
  param([string]$SubscriptionId)

  $alerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue
  $ai = Get-AzApplicationInsights -ErrorAction SilentlyContinue
  $status = ($alerts.Count -gt 0 -and $ai.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Reliability' -Id 'RE:10' -Name 'Measure & model health' -Description 'Alerts + App Insights presence' `
    -SubscriptionId $SubscriptionId -TestMethod 'Monitor+AppInsights' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("MetricAlerts={0}; AppInsightsApps={1}" -f $alerts.Count,$ai.Count) -Recommendation 'Collect availability/latency metrics; model SLI/SLO in dashboards'

}
