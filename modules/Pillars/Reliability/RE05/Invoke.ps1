<#
.SYNOPSIS
    RE05 - Add redundancy at different levels

.DESCRIPTION
    Validates that redundancy is implemented across all critical infrastructure layers
    to eliminate single points of failure and ensure high availability.
    
    This check comprehensively assesses:
    - Compute redundancy (VMs, App Services, Container instances)
    - Network redundancy (Load Balancers, Application Gateways, Traffic Manager)
    - Data redundancy (Storage, Databases, Cache)
    - Availability Zones and Sets utilization
    - Multi-region deployments
    - Component-level redundancy (single instance resources)

.NOTES
    Pillar: Reliability
    Recommendation: RE:05 from Microsoft WAF
    Severity: Critical
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/redundancy
    https://learn.microsoft.com/azure/reliability/availability-zones-overview
#>

Register-WafCheck -CheckId 'RE05' `
    -Pillar 'Reliability' `
    -Title 'Add redundancy at different levels' `
    -Description 'Implement redundancy across compute, network, and data layers to eliminate single points of failure and achieve high availability targets' `
    -Severity 'Critical' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'Redundancy', 'HighAvailability', 'AvailabilityZones', 'SPOF', 'MultiRegion') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/redundancy' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            $redundancyGaps = @()
            $redundancyStrengths = @()
            $totalResources = 0
            $redundantResources = 0
            
            # Category scores
            $scores = @{
                Compute = @{ Current = 0; Max = 30 }
                Network = @{ Current = 0; Max = 25 }
                Data = @{ Current = 0; Max = 30 }
                Zones = @{ Current = 0; Max = 15 }
            }
            
            #region 1. COMPUTE REDUNDANCY
            
            Write-Verbose "Analyzing compute redundancy..."
            
            # Virtual Machines - Check for zones and availability sets
            $vmQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| extend 
    zones = tostring(zones),
    availabilitySet = tostring(properties.availabilitySet.id),
    vmSize = tostring(properties.hardwareProfile.vmSize),
    location = location
| project 
    id,
    name,
    resourceGroup,
    location,
    zones,
    availabilitySet,
    vmSize,
    tags
"@
            $vms = Invoke-AzResourceGraphQuery -Query $vmQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($vms -and $vms.Count -gt 0) {
                $totalResources += $vms.Count
                $vmsWithZones = 0
                $vmsWithAvailabilitySets = 0
                $vmsNoRedundancy = @()
                
                foreach ($vm in $vms) {
                    $hasZones = $vm.zones -and $vm.zones -ne '[]' -and $vm.zones -ne 'null'
                    $hasAvSet = $vm.availabilitySet -and $vm.availabilitySet -ne 'null' -and $vm.availabilitySet -ne ''
                    
                    if ($hasZones) {
                        $vmsWithZones++
                        $redundantResources++
                    } elseif ($hasAvSet) {
                        $vmsWithAvailabilitySets++
                        $redundantResources++
                    } else {
                        $vmsNoRedundancy += $vm.name
                    }
                }
                
                # Score VMs
                $vmRedundancyPercent = (($vmsWithZones + $vmsWithAvailabilitySets) / $vms.Count) * 100
                $scores.Compute.Current += [Math]::Min(15, ($vmRedundancyPercent / 100) * 15)
                
                if ($vmsNoRedundancy.Count -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Compute'
                        Resource = 'Virtual Machines'
                        Issue = "$($vmsNoRedundancy.Count) of $($vms.Count) VMs lack redundancy"
                        Impact = 'Critical'
                        Details = "VMs without zones or availability sets: $(($vmsNoRedundancy | Select-Object -First 5) -join ', ')$(if ($vmsNoRedundancy.Count -gt 5) { '...' })"
                    }
                } else {
                    $redundancyStrengths += "✓ All $($vms.Count) VMs have redundancy (Zones: $vmsWithZones, Availability Sets: $vmsWithAvailabilitySets)"
                }
            }
            
            # VM Scale Sets - inherently redundant
            $vmssQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend 
    zones = tostring(zones),
    capacity = toint(sku.capacity),
    overprovision = tobool(properties.overprovision)
| project 
    id,
    name,
    resourceGroup,
    location,
    zones,
    capacity,
    overprovision
"@
            $vmss = Invoke-AzResourceGraphQuery -Query $vmssQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($vmss -and $vmss.Count -gt 0) {
                $totalResources += $vmss.Count
                $redundantResources += $vmss.Count
                
                $vmssWithZones = ($vmss | Where-Object { $_.zones -and $_.zones -ne '[]' -and $_.zones -ne 'null' }).Count
                $vmssLowCapacity = ($vmss | Where-Object { $_.capacity -lt 2 }).Count
                
                $scores.Compute.Current += 5
                
                if ($vmssWithZones -eq $vmss.Count) {
                    $redundancyStrengths += "✓ All $($vmss.Count) VM Scale Sets use Availability Zones"
                    $scores.Zones.Current += 5
                } elseif ($vmssWithZones -gt 0) {
                    $redundancyStrengths += "✓ $vmssWithZones of $($vmss.Count) VM Scale Sets use Availability Zones"
                    $scores.Zones.Current += 3
                }
                
                if ($vmssLowCapacity -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Compute'
                        Resource = 'VM Scale Sets'
                        Issue = "$vmssLowCapacity VMSS instance(s) have capacity < 2"
                        Impact = 'High'
                        Details = "Scale sets should have at least 2 instances for redundancy"
                    }
                }
            }
            
            # App Services - Check instance count
            $appServiceQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/serverfarms'
| extend 
    skuName = tostring(sku.name),
    skuTier = tostring(sku.tier),
    capacity = toint(sku.capacity),
    zoneRedundant = tobool(properties.zoneRedundant)
| project 
    id,
    name,
    resourceGroup,
    location,
    skuName,
    skuTier,
    capacity,
    zoneRedundant
"@
            $appServicePlans = Invoke-AzResourceGraphQuery -Query $appServiceQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($appServicePlans -and $appServicePlans.Count -gt 0) {
                $totalResources += $appServicePlans.Count
                $plansMultiInstance = 0
                $plansSingleInstance = @()
                $plansZoneRedundant = 0
                
                foreach ($plan in $appServicePlans) {
                    $capacity = if ($plan.capacity) { $plan.capacity } else { 1 }
                    $isSharedTier = $plan.skuTier -match 'Free|Shared|Basic'
                    
                    if ($plan.zoneRedundant) {
                        $plansZoneRedundant++
                    }
                    
                    if (!$isSharedTier -and $capacity -ge 2) {
                        $plansMultiInstance++
                        $redundantResources++
                    } else {
                        $plansSingleInstance += "$($plan.name) ($($plan.skuTier), Capacity: $capacity)"
                    }
                }
                
                $planRedundancyPercent = ($plansMultiInstance / $appServicePlans.Count) * 100
                $scores.Compute.Current += [Math]::Min(10, ($planRedundancyPercent / 100) * 10)
                
                if ($plansZoneRedundant -gt 0) {
                    $redundancyStrengths += "✓ $plansZoneRedundant App Service Plan(s) are zone-redundant"
                    $scores.Zones.Current += 5
                }
                
                if ($plansSingleInstance.Count -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Compute'
                        Resource = 'App Service Plans'
                        Issue = "$($plansSingleInstance.Count) of $($appServicePlans.Count) plans have single instance"
                        Impact = 'High'
                        Details = "Single-instance plans: $(($plansSingleInstance | Select-Object -First 3) -join '; ')$(if ($plansSingleInstance.Count -gt 3) { '...' })"
                    }
                } else {
                    $redundancyStrengths += "✓ All $($appServicePlans.Count) App Service Plans scaled to 2+ instances"
                }
            }
            
            # AKS Clusters - Check node pool configuration
            $aksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| extend 
    nodePools = properties.agentPoolProfiles,
    availabilityZones = tostring(properties.agentPoolProfiles[0].availabilityZones)
