
Register-WafCheck -Pillar 'Security' -Id 'SE:08' -Name 'Harden components' -Description 'Defender secure score & open recommendations' -InvokeScript {
  param([string]$SubscriptionId)

  $score = Get-SecureScore -SubscriptionId $SubscriptionId
  $recs = Get-DefenderAssessments -SubscriptionId $SubscriptionId
  $status = ($recs.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Security' -Id 'SE:08' -Name 'Harden components' -Description 'Open security assessments' `
    -SubscriptionId $SubscriptionId -TestMethod 'Defender Assessments' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("SecureScore={0}; OpenAssessments={1}" -f $score.SecureScore,$recs.Count) -Recommendation 'Remediate Defender recommendations; enforce secure configurations via Policy'

}
