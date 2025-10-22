<#
.SYNOPSIS
    PE12 - Continuous performance optimization

.DESCRIPTION
    Continuously optimize performance by monitoring, analyzing, and adjusting resources. Use automation, regular reviews, and performance testing to maintain efficiency.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:12 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/continuous-performance-optimize
#>

Register-WafCheck -CheckId 'PE12' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Continuous performance optimization' `
    -Description 'Continuously optimize performance by monitoring, analyzing, and adjusting resources. Use automation, regular reviews, and performance testing to maintain efficiency.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'ContinuousOptimization', 'Monitoring', 'Automation', 'Reviews') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/continuous-performance-optimize' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess continuous optimization indicators
            
            # 1. Autoscaling for Adjustment
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize Autoscale = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].Autoscale } else { 0 }
            
            # 2. Monitoring Tools (App Insights, Log Analytics)
            $monitorQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components' or type =~ 'microsoft.operationalinsights/workspaces'
| summarize Monitors = count()
"@
            $monitorResult = Invoke-AzResourceGraphQuery -Query $monitorQuery -SubscriptionId $SubscriptionId -UseCache
            $monitorCount = if ($monitorResult.Count -gt 0) { $monitorResult[0].Monitors } else { 0 }
            
            # 3. Load Testing for Reviews
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| summarize LoadTests = count()
"@
            $loadTestResult = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $loadTestCount = if ($loadTestResult.Count -gt 0) { $loadTestResult[0].LoadTests } else { 0 }
            
            # 4. Performance Alerts
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'performance' or properties.criteria.metricName contains 'cpu' or properties.criteria.metricName contains 'memory'
| summarize PerfAlerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].PerfAlerts } else { 0 }
            
            # 5. Advisor Performance Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling for dynamic adjustment"
            }
            
            if ($monitorCount -eq 0) {
                $indicators += "No monitoring tools for analysis"
            }
            
            if ($loadTestCount -eq 0) {
                $indicators += "No load testing for reviews"
            }
            
            if ($alertCount -eq 0) {
                $indicators += "No performance alerts"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            $evidence = @"
Continuous Optimization Assessment:
- Autoscaling: $autoscaleCount
- Monitoring Tools: $monitorCount
- Load Tests: $loadTestCount
- Performance Alerts: $alertCount
- Performance Recommendations: $perfRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE12' `
                    -Status 'Pass' `
                    -Message 'Effective continuous performance optimization' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        Monitors = $monitorCount
                        LoadTests = $loadTestCount
                        Alerts = $alertCount
                        PerfRecs = $perfRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE12' `
                    -Status 'Fail' `
                    -Message "Continuous optimization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: No continuous optimization leads to degradation.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Enable Autoscaling**: For adjustment
2. **Deploy Monitoring**: Tools
3. **Set Performance Alerts**: For notifications

### Phase 2: Reviews (Weeks 2-3)
1. **Run Load Tests**: Regularly
2. **Address Recs**: For improvements
3. **Schedule Reviews**: For optimization

$evidence
"@ `
                    -RemediationScript @"
# Quick Continuous Optimization Setup

# Enable Autoscaling
New-AzAutoscaleSetting -Name 'pe-opt' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1)

# Deploy Monitoring
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'pe-mon' -Location 'eastus'

Write-Host "Basic continuous opt - schedule reviews"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE12' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
