
Register-WafCheck -Pillar 'Reliability' -Id 'RE:03' -Name 'Failure mode analysis' -Description 'Dependencies & single points via ARG; Advisor HA' -InvokeScript {
  param([string]$SubscriptionId)

  $singleVmKql = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend az = tostring(properties.zones[0]), avset = tostring(properties.availabilitySet.id)
| where isempty(az) and isempty(avset)
| summarize singletons=count()
"@
  $vm = Invoke-Arg -Kql $singleVmKql -Subscriptions $SubscriptionId
  $adv = Get-Advisor -SubscriptionId $SubscriptionId -Category @('HighAvailability')
  $status = ($vm[0].singletons -gt 0 -or $adv.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Reliability' -Id 'RE:03' -Name 'Failure mode analysis' -Description 'Singleton VMs & HA Advisor recs' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG+Advisor' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("SingletonVMs={0}; HAAdvisor={1}" -f $vm[0].singletons,$adv.Count) `
    -Recommendation 'Eliminate single points (use AZ/VMSS); apply Advisor HA recommendations'

}
