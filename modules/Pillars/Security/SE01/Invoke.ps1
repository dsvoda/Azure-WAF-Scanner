
Register-WafCheck -Pillar 'Security' -Id 'SE:01' -Name 'Security baseline & posture' -Description 'Policy/Defender baseline coverage' -InvokeScript {
  param([string]$SubscriptionId)

  $pol = Get-PolicySummary -SubscriptionId $SubscriptionId
  $score = Get-SecureScore -SubscriptionId $SubscriptionId
  $status = ($score.SecureScore -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Security' -Id 'SE:01' -Name 'Security baseline & posture' -Description 'Policy summary + Secure Score' `
    -SubscriptionId $SubscriptionId -TestMethod 'Policy+SecureScore' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("SecureScore={0}; PolicySummaries={1}" -f $score.SecureScore, (($pol | Measure-Object).Count)) `
    -Recommendation 'Assign Azure Security Benchmark initiative; remediate Defender recommendations'

}
