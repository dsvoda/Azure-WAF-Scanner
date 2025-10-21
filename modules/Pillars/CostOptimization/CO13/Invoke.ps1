
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO13' -Name 'Optimize personnel time' -Description 'Manual (build times, noise, debugging)' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO13' -Name 'Optimize personnel time' -Description 'Evaluate CI/CD metrics & toil' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Use DevOps analytics for build times; reduce alert noise; add high-fidelity debugging' -Recommendation 'Automate repetitive tasks; mock prod in tests'

}
