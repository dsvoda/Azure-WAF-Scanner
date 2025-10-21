
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE01' -Name 'Define performance targets' -Description 'Alert rules for perf SLOs' -InvokeScript {
  param([string]$SubscriptionId)

  $alerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue | Where-Object { $_.Criteria -ne $null }
  $status = ($alerts.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE01' -Name 'Define performance targets' -Description 'Metric alerts as target proxies' `
    -SubscriptionId $SubscriptionId -TestMethod 'Monitor alerts' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("MetricAlerts={0}" -f $alerts.Count) -Recommendation 'Define numeric targets (latency, RPS) and alert on breaches'

}
