
function Get-OrphanedResources {
  param([string]$SubscriptionId)

  $orphans = @{}

  # Unattached managed disks
  $orphans.Disks = Invoke-Arg -Kql @"
resources
| where type =~ 'microsoft.compute/disks'
| extend attached = tostring(properties.managedBy)
| where isempty(attached)
| project id, name, resourceGroup, sku = tostring(sku.name), sizeGB = toint(properties.diskSizeGB)
"@ -Subscriptions $SubscriptionId

  # Unattached NICs
  $orphans.Nics = Invoke-Arg -Kql @"
resources
| where type =~ 'microsoft.network/networkinterfaces'
| extend vm = tostring(properties.virtualMachine.id)
| where isempty(vm)
| project id, name, resourceGroup
"@ -Subscriptions $SubscriptionId

  # Public IPs not associated
  $orphans.PublicIPs = Invoke-Arg -Kql @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend ipConf = tostring(properties.ipConfiguration.id)
| where isempty(ipConf)
| project id, name, resourceGroup, publicIP = tostring(properties.ipAddress)
"@ -Subscriptions $SubscriptionId

  # Empty NSGs (no rules)
  $orphans.Nsgs = Invoke-Arg -Kql @"
resources
| where type =~ 'microsoft.network/networksecuritygroups'
| extend ruleCount = array_length(properties.securityRules)
| where ruleCount == 0
| project id, name, resourceGroup
"@ -Subscriptions $SubscriptionId

  # Unused App Service plans (no apps)
  $orphans.AppServicePlans = Invoke-Arg -Kql @"
resources
| where type =~ 'microsoft.web/serverfarms'
| join kind=leftouter (
  resources
  | where type =~ 'microsoft.web/sites'
  | extend planId = tolower(tostring(properties.serverFarmId))
  | project siteId = id, planId
) on $left.id == $right.planId
| where isempty(siteId)
| project id, name, resourceGroup, sku = tostring(sku.tier)
"@ -Subscriptions $SubscriptionId

  # Disconnected NIC security groups?
  $orphans.EmptyRGs = Invoke-Arg -Kql @"
resources | summarize c=count() by resourceGroup | where c == 0 | project resourceGroup
"@ -Subscriptions $SubscriptionId

  return $orphans
}
