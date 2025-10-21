
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE05' -Name 'Optimize scaling & partitioning' -Description 'Autoscale settings presence' -InvokeScript {
  param([string]$SubscriptionId)

  $auto = Get-AzAutoScaleSetting -ErrorAction SilentlyContinue
  $status = ($auto.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE05' -Name 'Optimize scaling & partitioning' -Description 'Autoscale settings present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Autoscale' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AutoscaleSettings={0}" -f $auto.Count) -Recommendation 'Adopt metric-driven autoscale and partition by scale units'

}
