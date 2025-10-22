<#
.SYNOPSIS
    RE03 - Failure mode analysis

.DESCRIPTION
    Performs comprehensive failure mode analysis by identifying single points of failure,
    assessing redundancy across compute, networking, and data layers, and evaluating
    dependency tracking capabilities.
    
    This check identifies:
    - Virtual machines without availability zones or availability sets
    - Single-instance services without redundancy
    - Missing health probes and monitoring
    - Lack of dependency mapping tools
    - Network single points of failure
    - Storage redundancy issues

.NOTES
    Pillar: Reliability
    Recommendation: RE:03 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/failure-mode-analysis
#>

Register-WafCheck -CheckId 'RE03' `
    -Pillar 'Reliability' `
    -Title 'Perform failure mode analysis' `
    -Description 'Identify and document potential failure modes across all components. Analyze dependencies and single points of failure to understand failure impact and recovery requirements.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'FailureMode', 'SPOF', 'Dependencies', 'HighAvailability', 'Redundancy') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/failure-mode-analysis' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Initialize failure analysis
            $failurePoints = @()
            $totalResources = 0
            $resourcesWithRedundancy = 0
            
            # 1. VIRTUAL MACHINES - Check for availability zones and sets
            Write-Verbose "Analyzing VM redundancy..."
            $vmQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| extend 
    zones = tostring(zones),
    availabilitySet = tostring(properties.availabilitySet.id),
    vmSize = tostring(properties.hardwareProfile.vmSize)
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
                
                foreach ($vm in $vms) {
                    $hasZones = $vm.zones -and $vm.zones -ne '[]' -and $vm.zones -ne 'null'
                    $hasAvSet = $vm.availabilitySet -and $vm.availabilitySet -ne 'null' -and $vm.availabilitySet -ne ''
                    
                    if ($hasZones -or $hasAvSet) {
                        $resourcesWithRedundancy++
                    } else {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Virtual Machine'
                            ResourceName = $vm.name
                            ResourceId = $vm.id
                            Location = $vm.location
                            Issue = 'No availability zone or availability set configured'
                            Impact = 'High'
                            Reason = 'Single VM instance is a SPOF - any host failure causes downtime'
                        }
                    }
                }
            }
            
            # 2. APP SERVICES - Check for multiple instances
            Write-Verbose "Analyzing App Service redundancy..."
            $appServiceQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites'
| extend 
    skuName = tostring(properties.sku),
    state = tostring(properties.state),
    kind = tostring(kind)
| join kind=leftouter (
    Resources
    | where type =~ 'microsoft.web/serverfarms'
    | extend planId = tolower(id)
    | project 
        planId,
        planSku = tostring(sku.tier),
        planCapacity = toint(sku.capacity)
) on \$left.properties.serverFarmId == \$right.planId
| project 
    id,
    name,
    resourceGroup,
    location,
    skuName,
    state,
    kind,
    planSku,
    planCapacity
"@
            $appServices = Invoke-AzResourceGraphQuery -Query $appServiceQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($appServices -and $appServices.Count -gt 0) {
                $totalResources += $appServices.Count
                
                foreach ($app in $appServices) {
                    # Free/Shared tiers don't support scaling
                    $isSharedTier = $app.planSku -match 'Free|Shared'
                    $instanceCount = if ($app.planCapacity) { $app.planCapacity } else { 1 }
                    
                    if ($isSharedTier -or $instanceCount -le 1) {
                        $resourcesWithRedundancy++  # Don't count as redundant
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'App Service'
                            ResourceName = $app.name
                            ResourceId = $app.id
                            Location = $app.location
                            Issue = if ($isSharedTier) { "Using $($app.planSku) tier (no scaling)" } else { "Single instance (capacity: $instanceCount)" }
                            Impact = 'High'
                            Reason = 'Single instance or shared tier - any platform update or failure causes downtime'
                        }
                    } else {
                        $resourcesWithRedundancy++
                    }
                }
            }
            
            # 3. SQL DATABASES - Check for geo-replication
            Write-Verbose "Analyzing SQL Database redundancy..."
            $sqlQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| where name !~ 'master'
| extend 
    replicaCount = array_length(properties.replicationLinks),
    zoneRedundant = tobool(properties.zoneRedundant),
    skuTier = tostring(sku.tier)
| project 
    id,
    name,
    resourceGroup,
    location,
    replicaCount,
    zoneRedundant,
    skuTier
"@
            $sqlDatabases = Invoke-AzResourceGraphQuery -Query $sqlQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($sqlDatabases -and $sqlDatabases.Count -gt 0) {
                $totalResources += $sqlDatabases.Count
                
                foreach ($db in $sqlDatabases) {
                    $hasReplicas = $db.replicaCount -gt 0
                    $isZoneRedundant = $db.zoneRedundant -eq $true
                    
                    if ($hasReplicas -or $isZoneRedundant) {
                        $resourcesWithRedundancy++
                    } else {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'SQL Database'
                            ResourceName = $db.name
                            ResourceId = $db.id
                            Location = $db.location
                            Issue = 'No geo-replication or zone redundancy configured'
                            Impact = 'High'
                            Reason = 'Database is not protected against datacenter or regional failures'
                        }
                    }
                }
            }
            
            # 4. STORAGE ACCOUNTS - Check replication type
            Write-Verbose "Analyzing Storage Account redundancy..."
            $storageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    replication = tostring(sku.name),
    accessTier = tostring(properties.accessTier)
| project 
    id,
    name,
    resourceGroup,
    location,
    replication,
    accessTier
"@
            $storageAccounts = Invoke-AzResourceGraphQuery -Query $storageQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($storageAccounts -and $storageAccounts.Count -gt 0) {
                $totalResources += $storageAccounts.Count
                
                foreach ($storage in $storageAccounts) {
                    # LRS is single datacenter only
                    if ($storage.replication -eq 'Standard_LRS' -or $storage.replication -eq 'Premium_LRS') {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Storage Account'
                            ResourceName = $storage.name
                            ResourceId = $storage.id
                            Location = $storage.location
                            Issue = "Using LRS replication - single datacenter"
                            Impact = 'Medium'
                            Reason = 'Datacenter failure would result in data unavailability'
                        }
                    } else {
                        $resourcesWithRedundancy++
                    }
                }
            }
            
            # 5. LOAD BALANCERS - Check backend pool health
            Write-Verbose "Analyzing Load Balancer configuration..."
            $lbQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/loadbalancers'
| extend 
    backendPoolCount = array_length(properties.backendAddressPools),
    probeCount = array_length(properties.probes)
| project 
    id,
    name,
    resourceGroup,
    location,
    backendPoolCount,
    probeCount,
    skuName = tostring(sku.name)
"@
            $loadBalancers = Invoke-AzResourceGraphQuery -Query $lbQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($loadBalancers -and $loadBalancers.Count -gt 0) {
                foreach ($lb in $loadBalancers) {
                    if ($lb.probeCount -eq 0) {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Load Balancer'
                            ResourceName = $lb.name
                            ResourceId = $lb.id
                            Location = $lb.location
                            Issue = 'No health probes configured'
                            Impact = 'High'
                            Reason = 'Cannot detect backend failures - unhealthy instances will receive traffic'
                        }
                    }
                    
                    if ($lb.backendPoolCount -eq 0) {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Load Balancer'
                            ResourceName = $lb.name
                            ResourceId = $lb.id
                            Location = $lb.location
                            Issue = 'No backend pools configured'
                            Impact = 'Medium'
                            Reason = 'Load balancer not distributing traffic - potential misconfiguration'
                        }
                    }
                }
            }
            
            # 6. APPLICATION GATEWAYS - Check backend health
            Write-Verbose "Analyzing Application Gateway configuration..."
            $appGwQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgateways'
| extend 
    backendPoolCount = array_length(properties.backendAddressPools),
    probeCount = array_length(properties.probes),
    skuTier = tostring(sku.tier),
    capacity = toint(sku.capacity)
| project 
    id,
    name,
    resourceGroup,
    location,
    backendPoolCount,
    probeCount,
    skuTier,
    capacity
"@
            $appGateways = Invoke-AzResourceGraphQuery -Query $appGwQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($appGateways -and $appGateways.Count -gt 0) {
                foreach ($gw in $appGateways) {
                    if ($gw.probeCount -eq 0) {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Application Gateway'
                            ResourceName = $gw.name
                            ResourceId = $gw.id
                            Location = $gw.location
                            Issue = 'No custom health probes configured'
                            Impact = 'High'
                            Reason = 'Relies on default probe - may not accurately detect application failures'
                        }
                    }
                    
                    if ($gw.capacity -le 1) {
                        $failurePoints += [PSCustomObject]@{
                            ResourceType = 'Application Gateway'
                            ResourceName = $gw.name
                            ResourceId = $gw.id
                            Location = $gw.location
                            Issue = "Single instance (capacity: $($gw.capacity))"
                            Impact = 'High'
                            Reason = 'No redundancy - platform updates or failures cause downtime'
                        }
                    }
                }
            }
            
            # 7. CHECK FOR DEPENDENCY MAPPING TOOLS
            Write-Verbose "Checking dependency tracking capabilities..."
            
            # Application Insights for app dependency tracking
            $appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue
            $hasAppInsights = $appInsights -and $appInsights.Count -gt 0
            
            # Service Map / VM Insights for infrastructure dependencies
            $logAnalytics = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
            $hasServiceMap = $false
            $vmInsightsEnabled = 0
            
            if ($logAnalytics) {
                foreach ($workspace in $logAnalytics) {
                    try {
                        $solutions = Get-AzOperationalInsightsIntelligencePack `
                            -ResourceGroupName $workspace.ResourceGroupName `
                            -WorkspaceName $workspace.Name `
                            -ErrorAction SilentlyContinue
                        
                        if ($solutions | Where-Object { $_.Name -in @('ServiceMap', 'VMInsights') -and $_.Enabled }) {
                            $hasServiceMap = $true
                            
                            # Count VMs with VM Insights
                            $vmInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| where isnotnull(properties.extensions)
| mv-expand extension = properties.extensions
| where extension.properties.type in~ ('DependencyAgentWindows', 'DependencyAgentLinux')
| summarize vmInsightsCount = count()
"@
                            $vmInsightsResult = Invoke-AzResourceGraphQuery -Query $vmInsightsQuery `
                                -SubscriptionId $SubscriptionId -UseCache
                            
                            if ($vmInsightsResult -and $vmInsightsResult.Count -gt 0) {
                                $vmInsightsEnabled = $vmInsightsResult[0].vmInsightsCount
                            }
                            break
                        }
                    } catch {
                        # Continue checking other workspaces
                    }
                }
            }
            
            # 8. CHECK AZURE ADVISOR FOR HA RECOMMENDATIONS
            Write-Verbose "Checking Azure Advisor recommendations..."
            $advisorRecs = Get-AzAdvisorRecommendation -Category HighAvailability -ErrorAction SilentlyContinue
            $advisorHaCount = if ($advisorRecs) { $advisorRecs.Count } else { 0 }
            
            # BUILD COMPREHENSIVE ASSESSMENT
            $criticalFailures = ($failurePoints | Where-Object Impact -eq 'High').Count
            $mediumFailures = ($failurePoints | Where-Object Impact -eq 'Medium').Count
            
            $redundancyPercent = if ($totalResources -gt 0) {
                [Math]::Round(($resourcesWithRedundancy / $totalResources) * 100, 1)
            } else {
                0
            }
            
            # Group failures by type for summary
            $failuresByType = $failurePoints | Group-Object ResourceType | ForEach-Object {
                @{
                    Type = $_.Name
                    Count = $_.Count
                    HighImpact = ($_.Group | Where-Object Impact -eq 'High').Count
                }
            }
            
            $evidence = @"
Failure Mode Analysis Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

REDUNDANCY ASSESSMENT:
- Total Resources Analyzed: $totalResources
- Resources with Redundancy: $resourcesWithRedundancy ($redundancyPercent%)
- Single Points of Failure: $($failurePoints.Count)
  • Critical Impact: $criticalFailures
  • Medium Impact: $mediumFailures

FAILURE POINTS BY RESOURCE TYPE:
$(($failuresByType | ForEach-Object { "- $($_.Type): $($_.Count) issues ($($_.HighImpact) critical)" }) -join "`n")

DEPENDENCY TRACKING:
- Application Insights: $(if ($hasAppInsights) { "✓ Enabled ($($appInsights.Count) instances)" } else { "✗ Not deployed" })
- Service Map/VM Insights: $(if ($hasServiceMap) { "✓ Enabled ($vmInsightsEnabled VMs monitored)" } else { "✗ Not enabled" })

AZURE ADVISOR:
- High Availability Recommendations: $advisorHaCount

DETAILED FAILURES (Top 10):
$(($failurePoints | Select-Object -First 10 | ForEach-Object { "[$($_.Impact)] $($_.ResourceType) '$($_.ResourceName)': $($_.Issue)" }) -join "`n")
$(if ($failurePoints.Count -gt 10) { "... and $($failurePoints.Count - 10) more issues" } else { "" })
"@
            
            # DETERMINE STATUS
            if ($failurePoints.Count -eq 0 -and $hasAppInsights -and $hasServiceMap) {
                return New-WafResult -CheckId 'RE03' `
                    -Status 'Pass' `
                    -Message "Comprehensive failure mode analysis shows strong redundancy ($redundancyPercent% resources protected) with dependency tracking enabled" `
                    -Metadata @{
                        TotalResources = $totalResources
                        RedundantResources = $resourcesWithRedundancy
                        RedundancyPercent = $redundancyPercent
                        FailurePoints = $failurePoints.Count
                        CriticalFailures = $criticalFailures
                        HasAppInsights = $hasAppInsights
                        HasServiceMap = $hasServiceMap
                        AdvisorRecommendations = $advisorHaCount
                    }
                    
            } elseif ($criticalFailures -le 3 -and ($hasAppInsights -or $hasServiceMap)) {
                
                $affectedResources = $failurePoints | ForEach-Object { $_.ResourceId }
                
                return New-WafResult -CheckId 'RE03' `
                    -Status 'Warning' `
                    -Message "Failure mode analysis identified $($failurePoints.Count) potential failure points ($criticalFailures critical). Dependency tracking partially enabled." `
                    -AffectedResources $affectedResources `
                    -Recommendation @"
Address the identified single points of failure to improve reliability:

## IMMEDIATE ACTIONS (Critical Impact):

### 1. Virtual Machines Without Redundancy
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'Virtual Machine' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'Virtual Machine' }).Count)) VMs lack availability zones or sets
**Impact**: Any host failure causes VM downtime
**Solution**:
- Deploy new VMs across availability zones (99.99% SLA)
- Or use availability sets for VMs in same region (99.95% SLA)
- Consider VM Scale Sets for automatic scaling and redundancy
"@ } else { "✓ All VMs have redundancy configured" })

### 2. App Services Without Scale-Out
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'App Service' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'App Service' }).Count)) App Services on single instances
**Impact**: Platform updates or failures cause application downtime
**Solution**:
- Scale to at least 2 instances minimum
- Upgrade from Free/Shared to Standard tier or higher
- Enable autoscaling based on metrics
"@ } else { "✓ All App Services scaled appropriately" })

### 3. Databases Without Geo-Replication
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'SQL Database' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'SQL Database' }).Count)) databases lack replication
**Impact**: Regional failure causes data unavailability
**Solution**:
- Enable zone-redundant configuration for same-region protection
- Configure geo-replication for cross-region disaster recovery
- Consider failover groups for automatic failover
"@ } else { "✓ All databases have replication configured" })

### 4. Storage Without Geographic Redundancy
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'Storage Account' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'Storage Account' }).Count)) storage accounts use LRS only
**Impact**: Datacenter failure causes data unavailability
**Solution**:
- Upgrade to ZRS (zone-redundant) for same-region protection
- Use GRS/GZRS for cross-region disaster recovery
- Consider RA-GRS for read access to secondary region
"@ } else { "✓ All storage accounts have appropriate redundancy" })

## MONITORING & HEALTH PROBES:

### 5. Load Balancers Missing Health Probes
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'Load Balancer' -and $_.Issue -match 'probe' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'Load Balancer' -and $_.Issue -match 'probe' }).Count)) load balancers lack health probes
**Impact**: Failed backends continue receiving traffic
**Solution**:
```powershell
# Add health probe to load balancer
`$lb = Get-AzLoadBalancer -Name 'lb-name' -ResourceGroupName 'rg-name'
Add-AzLoadBalancerProbeConfig -LoadBalancer `$lb -Name 'health-probe' ``
    -Protocol Http -Port 80 -IntervalInSeconds 15 -ProbeCount 2 ``
    -RequestPath '/health'
Set-AzLoadBalancer -LoadBalancer `$lb
```
"@ } else { "✓ All load balancers have health probes" })

### 6. Application Gateways Missing Probes
$(if (($failurePoints | Where-Object { $_.ResourceType -eq 'Application Gateway' -and $_.Issue -match 'probe' }).Count -gt 0) { @"
**Issue**: $((($failurePoints | Where-Object { $_.ResourceType -eq 'Application Gateway' -and $_.Issue -match 'probe' }).Count)) app gateways lack custom probes
**Impact**: Default probe may not detect application-level failures
**Solution**:
```powershell
# Add custom health probe
`$appGw = Get-AzApplicationGateway -Name 'appgw-name' -ResourceGroupName 'rg-name'
Add-AzApplicationGatewayProbeConfig -ApplicationGateway `$appGw ``
    -Name 'custom-probe' -Protocol Https -Path '/api/health' ``
    -Interval 30 -Timeout 30 -UnhealthyThreshold 3 ``
    -HostName 'app.contoso.com'
Set-AzApplicationGateway -ApplicationGateway `$appGw
```
"@ } else { "✓ All application gateways have custom probes" })

## DEPENDENCY MAPPING:

### 7. Enable Application Insights
$(if (!$hasAppInsights) { @"
**Missing**: Application-level dependency tracking
**Solution**:
```powershell
# Create Application Insights
New-AzApplicationInsights -ResourceGroupName 'rg-name' ``
    -Name 'appinsights' -Location 'eastus' -Kind 'web'

# Enable for App Services
Set-AzWebApp -ResourceGroupName 'rg-name' -Name 'app-name' ``
    -AppSettings @{'APPLICATIONINSIGHTS_CONNECTION_STRING' = '...' }
```
**Benefits**:
- Automatic dependency mapping
- Distributed tracing
- Failure correlation
- Performance bottleneck identification
"@ } else { "✓ Application Insights enabled ($($appInsights.Count) instances)" })

### 8. Enable Service Map / VM Insights
$(if (!$hasServiceMap) { @"
**Missing**: Infrastructure dependency tracking
**Solution**:
```powershell
# Enable VM Insights on Log Analytics workspace
Set-AzOperationalInsightsIntelligencePack -ResourceGroupName 'rg-name' ``
    -WorkspaceName 'workspace-name' -IntelligencePackName 'ServiceMap' -Enabled `$true

# Install Dependency Agent on VMs
Set-AzVMExtension -ResourceGroupName 'rg-name' -VMName 'vm-name' ``
    -Name 'DependencyAgent' -Publisher 'Microsoft.Azure.Monitoring.DependencyAgent' ``
    -Type 'DependencyAgentWindows' -TypeHandlerVersion '9.10'
```
**Benefits**:
- Visualize server dependencies
- Identify external dependencies
- Detect communication failures
- Plan for failures
"@ } else { "✓ Service Map enabled ($vmInsightsEnabled VMs monitored)" })

## AZURE ADVISOR RECOMMENDATIONS:
$(if ($advisorHaCount -gt 0) { @"
**Action Required**: Review and implement $advisorHaCount Azure Advisor high availability recommendations
```powershell
# View recommendations
Get-AzAdvisorRecommendation -Category HighAvailability | 
    Format-Table -Property ShortDescription, ImpactedValue, Impact
```
"@ } else { "✓ No outstanding Advisor HA recommendations" })

## BEST PRACTICES:

1. **Document Failure Scenarios**:
   - Create failure mode effects analysis (FMEA) document
   - Map each component to its failure impact
   - Define recovery procedures for each scenario

2. **Test Failure Modes**:
   - Use Azure Chaos Studio to test resilience
   - Perform regular disaster recovery drills
   - Validate automatic failover mechanisms

3. **Implement Circuit Breakers**:
   - Use retry policies with exponential backoff
   - Implement circuit breakers for external dependencies
   - Set appropriate timeouts

4. **Monitor Dependencies**:
   - Create alerts for critical dependencies
   - Track dependency health in dashboards
   - Set up synthetic monitoring

Current State:
$evidence
"@ `
                    -RemediationScript @"
# Failure Mode Analysis - Remediation Script
# This script helps address common single points of failure

#region Virtual Machine Redundancy

# Get VMs without availability zones or sets
`$vmsWithoutRedundancy = Get-AzVM | Where-Object {
    `$vm = Get-AzVM -ResourceGroupName `$_.ResourceGroupName -Name `$_.Name -Status
    -not `$vm.Zones -and -not `$_.AvailabilitySetReference
}

Write-Host "Found `$(`$vmsWithoutRedundancy.Count) VMs without redundancy"

# For each VM, recommend moving to VMSS or adding to availability set
foreach (`$vm in `$vmsWithoutRedundancy) {
    Write-Host "`nVM: `$(`$vm.Name)"
    Write-Host "  Location: `$(`$vm.Location)"
    Write-Host "  Recommendation: Migrate to VM Scale Set or create new VM in availability zone"
    
    # Example: Create VM in availability zone (requires recreation)
    Write-Host "  Migration approach:"
    Write-Host "    1. Create managed disk snapshot"
    Write-Host "    2. Create new VM from snapshot in zone"
    Write-Host "    3. Validate new VM"
    Write-Host "    4. Update DNS/load balancer"
    Write-Host "    5. Decommission old VM"
}

#endregion

#region App Service Scaling

# Get App Services on single instances
`$appServicePlans = Get-AzAppServicePlan | Where-Object { `$_.Sku.Capacity -le 1 }

Write-Host "`n`nFound `$(`$appServicePlans.Count) App Service Plans with 1 instance"

foreach (`$plan in `$appServicePlans) {
    Write-Host "`nApp Service Plan: `$(`$plan.Name)"
    Write-Host "  Current SKU: `$(`$plan.Sku.Name) (Capacity: `$(`$plan.Sku.Capacity))"
    
    if (`$plan.Sku.Tier -in @('Free', 'Shared')) {
        Write-Host "  Action: Upgrade to Standard tier or higher"
        # Uncomment to upgrade:
        # Set-AzAppServicePlan -ResourceGroupName `$plan.ResourceGroupName ``
        #     -Name `$plan.Name -Tier 'Standard' -NumberofWorkers 2
    } else {
        Write-Host "  Action: Scale out to 2+ instances"
        # Uncomment to scale:
        # Set-AzAppServicePlan -ResourceGroupName `$plan.ResourceGroupName ``
        #     -Name `$plan.Name -NumberofWorkers 2
    }
}

#endregion

#region SQL Database Geo-Replication

# Get SQL databases without replication
`$sqlServers = Get-AzSqlServer

foreach (`$server in `$sqlServers) {
    `$databases = Get-AzSqlDatabase -ServerName `$server.ServerName ``
        -ResourceGroupName `$server.ResourceGroupName | 
        Where-Object { `$_.DatabaseName -ne 'master' }
    
    foreach (`$db in `$databases) {
        `$replicas = Get-AzSqlDatabaseReplicationLink -ServerName `$server.ServerName ``
            -DatabaseName `$db.DatabaseName -ResourceGroupName `$server.ResourceGroupName ``
            -ErrorAction SilentlyContinue
        
        if (-not `$replicas) {
            Write-Host "`nSQL Database: `$(`$db.DatabaseName)"
            Write-Host "  Server: `$(`$server.ServerName)"
            Write-Host "  Zone Redundant: `$(`$db.ZoneRedundant)"
            Write-Host "  Action: Enable geo-replication or zone redundancy"
            
            # Example: Enable zone redundancy (for supported SKUs)
            # Set-AzSqlDatabase -ResourceGroupName `$server.ResourceGroupName ``
            #     -ServerName `$server.ServerName -DatabaseName `$db.DatabaseName ``
            #     -ZoneRedundant
        }
    }
}

#endregion

#region Storage Account Redundancy

# Get storage accounts with LRS only
`$storageAccounts = Get-AzStorageAccount | Where-Object { 
    `$_.Sku.Name -in @('Standard_LRS', 'Premium_LRS') 
}

Write-Host "`n`nFound `$(`$storageAccounts.Count) storage accounts with LRS only"

foreach (`$storage in `$storageAccounts) {
    Write-Host "`nStorage Account: `$(`$storage.StorageAccountName)"
    Write-Host "  Current SKU: `$(`$storage.Sku.Name)"
    Write-Host "  Recommendation: Upgrade to ZRS or GRS"
    
    # Uncomment to upgrade (note: may require data migration):
    # Set-AzStorageAccount -ResourceGroupName `$storage.ResourceGroupName ``
    #     -Name `$storage.StorageAccountName -SkuName 'Standard_ZRS'
}

#endregion

#region Load Balancer Health Probes

# Get load balancers without health probes
`$loadBalancers = Get-AzLoadBalancer

foreach (`$lb in `$loadBalancers) {
    if (`$lb.Probes.Count -eq 0) {
        Write-Host "`nLoad Balancer: `$(`$lb.Name)"
        Write-Host "  Backend Pools: `$(`$lb.BackendAddressPools.Count)"
        Write-Host "  Health Probes: 0 (MISSING)"
        Write-Host "  Action: Add health probe"
        
        # Example: Add HTTP health probe
        # Add-AzLoadBalancerProbeConfig -LoadBalancer `$lb ``
        #     -Name 'http-probe' -Protocol Http -Port 80 ``
        #     -IntervalInSeconds 15 -ProbeCount 2 -RequestPath '/health'
        # Set-AzLoadBalancer -LoadBalancer `$lb
    }
}

