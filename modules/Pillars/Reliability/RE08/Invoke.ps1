
Register-WafCheck -Pillar 'Reliability' -Id 'RE08' -Name 'Chaos engineering tests' -Description 'Chaos Studio experiments presence' -InvokeScript {
  param([string]$SubscriptionId)

  try { $exp = Get-AzChaosExperiment -ErrorAction Stop; $status = ($exp.Count -gt 0) ? 'Pass' : 'Manual' }
  catch { $status = 'Manual'; $exp = @() }
  New-WafResult -Pillar 'Reliability' -Id 'RE08' -Name 'Chaos engineering tests' -Description 'Azure Chaos Studio experiments' `
    -SubscriptionId $SubscriptionId -TestMethod 'ChaosStudio presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("Experiments={0}" -f $exp.Count) -Recommendation 'Design and schedule chaos experiments for critical flows'

}
