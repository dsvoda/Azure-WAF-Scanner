<#
.SYNOPSIS
    RE06 - Design for scaling and partitioning

.DESCRIPTION
    Validates that workloads are designed to scale efficiently and use partitioning
    strategies to handle increased load. This check assesses horizontal scaling capabilities,
    autoscaling configurations, partitioning patterns, and whether services can handle
    growth in demand without architectural changes.
    
    This check comprehensively assesses:
    - Autoscaling configurations (VMSS, App Services, AKS)
    - Horizontal scaling readiness (multiple instances, scale-out capable)
    - Database partitioning and sharding strategies
    - Queue-based decoupling and async processing
    - Cache layer implementation for offloading
    - Traffic distribution mechanisms (load balancers)
    - Stateless application design patterns
    - Resource limits and quotas awareness

.NOTES
    Pillar: Reliability
    Recommendation: RE:06 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/scaling
    https://learn.microsoft.com/azure/architecture/best-practices/auto-scaling
#>

Register-WafCheck -CheckId 'RE06' `
    -Pillar 'Reliability' `
    -Title 'Design for scaling and partitioning' `
    -Description 'Implement horizontal scaling capabilities and partitioning strategies to handle increased load efficiently without requiring architectural redesign' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'Scaling', 'Partitioning', 'Autoscale', 'HorizontalScale', 'Performance') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/scaling' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            $scalingGaps = @()
            $scalingStrengths = @()
            $totalScalableResources = 0
            $resourcesWithAutoscale = 0
            
            # Category scores
            $scores = @{
                ComputeScaling = @{ Current = 0; Max = 30 }
                Autoscaling = @{ Current = 0; Max = 25 }
                DataPartitioning = @{ Current = 0; Max = 20 }
                Decoupling = @{ Current = 0; Max = 15 }
                Statelessness = @{ Current = 0; Max = 10 }
            }
            
            #region 1. COMPUTE SCALING ASSESSMENT
            
            Write-Verbose "Analyzing compute scaling configurations..."
            
            # VM Scale Sets - Ideal for horizontal scaling
            $vmssQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend 
    capacity = toint(sku.capacity),
    minCapacity = toint(properties.sku.capacity),
    overprovision = tobool(properties.overprovision),
    upgradeMode = tostring(properties.upgradePolicy.mode),
    zones = tostring(zones)
| project 
    id,
    name,
    resourceGroup,
    location,
    capacity,
    minCapacity,
    overprovision,
    upgradeMode,
    zones
"@
            $vmss = Invoke-AzResourceGraphQuery -Query $vmssQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($vmss -and $vmss.Count -gt 0) {
                $totalScalableResources += $vmss.Count
                
                # Check for autoscale settings on VMSS
                $vmssWithAutoscale = 0
                $vmssLowCapacity = 0
                
                foreach ($scaleSet in $vmss) {
                    $autoscaleSettings = Get-AzAutoscaleSetting -ErrorAction SilentlyContinue | 
                        Where-Object { $_.TargetResourceUri -eq $scaleSet.id }
                    
                    if ($autoscaleSettings) {
                        $vmssWithAutoscale++
                        $resourcesWithAutoscale++
                    }
                    
                    if ($scaleSet.capacity -lt 2) {
                        $vmssLowCapacity++
                    }
                }
                
                if ($vmssWithAutoscale -eq $vmss.Count) {
                    $scalingStrengths += "✓ All $($vmss.Count) VM Scale Set(s) have autoscaling configured"
                    $scores.ComputeScaling.Current += 15
                    $scores.Autoscaling.Current += 15
                } elseif ($vmssWithAutoscale -gt 0) {
                    $scalingStrengths += "✓ $vmssWithAutoscale of $($vmss.Count) VM Scale Set(s) have autoscaling"
                    $scores.ComputeScaling.Current += 10
                    $scores.Autoscaling.Current += 10
                    
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'VM Scale Sets'
                        Issue = "$($vmss.Count - $vmssWithAutoscale) VMSS without autoscaling"
                        Impact = 'High'
                        Details = "Scale sets should have autoscale rules for dynamic capacity"
                    }
                } else {
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'VM Scale Sets'
                        Issue = "None of $($vmss.Count) VMSS have autoscaling configured"
                        Impact = 'High'
                        Details = "All scale sets require manual scaling - implement autoscale rules"
                    }
                    $scores.ComputeScaling.Current += 5
                }
                
                if ($vmssLowCapacity -gt 0) {
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'VM Scale Sets'
                        Issue = "$vmssLowCapacity VMSS with capacity < 2"
                        Impact = 'Medium'
                        Details = "Minimum 2 instances recommended for production workloads"
                    }
                }
            }
            
            # App Service Plans - Check autoscaling
            $appServiceQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/serverfarms'
| extend 
    skuTier = tostring(sku.tier),
    capacity = toint(sku.capacity),
    kind = tostring(kind)
| project 
    id,
    name,
    resourceGroup,
    location,
    skuTier,
    capacity,
    kind
"@
            $appServicePlans = Invoke-AzResourceGraphQuery -Query $appServiceQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($appServicePlans -and $appServicePlans.Count -gt 0) {
                $totalScalableResources += $appServicePlans.Count
                $plansWithAutoscale = 0
                $plansSupportsAutoscale = 0
                $plansSingleInstance = 0
                
                foreach ($plan in $appServicePlans) {
                    # Check if tier supports autoscale (Standard and above)
                    $supportsAutoscale = $plan.skuTier -match 'Standard|Premium|PremiumV2|PremiumV3|Isolated'
                    
                    if ($supportsAutoscale) {
                        $plansSupportsAutoscale++
                        
                        # Check for autoscale settings
                        $autoscaleSettings = Get-AzAutoscaleSetting -ErrorAction SilentlyContinue | 
                            Where-Object { $_.TargetResourceUri -eq $plan.id }
                        
                        if ($autoscaleSettings) {
                            $plansWithAutoscale++
                            $resourcesWithAutoscale++
                        }
                    }
                    
                    if ($plan.capacity -lt 2) {
                        $plansSingleInstance++
                    }
                }
                
                if ($plansSupportsAutoscale -gt 0) {
                    $autoscalePercent = ($plansWithAutoscale / $plansSupportsAutoscale) * 100
                    
                    if ($autoscalePercent -eq 100) {
                        $scalingStrengths += "✓ All $plansSupportsAutoscale eligible App Service Plan(s) have autoscaling"
                        $scores.ComputeScaling.Current += 10
                        $scores.Autoscaling.Current += 10
                    } elseif ($plansWithAutoscale -gt 0) {
                        $scalingStrengths += "✓ $plansWithAutoscale of $plansSupportsAutoscale eligible plan(s) have autoscaling"
                        $scores.ComputeScaling.Current += 5
                        $scores.Autoscaling.Current += 5
                        
                        $scalingGaps += [PSCustomObject]@{
                            Category = 'Compute Scaling'
                            Resource = 'App Service Plans'
                            Issue = "$($plansSupportsAutoscale - $plansWithAutoscale) eligible plans without autoscaling"
                            Impact = 'High'
                            Details = "Configure autoscale rules for Standard tier and above plans"
                        }
                    } else {
                        $scalingGaps += [PSCustomObject]@{
                            Category = 'Compute Scaling'
                            Resource = 'App Service Plans'
                            Issue = "No autoscaling on $plansSupportsAutoscale eligible plans"
                            Impact = 'High'
                            Details = "All Standard+ plans should have autoscale configured"
                        }
                    }
                }
                
                if ($plansSingleInstance -gt 0) {
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'App Service Plans'
                        Issue = "$plansSingleInstance plan(s) running single instance"
                        Impact = 'High'
                        Details = "Scale to minimum 2 instances for production workloads"
                    }
                }
            }
            
            # AKS Clusters - Check node pool autoscaling
            $aksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| extend 
    nodePools = properties.agentPoolProfiles
| project 
    id,
    name,
    resourceGroup,
    location,
    nodePools
"@
            $aksClusters = Invoke-AzResourceGraphQuery -Query $aksQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($aksClusters -and $aksClusters.Count -gt 0) {
                $totalScalableResources += $aksClusters.Count
                $aksWithAutoscale = 0
                
                foreach ($aks in $aksClusters) {
                    try {
                        $cluster = Get-AzAksCluster -ResourceGroupName $aks.resourceGroup -Name $aks.name -ErrorAction SilentlyContinue
                        
                        if ($cluster) {
                            $hasAutoscale = $false
                            foreach ($pool in $cluster.AgentPoolProfiles) {
                                if ($pool.EnableAutoScaling) {
                                    $hasAutoscale = $true
                                    break
                                }
                            }
                            
                            if ($hasAutoscale) {
                                $aksWithAutoscale++
                                $resourcesWithAutoscale++
                            }
                        }
                    } catch {
                        Write-Verbose "Could not retrieve autoscale details for AKS: $($aks.name)"
                    }
                }
                
                if ($aksWithAutoscale -eq $aksClusters.Count) {
                    $scalingStrengths += "✓ All $($aksClusters.Count) AKS cluster(s) have node pool autoscaling"
                    $scores.ComputeScaling.Current += 5
                } elseif ($aksWithAutoscale -gt 0) {
                    $scalingStrengths += "✓ $aksWithAutoscale of $($aksClusters.Count) AKS cluster(s) have autoscaling"
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'AKS Clusters'
                        Issue = "$($aksClusters.Count - $aksWithAutoscale) cluster(s) without autoscaling"
                        Impact = 'Medium'
                        Details = "Enable cluster autoscaler on node pools for dynamic scaling"
                    }
                } else {
                    $scalingGaps += [PSCustomObject]@{
                        Category = 'Compute Scaling'
                        Resource = 'AKS Clusters'
                        Issue = "No AKS clusters have autoscaling enabled"
                        Impact = 'High'
                        Details = "Enable cluster autoscaler for responsive capacity management"
                    }
                }
            }
            
            #endregion
            
            #region 2. DATA PARTITIONING & SHARDING
            
            Write-Verbose "Analyzing data partitioning strategies..."
            
            # Cosmos DB - Check for partitioning
            $cosmosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.documentdb/databaseaccounts'
| extend 
    capabilities = properties.capabilities,
    locations = array_length(properties.locations)
| project 
    id,
    name,
    resourceGroup,
    location,
    capabilities,
    locations
"@
            $cosmosAccounts = Invoke-AzResourceGraphQuery -Query $cosmosQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($cosmosAccounts -and $cosmosAccounts.Count -gt 0) {
                $scalingStrengths += "✓ $($cosmosAccounts.Count) Cosmos DB account(s) - inherently partitioned and scalable"
                $scores.DataPartitioning.Current += 10
            }
            
            # SQL Databases - Check for elastic pools (indication of scaling strategy)
            $sqlElasticPoolQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/elasticpools'
| project 
    id,
    name,
    resourceGroup,
    maxDtu = toint(sku.capacity)
"@
            $elasticPools = Invoke-AzResourceGraphQuery -Query $sqlElasticPoolQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($elasticPools -and $elasticPools.Count -gt 0) {
                $scalingStrengths += "✓ $($elasticPools.Count) SQL Elastic Pool(s) - enables efficient resource sharing"
                $scores.DataPartitioning.Current += 5
            }
            
            # Check for SQL Databases (potential sharding candidates)
            $sqlDbQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| where name !~ 'master'
| extend 
    tier = tostring(sku.tier),
    capacity = toint(sku.capacity)
| project 
    id,
    name,
    resourceGroup,
    tier,
    capacity
"@
            $sqlDatabases = Invoke-AzResourceGraphQuery -Query $sqlDbQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($sqlDatabases -and $sqlDatabases.Count -gt 1) {
                # Multiple databases might indicate sharding strategy
                $scalingStrengths += "✓ $($sqlDatabases.Count) SQL database(s) - multiple databases can support partitioning"
                $scores.DataPartitioning.Current += 5
            } elseif ($sqlDatabases -and $sqlDatabases.Count -eq 1) {
                $scalingGaps += [PSCustomObject]@{
                    Category = 'Data Partitioning'
                    Resource = 'SQL Databases'
                    Issue = "Single SQL database - limited horizontal scaling"
                    Impact = 'Medium'
                    Details = "Consider sharding strategy or elastic pools for growth"
                }
            }
            
            # Redis Cache - Check for clustering
            $redisQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.cache/redis'
| extend 
    skuFamily = tostring(sku.family),
    shardCount = toint(properties.shardCount)
| project 
    id,
    name,
    resourceGroup,
    skuFamily,
    shardCount
"@
            $redisCaches = Invoke-AzResourceGraphQuery -Query $redisQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($redisCaches -and $redisCaches.Count -gt 0) {
                $redisWithClustering = ($redisCaches | Where-Object { $_.shardCount -gt 0 }).Count
                
                if ($redisWithClustering -gt 0) {
                    $scalingStrengths += "✓ $redisWithClustering Redis Cache(s) with clustering enabled"
                    $scores.DataPartitioning.Current += 5
                }
            }
            
            #endregion
            
            #region 3. DECOUPLING & ASYNC PATTERNS
            
            Write-Verbose "Analyzing decoupling mechanisms..."
            
            # Service Bus - Queue-based decoupling
            $serviceBusQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.servicebus/namespaces'
| project 
    id,
    name,
    resourceGroup,
    sku = tostring(sku.tier)
"@
            $serviceBusNamespaces = Invoke-AzResourceGraphQuery -Query $serviceBusQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($serviceBusNamespaces -and $serviceBusNamespaces.Count -gt 0) {
                $scalingStrengths += "✓ $($serviceBusNamespaces.Count) Service Bus namespace(s) - enables async processing"
                $scores.Decoupling.Current += 8
            }
            
            # Storage Queues
            $storageAccountsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| project 
    id,
    name,
    resourceGroup
"@
            $storageAccounts = Invoke-AzResourceGraphQuery -Query $storageAccountsQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Assume storage accounts may have queues (can't query queue count via Resource Graph)
            if ($storageAccounts -and $storageAccounts.Count -gt 0) {
                $scalingStrengths += "✓ $($storageAccounts.Count) Storage Account(s) - can support queue-based patterns"
                $scores.Decoupling.Current += 3
            }
            
            # Event Grid / Event Hubs
            $eventGridQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.eventgrid/topics' or type =~ 'microsoft.eventhub/namespaces'
| project 
    id,
    name,
    type,
    resourceGroup
"@
            $eventResources = Invoke-AzResourceGraphQuery -Query $eventGridQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($eventResources -and $eventResources.Count -gt 0) {
                $eventGridCount = ($eventResources | Where-Object { $_.type -match 'eventgrid' }).Count
                $eventHubCount = ($eventResources | Where-Object { $_.type -match 'eventhub' }).Count
                
                $scalingStrengths += "✓ Event-based decoupling: Event Grid($eventGridCount), Event Hub($eventHubCount)"
                $scores.Decoupling.Current += 4
            }
            
            if ($scores.Decoupling.Current -eq 0) {
                $scalingGaps += [PSCustomObject]@{
                    Category = 'Decoupling'
                    Resource = 'Messaging Services'
                    Issue = "No messaging/queue services detected"
                    Impact = 'High'
                    Details = "Implement Service Bus or Storage Queues for async processing and decoupling"
                }
            }
            
            #endregion
            
            #region 4. STATELESS DESIGN INDICATORS
            
            Write-Verbose "Analyzing stateless design patterns..."
            
            # Redis Cache presence indicates externalized state
            if ($redisCaches -and $redisCaches.Count -gt 0) {
                $scalingStrengths += "✓ $($redisCaches.Count) Redis Cache(s) - supports stateless application design"
                $scores.Statelessness.Current += 5
            }
            
            # Cosmos DB can serve as session store
            if ($cosmosAccounts -and $cosmosAccounts.Count -gt 0) {
                $scalingStrengths += "✓ Cosmos DB available for distributed state management"
                $scores.Statelessness.Current += 3
            }
            
            # App Service with Redis or external state
            if (($appServicePlans -and $appServicePlans.Count -gt 0) -and 
                ($redisCaches -and $redisCaches.Count -gt 0)) {
                $scalingStrengths += "✓ App Services with Redis Cache - stateless pattern possible"
                $scores.Statelessness.Current += 2
            } elseif ($appServicePlans -and $appServicePlans.Count -gt 0) {
                $scalingGaps += [PSCustomObject]@{
                    Category = 'Statelessness'
                    Resource = 'App Services'
                    Issue = "No external cache detected for session state"
                    Impact = 'Medium'
                    Details = "Deploy Redis Cache for session state to enable true stateless scaling"
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
            
            $autoscalePercentage = if ($totalScalableResources -gt 0) {
                [Math]::Round(($resourcesWithAutoscale / $totalScalableResources) * 100, 1)
            } else { 0 }
            
            # Build evidence
            $evidence = @"
Scaling and Partitioning Assessment:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OVERALL SCORE: $([Math]::Round($totalScore, 1)) / $maxTotalScore points ($overallPercentage%)
AUTOSCALING COVERAGE: $resourcesWithAutoscale / $totalScalableResources resources ($autoscalePercentage%)

CATEGORY SCORES:
- Compute Scaling:    $([Math]::Round($scores.ComputeScaling.Current, 1)) / $($scores.ComputeScaling.Max) points
- Autoscaling:        $([Math]::Round($scores.Autoscaling.Current, 1)) / $($scores.Autoscaling.Max) points
- Data Partitioning:  $([Math]::Round($scores.DataPartitioning.Current, 1)) / $($scores.DataPartitioning.Max) points
- Decoupling:         $([Math]::Round($scores.Decoupling.Current, 1)) / $($scores.Decoupling.Max) points
- Statelessness:      $([Math]::Round($scores.Statelessness.Current, 1)) / $($scores.Statelessness.Max) points

STRENGTHS:
$($scalingStrengths | ForEach-Object { "$_" } | Out-String)

GAPS IDENTIFIED: $($scalingGaps.Count) issues
$(if ($scalingGaps.Count -gt 0) {
    $scalingGaps | ForEach-Object { 
        "[$($_.Impact)] $($_.Category) - $($_.Resource): $($_.Issue)"
    } | Out-String
} else {
    "No scaling gaps identified"
})
"@
            
            # Determine status
            if ($overallPercentage -ge 80 -and $autoscalePercentage -ge 70) {
                return New-WafResult -CheckId 'RE06' `
                    -Status 'Pass' `
                    -Message "Strong scaling and partitioning design: $overallPercentage% score, $autoscalePercentage% autoscale coverage" `
                    -Metadata @{
                        OverallScore = $totalScore
                        MaxScore = $maxTotalScore
                        ScorePercentage = $overallPercentage
                        AutoscalePercentage = $autoscalePercentage
                        ScalableResources = $totalScalableResources
                        ResourcesWithAutoscale = $resourcesWithAutoscale
                        GapsCount = $scalingGaps.Count
                    }
                    
            } elseif ($overallPercentage -ge 50 -or $autoscalePercentage -ge 40) {
                
                return New-WafResult -CheckId 'RE06' `
                    -Status 'Warning' `
                    -Message "Partial scaling implementation with $($scalingGaps.Count) gap(s): $overallPercentage% score, $autoscalePercentage% autoscale coverage" `
                    -Recommendation @"
Improve your scaling and partitioning strategy:

$evidence

## REMEDIATION GUIDANCE:

### 1. IMPLEMENT AUTOSCALING ($([Math]::Round($scores.Autoscaling.Current, 1))/$($scores.Autoscaling.Max))

$(if (($scalingGaps | Where-Object Category -eq 'Compute Scaling').Count -gt 0) {@"
**Issues Found:**
$(($scalingGaps | Where-Object Category -eq 'Compute Scaling' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### VM Scale Sets - Enable Autoscaling:
``````powershell
# Create autoscale profile for VMSS
`$scaleSetId = '/subscriptions/.../virtualMachineScaleSets/vmss-web'

# Scale-out rule: Add instance when CPU > 70%
`$scaleOutRule = New-AzAutoscaleRule ``
    -MetricName 'Percentage CPU' ``
    -MetricResourceId `$scaleSetId ``
    -Operator GreaterThan ``
    -MetricStatistic Average ``
    -Threshold 70 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:05:00 ``
    -ScaleActionCooldown 00:05:00 ``
    -ScaleActionDirection Increase ``
    -ScaleActionValue 1

# Scale-in rule: Remove instance when CPU < 30%
`$scaleInRule = New-AzAutoscaleRule ``
    -MetricName 'Percentage CPU' ``
    -MetricResourceId `$scaleSetId ``
    -Operator LessThan ``
    -MetricStatistic Average ``
    -Threshold 30 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:10:00 ``
    -ScaleActionCooldown 00:10:00 ``
    -ScaleActionDirection Decrease ``
    -ScaleActionValue 1

# Create autoscale profile
`$profile = New-AzAutoscaleProfile ``
    -DefaultCapacity 2 ``
    -MaximumCapacity 10 ``
    -MinimumCapacity 2 ``
    -Rule `$scaleOutRule, `$scaleInRule ``
    -Name 'Auto-scale profile'

# Apply autoscale setting
Add-AzAutoscaleSetting ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'autoscale-vmss-web' ``
    -Location 'eastus' ``
    -TargetResourceId `$scaleSetId ``
    -AutoscaleProfile `$profile
``````

#### App Service Plans - Configure Autoscaling:
``````powershell
`$planId = '/subscriptions/.../serverfarms/plan-prod'

# CPU-based scaling
`$cpuRule = New-AzAutoscaleRule ``
    -MetricName 'CpuPercentage' ``
    -MetricResourceId `$planId ``
    -Operator GreaterThan ``
    -MetricStatistic Average ``
    -Threshold 75 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:05:00 ``
    -ScaleActionCooldown 00:05:00 ``
    -ScaleActionDirection Increase ``
    -ScaleActionValue 1

# Memory-based scaling
`$memoryRule = New-AzAutoscaleRule ``
    -MetricName 'MemoryPercentage' ``
    -MetricResourceId `$planId ``
    -Operator GreaterThan ``
    -MetricStatistic Average ``
    -Threshold 80 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:05:00 ``
    -ScaleActionCooldown 00:05:00 ``
    -ScaleActionDirection Increase ``
    -ScaleActionValue 1

# HTTP queue length scaling (responsive to load)
`$httpQueueRule = New-AzAutoscaleRule ``
    -MetricName 'HttpQueueLength' ``
    -MetricResourceId `$planId ``
    -Operator GreaterThan ``
    -MetricStatistic Average ``
    -Threshold 100 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:05:00 ``
    -ScaleActionCooldown 00:05:00 ``
    -ScaleActionDirection Increase ``
    -ScaleActionValue 2

# Scale-in rule
`$scaleInRule = New-AzAutoscaleRule ``
    -MetricName 'CpuPercentage' ``
    -MetricResourceId `$planId ``
    -Operator LessThan ``
    -MetricStatistic Average ``
    -Threshold 40 ``
    -TimeGrain 00:01:00 ``
    -TimeWindow 00:10:00 ``
    -ScaleActionCooldown 00:10:00 ``
    -ScaleActionDirection Decrease ``
    -ScaleActionValue 1

`$profile = New-AzAutoscaleProfile ``
    -DefaultCapacity 2 ``
    -MaximumCapacity 10 ``
    -MinimumCapacity 2 ``
    -Rule `$cpuRule, `$memoryRule, `$httpQueueRule, `$scaleInRule ``
    -Name 'Responsive-scaling'

Add-AzAutoscaleSetting ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'autoscale-plan-prod' ``
    -Location 'eastus' ``
    -TargetResourceId `$planId ``
    -AutoscaleProfile `$profile
``````

#### AKS Cluster - Enable Cluster Autoscaler:
``````powershell
# Enable autoscaler on node pool
`$cluster = Get-AzAksCluster -ResourceGroupName 'rg-prod' -Name 'aks-prod'

# Update node pool with autoscaling
Update-AzAksNodePool ``
    -ResourceGroupName 'rg-prod' ``
    -ClusterName 'aks-prod' ``
    -Name 'nodepool1' ``
    -EnableAutoScaling ``
    -MinCount 2 ``
    -MaxCount 10

# Or via Azure CLI for more control
az aks nodepool update ``
    --resource-group rg-prod ``
    --cluster-name aks-prod ``
    --name nodepool1 ``
    --enable-cluster-autoscaler ``
    --min-count 2 ``
    --max-count 10

# For multiple node pools (system + user workloads)
az aks nodepool add ``
    --resource-group rg-prod ``
    --cluster-name aks-prod ``
    --name userpool ``
    --node-count 2 ``
    --enable-cluster-autoscaler ``
    --min-count 2 ``
    --max-count 20 ``
    --node-vm-size Standard_D4s_v3
``````
"@} else {"✓ No compute scaling issues"})

### 2. IMPLEMENT DATA PARTITIONING ($([Math]::Round($scores.DataPartitioning.Current, 1))/$($scores.DataPartitioning.Max))

$(if (($scalingGaps | Where-Object Category -eq 'Data Partitioning').Count -gt 0) {@"
**Issues Found:**
$(($scalingGaps | Where-Object Category -eq 'Data Partitioning' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Cosmos DB - Optimal Partitioning:
``````powershell
# Choose effective partition key during container creation
# Good partition key characteristics:
# - High cardinality (many distinct values)
# - Even distribution of requests
# - Even distribution of storage

# Example: Multi-tenant app partitioned by tenantId
`$cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName 'rg-prod' -Name 'cosmos-prod'

New-AzCosmosDBSqlContainer ``
    -ResourceGroupName 'rg-prod' ``
    -AccountName 'cosmos-prod' ``
    -DatabaseName 'ProductionDB' ``
    -Name 'Orders' ``
    -PartitionKeyPath '/tenantId' ``
    -PartitionKeyKind Hash ``
    -Throughput 10000
``````

**Partition Key Selection Guide:**
| Scenario | Good Partition Key | Why |
|----------|-------------------|-----|
| Multi-tenant | `/tenantId` | Isolates tenant data, even distribution |
| E-commerce | `/userId` | Distributes user activity evenly |
| IoT/Telemetry | `/deviceId` | Balances device load |
| Time-series | `/date-deviceId` (composite) | Prevents hot partitions on recent dates |

#### SQL Database - Implement Sharding:
``````powershell
# Option 1: Elastic Database Pools
# Group databases for efficient resource sharing
New-AzSqlElasticPool ``
    -ResourceGroupName 'rg-prod' ``
    -ServerName 'sql-prod' ``
    -ElasticPoolName 'pool-tenants' ``
    -Edition 'Standard' ``
    -Dtu 400 ``
    -DatabaseDtuMin 0 ``
    -DatabaseDtuMax 100

# Move databases into pool
Set-AzSqlDatabase ``
    -ResourceGroupName 'rg-prod' ``
    -ServerName 'sql-prod' ``
    -DatabaseName 'TenantDB1' ``
    -ElasticPoolName 'pool-tenants'

# Option 2: Horizontal Partitioning (Sharding)
# Use Elastic Database Tools for multi-database queries
# Install-Package Microsoft.Azure.SqlDatabase.ElasticScale.Client

# Create shard map manager database
New-AzSqlDatabase ``
    -ResourceGroupName 'rg-prod' ``
    -ServerName 'sql-prod' ``
    -DatabaseName 'ShardMapManager' ``
    -Edition 'Standard' ``
    -RequestedServiceObjectiveName 'S1'

# Application code to create shard map
# using Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement;
# 
# ShardMapManager smm = ShardMapManagerFactory.CreateSqlShardMapManager(
#     connString, ShardMapManagerCreateMode.ReplaceExisting);
# 
# ListShardMap<int> shardMap = smm.CreateListShardMap<int>("CustomerShardMap");
``````

**Sharding Strategies:**
1. **Range-based**: Partition by ID ranges (1-10000, 10001-20000)
2. **List-based**: Partition by discrete values (RegionEast, RegionWest)
3. **Hash-based**: Partition by hash of key (even distribution)
4. **Composite**: Combine strategies for complex scenarios

#### Redis Cache - Enable Clustering:
``````powershell
# Premium tier required for clustering
New-AzRedisCache ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'redis-prod-clustered' ``
    -Location 'eastus' ``
    -Sku Premium ``
    -Size P1 ``
    -ShardCount 3

# Configure clients to use cluster mode
# Application configuration:
# StackExchange.Redis supports cluster mode automatically
# var connection = ConnectionMultiplexer.Connect("redis-prod-clustered.redis.cache.windows.net:6380,ssl=true,abortConnect=false");
``````
"@} else {"✓ No data partitioning issues"})

### 3. IMPLEMENT DECOUPLING ($([Math]::Round($scores.Decoupling.Current, 1))/$($scores.Decoupling.Max))

$(if (($scalingGaps | Where-Object Category -eq 'Decoupling').Count -gt 0) {@"
**Issues Found:**
$(($scalingGaps | Where-Object Category -eq 'Decoupling' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Service Bus - Async Message Processing:
``````powershell
# Create Service Bus namespace
New-AzServiceBusNamespace ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'sb-prod' ``
    -Location 'eastus' ``
    -SkuName Standard

# Create queues for different workload types
New-AzServiceBusQueue ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod' ``
    -Name 'orders' ``
    -MaxDeliveryCount 10 ``
    -LockDuration (New-TimeSpan -Minutes 5) ``
    -EnablePartitioning

New-AzServiceBusQueue ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod' ``
    -Name 'notifications' ``
    -MaxDeliveryCount 5 ``
    -EnableDeadLetteringOnMessageExpiration

# Create topic for pub-sub pattern
New-AzServiceBusTopic ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod' ``
    -Name 'events' ``
    -EnablePartitioning

# Create subscriptions
New-AzServiceBusSubscription ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod' ``
    -TopicName 'events' ``
    -Name 'audit-service' ``
    -MaxDeliveryCount 10

New-AzServiceBusSubscription ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod' ``
    -TopicName 'events' ``
    -Name 'analytics-service' ``
    -MaxDeliveryCount 10
``````

#### Storage Queues - Lightweight Async:
``````powershell
# Storage queues are simple and cost-effective for basic scenarios
`$storageAccount = Get-AzStorageAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'stprodqueue'

`$ctx = `$storageAccount.Context

# Queues created via SDK or REST API
# Azure CLI:
az storage queue create ``
    --name processing-queue ``
    --account-name stprodqueue

# Scale consumers independently based on queue length
# Use autoscale rules triggered by queue length metric
``````

#### Event Grid - Event-Driven Architecture:
``````powershell
# Create Event Grid topic
New-AzEventGridTopic ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'events-prod' ``
    -Location 'eastus'

# Subscribe to events
`$endpoint = 'https://function-processor.azurewebsites.net/api/ProcessEvent'

New-AzEventGridSubscription ``
    -ResourceGroupName 'rg-prod' ``
    -TopicName 'events-prod' ``
    -EventSubscriptionName 'processor-subscription' ``
    -Endpoint `$endpoint ``
    -EndpointType webhook ``
    -IncludedEventType 'OrderCreated','OrderUpdated'

# Subscribe Azure resources directly
`$resourceId = '/subscriptions/.../storageAccounts/stprod'
New-AzEventGridSubscription ``
    -ResourceId `$resourceId ``
    -EventSubscriptionName 'blob-created' ``
    -Endpoint `$endpoint ``
    -EndpointType webhook
``````

**Decoupling Patterns:**

| Pattern | Use Case | Azure Service |
|---------|----------|---------------|
| Queue-based Load Leveling | Smooth traffic spikes | Service Bus Queue, Storage Queue |
| Publisher-Subscriber | Multi-consumer events | Service Bus Topic, Event Grid |
| Event-driven | React to state changes | Event Grid, Event Hub |
| Claim-Check | Large message handling | Blob + Queue reference |
| Competing Consumers | Parallel processing | Service Bus Queue with multiple receivers |
"@} else {"✓ No decoupling issues"})

### 4. DESIGN FOR STATELESSNESS ($([Math]::Round($scores.Statelessness.Current, 1))/$($scores.Statelessness.Max))

$(if (($scalingGaps | Where-Object Category -eq 'Statelessness').Count -gt 0) {@"
**Issues Found:**
$(($scalingGaps | Where-Object Category -eq 'Statelessness' | ForEach-Object { "• [$($_.Impact)] $($_.Resource): $($_.Issue)" }) -join "`n")

**Actions Required:**

#### Redis Cache - Externalize Session State:
``````powershell
# Deploy Redis Cache for session management
New-AzRedisCache ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'redis-sessions' ``
    -Location 'eastus' ``
    -Sku Standard ``
    -Size C1

# Configure ASP.NET Core to use Redis
# In Startup.cs or Program.cs:
# services.AddStackExchangeRedisCache(options => {
#     options.Configuration = "redis-sessions.redis.cache.windows.net:6380,ssl=true,password=...";
#     options.InstanceName = "Session_";
# });
# services.AddSession(options => {
#     options.IdleTimeout = TimeSpan.FromMinutes(30);
#     options.Cookie.HttpOnly = true;
#     options.Cookie.IsEssential = true;
# });
``````

#### Cosmos DB - Distributed State Store:
``````powershell
# Use Cosmos DB for application state
New-AzCosmosDBAccount ``
    -ResourceGroupName 'rg-prod' ``
    -Name 'cosmos-state' ``
    -Location 'eastus' ``
    -ApiKind 'Sql' ``
    -EnableAutomaticFailover

# Create database and container for sessions
New-AzCosmosDBSqlDatabase ``
    -ResourceGroupName 'rg-prod' ``
    -AccountName 'cosmos-state' ``
    -Name 'StateStore'

New-AzCosmosDBSqlContainer ``
    -ResourceGroupName 'rg-prod' ``
    -AccountName 'cosmos-state' ``
    -DatabaseName 'StateStore' ``
    -Name 'Sessions' ``
    -PartitionKeyPath '/userId' ``
    -ThroughputType Autoscale ``
    -AutoscaleMaxThroughput 4000 ``
    -DefaultTimeToLive 3600  # Auto-expire old sessions
``````

**Stateless Design Principles:**

1. **Externalize Session State**
   - Move session data to Redis, Cosmos DB, or SQL
   - Enable any instance to serve any request
   
2. **Use Distributed Cache**
   - Cache frequently accessed data in Redis
   - Reduce database load
   
3. **Implement Idempotency**
   - Make operations safe to retry
   - Use unique identifiers for deduplication
   
4. **Avoid Instance Affinity**
   - Don't use sticky sessions in load balancers
   - Allow free load distribution
   
5. **Health Probes**
   - Implement /health endpoints
   - Enable load balancer to route around unhealthy instances
"@} else {"✓ No statelessness issues"})

## BEST PRACTICES:

### Autoscaling Configuration:
1. **Start Conservative**: Begin with 2-3 instances minimum
2. **Set Realistic Limits**: Max capacity should handle 2-3x peak load
3. **Multiple Metrics**: Scale on CPU, memory, AND request count
4. **Cooldown Periods**: Prevent rapid scaling oscillation (5-10 minutes)
5. **Test Under Load**: Validate scaling behavior before production

### Partitioning Strategy:
1. **Choose Partition Key Carefully**: High cardinality, even distribution
2. **Avoid Hot Partitions**: Don't partition by timestamp alone
3. **Plan for Growth**: Design supports 10x current scale
4. **Cross-Partition Queries**: Minimize or optimize them
5. **Monitor Partition Metrics**: Watch for imbalanced partitions

### Decoupling Benefits:
- ✅ Independent scaling of components
- ✅ Resilience to component failures
- ✅ Simplified deployments (deploy one service at a time)
- ✅ Cost efficiency (scale only what needs scaling)

## IMPLEMENTATION PRIORITY:

**Week 1**: Autoscaling
- Enable autoscale on all VMSS and App Service Plans
- Set conservative min/max values
- Monitor for 1 week

**Week 2**: Decoupling
- Deploy Service Bus for async operations
- Refactor long-running operations to queues
- Scale consumers independently

**Week 3**: Data Strategy
- Review Cosmos DB partition keys
- Plan SQL sharding if needed
- Enable Redis clustering for cache tier

**Week 4**: Statelessness
- Deploy Redis for session state
- Update application configuration
- Remove sticky sessions from load balancers
- Test instance replacement

## SUCCESS METRICS:
- ✓ 80%+ of compute resources have autoscaling
- ✓ Response time remains stable under 2x load
- ✓ Any instance can be removed without user impact
- ✓ Queue depths remain manageable during peak
- ✓ Database performance linear with instance count

Current State:
$evidence
"@ `
                    -RemediationScript @"
# Scaling Quick Setup Script
# Enables autoscaling on eligible resources

Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host "SCALING QUICK SETUP" -ForegroundColor Yellow
Write-Host "═" * 70 -ForegroundColor Yellow
Write-Host ""

`$fixed = 0
`$failed = 0

# 1. Enable autoscaling on VMSS
Write-Host "[1/3] Configuring VMSS autoscaling..." -ForegroundColor Cyan
`$vmssResources = Get-AzVmss

foreach (`$vmss in `$vmssResources | Select-Object -First 5) {
    Write-Host "  Processing: `$(`$vmss.Name)..." -ForegroundColor Yellow
    
    # Check if already has autoscale
    `$existing = Get-AzAutoscaleSetting | Where-Object { 
        `$_.TargetResourceUri -eq `$vmss.Id 
    }
    
    if (`$existing) {
        Write-Host "    ℹ Already has autoscaling" -ForegroundColor Gray
        continue
    }
    
    try {
        # Scale-out rule
        `$scaleOut = New-AzAutoscaleRule ``
            -MetricName 'Percentage CPU' ``
            -MetricResourceId `$vmss.Id ``
            -Operator GreaterThan ``
            -MetricStatistic Average ``
            -Threshold 70 ``
            -TimeGrain 00:01:00 ``
            -TimeWindow 00:05:00 ``
            -ScaleActionCooldown 00:05:00 ``
            -ScaleActionDirection Increase ``
            -ScaleActionValue 1
        
        # Scale-in rule
        `$scaleIn = New-AzAutoscaleRule ``
            -MetricName 'Percentage CPU' ``
            -MetricResourceId `$vmss.Id ``
            -Operator LessThan ``
            -MetricStatistic Average ``
            -Threshold 30 ``
            -TimeGrain 00:01:00 ``
            -TimeWindow 00:10:00 ``
            -ScaleActionCooldown 00:10:00 ``
            -ScaleActionDirection Decrease ``
            -ScaleActionValue 1
        
        `$profile = New-AzAutoscaleProfile ``
            -DefaultCapacity 2 ``
            -MaximumCapacity 10 ``
            -MinimumCapacity 2 ``
            -Rule `$scaleOut, `$scaleIn ``
            -Name 'Auto-created profile'
        
        Add-AzAutoscaleSetting ``
            -ResourceGroupName `$vmss.ResourceGroupName ``
            -Name "autoscale-`$(`$vmss.Name)" ``
            -Location `$vmss.Location ``
            -TargetResourceId `$vmss.Id ``
            -AutoscaleProfile `$profile
        
        Write-Host "    ✓ Enabled autoscaling" -ForegroundColor Green
        `$fixed++
    } catch {
        Write-Host "    ✗ Failed: `$_" -ForegroundColor Red
        `$failed++
    }
}

# 2. Enable autoscaling on App Service Plans
Write-Host "`n[2/3] Configuring App Service Plan autoscaling..." -ForegroundColor Cyan
`$plans = Get-AzAppServicePlan | Where-Object { 
    `$_.Sku.Tier -match 'Standard|Premium'
}

foreach (`$plan in `$plans | Select-Object -First 5) {
    Write-Host "  Processing: `$(`$plan.Name)..." -ForegroundColor Yellow
    
    `$existing = Get-AzAutoscaleSetting | Where-Object { 
        `$_.TargetResourceUri -eq `$plan.Id 
    }
    
    if (`$existing) {
        Write-Host "    ℹ Already has autoscaling" -ForegroundColor Gray
        continue
    }
    
    try {
        `$cpuRule = New-AzAutoscaleRule ``
            -MetricName 'CpuPercentage' ``
            -MetricResourceId `$plan.Id ``
            -Operator GreaterThan ``
            -MetricStatistic Average ``
            -Threshold 75 ``
            -TimeGrain 00:01:00 ``
            -TimeWindow 00:05:00 ``
            -ScaleActionCooldown 00:05:00 ``
            -ScaleActionDirection Increase ``
            -ScaleActionValue 1
        
        `$scaleIn = New-AzAutoscaleRule ``
            -MetricName 'CpuPercentage' ``
            -MetricResourceId `$plan.Id ``
            -Operator LessThan ``
            -MetricStatistic Average ``
            -Threshold 40 ``
            -TimeGrain 00:01:00 ``
            -TimeWindow 00:10:00 ``
            -ScaleActionCooldown 00:10:00 ``
            -ScaleActionDirection Decrease ``
            -ScaleActionValue 1
        
        `$profile = New-AzAutoscaleProfile ``
            -DefaultCapacity 2 ``
            -MaximumCapacity 10 ``
            -MinimumCapacity 2 ``
            -Rule `$cpuRule, `$scaleIn ``
            -Name 'Auto-created profile'
        
        Add-AzAutoscaleSetting ``
            -ResourceGroupName `$plan.ResourceGroupName ``
            -Name "autoscale-`$(`$plan.Name)" ``
            -Location `$plan.Location ``
            -TargetResourceId `$plan.Id ``
            -AutoscaleProfile `$profile
        
        Write-Host "    ✓ Enabled autoscaling" -ForegroundColor Green
        `$fixed++
    } catch {
        Write-Host "    ✗ Failed: `$_" -ForegroundColor Red
        `$failed++
    }
}

# 3. Report on decoupling needs
Write-Host "`n[3/3] Checking for messaging infrastructure..." -ForegroundColor Cyan
`$serviceBus = Get-AzServiceBusNamespace -ErrorAction SilentlyContinue
`$storageAccounts = Get-AzStorageAccount -ErrorAction SilentlyContinue

if (`$serviceBus.Count -eq 0) {
    Write-Host "  ⚠ No Service Bus namespaces found" -ForegroundColor Yellow
    Write-Host "    Consider deploying Service Bus for async processing" -ForegroundColor Gray
} else {
    Write-Host "  ✓ Found `$(`$serviceBus.Count) Service Bus namespace(s)" -ForegroundColor Green
}

if (`$storageAccounts.Count -eq 0) {
    Write-Host "  ⚠ No Storage Accounts found" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Found `$(`$storageAccounts.Count) Storage Account(s) (can support queues)" -ForegroundColor Green
}

# Summary
Write-Host "`n"
Write-Host "═" * 70 -ForegroundColor Green
Write-Host "SETUP COMPLETE" -ForegroundColor Green
Write-Host "═" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "Autoscaling configured:" -ForegroundColor White
Write-Host "  ✓ Successfully enabled: `$fixed resources" -ForegroundColor Green
Write-Host "  ✗ Failed: `$failed resources" -ForegroundColor Red
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Monitor autoscale behavior for 1 week" -ForegroundColor Gray
Write-Host "  2. Adjust min/max/thresholds based on actual usage" -ForegroundColor Gray
Write-Host "  3. Deploy Service Bus for async processing" -ForegroundColor Gray
Write-Host "  4. Externalize session state to Redis" -ForegroundColor Gray
Write-Host "  5. Review database partitioning strategy" -ForegroundColor Gray
"@
                    
            } else {
                
                return New-WafResult -CheckId 'RE06' `
                    -Status 'Fail' `
                    -Message "CRITICAL: Insufficient scaling capabilities - $($scalingGaps.Count) issues identified ($overallPercentage% score, $autoscalePercentage% autoscale coverage)" `
                    -Recommendation @"
**IMMEDIATE ACTION REQUIRED**: Your workload lacks proper scaling capabilities.

Current Score: $overallPercentage% (CRITICAL)
Autoscaling Coverage: $autoscalePercentage%

$evidence

## Why This Is Critical:

Without proper scaling design:
- ❌ Cannot handle traffic spikes (capacity fixed)
- ❌ Manual intervention required during growth
- ❌ Poor resource utilization (over/under provisioned)
- ❌ Increased downtime during scaling events
- ❌ Higher operational costs
- ❌ Longer time to market for new features

## IMMEDIATE ACTIONS (Next 48 Hours):

### 1. Enable Autoscaling NOW

**App Service Plans** (Fastest to implement):
``````powershell
# Get all Standard+ tier plans
Get-AzAppServicePlan | Where-Object { `$_.Sku.Tier -match 'Standard|Premium' } | ForEach-Object {
    Write-Host "Enabling autoscale on `$(`$_.Name)..."
    
    `$rule = New-AzAutoscaleRule ``
        -MetricName 'CpuPercentage' ``
        -MetricResourceId `$_.Id ``
        -Operator GreaterThan ``
        -MetricStatistic Average ``
        -Threshold 75 ``
        -TimeGrain 00:01:00 ``
        -ScaleActionCooldown 00:05:00 ``
        -ScaleActionDirection Increase ``
        -ScaleActionValue 1
    
    `$profile = New-AzAutoscaleProfile ``
        -DefaultCapacity 2 ``
        -MaximumCapacity 10 ``
        -MinimumCapacity 2 ``
        -Rule `$rule ``
        -Name 'Emergency autoscale'
    
    Add-AzAutoscaleSetting ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -Name "autoscale-`$(`$_.Name)" ``
        -Location `$_.Location ``
        -TargetResourceId `$_.Id ``
        -AutoscaleProfile `$profile
}
``````

### 2. Deploy Messaging Infrastructure

**Service Bus** (Enable async processing):
``````powershell
# Quick Service Bus deployment
New-AzServiceBusNamespace ``
    -ResourceGroupName 'rg-prod' ``
    -Name "sb-prod-`$(Get-Random -Max 9999)" ``
    -Location 'eastus' ``
    -SkuName Standard

# Create processing queue
New-AzServiceBusQueue ``
    -ResourceGroupName 'rg-prod' ``
    -NamespaceName 'sb-prod-*' ``
    -Name 'processing' ``
    -EnablePartitioning
``````

### 3. Document Current Bottlenecks

Identify which components cannot scale:
``````powershell
# Check for single-instance resources
`$singleInstance = @()

# VMs not in VMSS
`$vms = Get-AzVM
foreach (`$vm in `$vms) {
    `$vmDetail = Get-AzVM -ResourceGroupName `$vm.ResourceGroupName -Name `$vm.Name -Status
    if (-not `$vmDetail.Zones -and -not `$vm.AvailabilitySetReference) {
        `$singleInstance += "VM: `$(`$vm.Name)"
    }
}

# App Service Plans with 1 instance
`$plans = Get-AzAppServicePlan | Where-Object { `$_.Sku.Capacity -lt 2 }
foreach (`$plan in `$plans) {
    `$singleInstance += "App Service Plan: `$(`$plan.Name)"
}

# Output bottlenecks
`$singleInstance | Out-File 'scaling-bottlenecks.txt'
Write-Host "Bottlenecks documented in scaling-bottlenecks.txt"
``````

## WEEK 1-2: FOUNDATION

### Enable Horizontal Scaling:
1. **Migrate VMs to VMSS** (if applicable)
2. **Scale App Services to 2+ instances**
3. **Deploy Service Bus for decoupling**
4. **Enable autoscaling with conservative settings**

### Deploy Redis Cache:
``````powershell
New-AzRedisCache ``
    -ResourceGroupName 'rg-prod' ``
    -Name "redis-`$(Get-Random)" ``
    -Location 'eastus' ``
    -Sku Standard ``
    -Size C1
``````

## WEEK 3-4: OPTIMIZATION

### Refine Autoscaling:
- Add multiple metric triggers (CPU + Memory + Queue Length)
- Adjust thresholds based on 2 weeks of data
- Test scaling behavior under load

### Review Data Layer:
- Assess Cosmos DB partition keys
- Plan SQL sharding if needed
- Enable Redis clustering for high traffic

### Externalize State:
- Move session state to Redis
- Update application configuration
- Remove sticky sessions

## ARCHITECTURAL PATTERNS:

### Pattern 1: Queue-Based Load Leveling
``````
[Web App] → [Service Bus Queue] → [Worker VMSS]
         ↓
    [Redis Cache]
``````
**Benefits**: Workers scale independently, web tier stays responsive

### Pattern 2: Partitioned Data
``````
[App Instance 1] ─┐
[App Instance 2] ─┼→ [Cosmos DB: /tenantId] → Partitions 1-N
[App Instance N] ─┘
``````
**Benefits**: Linear scalability with tenant count

### Pattern 3: Stateless with External Cache
``````
[Load Balancer] → [Stateless App Instances] → [Redis Session Store]
                                             ↓
                                        [SQL Database]
``````
**Benefits**: Any instance can serve any request

## COST IMPACT:

Initial investment in scaling infrastructure:
- Service Bus: ~`$10/month (Standard tier)
- Redis Cache: ~`$15/month (C1 Standard)
- Autoscaling: No additional cost (pay for instances used)

**ROI**: Preventing a single outage due to capacity constraints typically pays for years of scaling infrastructure.

## TESTING REQUIREMENTS:

After implementing scaling:
1. **Load Test**: Verify autoscale triggers appropriately
2. **Stress Test**: Confirm max capacity handles peak + 50%
3. **Instance Failure**: Remove instances, verify no user impact
4. **Data Consistency**: Test cross-partition queries
5. **Performance**: Measure response time scaling linearly

## SUCCESS CRITERIA:

Within 30 days:
- ✓ 80%+ compute resources have autoscaling
- ✓ No single-instance production workloads
- ✓ Messaging infrastructure deployed
- ✓ Session state externalized
- ✓ Load testing completed
- ✓ Documented scaling procedures

Current Critical Issues:
$evidence

**START TODAY**: Every day without proper scaling is a risk to business continuity and growth.
"@ `
                    -RemediationScript @"
# EMERGENCY SCALING SETUP
# Enables basic autoscaling immediately

Write-Host "═" * 70 -ForegroundColor Red
Write-Host "EMERGENCY SCALING IMPLEMENTATION" -ForegroundColor Red
Write-Host "═" * 70 -ForegroundColor Red
Write-Host ""

`$fixed = 0
`$skipped = 0

# App Service Plans - Quickest win
Write-Host "Enabling autoscaling on App Service Plans..." -ForegroundColor Cyan
`$plans = Get-AzAppServicePlan | Where-Object { 
    `$_.Sku.Tier -match 'Standard|Premium' 
}

foreach (`$plan in `$plans) {
    `$existing = Get-AzAutoscaleSetting | Where-Object { 
        `$_.TargetResourceUri -eq `$plan.Id 
    }
    
    if (`$existing) {
        Write-Host "  ✓ `$(`$plan.Name) already has autoscaling" -ForegroundColor Green
        `$skipped++
        continue
    }
    
    try {
        `$rule = New-AzAutoscaleRule ``
            -MetricName 'CpuPercentage' ``
            -MetricResourceId `$plan.Id ``
            -Operator GreaterThan ``
            -MetricStatistic Average ``
            -Threshold 75 ``
            -TimeGrain 00:01:00 ``
            -TimeWindow 00:05:00 ``
            -ScaleActionCooldown 00:05:00 ``
            -ScaleActionDirection Increase ``
            -ScaleActionValue 1
        
        `$profile = New-AzAutoscaleProfile ``
            -DefaultCapacity 2 ``
            -MaximumCapacity 10 ``
            -MinimumCapacity 2 ``
            -Rule `$rule ``
            -Name 'Emergency-autoscale'
        
        Add-AzAutoscaleSetting ``
            -ResourceGroupName `$plan.ResourceGroupName ``
            -Name "emergency-autoscale-`$(`$plan.Name)" ``
            -Location `$plan.Location ``
            -TargetResourceId `$plan.Id ``
            -AutoscaleProfile `$profile
        
        Write-Host "  ✓ Enabled autoscaling: `$(`$plan.Name)" -ForegroundColor Green
        `$fixed++
    } catch {
        Write-Host "  ✗ Failed: `$(`$plan.Name) - `$_" -ForegroundColor Red
    }
}

Write-Host "`n"
Write-Host "═" * 70 -ForegroundColor Green
Write-Host "EMERGENCY SETUP COMPLETE" -ForegroundColor Green
Write-Host "═" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "Resources configured: `$fixed" -ForegroundColor Green
Write-Host "Resources already configured: `$skipped" -ForegroundColor Gray
Write-Host ""
Write-Host "CRITICAL NEXT STEPS:" -ForegroundColor Red
Write-Host "  1. Monitor autoscale behavior immediately" -ForegroundColor Yellow
Write-Host "  2. Deploy Service Bus for async processing" -ForegroundColor Yellow
Write-Host "  3. Review database scaling strategy" -ForegroundColor Yellow
Write-Host "  4. Plan load testing within 1 week" -ForegroundColor Yellow
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE06' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
