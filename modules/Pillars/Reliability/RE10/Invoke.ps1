<#
.SYNOPSIS
    RE10 - Measure and model health signals

.DESCRIPTION
    Measure and model the solution's health signals. Continuously capture uptime and other reliability data from across the workload and also from individual components and key flows.

.NOTES
    Pillar: Reliability
    Recommendation: RE:10 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/reliability/monitoring-alerting-strategy
#>

Register-WafCheck -CheckId 'RE10' `
    -Pillar 'Reliability' `
    -Title 'Measure and model health signals' `
    -Description 'Measure and model the solution''s health signals. Continuously capture uptime and other reliability data from across the workload and also from individual components and key flows.' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('Reliability', 'Monitoring', 'HealthSignals', 'Uptime') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/reliability/monitoring-alerting-strategy' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Initialize assessment
            $issues = @()
            $totalAlerts = 0
            
            # 1. Metric Alerts - For health signals
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/alertrules'
| extend 
    enabled = tobool(properties.enabled)
| project 
    id, name, enabled
"@
            $alerts = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            
            $enabledAlerts = $($alerts | Where-Object { $_.enabled -eq $true } | Measure-Object).Count
            $totalAlerts += $alerts.Count
            
            if ($enabledAlerts -eq 0) {
                $issues += "No enabled alert rules configured"
            }
            
            # 2. Application Insights - For application health
            $appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue
            if ($appInsights.Count -eq 0) {
                $issues += "No Application Insights instances"
            }
            
            # 3. Monitor Workspaces - For log analytics
            $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
            if ($workspaces.Count -eq 0) {
                $issues += "No Log Analytics workspaces for health modeling"
            }
            
            $evidence = @"
Health Signals Assessment:
- Alert Rules: $($alerts.Count) total, $enabledAlerts enabled
- Application Insights: $($appInsights.Count)
- Log Analytics Workspaces: $($workspaces.Count)
- Total Monitoring Resources: $totalAlerts + $($appInsights.Count) + $($workspaces.Count)
"@
            
            if ($enabledAlerts -ge 5 -and $issues.Count -eq 0) {
                return New-WafResult -CheckId 'RE10' `
                    -Status 'Pass' `
                    -Message "Effective health monitoring with $enabledAlerts enabled alerts" `
                    -Metadata @{
                        Alerts = $alerts.Count
                        EnabledAlerts = $enabledAlerts
                        AppInsights = $appInsights.Count
                        Workspaces = $workspaces.Count
                    }
            } else {
                return New-WafResult -CheckId 'RE10' `
                    -Status 'Fail' `
                    -Message "Poor health signal capture: Only $enabledAlerts enabled alerts, $($issues.Count) issues" `
                    -Recommendation @"
**CRITICAL**: Inadequate health monitoring.

Issues identified:
$($issues | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basic Monitoring (Week 1)
1. **Deploy App Insights**: For key apps
2. **Create Alerts**: For uptime metrics
3. **Set Up Workspaces**: For logs

### Phase 2: Advanced Modeling (Weeks 2-3)
1. **Build Dashboards**: For health signals
2. **Model Uptime**: Calculate SLOs
3. **Automate Reports**: Weekly reviews

$evidence
"@ `
                    -RemediationScript @"
# Quick Health Monitoring Setup
New-AzApplicationInsights -ResourceGroupName 'rg-monitor' -Name 'app-health' -Location 'eastus'

# Create Basic Alert
New-AzMetricAlertRuleV2 -Name 'health-alert' -ResourceGroupName 'rg-monitor' -WindowSize (New-TimeSpan -Minutes 5) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'Availability' -Operator GreaterThan -Threshold 99)
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE10' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