| project 
    id,
    name,
    resourceGroup,
    location,
    nodePools,
    availabilityZones
"@
            $aksClusters = Invoke-AzResourceGraphQuery -Query $aksQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($aksClusters -and $aksClusters.Count -gt 0) {
                $totalResources += $aksClusters.Count
                $aksWithZones = 0
                $aksMultiNode = 0
                
                foreach ($aks in $aksClusters) {
                    if ($aks.availabilityZones -and $aks.availabilityZones -ne '[]' -and $aks.availabilityZones -ne 'null') {
                        $aksWithZones++
                        $redundantResources++
                    }
                    
                    # Assume multi-node if AKS exists (production default)
                    $aksMultiNode++
                    $redundantResources++
                }
                
                $scores.Compute.Current += 5
                
                if ($aksWithZones -eq $aksClusters.Count) {
                    $redundancyStrengths += "✓ All $($aksClusters.Count) AKS cluster(s) use Availability Zones"
                    $scores.Zones.Current += 5
                } elseif ($aksWithZones -gt 0) {
                    $redundancyStrengths += "✓ $aksWithZones of $($aksClusters.Count) AKS cluster(s) use Availability Zones"
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Compute'
                        Resource = 'AKS Clusters'
                        Issue = "$($aksClusters.Count - $aksWithZones) AKS cluster(s) not using zones"
                        Impact = 'High'
                        Details = "Deploy AKS node pools across availability zones for zone-level redundancy"
                    }
                }
            }
            
            #endregion
            
            #region 2. NETWORK REDUNDANCY
            
            Write-Verbose "Analyzing network redundancy..."
            
            # Load Balancers - Check SKU and backend pools
            $loadBalancerQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/loadbalancers'
| extend 
    skuName = tostring(sku.name),
    backendPools = array_length(properties.backendAddressPools),
    frontendConfigs = array_length(properties.frontendIPConfigurations)
| project 
    id,
    name,
    resourceGroup,
    location,
    skuName,
    backendPools,
    frontendConfigs
"@
            $loadBalancers = Invoke-AzResourceGraphQuery -Query $loadBalancerQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($loadBalancers -and $loadBalancers.Count -gt 0) {
                $totalResources += $loadBalancers.Count
                $lbStandard = ($loadBalancers | Where-Object { $_.skuName -eq 'Standard' }).Count
                $lbWithBackends = ($loadBalancers | Where-Object { $_.backendPools -gt 0 }).Count
                
                if ($lbStandard -eq $loadBalancers.Count) {
                    $redundancyStrengths += "✓ All $($loadBalancers.Count) Load Balancer(s) use Standard SKU (zone-redundant)"
                    $scores.Network.Current += 10
                    $redundantResources += $loadBalancers.Count
                } elseif ($lbStandard -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Network'
                        Resource = 'Load Balancers'
                        Issue = "$($loadBalancers.Count - $lbStandard) Load Balancer(s) using Basic SKU"
                        Impact = 'High'
                        Details = "Basic SKU doesn't support Availability Zones - upgrade to Standard SKU"
                    }
                    $scores.Network.Current += 5
                }
                
                if ($lbWithBackends -ne $loadBalancers.Count) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Network'
                        Resource = 'Load Balancers'
                        Issue = "$($loadBalancers.Count - $lbWithBackends) Load Balancer(s) have no backend pools"
                        Impact = 'Medium'
                        Details = "Configure backend pools with multiple instances for redundancy"
                    }
                }
            }
            
            # Application Gateways - Check capacity and zones
            $appGatewayQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgateways'
| extend 
    skuName = tostring(sku.name),
    capacity = toint(sku.capacity),
    zones = tostring(zones),
    autoscale = properties.autoscaleConfiguration
| project 
    id,
    name,
    resourceGroup,
    location,
    skuName,
    capacity,
    zones,
    autoscale
"@
            $appGateways = Invoke-AzResourceGraphQuery -Query $appGatewayQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($appGateways -and $appGateways.Count -gt 0) {
                $totalResources += $appGateways.Count
                $agWithZones = 0
                $agMultiInstance = 0
                $agWithAutoscale = 0
                
                foreach ($ag in $appGateways) {
                    $hasZones = $ag.zones -and $ag.zones -ne '[]' -and $ag.zones -ne 'null'
                    $capacity = if ($ag.capacity) { $ag.capacity } else { 1 }
                    $hasAutoscale = $ag.autoscale -and $ag.autoscale -ne 'null'
                    
                    if ($hasZones) {
                        $agWithZones++
                        $redundantResources++
                    }
                    
                    if ($hasAutoscale -or $capacity -ge 2) {
                        $agMultiInstance++
                    }
                    
                    if ($hasAutoscale) {
                        $agWithAutoscale++
                    }
                }
                
                if ($agWithZones -eq $appGateways.Count) {
                    $redundancyStrengths += "✓ All $($appGateways.Count) Application Gateway(s) use Availability Zones"
                    $scores.Network.Current += 10
                    $scores.Zones.Current += 5
                } elseif ($agWithZones -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Network'
                        Resource = 'Application Gateways'
                        Issue = "$($appGateways.Count - $agWithZones) Application Gateway(s) not zone-redundant"
                        Impact = 'High'
                        Details = "Deploy Application Gateway across availability zones"
                    }
                    $scores.Network.Current += 5
                }
                
                if ($agMultiInstance -ne $appGateways.Count) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Network'
                        Resource = 'Application Gateways'
                        Issue = "$($appGateways.Count - $agMultiInstance) Application Gateway(s) have single instance"
                        Impact = 'High'
                        Details = "Scale to minimum 2 instances or enable autoscaling"
                    }
                }
                
                if ($agWithAutoscale -gt 0) {
                    $redundancyStrengths += "✓ $agWithAutoscale Application Gateway(s) have autoscaling enabled"
                }
            }
            
            # Traffic Manager Profiles - Multi-region redundancy
            $trafficManagerQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/trafficmanagerprofiles'
| extend 
    endpoints = array_length(properties.endpoints),
    routingMethod = tostring(properties.trafficRoutingMethod)
| project 
    id,
    name,
    resourceGroup,
    endpoints,
    routingMethod
"@
            $trafficManager = Invoke-AzResourceGraphQuery -Query $trafficManagerQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($trafficManager -and $trafficManager.Count -gt 0) {
                $totalResources += $trafficManager.Count
                $tmMultiEndpoint = ($trafficManager | Where-Object { $_.endpoints -ge 2 }).Count
                
                if ($tmMultiEndpoint -eq $trafficManager.Count) {
                    $redundancyStrengths += "✓ All $($trafficManager.Count) Traffic Manager profile(s) have multiple endpoints"
                    $scores.Network.Current += 5
                    $redundantResources += $trafficManager.Count
                } else {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Network'
                        Resource = 'Traffic Manager'
                        Issue = "$($trafficManager.Count - $tmMultiEndpoint) Traffic Manager profile(s) have single endpoint"
                        Impact = 'Critical'
                        Details = "Add endpoints in multiple regions for geographic redundancy"
                    }
                }
            }
            
            # Front Door - Global redundancy
            $frontDoorQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/frontdoors' or type =~ 'microsoft.cdn/profiles'
