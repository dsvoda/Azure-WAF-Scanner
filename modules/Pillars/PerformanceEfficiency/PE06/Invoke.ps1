<#
.SYNOPSIS
    PE06 - Conduct performance testing

.DESCRIPTION
    Conduct performance testing to validate that the workload meets its performance targets under various load conditions. Use load testing, stress testing, and other methods to identify bottlenecks.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:06 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/performance-test
#>

Register-WafCheck -CheckId 'PE06' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Conduct performance testing' `
    -Description 'Conduct performance testing to validate that the workload meets its performance targets under various load conditions. Use load testing, stress testing, and other methods to identify bottlenecks.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'Testing', 'LoadTesting', 'StressTesting', 'Bottlenecks') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/performance-test' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess performance testing indicators
            
            # 1. Load Testing Services
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| summarize LoadTests = count()
"@
            $loadTestResult = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $loadTestCount = if ($loadTestResult.Count -gt 0) { $loadTestResult[0].LoadTests } else { 0 }
            
            # 2. Chaos Experiments for Stress
            $chaosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.chaos/experiments'
| summarize ChaosExperiments = count()
"@
            $chaosResult = Invoke-AzResourceGraphQuery -Query $chaosQuery -SubscriptionId $SubscriptionId -UseCache
            $chaosCount = if ($chaosResult.Count -gt 0) { $chaosResult[0].ChaosExperiments } else { 0 }
            
            # 3. Application Insights for Testing
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 4. Performance Alerts
            $perfAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'performance' or properties.criteria.metricName contains 'latency' or properties.criteria.metricName contains 'throughput'
| summarize PerfAlerts = count()
"@
            $perfAlertResult = Invoke-AzResourceGraphQuery -Query $perfAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $perfAlertCount = if ($perfAlertResult.Count -gt 0) { $perfAlertResult[0].PerfAlerts } else { 0 }
            
            # 5. Advisor Performance Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($loadTestCount -eq 0) {
                $indicators += "No load testing services"
            }
            
            if ($chaosCount -eq 0) {
                $indicators += "No chaos experiments for stress testing"
            }
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for performance analysis"
            }
            
            if ($perfAlertCount -eq 0) {
                $indicators += "No performance alerts"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            $evidence = @"
Performance Testing Assessment:
- Load Tests: $loadTestCount
- Chaos Experiments: $chaosCount
- App Insights: $appInsightsCount
- Performance Alerts: $perfAlertCount
- Performance Recommendations: $perfRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE06' `
                    -Status 'Pass' `
                    -Message 'Effective performance testing in place' `
                    -Metadata @{
                        LoadTests = $loadTestCount
                        Chaos = $chaosCount
                        AppInsights = $appInsightsCount
                        PerfAlerts = $perfAlertCount
                        PerfRecs = $perfRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE06' `
                    -Status 'Fail' `
                    -Message "Performance testing gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: No performance testing risks bottlenecks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Testing Basics (Week 1)
1. **Deploy Load Tests**: For validation
2. **Set Chaos Experiments**: For stress
3. **Enable App Insights**: For analysis

### Phase 2: Monitoring (Weeks 2-3)
1. **Create Perf Alerts**: For thresholds
2. **Address Recs**: For improvements
3. **Define Test Strategy**: Regular runs

$evidence
"@ `
                    -RemediationScript @"
# Quick Performance Testing Setup

# Create Load Test
New-AzLoadTest -Name 'pe-load' -ResourceGroupName 'rg' -Location 'eastus'

# Create Chaos Experiment
New-AzChaosExperiment -Name 'pe-chaos' -ResourceGroupName 'rg' -Location 'eastus' -DefinitionFile 'experiment.json'

Write-Host "Basic testing - run and analyze"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE06' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
