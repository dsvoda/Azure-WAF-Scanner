<#
.SYNOPSIS
    OE07 - Implement observability

.DESCRIPTION
    Implement observability to understand the health of your workload and identify issues. Use metrics, logs, and traces to gain insights into performance, reliability, and security. Instrument your application to collect telemetry data for comprehensive monitoring.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:07 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/observability
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/instrument-application
#>

Register-WafCheck -CheckId 'OE07' `
    -Pillar 'OperationalExcellence' `
    -Title 'Implement observability' `
    -Description 'Implement observability to understand the health of your workload and identify issues. Use metrics, logs, and traces to gain insights into performance, reliability, and security. Instrument your application to collect telemetry data for comprehensive monitoring.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'Observability', 'Monitoring', 'Logging', 'Tracing') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/observability' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess observability indicators
            
            # 1. Application Insights Instances
            $appInsightsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components'
| summarize AppInsights = count()
"@
            $appInsightsResult = Invoke-AzResourceGraphQuery -Query $appInsightsQuery -SubscriptionId $SubscriptionId -UseCache
            $appInsightsCount = if ($appInsightsResult.Count -gt 0) { $appInsightsResult[0].AppInsights } else { 0 }
            
            # 2. Log Analytics Workspaces
            $logAnalyticsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationalinsights/workspaces'
| summarize LogAnalytics = count()
"@
            $logAnalyticsResult = Invoke-AzResourceGraphQuery -Query $logAnalyticsQuery -SubscriptionId $SubscriptionId -UseCache
            $logAnalyticsCount = if ($logAnalyticsResult.Count -gt 0) { $logAnalyticsResult[0].LogAnalytics } else { 0 }
            
            # 3. Diagnostic Settings
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| summarize DiagSettings = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagSettings } else { 0 }
            
            # 4. Alerts (Metric and Activity)
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts' or type =~ 'microsoft.insights/activitylogalerts'
| summarize Alerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].Alerts } else { 0 }
            
            # 5. Dashboards for Insights
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
                $indicators += "No Application Insights for tracing"
            }
            
            if ($logAnalyticsCount -eq 0) {
                $indicators += "No Log Analytics for logging"
            }
            
            if ($diagCount -eq 0) {
                $indicators += "No diagnostic settings for data collection"
            }
            
            if ($alertCount -eq 0) {
                $indicators += "No alerts for proactive monitoring"
            }
            
            if ($dashboardCount -eq 0) {
                $indicators += "No dashboards for insights"
            }
            
            $evidence = @"
Observability Assessment:
- App Insights: $appInsightsCount
- Log Analytics: $logAnalyticsCount
- Diagnostic Settings: $diagCount
- Alerts: $alertCount
- Dashboards: $dashboardCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE07' `
                    -Status 'Pass' `
                    -Message 'Comprehensive observability implemented' `
                    -Metadata @{
                        AppInsights = $appInsightsCount
                        LogAnalytics = $logAnalyticsCount
                        DiagSettings = $diagCount
                        Alerts = $alertCount
                        Dashboards = $dashboardCount
                    }
            } else {
                return New-WafResult -CheckId 'OE07' `
                    -Status 'Fail' `
                    -Message "Observability gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Poor observability hinders issue detection.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Deploy App Insights**: For apps
2. **Set Log Analytics**: For logs
3. **Enable Diagnostics**: On resources

### Phase 2: Advanced (Weeks 2-3)
1. **Create Alerts**: For thresholds
2. **Build Dashboards**: For views
3. **Integrate Tracing**: For end-to-end

$evidence
"@ `
                    -RemediationScript @"
# Quick Observability Setup

# Deploy App Insights
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'oe-observe' -Location 'eastus'

# Create Log Analytics
New-AzOperationalInsightsWorkspace -ResourceGroupName 'rg' -Name 'oe-logs' -Location 'eastus'

# Enable Diagnostic
Set-AzDiagnosticSetting -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm' -WorkspaceId (Get-AzOperationalInsightsWorkspace -Name 'oe-logs' -ResourceGroupName 'rg').ResourceId -Enabled $true -Category 'VMProtectionAlerts'

Write-Host "Basic observability - add alerts and dashboards"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE07' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
