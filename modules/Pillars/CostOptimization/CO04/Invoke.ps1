
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO:04' -Name 'Spending guardrails' -Description 'Policy guardrails presence' -InvokeScript {
  param([string]$SubscriptionId)

  $assign = Get-AzPolicyAssignment -ErrorAction SilentlyContinue
  $has = $assign | Where-Object { $_.PolicyDefinitionId -match 'allowedlocations|allowedResourceTypes|allowedvmSKUs' }
  $status = ($has) ? 'Pass' : 'Fail'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO:04' -Name 'Spending guardrails' -Description 'Allowed locations/SKU/type policies present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Policy assignments' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("GuardrailPoliciesFound={0}" -f (($has|Measure-Object).Count)) -Recommendation 'Assign initiatives for allowed locations/SKUs; add budgets; enforce via deny/auditIfNotExists'

}
