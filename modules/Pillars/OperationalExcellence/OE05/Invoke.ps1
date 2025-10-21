
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:05' -Name 'Infrastructure as Code' -Description 'ARM/Bicep deployments presence (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  $deploys = Get-AzDeployment -ErrorAction SilentlyContinue
  $rgdeploys = Get-AzResourceGroup | ForEach-Object { Get-AzResourceGroupDeployment -ResourceGroupName $_.ResourceGroupName -ErrorAction SilentlyContinue } | Measure-Object | Select-Object -ExpandProperty Count
  $count = ($deploys | Measure-Object).Count + $rgdeploys
  $status = ($count -gt 0) ? 'Warn' : 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:05' -Name 'Infrastructure as Code' -Description 'ARM/Bicep deployments detected' `
    -SubscriptionId $SubscriptionId -TestMethod 'Deployments presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("DeploymentRecords={0}" -f $count) -Recommendation 'Manage infra with Bicep/ARM/Terraform via CI; add preflight validation'

}
