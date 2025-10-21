
Register-WafCheck -Pillar 'Reliability' -Id 'RE:05' -Name 'Redundancy' -Description 'Redundancy for compute/network across AZ/sets' -InvokeScript {
  param([string]$SubscriptionId)
  $redundancyKql = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend az = tostring(properties.zones[0]), avset = tostring(properties.availabilitySet.id)
| extend hasRedundancy = iif(isnotempty(az) or isnotempty(avset), true, false)
| summarize total=count(), nonRedundant=countif(hasRedundancy==false)
"@
  $r = Invoke-Arg -Kql $redundancyKql -Subscriptions $SubscriptionId
  $status = ($r[0].nonRedundant -gt 0) ? 'Fail' : 'Pass'
  New-WafResult -Pillar 'Reliability' -Id 'RE:05' -Name 'Redundancy' -Description 'VMs in AZ/AvSet' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG KQL' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ($r | ConvertTo-Json -Depth 5) -Recommendation 'Place singletons into AZs/Availability Sets; prefer VMSS' -EstimatedROI $null
}
