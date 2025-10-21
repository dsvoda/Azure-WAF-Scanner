
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE12' -Name 'Deployment failure mitigation' -Description 'Feature flags/App Configuration presence' -InvokeScript {
  param([string]$SubscriptionId)

  try { $appcfg = Get-AzAppConfigurationStore -ErrorAction Stop; $status = ($appcfg.Count -gt 0) ? 'Warn' : 'Manual' } catch { $status = 'Manual' }
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE12' -Name 'Deployment failure mitigation' -Description 'Feature flags/rollback patterns recommended' `
    -SubscriptionId $SubscriptionId -TestMethod 'App Configuration presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AppConfigurationStores={0}" -f (if($appcfg){$appcfg.Count}else{0})) -Recommendation 'Use feature flags and automated rollback on failure detection'

}