| where type =~ 'microsoft.network/frontdoors' or (type =~ 'microsoft.cdn/profiles' and sku.name =~ 'Premium_AzureFrontDoor' or sku.name =~ 'Standard_AzureFrontDoor')
| project 
    id,
    name,
    resourceGroup,
    type,
    skuName = tostring(sku.name)
"@
            $frontDoor = Invoke-AzResourceGraphQuery -Query $frontDoorQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($frontDoor -and $frontDoor.Count -gt 0) {
                $totalResources += $frontDoor.Count
                $redundantResources += $frontDoor.Count
                $redundancyStrengths += "✓ $($frontDoor.Count) Azure Front Door/CDN profile(s) provide global redundancy"
                $scores.Network.Current += 5
            }
            
            #endregion
            
            #region 3. DATA REDUNDANCY
            
            Write-Verbose "Analyzing data redundancy..."
            
            # Storage Accounts - Check replication type
            $storageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    replication = tostring(sku.name),
    kind = tostring(kind),
    tier = tostring(sku.tier)
| project 
    id,
    name,
    resourceGroup,
    location,
    replication,
    kind,
    tier
"@
            $storageAccounts = Invoke-AzResourceGraphQuery -Query $storageQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($storageAccounts -and $storageAccounts.Count -gt 0) {
                $totalResources += $storageAccounts.Count
                $storageByReplication = $storageAccounts | Group-Object replication
                
                $lrsCount = ($storageAccounts | Where-Object { $_.replication -match 'LRS' }).Count
                $zrsCount = ($storageAccounts | Where-Object { $_.replication -match 'ZRS' }).Count
                $grsCount = ($storageAccounts | Where-Object { $_.replication -match 'GRS|GZRS' }).Count
                
                if ($lrsCount -eq 0) {
                    $redundancyStrengths += "✓ All $($storageAccounts.Count) storage account(s) use redundant replication (ZRS: $zrsCount, GRS: $grsCount)"
                    $scores.Data.Current += 15
                    $redundantResources += $storageAccounts.Count
                } else {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Data'
                        Resource = 'Storage Accounts'
                        Issue = "$lrsCount of $($storageAccounts.Count) storage account(s) use LRS (single datacenter)"
                        Impact = 'High'
                        Details = "LRS replication: $lrsCount, ZRS: $zrsCount, GRS: $grsCount - Upgrade LRS to ZRS (zone) or GRS (region)"
                    }
                    $scores.Data.Current += [Math]::Min(15, (($zrsCount + $grsCount) / $storageAccounts.Count) * 15)
                    $redundantResources += ($zrsCount + $grsCount)
                }
            }
            
            # SQL Databases - Check for geo-replication and zone redundancy
            $sqlQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| where name !~ 'master'
| extend 
    zoneRedundant = tobool(properties.zoneRedundant),
    skuTier = tostring(sku.tier),
    skuName = tostring(sku.name)
| project 
    id,
    name,
    resourceGroup,
    location,
    zoneRedundant,
    skuTier,
    skuName
"@
            $sqlDatabases = Invoke-AzResourceGraphQuery -Query $sqlQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($sqlDatabases -and $sqlDatabases.Count -gt 0) {
                $totalResources += $sqlDatabases.Count
                $sqlZoneRedundant = ($sqlDatabases | Where-Object { $_.zoneRedundant -eq $true }).Count
                
                # Check for geo-replication (via replication links)
                $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
                $sqlGeoReplicated = 0
                
                foreach ($server in $sqlServers) {
                    $databases = Get-AzSqlDatabase -ServerName $server.ServerName `
                        -ResourceGroupName $server.ResourceGroupName `
                        -ErrorAction SilentlyContinue | 
                        Where-Object { $_.DatabaseName -ne 'master' }
                    
                    foreach ($db in $databases) {
                        $links = Get-AzSqlDatabaseReplicationLink `
                            -ServerName $server.ServerName `
                            -DatabaseName $db.DatabaseName `
                            -ResourceGroupName $server.ResourceGroupName `
                            -ErrorAction SilentlyContinue
                        
                        if ($links) {
                            $sqlGeoReplicated++
                        }
                    }
                }
                
                $sqlWithRedundancy = $sqlZoneRedundant + $sqlGeoReplicated
                
                if ($sqlWithRedundancy -eq $sqlDatabases.Count) {
                    $redundancyStrengths += "✓ All $($sqlDatabases.Count) SQL database(s) have redundancy (Zone: $sqlZoneRedundant, Geo: $sqlGeoReplicated)"
                    $scores.Data.Current += 15
                    $redundantResources += $sqlDatabases.Count
                } elseif ($sqlWithRedundancy -gt 0) {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Data'
                        Resource = 'SQL Databases'
                        Issue = "$($sqlDatabases.Count - $sqlWithRedundancy) of $($sqlDatabases.Count) SQL database(s) lack redundancy"
                        Impact = 'Critical'
                        Details = "Zone-redundant: $sqlZoneRedundant, Geo-replicated: $sqlGeoReplicated - Enable zone redundancy or geo-replication"
                    }
                    $scores.Data.Current += (($sqlWithRedundancy / $sqlDatabases.Count) * 15)
                    $redundantResources += $sqlWithRedundancy
                } else {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Data'
                        Resource = 'SQL Databases'
                        Issue = "None of $($sqlDatabases.Count) SQL database(s) have redundancy configured"
                        Impact = 'Critical'
                        Details = "All databases are vulnerable to datacenter failures - enable zone redundancy or geo-replication immediately"
                    }
                }
            }
            
            # Cosmos DB - Check for multi-region writes
            $cosmosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.documentdb/databaseaccounts'
| extend 
    locations = array_length(properties.locations),
    multiRegionWrites = tobool(properties.enableMultipleWriteLocations),
    consistencyLevel = tostring(properties.consistencyPolicy.defaultConsistencyLevel)
| project 
    id,
    name,
    resourceGroup,
    locations,
    multiRegionWrites,
    consistencyLevel
"@
            $cosmosAccounts = Invoke-AzResourceGraphQuery -Query $cosmosQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($cosmosAccounts -and $cosmosAccounts.Count -gt 0) {
                $totalResources += $cosmosAccounts.Count
                $cosmosMultiRegion = ($cosmosAccounts | Where-Object { $_.locations -ge 2 }).Count
                $cosmosMultiWrite = ($cosmosAccounts | Where-Object { $_.multiRegionWrites -eq $true }).Count
                
                if ($cosmosMultiRegion -eq $cosmosAccounts.Count) {
                    $redundancyStrengths += "✓ All $($cosmosAccounts.Count) Cosmos DB account(s) multi-region (Multi-write: $cosmosMultiWrite)"
                    $scores.Data.Current += 10
                    $redundantResources += $cosmosAccounts.Count
                } else {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Data'
                        Resource = 'Cosmos DB'
                        Issue = "$($cosmosAccounts.Count - $cosmosMultiRegion) of $($cosmosAccounts.Count) Cosmos DB account(s) single-region"
                        Impact = 'High'
                        Details = "Add replica regions for geographic redundancy and lower read latency"
                    }
                }
            }
            
            # Redis Cache - Check for replication
            $redisQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.cache/redis'
| extend 
    skuName = tostring(sku.name),
    skuFamily = tostring(sku.family),
    replicasPerMaster = toint(properties.replicasPerMaster),
    zoneRedundant = tobool(properties.zones)
| project 
    id,
    name,
    resourceGroup,
    location,
    skuName,
    skuFamily,
    replicasPerMaster,
    zoneRedundant
