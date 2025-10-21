
Register-WafCheck -Pillar 'Security' -Id 'SE02' -Name 'Secure SDLC & supply chain' -Description 'DevOps security signals (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Security' -Id 'SE02' -Name 'Secure SDLC & supply chain' -Description 'Validate pipelines scanning (Defender for DevOps)' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual verification' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Pipelines & repos not discoverable via Az.* at subscription scope' -Recommendation 'Integrate code scanning; enable Defender for DevOps; require threat modeling'

}