#endregion

#region Enable Application Insights

# Check if Application Insights exists
`$appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue

if (-not `$appInsights -or `$appInsights.Count -eq 0) {
    Write-Host "`n`nNo Application Insights found"
    Write-Host "Recommendation: Create Application Insights for dependency tracking"
    
    # Example: Create Application Insights
    # New-AzApplicationInsights -ResourceGroupName 'rg-monitoring' ``
    #     -Name 'app-insights' -Location 'eastus' -Kind 'web'
}

#endregion

#region Summary Report

Write-Host "`n`n" -NoNewline
Write-Host "═" * 70 -ForegroundColor Cyan
Write-Host "FAILURE MODE ANALYSIS - REMEDIATION SUMMARY" -ForegroundColor Cyan
Write-Host "═" * 70 -ForegroundColor Cyan

`$summary = @{
    VMsWithoutRedundancy = `$vmsWithoutRedundancy.Count
    SingleInstanceAppPlans = `$appServicePlans.Count
    StorageAccountsWithLRS = `$storageAccounts.Count
    TotalIssues = `$vmsWithoutRedundancy.Count + `$appServicePlans.Count + `$storageAccounts.Count
}

Write-Host "`nTotal Issues Identified: `$(`$summary.TotalIssues)"
Write-Host "  - VMs without redundancy: `$(`$summary.VMsWithoutRedundancy)"
Write-Host "  - Single-instance App Services: `$(`$summary.SingleInstanceAppPlans)"
Write-Host "  - Storage accounts with LRS: `$(`$summary.StorageAccountsWithLRS)"

