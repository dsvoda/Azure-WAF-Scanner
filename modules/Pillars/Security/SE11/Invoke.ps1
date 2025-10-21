
Register-WafCheck -Pillar 'Security' -Id 'SE11' -Name 'Security testing regimen' -Description 'Vulnerability assessment signals' -InvokeScript {
  param([string]$SubscriptionId)

  $assess = Get-DefenderAssessments -SubscriptionId $SubscriptionId | Where-Object { $_.DisplayName -match 'vulnerab' }
  $status = ($assess.Count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Security' -Id 'SE11' -Name 'Security testing regimen' -Description 'Vulnerability assessments present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Defender Assessments' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("VA_Findings={0}" -f $assess.Count) -Recommendation 'Enable VM/Container/DB vulnerability assessment in Defender; test detection rules'

}