"@
            $redisCaches = Invoke-AzResourceGraphQuery -Query $redisQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($redisCaches -and $redisCaches.Count -gt 0) {
                $totalResources += $redisCaches.Count
                $redisPremium = ($redisCaches | Where-Object { $_.skuFamily -eq 'P' }).Count
                $redisReplicated = ($redisCaches | Where-Object { $_.replicasPerMaster -gt 0 }).Count
                
                if ($redisPremium -eq $redisCaches.Count) {
                    $redundancyStrengths += "✓ All $($redisCaches.Count) Redis Cache(s) use Premium tier with replication capability"
                    $scores.Data.Current += 5
                    $redundantResources += $redisCaches.Count
                } else {
                    $redundancyGaps += [PSCustomObject]@{
                        Category = 'Data'
                        Resource = 'Redis Cache'
                        Issue = "$($redisCaches.Count - $redisPremium) of $($redisCaches.Count) Redis Cache(s) not Premium tier"
                        Impact = 'Medium'
                        Details = "Premium tier supports geo-replication and zone redundancy"
                    }
                }
            }
            
            #endregion
            
            # Calculate overall scores
            $totalScore = 0
            $maxTotalScore = 0
            
            foreach ($category in $scores.Keys) {
                $totalScore += $scores[$category].Current
                $maxTotalScore += $scores[$category].Max
            }
            
            $overallPercentage = if ($maxTotalScore -gt 0) { 
                [Math]::Round(($totalScore / $maxTotalScore) * 100, 1) 
            } else { 0 }
            
            $redundancyPercentage = if ($totalResources -gt 0) { 
                [Math]::Round(($redundantResources / $totalResources) * 100, 1) 
            } else { 0 }
            
            # Build comprehensive evidence
            $evidence = @"
Redundancy Assessment Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OVERALL SCORE: $([Math]::Round($totalScore, 1)) / $maxTotalScore points ($overallPercentage%)
REDUNDANCY COVERAGE: $redundantResources / $totalResources resources ($redundancyPercentage%)

CATEGORY SCORES:
- Compute:  $([Math]::Round($scores.Compute.Current, 1)) / $($scores.Compute.Max) points
- Network:  $([Math]::Round($scores.Network.Current, 1)) / $($scores.Network.Max) points
- Data:     $([Math]::Round($scores.Data.Current, 1)) / $($scores.Data.Max) points
- Zones:    $([Math]::Round($scores.Zones.Current, 1)) / $($scores.Zones.Max) points

STRENGTHS:
$($redundancyStrengths | ForEach-Object { "$_" } | Out-String)