Write-Host "`nNext Steps:"
Write-Host "1. Review each resource listed above"
Write-Host "2. Prioritize by business criticality"
Write-Host "3. Plan migration/upgrade schedule"
Write-Host "4. Test in non-production first"
Write-Host "5. Implement monitoring and alerting"

Write-Host "`nFor detailed guidance, see: https://learn.microsoft.com/azure/well-architected/reliability/"

#endregion
"@
                
            } else {
                
                $affectedResources = $failurePoints | ForEach-Object { $_.ResourceId }
                
                return New-WafResult -CheckId 'RE03' `
                    -Status 'Fail' `
                    -Message "CRITICAL: Failure mode analysis identified $($failurePoints.Count) single points of failure ($criticalFailures critical). Only $redundancyPercent% of resources have redundancy configured. Dependency tracking not fully enabled." `
                    -AffectedResources $affectedResources `
                    -Recommendation @"
**IMMEDIATE ACTION REQUIRED**: Your environment has significant single points of failure that pose high risk to service availability.

## CRITICAL ISSUES SUMMARY:
- $criticalFailures resources with HIGH impact failures
- $mediumFailures resources with MEDIUM impact failures  
- $redundancyPercent% redundancy coverage (target: >90%)
- Dependency tracking: $(if ($hasAppInsights) { "Partial" } else { "Missing" })

## PRIORITY 1 - ELIMINATE CRITICAL SPOFs (Week 1):

### Virtual Machines (High Risk)
$((($failurePoints | Where-Object { $_.ResourceType -eq 'Virtual Machine' } | Select-Object -First 3) | ForEach-Object { "❌ $($_.ResourceName): $($_.Issue)" }) -join "`n")
$(if (($failurePoints | Where-Object ResourceType -eq 'Virtual Machine').Count -gt 3) { "... and $(($failurePoints | Where-Object ResourceType -eq 'Virtual Machine').Count - 3) more VMs" })

**Immediate Action**:
1. Identify production VMs from the list above
2. Plan zone-redundant replacements
3. Implement VM Scale Sets for auto-scaling and redundancy

### Databases (High Risk)
$((($failurePoints | Where-Object { $_.ResourceType -eq 'SQL Database' } | Select-Object -First 3) | ForEach-Object { "❌ $($_.ResourceName): $($_.Issue)" }) -join "`n")

**Immediate Action**:
1. Enable geo-replication for production databases
2. Configure automatic failover groups
3. Test failover procedures

### Application Services (High Risk)
$((($failurePoints | Where-Object { $_.ResourceType -eq 'App Service' } | Select-Object -First 3) | ForEach-Object { "❌ $($_.ResourceName): $($_.Issue)" }) -join "`n")

**Immediate Action**:
1. Scale to minimum 2 instances per app
2. Upgrade from Free/Shared tiers
3. Enable autoscaling rules

## PRIORITY 2 - HEALTH MONITORING (Week 2):

### Missing Health Probes
Load balancers and application gateways must have health probes configured:

```powershell
# Add health probe to load balancer
`$lb = Get-AzLoadBalancer -Name '<lb-name>' -ResourceGroupName '<rg-name>'
Add-AzLoadBalancerProbeConfig -LoadBalancer `$lb ``
    -Name 'app-health-probe' -Protocol Http -Port 80 ``
    -IntervalInSeconds 15 -ProbeCount 2 -RequestPath '/health'
Set-AzLoadBalancer -LoadBalancer `$lb
```

**Benefits**:
- Automatic detection of failed backends
- Traffic routed only to healthy instances
- Reduced mean time to recovery (MTTR)

## PRIORITY 3 - DEPENDENCY MAPPING (Week 3):

### Enable Application Insights
Deploy Application Insights to ALL applications:
```powershell
# Create Application Insights
`$appInsights = New-AzApplicationInsights ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'prod-appinsights' ``
    -Location 'eastus' ``
    -Kind 'web'

# Connect to App Services
Get-AzWebApp | ForEach-Object {
    Set-AzWebApp -ResourceGroupName `$_.ResourceGroup -Name `$_.Name ``
        -AppSettings @{
            'APPLICATIONINSIGHTS_CONNECTION_STRING' = `$appInsights.ConnectionString
            'ApplicationInsightsAgent_EXTENSION_VERSION' = '~3'
        }
}
```

### Enable VM Insights
Install dependency agents on all VMs:
```powershell
# Enable for all VMs
Get-AzVM | ForEach-Object {
    Set-AzVMExtension ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -VMName `$_.Name ``
        -Name 'DependencyAgent' ``
        -Publisher 'Microsoft.Azure.Monitoring.DependencyAgent' ``
        -Type 'DependencyAgentWindows' ``
        -TypeHandlerVersion '9.10'
}
```

## PRIORITY 4 - STORAGE REDUNDANCY (Week 4):

Upgrade storage accounts to geo-redundant options:
```powershell
# Upgrade to ZRS (zone-redundant storage)
Get-AzStorageAccount | Where-Object { `$_.Sku.Name -eq 'Standard_LRS' } | ForEach-Object {
    Set-AzStorageAccount ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -Name `$_.StorageAccountName ``
        -SkuName 'Standard_ZRS'
}
```

## TESTING & VALIDATION:

After implementing redundancy, **TEST THE FAILURE MODES**:

1. **Azure Chaos Studio**: Test resilience automatically
2. **Manual Failover Tests**: Validate database failovers
3. **Load Balancer Tests**: Verify health probe behavior
4. **Zone Failure Simulation**: Test zone-down scenarios

## MONITORING & ALERTING:

Set up alerts for:
- Health probe failures
- Database replication lag
- Availability zone unavailability
- Storage account failover events

```powershell
# Example: Alert on health probe failures
`$actionGroup = Get-AzActionGroup -ResourceGroupName 'rg-monitoring' -Name 'ops-team'

New-AzMetricAlertRuleV2 ``
    -Name 'health-probe-failures' ``
    -ResourceGroupName 'rg-monitoring' ``
    -TargetResourceId '/subscriptions/.../loadBalancers/lb-prod' ``
    -Condition (New-AzMetricAlertRuleV2Criteria ``
        -MetricName 'HealthProbeStatus' ``
        -Operator LessThan ``
        -Threshold 50) ``
    -ActionGroup `$actionGroup ``
    -Severity 2
```

## DOCUMENTATION REQUIREMENTS:

Create and maintain:
1. **FMEA Document**: List all components and their failure modes
2. **Dependency Map**: Visual diagram of component dependencies
3. **Runbooks**: Recovery procedures for each failure scenario
4. **Incident Response**: Escalation paths and contact lists

## COST IMPACT:

Implementing redundancy will increase costs:
- Availability Zones: +0-10% (no additional VM cost)
- App Service scale-out: +100% (2x instances)
- Geo-replication: +100% (secondary region storage)
- VM Insights: ~`$2-3 per VM per month

**However**: Cost of downtime typically exceeds redundancy costs significantly.

Example: 1 hour of downtime at `$10,000/hour = 5 years of redundancy costs.

## SUCCESS METRICS:

Track these KPIs monthly:
- Redundancy coverage: Target 95%+
- Mean Time Between Failures (MTBF): Target increase
- Mean Time To Recovery (MTTR): Target decrease
- Azure Advisor HA score: Target 100%
- Dependency tracking coverage: Target 100%

Current State:
$evidence

**START THIS WEEK**: Failure mode analysis shows critical gaps that require immediate attention.
"@ `
                    -RemediationScript @"
# URGENT: Critical Failure Mode Remediation
# This script addresses the most critical single points of failure

Write-Host "═" * 70 -ForegroundColor Red
Write-Host "CRITICAL FAILURE MODE ANALYSIS - URGENT REMEDIATION" -ForegroundColor Red
Write-Host "═" * 70 -ForegroundColor Red
Write-Host ""

`$criticalIssues = @()

#region CRITICAL: Virtual Machines Without Redundancy

Write-Host "[CRITICAL] Analyzing VMs without redundancy..." -ForegroundColor Red

`$vmsWithoutHA = @()
Get-AzVM | ForEach-Object {
    `$vm = Get-AzVM -ResourceGroupName `$_.ResourceGroupName -Name `$_.Name -Status
    if (-not `$vm.Zones -and -not `$_.AvailabilitySetReference) {
        `$vmsWithoutHA += `$_
        `$criticalIssues += "VM '`$(`$_.Name)' has no redundancy"
    }
}

