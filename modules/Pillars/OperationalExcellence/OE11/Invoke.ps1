
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:11' -Name 'Safe deployment practices' -Description 'App Service deployment slots presence' -InvokeScript {
  param([string]$SubscriptionId)

  $apps = Get-AzWebApp -ErrorAction SilentlyContinue
  $slots = 0
  foreach($a in $apps){ $slots += (Get-AzWebAppSlot -ResourceGroupName $a.ResourceGroup -Name $a.Name -ErrorAction SilentlyContinue).Count }
  $status = ($slots -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:11' -Name 'Safe deployment practices' -Description 'Deployment slots (blue/green/canary)' `
    -SubscriptionId $SubscriptionId -TestMethod 'AppService slots' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("WebApps={0}; Slots={1}" -f $apps.Count,$slots) -Recommendation 'Adopt small, incremental releases with slots and gates'

}