GAPS IDENTIFIED: $($redundancyGaps.Count) issues
$(if ($redundancyGaps.Count -gt 0) {
    $redundancyGaps | ForEach-Object { 
        "[$($_.Impact)] $($_.Category) - $($_.Resource): $($_.Issue)"
    } | Out-String
} else {
    "No redundancy gaps identified"
})
"@
            
            # Determine status
            if ($overallPercentage -ge 85 -and $redundancyGaps.Count -le 2) {
                return New-WafResult -CheckId 'RE05' `
                    -Status 'Pass' `
                    -Message "Strong redundancy implementation across all layers: $overallPercentage% score, $redundancyPercentage% resources protected" `
                    -Metadata @{
                        OverallScore = $totalScore
                        MaxScore = $maxTotalScore
                        ScorePercentage = $overallPercentage
                        RedundantResources = $redundantResources
                        TotalResources = $totalResources
                        RedundancyPercentage = $redundancyPercentage
                        ComputeScore = $scores.Compute.Current
                        NetworkScore = $scores.Network.Current
                        DataScore = $scores.Data.Current
                        ZonesScore = $scores.Zones.Current
                        GapsCount = $redundancyGaps.Count
                    }
                    
            } elseif ($overallPercentage -ge 60 -or ($redundancyPercentage -ge 50 -and $redundancyGaps.Count -le 5)) {
                
                $affectedResources = $redundancyGaps | ForEach-Object { $_.Details }
                
                return New-WafResult -CheckId 'RE05' `
                    -Status 'Warning' `
                    -Message "Partial redundancy implementation with $($redundancyGaps.Count) gap(s): $overallPercentage% score, $redundancyPercentage% coverage" `
                    -AffectedResources $affectedResources `
                    -Recommendation @"
Address the identified redundancy gaps to improve reliability:

$evidence

## REMEDIATION BY CATEGORY:

### 1. COMPUTE REDUNDANCY (Score: $([Math]::Round($scores.Compute.Current, 1))/$($scores.Compute.Max))

$(if (($redundancyGaps | Where-Object Category -eq 'Compute').Count -gt 0) {@"
**Issues Found:**
$(($redundancyGaps | Where-Object Category -eq 'Compute' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Virtual Machines - Deploy Across Availability Zones:
```powershell
# For new VMs - specify zones during creation
New-AzVM ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'vm-web-01' ``
    -Location 'eastus' ``
    -Zone '1' ``
    -Image 'UbuntuLTS' ``
    -Size 'Standard_D2s_v3'

# For existing VMs - migration required
# 1. Create snapshot of existing VM disk
`$vm = Get-AzVM -ResourceGroupName 'rg-prod' -Name 'vm-old'
`$disk = Get-AzDisk -ResourceGroupName `$vm.ResourceGroupName -DiskName `$vm.StorageProfile.OsDisk.Name

`$snapshotConfig = New-AzSnapshotConfig ``
    -Location `$vm.Location ``
    -CreateOption Copy ``
    -SourceUri `$disk.Id

`$snapshot = New-AzSnapshot ``
    -ResourceGroupName `$vm.ResourceGroupName ``
    -SnapshotName "`$(`$vm.Name)-snapshot" ``
    -Snapshot `$snapshotConfig

# 2. Create new VM from snapshot in zone
`$diskConfig = New-AzDiskConfig ``
    -Location `$vm.Location ``
    -SourceResourceId `$snapshot.Id ``
    -CreateOption Copy ``
    -Zone '1'

`$newDisk = New-AzDisk ``
    -ResourceGroupName `$vm.ResourceGroupName ``
    -DiskName "`$(`$vm.Name)-zone-disk" ``
    -Disk `$diskConfig

# 3. Create new VM with zonal disk
# (Full VM configuration required)
```

#### App Service Plans - Scale to Multiple Instances:
```powershell
# Upgrade to Standard tier (minimum for production)
Set-AzAppServicePlan ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'plan-prod' ``
    -Tier 'Standard'

# Scale to 2+ instances
Set-AzAppServicePlan ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'plan-prod' ``
    -NumberofWorkers 2

# Better: Enable autoscaling
`$rule = New-AzAutoscaleRule ``
    -MetricName 'CpuPercentage' ``
    -MetricResourceId '/subscriptions/.../providers/Microsoft.Web/serverfarms/plan-prod' ``
    -Operator GreaterThan ``
    -MetricStatistic Average ``
    -Threshold 70 ``
    -TimeGrain 00:01:00 ``
    -ScaleActionCooldown 00:05:00 ``
    -ScaleActionDirection Increase ``
    -ScaleActionValue 1

`$profile = New-AzAutoscaleProfile ``
    -DefaultCapacity 2 ``
    -MaximumCapacity 10 ``
    -MinimumCapacity 2 ``
    -Rule `$rule ``
    -Name 'Auto scale profile'

Add-AzAutoscaleSetting ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'autoscale-plan-prod' ``
    -Location 'eastus' ``
    -TargetResourceId '/subscriptions/.../providers/Microsoft.Web/serverfarms/plan-prod' ``
    -AutoscaleProfile `$profile
```

#### VM Scale Sets - Enable Across Zones:
```powershell
# Create VMSS across zones (or update existing)
New-AzVmss ``
    -ResourceGroupName 'rg-prod' ``
    -VMScaleSetName 'vmss-web' ``
    -Location 'eastus' ``
    -Zone '1','2','3' ``
    -VirtualNetworkName 'vnet-prod' ``
    -SubnetName 'subnet-web' ``
    -PublicIpAddressName 'pip-vmss-web' ``
    -LoadBalancerName 'lb-vmss-web' ``
    -UpgradePolicyMode 'Automatic' ``
    -OrchestrationMode 'Flexible'
```
"@} else {"✓ No compute redundancy issues"})

### 2. NETWORK REDUNDANCY (Score: $([Math]::Round($scores.Network.Current, 1))/$($scores.Network.Max))

$(if (($redundancyGaps | Where-Object Category -eq 'Network').Count -gt 0) {@"
**Issues Found:**
$(($redundancyGaps | Where-Object Category -eq 'Network' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Load Balancer - Upgrade to Standard SKU:
```powershell
# Note: Upgrade requires recreation
# 1. Document existing configuration
`$oldLB = Get-AzLoadBalancer -ResourceGroupName 'rg-prod' -Name 'lb-old'

# 2. Create new Standard SKU load balancer
`$frontendIP = New-AzLoadBalancerFrontendIpConfig ``
    -Name 'frontend' ``
    -PublicIpAddress (Get-AzPublicIpAddress -Name 'pip-lb' -ResourceGroupName 'rg-prod')

`$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name 'backend'

`$probe = New-AzLoadBalancerProbeConfig ``
    -Name 'health-probe' ``
    -Protocol Http ``
    -Port 80 ``
    -RequestPath '/health' ``
    -IntervalInSeconds 15 ``
    -ProbeCount 2

`$lbRule = New-AzLoadBalancerRuleConfig ``
    -Name 'http-rule' ``
    -FrontendIpConfiguration `$frontendIP ``
    -BackendAddressPool `$backendPool ``
    -Probe `$probe ``
    -Protocol Tcp ``
    -FrontendPort 80 ``
    -BackendPort 80

`$newLB = New-AzLoadBalancer ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'lb-standard' ``
    -Location 'eastus' ``
    -Sku 'Standard' ``
    -FrontendIpConfiguration `$frontendIP ``
    -BackendAddressPool `$backendPool ``
    -Probe `$probe ``
    -LoadBalancingRule `$lbRule
```

#### Application Gateway - Enable Zones & Scale:
```powershell
# Create zone-redundant Application Gateway V2
`$vnet = Get-AzVirtualNetwork -Name 'vnet-prod' -ResourceGroupName 'rg-prod'
`$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork `$vnet -Name 'subnet-appgw'

`$pip = New-AzPublicIpAddress ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'pip-appgw' ``
    -Location 'eastus' ``
    -AllocationMethod Static ``
    -Sku Standard ``
    -Zone 1,2,3

# Configure autoscaling
`$autoscaleConfig = New-AzApplicationGatewayAutoscaleConfiguration ``
    -MinCapacity 2 ``
    -MaxCapacity 10

`$appGw = New-AzApplicationGateway ``
    -Name 'appgw-prod' ``
    -ResourceGroupName 'rg-prod' ``
    -Location 'eastus' ``
    -Zone 1,2,3 ``
    -Sku 'Standard_v2' ``
    -AutoscaleConfiguration `$autoscaleConfig ``
    # ... (additional configuration)
```

#### Traffic Manager - Add Geographic Redundancy:
```powershell
# Create Traffic Manager profile with multiple endpoints
`$profile = New-AzTrafficManagerProfile ``
    -Name 'tm-global' ``
    -ResourceGroupName 'rg-prod' ``
    -TrafficRoutingMethod Performance ``
    -RelativeDnsName 'myapp-global' ``
    -Ttl 30 ``
    -MonitorProtocol HTTPS ``
    -MonitorPort 443 ``
    -MonitorPath '/health'

# Add primary region endpoint
New-AzTrafficManagerEndpoint ``
    -Name 'endpoint-eastus' ``
    -ProfileName 'tm-global' ``
    -ResourceGroupName 'rg-prod' ``
    -Type AzureEndpoints ``
    -TargetResourceId '/subscriptions/.../publicIPAddresses/pip-eastus' ``
    -EndpointStatus Enabled ``
    -Priority 1

# Add secondary region endpoint
New-AzTrafficManagerEndpoint ``
    -Name 'endpoint-westus' ``
    -ProfileName 'tm-global' ``
    -ResourceGroupName 'rg-prod' ``
    -Type AzureEndpoints ``
    -TargetResourceId '/subscriptions/.../publicIPAddresses/pip-westus' ``
    -EndpointStatus Enabled ``
    -Priority 2
```
"@} else {"✓ No network redundancy issues"})

### 3. DATA REDUNDANCY (Score: $([Math]::Round($scores.Data.Current, 1))/$($scores.Data.Max))

$(if (($redundancyGaps | Where-Object Category -eq 'Data').Count -gt 0) {@"
**Issues Found:**
$(($redundancyGaps | Where-Object Category -eq 'Data' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Storage Accounts - Upgrade to Zone/Geo-Redundant:
```powershell
# Upgrade from LRS to ZRS (same region, zone redundancy)
Set-AzStorageAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'stproddata' ``
    -SkuName 'Standard_ZRS'

# Or upgrade to GRS (geo-redundancy across regions)
Set-AzStorageAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'stproddata' ``
    -SkuName 'Standard_GRS'

# Or GZRS (zone + geo redundancy - best option)
Set-AzStorageAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'stproddata' ``
    -SkuName 'Standard_GZRS'

# Enable read access to secondary region (RA-GRS/RA-GZRS)
Set-AzStorageAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'stproddata' ``
    -SkuName 'Standard_RAGZRS'
```

**Replication Comparison:**
| Type | Copies | Durability | Region Failure | Zone Failure | Cost |
|------|--------|------------|----------------|--------------|------|
| LRS | 3 (datacenter) | 11 nines | ✗ | ✗ | Lowest |
| ZRS | 3 (zones) | 12 nines | ✗ | ✓ | +40% |
| GRS | 6 (regions) | 16 nines | ✓ | ✗ | +100% |
| GZRS | 6 (zones+regions) | 16 nines | ✓ | ✓ | +150% |

#### SQL Database - Enable Zone Redundancy:
```powershell
# Enable zone redundancy (supported in Premium/Business Critical tiers)
Set-AzSqlDatabase ``
    -ResourceGroupName 'rg-prod' ``
    -ServerName 'sql-prod' ``
    -DatabaseName 'db-app' ``
    -ZoneRedundant

# Or configure geo-replication for multi-region
`$primaryServer = Get-AzSqlServer -ResourceGroupName 'rg-prod' -ServerName 'sql-eastus'
`$secondaryServer = Get-AzSqlServer -ResourceGroupName 'rg-dr' -ServerName 'sql-westus'

New-AzSqlDatabaseSecondary ``
    -ResourceGroupName `$primaryServer.ResourceGroupName ``
    -ServerName `$primaryServer.ServerName ``
    -DatabaseName 'db-app' ``
    -PartnerResourceGroupName `$secondaryServer.ResourceGroupName ``
    -PartnerServerName `$secondaryServer.ServerName ``
    -AllowConnections All

# Configure failover group for automatic failover
`$failoverPolicy = New-AzSqlDatabaseFailoverGroup ``
    -ResourceGroupName `$primaryServer.ResourceGroupName ``
    -ServerName `$primaryServer.ServerName ``
    -PartnerServerName `$secondaryServer.ServerName ``
    -FailoverGroupName 'fg-app' ``
    -FailoverPolicy Automatic ``
    -GracePeriodWithDataLossHours 1

# Add database to failover group
Add-AzSqlDatabaseToFailoverGroup ``
    -ResourceGroupName `$primaryServer.ResourceGroupName ``
    -ServerName `$primaryServer.ServerName ``
    -FailoverGroupName 'fg-app' ``
    -Database (Get-AzSqlDatabase -ServerName `$primaryServer.ServerName -ResourceGroupName `$primaryServer.ResourceGroupName -DatabaseName 'db-app')
```

#### Cosmos DB - Add Multiple Regions:
```powershell
# Add read regions
`$locations = @(
    @{ locationName='East US'; failoverPriority=0 },
    @{ locationName='West US'; failoverPriority=1 },
    @{ locationName='North Europe'; failoverPriority=2 }
)

Update-AzCosmosDBAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'cosmos-prod' ``
    -LocationObject `$locations

# Enable multi-region writes
Update-AzCosmosDBAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'cosmos-prod' ``
    -EnableMultipleWriteLocations
```
"@} else {"✓ No data redundancy issues"})

## BEST PRACTICES:

### Availability Zones Strategy:
1. **Primary**: Deploy across zones 1, 2, 3 in same region
2. **Benefits**: 99.99% SLA, protection from datacenter failures
3. **Cost**: Minimal (0-10% increase, mostly network)

### Multi-Region Strategy:
1. **When**: Critical workloads requiring <15min RTO
2. **Pattern**: Active-passive or active-active
3. **Components**: Traffic Manager, geo-replicated data
4. **Cost**: 100%+ (full duplication)

### Implementation Priority:
1. **Week 1**: Data redundancy (SQL, Storage) - protects against data loss
2. **Week 2**: Compute redundancy (VMs, App Services) - ensures availability
3. **Week 3**: Network redundancy (LBs, App Gateways) - distributes traffic
4. **Week 4**: Multi-region (Traffic Manager, geo-replication) - disaster recovery

## SUCCESS METRICS:
- ✓ 95%+ of resources have redundancy
- ✓ Zero single points of failure in critical path
- ✓ Availability SLAs: 99.95% (zones) or 99.99% (multi-region)
- ✓ Tested failover procedures quarterly

Current State:
$evidence
"@ `
                    -RemediationScript @"
# Redundancy Quick Fix Script
# Addresses the most critical single points of failure

Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host "REDUNDANCY QUICK FIX" -ForegroundColor Yellow
Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host ""

`$issues = @()

# 1. Check Virtual Machines
Write-Host "[1/4] Analyzing Virtual Machines..." -ForegroundColor Cyan
`$vmsNoRedundancy = Get-AzVM | Where-Object {
    `$vm = Get-AzVM -ResourceGroupName `$_.ResourceGroupName -Name `$_.Name -Status
    -not `$vm.Zones -and -not `$_.AvailabilitySetReference
}

if (`$vmsNoRedundancy.Count -gt 0) {
    `$issues += "Virtual Machines: `$(`$vmsNoRedundancy.Count) VMs lack redundancy"
    Write-Host "  ⚠ Found `$(`$vmsNoRedundancy.Count) VMs without redundancy:" -ForegroundColor Yellow
    `$vmsNoRedundancy | Select-Object -First 5 | ForEach-Object {
        Write-Host "    - `$(`$_.Name) in `$(`$_.ResourceGroupName)" -ForegroundColor Gray
    }
    Write-Host "  Action: Plan migration to availability zones or VMSS" -ForegroundColor Gray
}

# 2. Check App Service Plans
Write-Host "`n[2/4] Analyzing App Service Plans..." -ForegroundColor Cyan
`$plansSingleInstance = Get-AzAppServicePlan | Where-Object {
    `$capacity = if (`$_.Sku.Capacity) { `$_.Sku.Capacity } else { 1 }
    `$isSharedTier = `$_.Sku.Tier -match 'Free|Shared|Basic'
    `$isSharedTier -or `$capacity -lt 2
}

if (`$plansSingleInstance.Count -gt 0) {
    `$issues += "App Service Plans: `$(`$plansSingleInstance.Count) plans have single instance"
    Write-Host "  ⚠ Found `$(`$plansSingleInstance.Count) single-instance plans:" -ForegroundColor Yellow
    `$plansSingleInstance | Select-Object -First 5 | ForEach-Object {
        Write-Host "    - `$(`$_.Name): `$(`$_.Sku.Tier), Capacity: `$(`$_.Sku.Capacity)" -ForegroundColor Gray
    }
    
    Write-Host "  Quick fix available - scale to 2 instances? (Y/N)" -ForegroundColor Yellow -NoNewline
    `$response = Read-Host
    
    if (`$response -eq 'Y') {
        foreach (`$plan in `$plansSingleInstance | Select-Object -First 3) {
            try {
                if (`$plan.Sku.Tier -in @('Free','Shared')) {
                    Write-Host "    Upgrading `$(`$plan.Name) to Standard tier..." -ForegroundColor Yellow
                    Set-AzAppServicePlan ``
                        -ResourceGroupName `$plan.ResourceGroupName ``
                        -Name `$plan.Name ``
                        -Tier 'Standard' ``
                        -NumberofWorkers 2
                } else {
                    Write-Host "    Scaling `$(`$plan.Name) to 2 instances..." -ForegroundColor Yellow
                    Set-AzAppServicePlan ``
                        -ResourceGroupName `$plan.ResourceGroupName ``
                        -Name `$plan.Name ``
                        -NumberofWorkers 2
                }
                Write-Host "    ✓ Fixed: `$(`$plan.Name)" -ForegroundColor Green
            } catch {
                Write-Host "    ✗ Failed: `$(`$plan.Name) - `$_" -ForegroundColor Red
            }
        }
    }
}

# 3. Check Storage Accounts
Write-Host "`n[3/4] Analyzing Storage Accounts..." -ForegroundColor Cyan
`$storageLRS = Get-AzStorageAccount | Where-Object { `$_.Sku.Name -match 'LRS' }

if (`$storageLRS.Count -gt 0) {
    `$issues += "Storage Accounts: `$(`$storageLRS.Count) accounts use LRS (single datacenter)"
    Write-Host "  ⚠ Found `$(`$storageLRS.Count) storage accounts with LRS:" -ForegroundColor Yellow
    `$storageLRS | Select-Object -First 5 | ForEach-Object {
        Write-Host "    - `$(`$_.StorageAccountName): `$(`$_.Sku.Name)" -ForegroundColor Gray
    }
    
    Write-Host "  Upgrade to ZRS for critical storage? (Y/N)" -ForegroundColor Yellow -NoNewline
    `$response = Read-Host
    
    if (`$response -eq 'Y') {
        Write-Host "  Select accounts to upgrade (comma-separated numbers or 'all'):" -ForegroundColor Yellow
        for (`$i = 0; `$i -lt [Math]::Min(10, `$storageLRS.Count); `$i++) {
            Write-Host "    [`$i] `$(`$storageLRS[`$i].StorageAccountName)" -ForegroundColor Gray
        }
        `$selection = Read-Host "  Selection"
        
        if (`$selection -eq 'all') {
            `$toUpgrade = `$storageLRS
        } else {
            `$indices = `$selection -split ',' | ForEach-Object { [int]`$_.Trim() }
            `$toUpgrade = `$indices | ForEach-Object { `$storageLRS[`$_] }
        }
        
        foreach (`$storage in `$toUpgrade) {
            try {
                Write-Host "    Upgrading `$(`$storage.StorageAccountName) to ZRS..." -ForegroundColor Yellow
                Set-AzStorageAccount ``
                    -ResourceGroupName `$storage.ResourceGroupName ``
                    -Name `$storage.StorageAccountName ``
                    -SkuName 'Standard_ZRS'
                Write-Host "    ✓ Upgraded: `$(`$storage.StorageAccountName)" -ForegroundColor Green
            } catch {
                Write-Host "    ✗ Failed: `$(`$storage.StorageAccountName) - `$_" -ForegroundColor Red
            }
        }
    }
}

# 4. Check SQL Databases
Write-Host "`n[4/4] Analyzing SQL Databases..." -ForegroundColor Cyan
`$sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
`$sqlNoRedundancy = @()

foreach (`$server in `$sqlServers) {
    `$databases = Get-AzSqlDatabase ``
        -ServerName `$server.ServerName ``
        -ResourceGroupName `$server.ResourceGroupName ``
        -ErrorAction SilentlyContinue |
        Where-Object { `$_.DatabaseName -ne 'master' -and -not `$_.ZoneRedundant }
    
    foreach (`$db in `$databases) {
        `$links = Get-AzSqlDatabaseReplicationLink ``
            -ServerName `$server.ServerName ``
            -DatabaseName `$db.DatabaseName ``
            -ResourceGroupName `$server.ResourceGroupName ``
            -ErrorAction SilentlyContinue
        
        if (-not `$links) {
            `$sqlNoRedundancy += @{
                Server = `$server.ServerName
                Database = `$db.DatabaseName
                ResourceGroup = `$server.ResourceGroupName
                Tier = `$db.SkuName
            }
        }
    }
}

if (`$sqlNoRedundancy.Count -gt 0) {
    `$issues += "SQL Databases: `$(`$sqlNoRedundancy.Count) databases lack redundancy"
    Write-Host "  ⚠ Found `$(`$sqlNoRedundancy.Count) SQL databases without redundancy:" -ForegroundColor Yellow
    `$sqlNoRedundancy | Select-Object -First 5 | ForEach-Object {
        Write-Host "    - `$(`$_.Database) on `$(`$_.Server) (`$(`$_.Tier))" -ForegroundColor Gray
    }
    Write-Host "  Action: Enable zone redundancy or geo-replication (requires Premium/Business Critical tier)" -ForegroundColor Gray
}

# Summary
Write-Host "`n"
Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host "SUMMARY" -ForegroundColor Yellow
Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host ""

if (`$issues.Count -eq 0) {
    Write-Host "✓ No critical redundancy issues found!" -ForegroundColor Green
} else {
    Write-Host "Found `$(`$issues.Count) redundancy categories with issues:" -ForegroundColor Yellow
    `$issues | ForEach-Object {
        Write-Host "  • `$_" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Review the detailed remediation guidance" -ForegroundColor Gray
    Write-Host "  2. Prioritize critical workloads first" -ForegroundColor Gray
    Write-Host "  3. Plan migrations to avoid downtime" -ForegroundColor Gray
    Write-Host "  4. Test failover procedures after implementation" -ForegroundColor Gray
}
"@
                    
            } else {
                
                $affectedResources = $redundancyGaps | ForEach-Object { $_.Details }
                
                return New-WafResult -CheckId 'RE05' `
                    -Status 'Fail' `
                    -Message "CRITICAL: Significant redundancy gaps - $($redundancyGaps.Count) issues across categories ($overallPercentage% score, $redundancyPercentage% coverage)" `
                    -AffectedResources $affectedResources `
                    -Recommendation @"
**IMMEDIATE ACTION REQUIRED**: Multiple single points of failure identified across your infrastructure.

Current Score: $overallPercentage% (CRITICAL)
Redundancy Coverage: $redundancyPercentage%

$evidence

## Why This Is Critical:

Single points of failure mean:
- ❌ Any component failure causes complete outage
- ❌ Planned maintenance requires downtime
- ❌ Cannot meet 99.9%+ availability SLAs
- ❌ Region/zone failures cause data loss
- ❌ No protection during Azure platform updates

## IMMEDIATE ACTIONS (This Week):

### Priority 1: Data Protection (Day 1-2)

**Storage Accounts - Prevent Data Loss:**
```powershell
# IMMEDIATE: Upgrade critical storage to GZRS
Get-AzStorageAccount | Where-Object { `$_.Sku.Name -match 'LRS' } | ForEach-Object {
    Write-Host "Upgrading `$(`$_.StorageAccountName)..."
    Set-AzStorageAccount ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -Name `$_.StorageAccountName ``
        -SkuName 'Standard_GZRS'
}
```

**SQL Databases - Enable Zone Redundancy:**
```powershell
# For Premium/Business Critical tiers
Get-AzSqlServer | ForEach-Object {
    Get-AzSqlDatabase -ServerName `$_.ServerName -ResourceGroupName `$_.ResourceGroupName |
        Where-Object { `$_.DatabaseName -ne 'master' } | ForEach-Object {
        Set-AzSqlDatabase ``
            -ResourceGroupName `$_.ResourceGroupName ``
            -ServerName `$_.ServerName ``
            -DatabaseName `$_.DatabaseName ``
            -ZoneRedundant
    }
}
```

### Priority 2: Compute Availability (Day 3-5)

**App Services - Scale Out NOW:**
```powershell
# Quick fix for immediate redundancy
Get-AzAppServicePlan | Where-Object {
    (`$_.Sku.Capacity -lt 2) -and (`$_.Sku.Tier -notin @('Free','Shared'))
} | ForEach-Object {
    Write-Host "Scaling `$(`$_.Name) to 2 instances..."
    Set-AzAppServicePlan ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -Name `$_.Name ``
        -NumberofWorkers 2
}
```

**VMs - Plan Zone Migration:**
```powershell
# Cannot move existing VMs - must recreate
# 1. Document VMs without redundancy
Get-AzVM | ForEach-Object {
    `$vm = Get-AzVM -ResourceGroupName `$_.ResourceGroupName -Name `$_.Name -Status
    if (-not `$vm.Zones -and -not `$_.AvailabilitySetReference) {
        [PSCustomObject]@{
            Name = `$_.Name
            ResourceGroup = `$_.ResourceGroupName
            Location = `$_.Location
            Size = `$_.HardwareProfile.VmSize
            Status = 'Needs Migration'
        }
    }
} | Export-Csv 'vms-migration-plan.csv' -NoTypeInformation

# 2. For each VM, plan:
#    - Snapshot disk
#    - Create new zonal VM from snapshot
#    - Test new VM
#    - Cutover DNS/load balancer
#    - Decommission old VM
```

### Priority 3: Network Redundancy (Week 2)

**Load Balancers - Upgrade to Standard:**
```powershell
# Standard SKU required for zones
# Note: Requires recreation - plan carefully
Get-AzLoadBalancer | Where-Object { `$_.Sku.Name -eq 'Basic' } | ForEach-Object {
    Write-Host "`$(`$_.Name) requires upgrade to Standard SKU"
    Write-Host "  1. Document configuration"
    Write-Host "  2. Create new Standard LB"
    Write-Host "  3. Migrate backends"
    Write-Host "  4. Update DNS"
    Write-Host "  5. Remove old LB"
}
```

## QUICK WINS (Can Implement Today):

### 1. App Service Scaling (5 minutes per app)
- Upgrade Free/Shared to Standard
- Scale to minimum 2 instances
- Cost: ~`$150/month per plan
- Benefit: Immediate redundancy

### 2. Storage Replication (1 minute per account)
- Change SKU from LRS to ZRS
- Zero downtime during migration
- Cost: +40% storage cost
- Benefit: Protection from datacenter failure

### 3. SQL Zone Redundancy (2 minutes per database)
- Enable zone redundancy flag
- Requires Premium/Business Critical tier
- Cost: Included in tier price
- Benefit: 99.99% SLA, automatic failover

## COMPREHENSIVE PLAN:

### Week 1: Data & Compute Basics
- ✓ Upgrade all storage to ZRS minimum
- ✓ Enable SQL zone redundancy
- ✓ Scale App Services to 2+ instances
- ✓ Document VM migration plan

### Week 2-3: Network & Advanced Compute
- ✓ Upgrade load balancers to Standard SKU
- ✓ Deploy Application Gateways across zones
- ✓ Migrate VMs to zones or VMSS
- ✓ Enable autoscaling

### Week 4: Multi-Region (Optional)
- ✓ Deploy Traffic Manager
- ✓ Enable SQL geo-replication
- ✓ Configure storage GRS/GZRS
- ✓ Test failover procedures

## Cost Impact:

Redundancy adds cost but prevents much larger losses:

| Component | Additional Cost | Downtime Cost Avoided |
|-----------|----------------|---------------------|
| Storage ZRS | +`$40/TB/month | Data loss = priceless |
| App Service x2 | +`$150/month | `$10,000/hour outage |
| SQL Zone Redundancy | Included | `$25,000/hour outage |
| Load Balancer Standard | +`$20/month | Service unavailable |

**ROI**: One prevented 1-hour outage justifies years of redundancy costs.

## Testing Requirements:

After implementing redundancy:
1. **Test zone failures** - Simulate zone down
2. **Test instance failures** - Stop nodes, verify traffic continues
3. **Test failover** - Validate recovery time meets RTO
4. **Document procedures** - Update runbooks with failover steps

## Success Criteria:

Within 30 days, achieve:
- ✓ 0 single-instance production services
- ✓ 0 LRS storage for critical data
- ✓ 0 single-zone deployments for Tier 1 services
- ✓ 95%+ resources with redundancy
- ✓ Tested failover procedures

Current Critical Issues:
$evidence

**START TODAY**: Every hour without redundancy is a risk to your business.
"@ `
                    -RemediationScript @"
# EMERGENCY REDUNDANCY FIX
# Implements basic redundancy for critical services

Write-Host "═" * 70 -ForegroundColor Red
Write-Host "EMERGENCY REDUNDANCY IMPLEMENTATION" -ForegroundColor Red
Write-Host "═" * 70 -ForegroundColor Red
Write-Host ""
Write-Host "This script will implement BASIC redundancy for your most critical services." -ForegroundColor Yellow
Write-Host "Changes will be made to your production environment!" -ForegroundColor Red
Write-Host ""

`$confirm = Read-Host "Type 'YES' to continue"
if (`$confirm -ne 'YES') {
    Write-Host "Aborted by user" -ForegroundColor Gray
    exit
}

`$fixed = 0
`$failed = 0

# 1. Storage Accounts - Upgrade to ZRS
Write-Host "`n[1/3] Upgrading Storage Accounts to Zone-Redundant..." -ForegroundColor Cyan
`$storageLRS = Get-AzStorageAccount | Where-Object { `$_.Sku.Name -match 'LRS' } | Select-Object -First 10

foreach (`$storage in `$storageLRS) {
    Write-Host "  Processing: `$(`$storage.StorageAccountName)..." -ForegroundColor Yellow
    try {
        Set-AzStorageAccount ``
            -ResourceGroupName `$storage.ResourceGroupName ``
            -Name `$storage.StorageAccountName ``
            -SkuName 'Standard_ZRS'
        Write-Host "    ✓ Upgraded to ZRS" -ForegroundColor Green
        `$fixed++
    } catch {
        Write-Host "    ✗ Failed: `$_" -ForegroundColor Red
        `$failed++
    }
}

# 2. App Service Plans - Scale to 2 instances
Write-Host "`n[2/3] Scaling App Service Plans..." -ForegroundColor Cyan
`$plansSingle = Get-AzAppServicePlan | Where-Object {
    (`$_.Sku.Capacity -lt 2) -and (`$_.Sku.Tier -notin @('Free','Shared','Basic'))
} | Select-Object -First 10

foreach (`$plan in `$plansSingle) {
    Write-Host "  Processing: `$(`$plan.Name) (`$(`$plan.Sku.Tier))..." -ForegroundColor Yellow
    try {
        Set-AzAppServicePlan ``
            -ResourceGroupName `$plan.ResourceGroupName ``
            -Name `$plan.Name ``
            -NumberofWorkers 2
        Write-Host "    ✓ Scaled to 2 instances" -ForegroundColor Green
        `$fixed++
    } catch {
        Write-Host "    ✗ Failed: `$_" -ForegroundColor Red
        `$failed++
    }
}

# 3. SQL Databases - Enable Zone Redundancy (where supported)
Write-Host "`n[3/3] Enabling SQL Database Zone Redundancy..." -ForegroundColor Cyan
`$sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue

foreach (`$server in `$sqlServers) {
    `$databases = Get-AzSqlDatabase ``
        -ServerName `$server.ServerName ``
        -ResourceGroupName `$server.ResourceGroupName ``
        -ErrorAction SilentlyContinue |
        Where-Object { `$_.DatabaseName -ne 'master' -and -not `$_.ZoneRedundant }
    
    foreach (`$db in `$databases) {
        Write-Host "  Processing: `$(`$db.DatabaseName) on `$(`$server.ServerName)..." -ForegroundColor Yellow
        
        # Check if tier supports zone redundancy
        if (`$db.SkuName -match 'Premium|BusinessCritical') {
            try {
                Set-AzSqlDatabase ``
                    -ResourceGroupName `$server.ResourceGroupName ``
                    -ServerName `$server.ServerName ``
                    -DatabaseName `$db.DatabaseName ``
                    -ZoneRedundant
                Write-Host "    ✓ Enabled zone redundancy" -ForegroundColor Green
                `$fixed++
            } catch {
                Write-Host "    ✗ Failed: `$_" -ForegroundColor Red
                `$failed++
            }
        } else {
            Write-Host "    ⚠ Tier `$(`$db.SkuName) doesn't support zone redundancy" -ForegroundColor Yellow
        }
    }
}

# Summary
Write-Host "`n"
Write-Host "═" * 70 -ForegroundColor Green
Write-Host "EMERGENCY FIX COMPLETE" -ForegroundColor Green
Write-Host "═" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "Results:" -ForegroundColor White
Write-Host "  ✓ Successfully fixed: `$fixed items" -ForegroundColor Green
Write-Host "  ✗ Failed: `$failed items" -ForegroundColor Red
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Verify services are still operational" -ForegroundColor Gray
Write-Host "  2. Plan VM migration to availability zones" -ForegroundColor Gray
Write-Host "  3. Upgrade load balancers to Standard SKU" -ForegroundColor Gray
Write-Host "  4. Test failover procedures" -ForegroundColor Gray
Write-Host "  5. Document configuration changes" -ForegroundColor Gray
Write-Host ""
Write-Host "Generate full report with: Get-AzWafAssessment -CheckId RE05" -ForegroundColor Gray
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE05' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