Write-Host "  Found `$(`$vmsWithoutHA.Count) VMs without redundancy" -ForegroundColor Yellow

if (`$vmsWithoutHA.Count -gt 0) {
    Write-Host "`n  URGENT ACTION PLAN FOR VMs:" -ForegroundColor Red
    Write-Host "  1. Create snapshots of all critical VM disks"
    Write-Host "  2. Deploy new zone-redundant VMs from snapshots"
    Write-Host "  3. Test application functionality"
    Write-Host "  4. Cutover DNS/load balancers to new VMs"
    Write-Host "  5. Decommission old VMs after validation"
    
    # Create snapshot script
    Write-Host "`n  Snapshot creation script:"
    Write-Host "  " -NoNewline
    Write-Host "foreach (`$vm in `$vmsWithoutHA) {" -ForegroundColor Gray
    Write-Host "      `$disks = Get-AzDisk -ResourceGroupName `$vm.ResourceGroupName | Where-Object { `$_.ManagedBy -eq `$vm.Id }"
    Write-Host "      foreach (`$disk in `$disks) {"
    Write-Host "          New-AzSnapshotConfig -SourceUri `$disk.Id -Location `$disk.Location -CreateOption Copy |"
    Write-Host "              New-AzSnapshot -ResourceGroupName `$vm.ResourceGroupName -SnapshotName \"`$(`$disk.Name)-snapshot\""
    Write-Host "      }"
    Write-Host "  }"
}

