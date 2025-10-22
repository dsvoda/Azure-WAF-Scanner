<#
.SYNOPSIS
    PE04 - Collect performance data

.DESCRIPTION
    Collect performance data to measure your workload's performance against targets. Use monitoring tools to gather metrics, logs, and traces for analysis and optimization.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:04 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/collect-performance-data
#>

Register-WafCheck -CheckId 'PE04' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Collect performance data' `
    -Description 'Collect performance data to measure your workload''s performance against targets. Use monitoring tools to gather metrics, logs, and traces for analysis and optimization.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'DataCollection', 'Monitoring', 'Metrics', 'Logs') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/collect-performance-data' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess performance data collection indicators
            
            # 1. Application Insights for Metrics/Tracing
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 2. Log Analytics Workspaces for Logs
            $logAnalyticsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationalinsights/workspaces'
| summarize LogAnalytics = count()
"@
            $logAnalyticsResult = Invoke-AzResourceGraphQuery -Query $logAnalyticsQuery -SubscriptionId $SubscriptionId -UseCache
            $logAnalyticsCount = if ($logAnalyticsResult.Count -gt 0) { $logAnalyticsResult[0].LogAnalytics } else { 0 }
            
            # 3. Diagnostic Settings Enabled
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| summarize DiagSettings = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagSettings } else { 0 }
            
            # 4. Performance Alerts
            $perfAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'performance' or properties.criteria.metricName contains 'cpu' or properties.criteria.metricName contains 'memory' or properties.criteria.metricName contains 'latency'
| summarize PerfAlerts = count()
"@
            $perfAlertResult = Invoke-AzResourceGraphQuery -Query $perfAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $perfAlertCount = if ($perfAlertResult.Count -gt 0) { $perfAlertResult[0].PerfAlerts } else { 0 }
            
            # 5. Dashboards for Analysis
            $dashboardQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.portal/dashboards'
| summarize Dashboards = count()
"@
            $dashboardResult = Invoke-AzResourceGraphQuery -Query $dashboardQuery -SubscriptionId $SubscriptionId -UseCache
            $dashboardCount = if ($dashboardResult.Count -gt 0) { $dashboardResult[0].Dashboards } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($appInsightsCount -eq 0) {
                $indicators += "No Application Insights for metrics/tracing"
            }
            
            if ($logAnalyticsCount -eq 0) {
                $indicators += "No Log Analytics for logs"
            }
            
            if ($diagCount -eq 0) {
                $indicators += "No diagnostic settings for collection"
            }
            
            if ($perfAlertCount -eq 0) {
                $indicators += "No performance alerts"
            }
            
            if ($dashboardCount -eq 0) {
                $indicators += "No dashboards for analysis"
            }
            
            $evidence = @"
Performance Data Assessment:
- App Insights: $appInsightsCount
- Log Analytics: $logAnalyticsCount
- Diagnostic Settings: $diagCount
- Performance Alerts: $perfAlertCount
- Dashboards: $dashboardCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE04' `
                    -Status 'Pass' `
                    -Message 'Effective performance data collection' `
                    -Metadata @{
                        AppInsights = $appInsightsCount
                        LogAnalytics = $logAnalyticsCount
                        DiagSettings = $diagCount
                        PerfAlerts = $perfAlertCount
                        Dashboards = $dashboardCount
                    }
            } else {
                return New-WafResult -CheckId 'PE04' `
                    -Status 'Fail' `
                    -Message "Data collection gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Poor data collection hinders optimization.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Deploy App Insights**: For metrics
2. **Set Log Analytics**: For logs
3. **Enable Diagnostics**: On resources

### Phase 2: Advanced (Weeks 2-3)
1. **Create Perf Alerts**: For thresholds
2. **Build Dashboards**: For views
3. **Analyze Data**: For insights

$evidence
"@ `
                    -RemediationScript @"
# Quick Data Collection Setup

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'pe-data' -Location 'eastus'

# Create Log Analytics
New-AzOperationalInsightsWorkspace -ResourceGroupName 'rg' -Name 'pe-logs' -Location 'eastus'

# Enable Diagnostic
Set-AzDiagnosticSetting -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm' -WorkspaceId (Get-AzOperationalInsightsWorkspace -Name 'pe-logs' -ResourceGroupName 'rg').ResourceId -Enabled $true -Category 'PerformanceCounters'

Write-Host "Basic data collection - add alerts and dashboards"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE04' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
