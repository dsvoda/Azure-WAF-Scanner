
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE10' -Name 'Optimize operational tasks' -Description 'Manual (backups, reindexing windows)' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE10' -Name 'Optimize operational tasks' -Description 'Measure impact of backups, rotations, deployments' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Correlate performance dips with operational jobs via Monitor' -Recommendation 'Schedule heavy ops in off-peak; throttle and monitor'

}