#endregion

#region CRITICAL: Databases Without Replication

Write-Host "`n[CRITICAL] Analyzing databases without replication..." -ForegroundColor Red

`$dbsWithoutReplica = @()
Get-AzSqlServer | ForEach-Object {
    `$server = `$_
    Get-AzSqlDatabase -ServerName `$server.ServerName -ResourceGroupName `$server.ResourceGroupName | 
        Where-Object { `$_.DatabaseName -ne 'master' } | ForEach-Object {
        `$db = `$_
        `$replicas = Get-AzSqlDatabaseReplicationLink ``
            -ServerName `$server.ServerName ``
            -DatabaseName `$db.DatabaseName ``
            -ResourceGroupName `$server.ResourceGroupName ``
            -ErrorAction SilentlyContinue
        
        if (-not `$replicas -and -not `$db.ZoneRedundant) {
            `$dbsWithoutReplica += @{
                Server = `$server.ServerName
                Database = `$db.DatabaseName
                ResourceGroup = `$server.ResourceGroupName
            }
            `$criticalIssues += "Database '`$(`$db.DatabaseName)' has no replication"
        }
    }
}

Write-Host "  Found `$(`$dbsWithoutReplica.Count) databases without replication" -ForegroundColor Yellow

if (`$dbsWithoutReplica.Count -gt 0) {
    Write-Host "`n  URGENT ACTION PLAN FOR DATABASES:" -ForegroundColor Red
    Write-Host "  Option 1: Enable zone redundancy (same region protection)"
    Write-Host "  Option 2: Configure geo-replication (cross-region DR)"
    Write-Host ""
    Write-Host "  Quick implementation (zone redundancy):"
    
    foreach (`$db in `$dbsWithoutReplica | Select-Object -First 3) {
        Write-Host "    Set-AzSqlDatabase -ResourceGroupName '`$(`$db.ResourceGroup)' ``" -ForegroundColor Gray
        Write-Host "        -ServerName '`$(`$db.Server)' -DatabaseName '`$(`$db.Database)' ``"
        Write-Host "        -ZoneRedundant"
    }
}

#endregion

#region CRITICAL: App Services on Single Instances

Write-Host "`n[CRITICAL] Analyzing App Services on single instances..." -ForegroundColor Red

`$singleInstanceApps = Get-AzAppServicePlan | Where-Object { `$_.Sku.Capacity -le 1 }

Write-Host "  Found `$(`$singleInstanceApps.Count) App Service Plans with 1 instance" -ForegroundColor Yellow

if (`$singleInstanceApps.Count -gt 0) {
    Write-Host "`n  URGENT ACTION PLAN FOR APP SERVICES:" -ForegroundColor Red
    Write-Host "  Immediate scale-out required for production apps"
    Write-Host ""
    
    foreach (`$plan in `$singleInstanceApps | Select-Object -First 3) {
        `$criticalIssues += "App Service Plan '`$(`$plan.Name)' has only 1 instance"
        
        if (`$plan.Sku.Tier -in @('Free', 'Shared')) {
            Write-Host "    Plan: `$(`$plan.Name) (Tier: `$(`$plan.Sku.Tier))" -ForegroundColor Yellow
            Write-Host "      ACTION: Upgrade to Standard tier and scale to 2+ instances"
            Write-Host "      Set-AzAppServicePlan -ResourceGroupName '`$(`$plan.ResourceGroupName)' ``" -ForegroundColor Gray
            Write-Host "          -Name '`$(`$plan.Name)' -Tier 'Standard' -NumberofWorkers 2"
        } else {
            Write-Host "    Plan: `$(`$plan.Name) (Tier: `$(`$plan.Sku.Tier))" -ForegroundColor Yellow
            Write-Host "      ACTION: Scale to 2+ instances"
            Write-Host "      Set-AzAppServicePlan -ResourceGroupName '`$(`$plan.ResourceGroupName)' ``" -ForegroundColor Gray
            Write-Host "          -Name '`$(`$plan.Name)' -NumberofWorkers 2"
        }
    }
}

#endregion

#region Enable Health Probes

Write-Host "`n[HIGH] Checking load balancers for health probes..." -ForegroundColor Yellow

`$lbsWithoutProbes = Get-AzLoadBalancer | Where-Object { `$_.Probes.Count -eq 0 }

