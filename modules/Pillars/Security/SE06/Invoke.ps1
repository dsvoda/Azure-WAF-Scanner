
Register-WafCheck -Pillar 'Security' -Id 'SE06' -Name 'Ingress/egress controls' -Description 'NSGs + Firewall + DDoS plan' -InvokeScript {
  param([string]$SubscriptionId)

  $noNsg = Invoke-Arg -Kql "resources | where type =~ 'microsoft.network/virtualnetworks/subnets' | extend nsg=tostring(properties.networkSecurityGroup.id) | where isempty(nsg) or nsg=='null' | summarize c=count()" -Subscriptions $SubscriptionId
  $fw = Invoke-Arg -Kql "resources | where type =~ 'microsoft.network/azurefirewalls' | summarize c=count()" -Subscriptions $SubscriptionId
  $ddos = Invoke-Arg -Kql "resources | where type =~ 'microsoft.network/virtualnetworks' | extend ddos=bool(tostring(properties.enableDdosProtection)) | summarize protected=countif(ddos==true)" -Subscriptions $SubscriptionId
  $status = ($noNsg[0].c -eq 0 -and $fw[0].c -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Security' -Id 'SE06' -Name 'Ingress/egress controls' -Description 'Subnets with NSGs; central firewall; DDoS' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG KQL' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("SubnetsWithoutNSG={0}; Firewalls={1}; DDoSProtectedVNets={2}" -f $noNsg[0].c,$fw[0].c,$ddos[0].protected) -Recommendation 'Apply NSGs to all subnets; route egress via Firewall; enable DDoS protection for internet-facing VNets'

}
