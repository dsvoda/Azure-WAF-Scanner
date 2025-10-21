
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:04' -Name 'Dev & QA best practices' -Description 'Manual + lint/CI indicators' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:04' -Name 'Dev & QA best practices' -Description 'Standardize repos, linting, tests' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Source control/lint config outside Azure subscription' -Recommendation 'Require lint/tests in pipelines; use templates and style guides'

}
