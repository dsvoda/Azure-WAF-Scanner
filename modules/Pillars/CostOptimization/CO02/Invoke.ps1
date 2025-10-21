
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:02' -Name 'Cost model maintained' -Description 'Forecasts (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  try { $q = Get-DailyCosts -SubscriptionId $SubscriptionId; $has = $q -and $q.Rows.Count -gt 0 } catch { $has = $false }
  $status = $has ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:02' -Name 'Cost model maintained' -Description 'Costs available for forecasting' `
    -SubscriptionId $SubscriptionId -TestMethod 'CostManagement' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DailyRows={0}" -f (0 + (if($has){$q.Rows.Count}else{0}))) -Recommendation 'Use Cost Management forecasts and maintain a cost model with buffers'

}
