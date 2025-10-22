<#
.SYNOPSIS
    PE01 - Define performance targets

.DESCRIPTION
    Define performance targets by establishing service level objectives (SLOs) for availability, throughput, latency, and scalability. Align targets with business requirements and use them to guide architectural decisions.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/performance-targets
#>

Register-WafCheck -CheckId 'PE01' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Define performance targets' `
    -Description 'Define performance targets by establishing service level objectives (SLOs) for availability, throughput, latency, and scalability. Align targets with business requirements and use them to guide architectural decisions.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'SLAs', 'SLOs', 'Targets', 'BusinessAlignment') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/performance-targets' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess performance targets indicators
            
            # 1. Azure Monitor Metrics and Alerts (for SLO monitoring)
            $metricAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'availability' or properties.criteria.metricName contains 'latency' or properties.criteria.metricName contains 'throughput'
| summarize MetricAlerts = count()
"@
            $metricAlertResult = Invoke-AzResourceGraphQuery -Query $metricAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $metricAlertCount = if ($metricAlertResult.Count -gt 0) { $metricAlertResult[0].MetricAlerts } else { 0 }
            
            # 2. Application Insights for Latency/Throughput
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 3. Load Testing Services
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| summarize LoadTests = count()
"@
            $loadTestResult = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $loadTestCount = if ($loadTestResult.Count -gt 0) { $loadTestResult[0].LoadTests } else { 0 }
            
            # 4. SLO Tags on Resources
            $sloTagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['slo']) or isnotempty(tags['SLO']) or isnotempty(tags['performanceTarget'])
| summarize SLOTagged = count()
"@
            $sloTagResult = Invoke-AzResourceGraphQuery -Query $sloTagQuery -SubscriptionId $SubscriptionId -UseCache
            $sloTagCount = if ($sloTagResult.Count -gt 0) { $sloTagResult[0].SLOTagged } else { 0 }
            
            # 5. Advisor Performance Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($metricAlertCount -eq 0) {
                $indicators += "No metric alerts for performance monitoring"
            }
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for detailed metrics"
            }
            
            if ($loadTestCount -eq 0) {
                $indicators += "No load testing services"
            }
            
            if ($sloTagCount -eq 0) {
                $indicators += "No resources tagged with SLO targets"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            $evidence = @"
Performance Targets Assessment:
- Metric Alerts: $metricAlertCount
- App Insights: $appInsightsCount
- Load Tests: $loadTestCount
- SLO Tagged Resources: $sloTagCount
- Performance Recommendations: $perfRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE01' `
                    -Status 'Pass' `
                    -Message 'Defined performance targets with monitoring' `
                    -Metadata @{
                        MetricAlerts = $metricAlertCount
                        AppInsights = $appInsightsCount
                        LoadTests = $loadTestCount
                        SLOTags = $sloTagCount
                        PerfRecs = $perfRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE01' `
                    -Status 'Fail' `
                    -Message "Performance targets gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Undefined targets lead to inefficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Monitoring Basics (Week 1)
1. **Set Metric Alerts**: For SLOs
2. **Deploy App Insights**: For metrics
3. **Run Load Tests**: For validation

### Phase 2: Alignment (Weeks 2-3)
1. **Tag SLOs**: On resources
2. **Address Recs**: For improvements
3. **Align with Business**: Review targets

$evidence
"@ `
                    -RemediationScript @"
# Quick Performance Targets Setup

# Create Metric Alert
New-AzMetricAlertRuleV2 -Name 'perf-alert' -ResourceGroupName 'rg' -WindowSize (New-TimeSpan -Minutes 5) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'Availability' -Operator LessThan -Threshold 99.9)

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'pe-target' -Location 'eastus'

Write-Host "Basic targets setup - define SLOs and tag"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE01' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
