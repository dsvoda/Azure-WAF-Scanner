<#
.SYNOPSIS
    PE09 - Prioritize critical flows

.DESCRIPTION
    Prioritize critical flows by identifying key user and system paths, setting performance targets for them, and optimizing accordingly. Use monitoring to ensure critical flows meet SLOs.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:09 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/prioritize-critical-flows
#>

Register-WafCheck -CheckId 'PE09' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Prioritize critical flows' `
    -Description 'Prioritize critical flows by identifying key user and system paths, setting performance targets for them, and optimizing accordingly. Use monitoring to ensure critical flows meet SLOs.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'CriticalFlows', 'Prioritization', 'SLOs', 'Monitoring') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/prioritize-critical-flows' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess critical flows prioritization indicators
            
            # 1. Tagging for Critical Flows
            $criticalTagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['critical']) or isnotempty(tags['priority']) or isnotempty(tags['flow']) or isnotempty(tags['SLO'])
| summarize CriticalTagged = count()
"@
            $criticalTagResult = Invoke-AzResourceGraphQuery -Query $criticalTagQuery -SubscriptionId $SubscriptionId -UseCache
            $criticalTagged = if ($criticalTagResult.Count -gt 0) { $criticalTagResult[0].CriticalTagged } else { 0 }
            
            $totalResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize TotalResources = count()
"@
            $totalResult = Invoke-AzResourceGraphQuery -Query $totalResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            $totalCount = if ($totalResult.Count -gt 0) { $totalResult[0].TotalResources } else { 0 }
            
            $tagPercent = if ($totalCount -gt 0) { [Math]::Round(($criticalTagged / $totalCount) * 100, 1) } else { 0 }
            
            # 2. Application Insights for Flow Monitoring
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 3. Traffic Routing for Priority (Traffic Manager/App Gateway)
            $routingQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/trafficmanagerprofiles' or type =~ 'microsoft.network/applicationgateways'
| summarize RoutingTools = count()
"@
            $routingResult = Invoke-AzResourceGraphQuery -Query $routingQuery -SubscriptionId $SubscriptionId -UseCache
            $routingCount = if ($routingResult.Count -gt 0) { $routingResult[0].RoutingTools } else { 0 }
            
            # 4. SLO Alerts
            $sloAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.description contains 'SLO' or properties.description contains 'critical flow'
| summarize SLOAlerts = count()
"@
            $sloAlertResult = Invoke-AzResourceGraphQuery -Query $sloAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $sloAlertCount = if ($sloAlertResult.Count -gt 0) { $sloAlertResult[0].SLOAlerts } else { 0 }
            
            # 5. Advisor Performance Recs for Flows
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $flowRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'flow|path|latency|throughput' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($tagPercent -lt 50) {
                $indicators += "Low tagging for critical flows ($tagPercent%)"
            }
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for flow monitoring"
            }
            
            if ($routingCount -eq 0) {
                $indicators += "No routing tools for priority flows"
            }
            
            if ($sloAlertCount -eq 0) {
                $indicators += "No SLO alerts for critical flows"
            }
            
            if ($flowRecs -gt 0) {
                $indicators += "Unresolved flow performance recommendations ($flowRecs)"
            }
            
            $evidence = @"
Critical Flows Assessment:
- Tagged Resources: $criticalTagged / $totalCount ($tagPercent%)
- App Insights: $appInsightsCount
- Routing Tools: $routingCount
- SLO Alerts: $sloAlertCount
- Flow Recommendations: $flowRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE09' `
                    -Status 'Pass' `
                    -Message 'Prioritized critical flows with monitoring and optimization' `
                    -Metadata @{
                        TagPercent = $tagPercent
                        AppInsights = $appInsightsCount
                        Routing = $routingCount
                        SLOAlerts = $sloAlertCount
                        FlowRecs = $flowRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE09' `
                    -Status 'Fail' `
                    -Message "Critical flows prioritization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unprioritized flows risk performance issues.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Identification (Week 1)
1. **Tag Critical Flows**: Resources
2. **Deploy App Insights**: For tracing
3. **Set Routing**: For priority

### Phase 2: Monitoring (Weeks 2-3)
1. **Create SLO Alerts**: For thresholds
2. **Address Recs**: For improvements
3. **Map Flows**: Document paths

$evidence
"@ `
                    -RemediationScript @"
# Quick Critical Flows Setup

# Tag Resource
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Web/sites/app' -Tag @{'critical' = 'yes'; 'SLO' = '99.9'} -Operation Merge

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'pe-flow' -Location 'eastus'

Write-Host "Basic flows setup - define SLOs and monitor"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE09' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
