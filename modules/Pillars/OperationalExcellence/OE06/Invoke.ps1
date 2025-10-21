
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:06' -Name 'Automated pipelines across environments' -Description 'Manual (CI/CD visibility)' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:06' -Name 'Automated pipelines across environments' -Description 'Pipelines promote changes across envs with gates' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Pipeline topology not visible via subscription' -Recommendation 'Use GitHub Actions/Azure DevOps with gates and quality checks'

}
