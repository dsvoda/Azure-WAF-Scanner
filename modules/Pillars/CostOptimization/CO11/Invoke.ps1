<#
.SYNOPSIS
    CO11 - Optimize workload code costs

.DESCRIPTION
    Optimize code costs by improving efficiency, reducing execution time, and minimizing resource consumption. Use profiling, caching, and asynchronous patterns to enhance performance and lower expenses.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:11 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-code-costs
#>

Register-WafCheck -CheckId 'CO11' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize workload code costs' `
    -Description 'Optimize code costs by improving efficiency, reducing execution time, and minimizing resource consumption. Use profiling, caching, and asynchronous patterns to enhance performance and lower expenses.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'CodeEfficiency', 'Profiling', 'Caching', 'Asynchronous') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-code-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess code cost optimization indicators
            
            # 1. Application Insights for Profiling
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 2. Caching Services (Redis, CDN for efficiency)
            $cacheQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.cache/redis' or type =~ 'microsoft.cdn/profiles'
| summarize Caches = count()
"@
            $cacheResult = Invoke-AzResourceGraphQuery -Query $cacheQuery -SubscriptionId $SubscriptionId -UseCache
            $cacheCount = if ($cacheResult.Count -gt 0) { $cacheResult[0].Caches } else { 0 }
            
            # 3. Serverless/Functions (pay-per-execution)
            $serverlessQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites' and kind contains 'functionapp' and properties.sku contains 'Dynamic'
| summarize ServerlessFunctions = count()
"@
            $serverlessResult = Invoke-AzResourceGraphQuery -Query $serverlessQuery -SubscriptionId $SubscriptionId -UseCache
            $serverlessCount = if ($serverlessResult.Count -gt 0) { $serverlessResult[0].ServerlessFunctions } else { 0 }
            
            # 4. Advisor Performance Recs (indirect for code efficiency)
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # 5. Logic Apps/Async Patterns (as proxy)
            $logicQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.logic/workflows'
| summarize LogicApps = count()
"@
            $logicResult = Invoke-AzResourceGraphQuery -Query $logicQuery -SubscriptionId $SubscriptionId -UseCache
            $logicCount = if ($logicResult.Count -gt 0) { $logicResult[0].LogicApps } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for code profiling"
            }
            
            if ($cacheCount -eq 0) {
                $indicators += "No caching services for efficiency"
            }
            
            if ($serverlessCount -eq 0) {
                $indicators += "No serverless functions for pay-per-use"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            if ($logicCount -eq 0) {
                $indicators += "No Logic Apps for asynchronous patterns"
            }
            
            $evidence = @"
Code Cost Assessment:
- App Insights: $appInsightsCount
- Caching Services: $cacheCount
- Serverless Functions: $serverlessCount
- Performance Recs: $perfRecs
- Logic Apps: $logicCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO11' `
                    -Status 'Pass' `
                    -Message 'Optimized code costs with efficient patterns' `
                    -Metadata @{
                        AppInsights = $appInsightsCount
                        Caches = $cacheCount
                        Serverless = $serverlessCount
                        PerfRecs = $perfRecs
                        LogicApps = $logicCount
                    }
            } else {
                return New-WafResult -CheckId 'CO11' `
                    -Status 'Fail' `
                    -Message "Code cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inefficient code increases runtime costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Profiling & Caching (Week 1)
1. **Deploy App Insights**: For monitoring
2. **Add Caching**: Redis/CDN
3. **Use Serverless**: For functions

### Phase 2: Advanced Patterns (Weeks 2-3)
1. **Implement Async**: With Logic Apps
2. **Address Perf Recs**: Optimize code
3. **Profile & Refactor**: Reduce time

$evidence
"@ `
                    -RemediationScript @"
# Quick Code Optimization Setup

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'code-opt' -Location 'eastus'

# Create Redis Cache
New-AzRedisCache -ResourceGroupName 'rg' -Name 'cache' -Location 'eastus' -Sku Basic -Size C0

Write-Host "Basic code opt tools - profile and refactor code"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO11' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
