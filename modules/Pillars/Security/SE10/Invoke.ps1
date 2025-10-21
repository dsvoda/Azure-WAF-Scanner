
Register-WafCheck -Pillar 'Security' -Id 'SE10' -Name 'Threat detection & alerting' -Description 'Defender plans + Monitor alerts' -InvokeScript {
  param([string]$SubscriptionId)

  $pricings = Get-AzSecurityPricing -ErrorAction SilentlyContinue
  $std = @($pricings | Where-Object { $_.PricingTier -eq 'Standard' }).Count
  $alerts = Get-AzActivityLogAlert -ErrorAction SilentlyContinue
  $status = ($std -gt 0 -and $alerts.Count -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Security' -Id 'SE10' -Name 'Threat detection & alerting' -Description 'Defender pricing + Activity alerts' `
    -SubscriptionId $SubscriptionId -TestMethod 'Defender+Alerts' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DefenderStandardPlans={0}; ActivityAlerts={1}" -f $std,$alerts.Count) -Recommendation 'Enable Standard plans for key resources; integrate alerts to SIEM/SOAR'

}
