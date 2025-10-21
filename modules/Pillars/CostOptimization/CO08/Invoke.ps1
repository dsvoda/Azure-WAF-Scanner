
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:08' -Name 'Optimize environment costs' -Description 'Environment tags + budgets per env (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $envTag = Invoke-Arg -Kql "resources | where isnotempty(tags.['environment']) | summarize tagged=count()" -Subscriptions $SubscriptionId
  $status = ($envTag[0].tagged -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:08' -Name 'Optimize environment costs' -Description 'Environment tagging present' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG tags' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("EnvTaggedResources={0}" -f $envTag[0].tagged) -Recommendation 'Tag all resources with environment (prod/nonprod) and apply budgets per env'

}
