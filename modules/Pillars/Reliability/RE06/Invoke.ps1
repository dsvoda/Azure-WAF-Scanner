
Register-WafCheck -Pillar 'Reliability' -Id 'RE06' -Name 'Scaling strategy' -Description 'Autoscale settings for AppSvc/VMSS/AKS' -InvokeScript {
  param([string]$SubscriptionId)

  $auto = Get-AzAutoScaleSetting -ErrorAction SilentlyContinue
  $status = ($auto.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Reliability' -Id 'RE06' -Name 'Scaling strategy' -Description 'Autoscale settings presence' `
    -SubscriptionId $SubscriptionId -TestMethod 'Autoscale' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AutoscaleSettings={0}" -f $auto.Count) -Recommendation 'Implement metric-based autoscale for App Service/VMSS/AKS'

}
