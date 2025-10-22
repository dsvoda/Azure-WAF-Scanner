<#
.SYNOPSIS
    PE05 - Architecture strategies for optimizing scaling and partitioning

.DESCRIPTION
    Optimize scaling and partitioning by incorporating reliable and controlled scaling and partitioning. The scale unit design of the workload serves as the basis for the scaling and partitioning strategy. Scaling adjusts resources based on demand to handle varying loads, while partitioning divides the workload into smaller units to distribute data and processing, improving performance efficiency and resource utilization in cloud environments.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:05 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/scale-partition
#>

Register-WafCheck -CheckId 'PE05' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Architecture strategies for optimizing scaling and partitioning' `
    -Description 'Optimize scaling and partitioning by incorporating reliable and controlled scaling and partitioning. The scale unit design of the workload serves as the basis for the scaling and partitioning strategy.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'Scaling', 'Partitioning', 'ScaleUnit', 'Autoscaling') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/scale-partition' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess scaling and partitioning indicators
            
            # 1. Autoscaling Settings
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize AutoscaleSettings = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].AutoscaleSettings } else { 0 }
            
            # 2. Partitioned Resources (e.g., Cosmos DB)
            $partitionQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.documentdb/databaseaccounts'
| extend 
    capabilities = properties.capabilities
| where capabilities contains 'EnablePartitioning' or properties.enableMultipleWriteLocations == true
| summarize PartitionedCosmos = count()
"@
            $partitionResult = Invoke-AzResourceGraphQuery -Query $partitionQuery -SubscriptionId $SubscriptionId -UseCache
            $partitionCount = if ($partitionResult.Count -gt 0) { $partitionResult[0].PartitionedCosmos } else { 0 }
            
            # 3. Load Balancers for Distribution
            $lbQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.network/loadbalancers', 'microsoft.network/applicationgateways')
| summarize LoadBalancers = count()
"@
            $lbResult = Invoke-AzResourceGraphQuery -Query $lbQuery -SubscriptionId $SubscriptionId -UseCache
            $lbCount = if ($lbResult.Count -gt 0) { $lbResult[0].LoadBalancers } else { 0 }
            
            # 4. Multi-Region Deployments (for geo-partitioning)
            $regionQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize UniqueRegions = dcount(location)
"@
            $regionResult = Invoke-AzResourceGraphQuery -Query $regionQuery -SubscriptionId $SubscriptionId -UseCache
            $uniqueRegions = if ($regionResult.Count -gt 0) { $regionResult[0].UniqueRegions } else { 0 }
            
            # 5. Advisor Scaling/Partitioning Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $scaleRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'scale|partition|load balance' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling configurations"
            }
            
            if ($partitionCount -eq 0) {
                $indicators += "No partitioned Cosmos DB instances"
            }
            
            if ($lbCount -eq 0) {
                $indicators += "No load balancers for distribution"
            }
            
            if ($uniqueRegions <= 1) {
                $indicators += "Single region deployment - no geo-partitioning"
            }
            
            if ($scaleRecs -gt 0) {
                $indicators += "Unresolved scaling/partitioning recommendations ($scaleRecs)"
            }
            
            $evidence = @"
Scaling & Partitioning Assessment:
- Autoscaling Settings: $autoscaleCount
- Partitioned Cosmos: $partitionCount
- Load Balancers: $lbCount
- Unique Regions: $uniqueRegions
- Scaling Recommendations: $scaleRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE05' `
                    -Status 'Pass' `
                    -Message 'Optimized scaling and partitioning strategies' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        Partitioned = $partitionCount
                        LoadBalancers = $lbCount
                        Regions = $uniqueRegions
                        ScaleRecs = $scaleRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE05' `
                    -Status 'Fail' `
                    -Message "Scaling/partitioning gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Poor scaling/partitioning affects performance.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Enable Autoscaling**: For resources
2. **Partition Data**: In DBs
3. **Add Load Balancers**: For distribution

### Phase 2: Advanced (Weeks 2-3)
1. **Go Multi-Region**: For geo
2. **Address Recs**: For improvements
3. **Test Strategies**: With load

$evidence
"@ `
                    -RemediationScript @"
# Quick Scaling Setup

# Enable Autoscaling
New-AzAutoscaleSetting -Name 'pe-scale' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1)

# Add Load Balancer
New-AzLoadBalancer -ResourceGroupName 'rg' -Name 'pe-lb' -Location 'eastus' -Sku 'Standard'

Write-Host "Basic scaling - partition DBs"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE05' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
