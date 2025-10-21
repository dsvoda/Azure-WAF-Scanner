
Register-WafCheck -Pillar 'Reliability' -Id 'RE04' -Name 'Reliability targets & health model' -Description 'Alert rules tied to SLOs; presence check' -InvokeScript {
  param([string]$SubscriptionId)

  $alerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue
  $status = ($alerts.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Reliability' -Id 'RE04' -Name 'Reliability targets & health model' -Description 'Metric alert rules present (proxy for SLOs)' `
    -SubscriptionId $SubscriptionId -TestMethod 'Monitor Alerts' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("MetricAlerts={0}" -f $alerts.Count) `
    -Recommendation 'Define SLOs (uptime/RTO/RPO) and create metric alerts for breaches'

}
