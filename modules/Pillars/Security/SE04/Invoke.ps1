
Register-WafCheck -Pillar 'Security' -Id 'SE:04' -Name 'Segmentation & perimeters' -Description 'NSG on all subnets; firewall for egress' -InvokeScript {
  param([string]$SubscriptionId)

  $qNoNsg = @"
resources
| where type =~ 'microsoft.network/virtualnetworks/subnets'
| extend nsg= tostring(properties.networkSecurityGroup.id)
| where isempty(nsg) or nsg == 'null'
| project id, name = tostring(split(id,'/')[10])
"@
  $noNsg = Invoke-Arg -Kql $qNoNsg -Subscriptions $SubscriptionId
  $fws = Invoke-Arg -Kql "resources | where type =~ 'microsoft.network/azurefirewalls' | summarize c=count()" -Subscriptions $SubscriptionId
  $status = ($noNsg.Count -eq 0) ? 'Pass' : 'Fail'
  $ev = "SubnetsWithoutNSG={0}; Firewalls={1}" -f $noNsg.Count,$fws[0].c
  if ($noNsg.Count -le 20 -and $noNsg.Count -gt 0) { $ev += "; Examples: " + (($noNsg | Select-Object -First 3).id -join ',') }
  New-WafResult -Pillar 'Security' -Id 'SE:04' -Name 'Segmentation & perimeters' `
    -Description 'All subnets should have NSG; central firewall recommended' -SubscriptionId $SubscriptionId -TestMethod 'ARG KQL' `
    -Status $status -Score (Convert-StatusToScore $status) -Evidence $ev `
    -Recommendation 'Associate NSGs with every subnet; enable default deny; centralize egress via Firewall'

}
