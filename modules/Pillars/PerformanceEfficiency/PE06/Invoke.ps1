
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE06' -Name 'Performance testing' -Description 'Automated load tests in staging' -InvokeScript {
  param([string]$SubscriptionId)
  try { $lt = Get-AzLoadTest -ErrorAction Stop; $status = ($lt.Count -gt 0) ? 'Pass' : 'Manual' }
  catch { $status = 'Manual'; $lt = @() }
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE06' -Name 'Performance testing' `
    -Description 'Azure Load Testing presence' -SubscriptionId $SubscriptionId -TestMethod 'Az.LoadTesting presence' `
    -Status $status -Score (Convert-StatusToScore $status) -Evidence ("LoadTests={0}" -f $lt.Count) `
    -Recommendation 'Run perf tests per release; compare to SLO/benchmarks; gate promotion on results'
}