if (`$lbsWithoutProbes.Count -gt 0) {
    Write-Host "  Found `$(`$lbsWithoutProbes.Count) load balancers without health probes"
    Write-Host "  WARNING: These LBs cannot detect backend failures!"
    
    foreach (`$lb in `$lbsWithoutProbes) {
        `$criticalIssues += "Load Balancer '`$(`$lb.Name)' has no health probes"
    }
}

#endregion

#region Summary and Action Plan

Write-Host "`n"
Write-Host "═" * 70 -ForegroundColor Red
Write-Host "CRITICAL ISSUES SUMMARY" -ForegroundColor Red
Write-Host "═" * 70 -ForegroundColor Red
Write-Host ""
Write-Host "Total Critical Issues: `$(`$criticalIssues.Count)" -ForegroundColor Red
Write-Host ""

foreach (`$issue in `$criticalIssues | Select-Object -First 10) {
    Write-Host "  ❌ `$issue" -ForegroundColor Yellow
}

if (`$criticalIssues.Count -gt 10) {
    Write-Host "  ... and `$(`$criticalIssues.Count - 10) more issues" -ForegroundColor Gray
}

Write-Host ""
Write-Host "IMMEDIATE ACTIONS REQUIRED:" -ForegroundColor Red
Write-Host ""
Write-Host "Week 1 - CRITICAL PRIORITY:" -ForegroundColor Red
Write-Host "  [ ] Scale App Services to 2+ instances"
Write-Host "  [ ] Enable database replication/zone redundancy"
Write-Host "  [ ] Add health probes to all load balancers"
Write-Host ""
Write-Host "Week 2-3 - HIGH PRIORITY:" -ForegroundColor Yellow
Write-Host "  [ ] Plan VM migration to availability zones"
Write-Host "  [ ] Create VM snapshots"
Write-Host "  [ ] Deploy zone-redundant VMs"
Write-Host ""
Write-Host "Week 4 - TESTING:" -ForegroundColor Yellow
Write-Host "  [ ] Test database failover"
Write-Host "  [ ] Verify health probe behavior"
Write-Host "  [ ] Validate VM redundancy"
Write-Host ""

# Generate action plan document
`$actionPlan = @"
# CRITICAL FAILURE MODE REMEDIATION PLAN
Generated: $(Get-Date)

## Critical Issues Identified: `$(`$criticalIssues.Count)

## Immediate Actions (This Week):
$(`$criticalIssues | Select-Object -First 10 | ForEach-Object { "- `$_" })

## Implementation Priority:

### Priority 1: App Services (Can be done immediately)
- Scale all production App Service Plans to 2+ instances
- Estimated time: 1-2 hours
- Estimated cost increase: 100% (2x instances)
- Benefit: Immediate protection from platform updates/failures

### Priority 2: Databases (Quick wins)
- Enable zone redundancy for SQL databases
- Estimated time: 2-4 hours
- Estimated cost increase: ~40%
- Benefit: Protection from datacenter failures

### Priority 3: Load Balancer Probes (Low effort, high impact)
- Add health probes to all load balancers
- Estimated time: 30 minutes per LB
- Estimated cost increase: None
- Benefit: Automatic failure detection

### Priority 4: Virtual Machines (Complex, plan carefully)
- Migrate to zone-redundant deployments
- Estimated time: 1-2 weeks
- Estimated cost increase: 0-10%
- Benefit: 99.99% SLA, zone failure protection

## Success Criteria:
- [ ] Zero single-instance production applications
- [ ] All databases have replication configured
- [ ] All load balancers have health probes
- [ ] All production VMs in availability zones or sets
- [ ] Dependency tracking enabled (App Insights + Service Map)

## Contact for Questions:
- Azure Support: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- WAF Documentation: https://learn.microsoft.com/azure/well-architected/
"@

`$actionPlan | Out-File 'critical-remediation-plan.md' -Encoding UTF8

Write-Host "Action plan saved to: critical-remediation-plan.md" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  RECOMMENDATION: Schedule a meeting THIS WEEK to review and prioritize" -ForegroundColor Red
Write-Host ""

#endregion
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE03' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
