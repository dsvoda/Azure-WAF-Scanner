
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:03' -Name 'Collect & review cost data' -Description 'Daily cost capture, trends, budgets, alerts' -InvokeScript {
  param([string]$SubscriptionId)
  $daily = Get-DailyCosts -SubscriptionId $SubscriptionId
  $hasCosts = try { $daily.Rows.Count -gt 0 } catch { $false }
  $budgets = Get-AzConsumptionBudget -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
  $status  = ($hasCosts -and $budgets) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:03' -Name 'Collect & review cost data' `
    -Description 'Daily costs + budgets' -SubscriptionId $SubscriptionId -TestMethod 'CostManagement+Budgets' `
    -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DailyRows={0}; Budgets={1}" -f (0 + (if($hasCosts){$daily.Rows.Count}else{0})), (0 + (($budgets|Measure-Object).Count))) `
    -Recommendation 'Create monthly budgets with 50/80/100% alerts; enable anomaly detection; review weekly' -EstimatedROI $null
}
