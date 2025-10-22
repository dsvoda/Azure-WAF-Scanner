<#
.SYNOPSIS
    PE07 - Architecture strategies for optimizing code and infrastructure

.DESCRIPTION
    Optimize code and infrastructure performance by instrumenting code, identifying hot paths, refining logic, managing memory, using concurrency, and streamlining infrastructure. Leverage Azure tools for analysis and optimization.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:07 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-code-infrastructure
#>

Register-WafCheck -CheckId 'PE07' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Architecture strategies for optimizing code and infrastructure' `
    -Description 'Optimize code and infrastructure performance by instrumenting code, identifying hot paths, refining logic, managing memory, using concurrency, and streamlining infrastructure. Leverage Azure tools for analysis and optimization.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'CodeOptimization', 'InfrastructureOptimization', 'HotPaths', 'Concurrency') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-code-infrastructure' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess optimization indicators
            
            # 1. Application Insights for Profiling
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 2. High Performance SKUs/Tiers
            $highPerfQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where sku.name contains 'Premium' or sku.name contains 'HighPerformance' or sku.tier == 'Premium'
| summarize HighPerfTiers = count()
"@
            $highPerfResult = Invoke-AzResourceGraphQuery -Query $highPerfQuery -SubscriptionId $SubscriptionId -UseCache
            $highPerfCount = if ($highPerfResult.Count -gt 0) { $highPerfResult[0].HighPerfTiers } else { 0 }
            
            # 3. Concurrency Indicators (Load Balancers, Queues)
            $concurrencyQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.network/loadbalancers', 'microsoft.servicebus/namespaces/queues', 'microsoft.storage/storageaccounts/queueservices/queues')
| summarize ConcurrencyTools = count()
"@
            $concurrencyResult = Invoke-AzResourceGraphQuery -Query $concurrencyQuery -SubscriptionId $SubscriptionId -UseCache
            $concurrencyCount = if ($concurrencyResult.Count -gt 0) { $concurrencyResult[0].ConcurrencyTools } else { 0 }
            
            # 4. Advisor Performance Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # 5. Multi-Region for Parallelism
            $regionQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize UniqueRegions = dcount(location)
"@
            $regionResult = Invoke-AzResourceGraphQuery -Query $regionQuery -SubscriptionId $SubscriptionId -UseCache
            $uniqueRegions = if ($regionResult.Count -gt 0) { $regionResult[0].UniqueRegions } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for profiling"
            }
            
            if ($highPerfCount -eq 0) {
                $indicators += "No high-performance tiers used"
            }
            
            if ($concurrencyCount -eq 0) {
                $indicators += "No tools for concurrency/parallelism"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            if ($uniqueRegions <= 1) {
                $indicators += "Single region - limited parallelism"
            }
            
            $evidence = @"
Code & Infra Optimization Assessment:
- App Insights: $appInsightsCount
- High Perf Tiers: $highPerfCount
- Concurrency Tools: $concurrencyCount
- Unique Regions: $uniqueRegions
- Performance Recommendations: $perfRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE07' `
                    -Status 'Pass' `
                    -Message 'Optimized code and infrastructure for performance' `
                    -Metadata @{
                        AppInsights = $appInsightsCount
                        HighPerf = $highPerfCount
                        Concurrency = $concurrencyCount
                        Regions = $uniqueRegions
                        PerfRecs = $perfRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE07' `
                    -Status 'Fail' `
                    -Message "Optimization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inefficient code/infra affects performance.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Profiling (Week 1)
1. **Deploy App Insights**: For hot paths
2. **Use High Perf Tiers**: Where needed
3. **Implement Concurrency**: Tools/patterns

### Phase 2: Advanced (Weeks 2-3)
1. **Go Multi-Region**: For parallelism
2. **Address Recs**: For improvements
3. **Optimize Logic**: Code reviews

$evidence
"@ `
                    -RemediationScript @"
# Quick Optimization Setup

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'pe-opt' -Location 'eastus'

# Use High Perf Storage
Update-AzStorageAccount -ResourceGroupName 'rg' -Name 'store' -SkuName 'Premium_LRS'

Write-Host "Basic optimization - profile and refactor"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE07' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
