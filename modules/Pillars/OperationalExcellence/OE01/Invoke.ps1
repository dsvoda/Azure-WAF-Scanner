
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:01' -Name 'Standard practices defined' -Description 'Manual: standards/process culture' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:01' -Name 'Standard practices defined' -Description 'Document standards; blameless culture; CI' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Standards not discoverable from Azure APIs' -Recommendation 'Publish standards; measure code reviews, deployment frequency, MTTR'

}
