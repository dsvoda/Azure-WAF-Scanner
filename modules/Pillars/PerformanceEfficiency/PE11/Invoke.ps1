<#
.SYNOPSIS
    PE11 - Respond to live performance issues

.DESCRIPTION
    Respond to live performance issues by establishing processes for detection, triage, and remediation. Use monitoring, alerting, and diagnostics to quickly identify and resolve performance degradation.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:11 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/respond-live-performance-issues
#>

Register-WafCheck -CheckId 'PE11' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Respond to live performance issues' `
    -Description 'Respond to live performance issues by establishing processes for detection, triage, and remediation. Use monitoring, alerting, and diagnostics to quickly identify and resolve performance degradation.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'LiveIssues', 'Detection', 'Triage', 'Remediation') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/respond-live-performance-issues' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess live issue response indicators
            
            # 1. Performance Alerts
            $perfAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'performance' or properties.criteria.metricName contains 'latency' or properties.criteria.metricName contains 'throughput' or properties.description contains 'degradation'
| summarize PerfAlerts = count()
"@
            $perfAlertResult = Invoke-AzResourceGraphQuery -Query $perfAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $perfAlertCount = if ($perfAlertResult.Count -gt 0) { $perfAlertResult[0].PerfAlerts } else { 0 }
            
            # 2. Action Groups for Response
            $actionGroupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/actiongroups'
| summarize ActionGroups = count()
"@
            $actionGroupResult = Invoke-AzResourceGraphQuery -Query $actionGroupQuery -SubscriptionId $SubscriptionId -UseCache
            $actionGroupCount = if ($actionGroupResult.Count -gt 0) { $actionGroupResult[0].ActionGroups } else { 0 }
            
            # 3. Diagnostic Settings for Triage
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| summarize DiagSettings = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagSettings } else { 0 }
            
            # 4. Microsoft Sentinel for Advanced Detection
            $sentinelQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationsmanagement/solutions' and name contains 'SecurityInsights'
| summarize Sentinel = count()
"@
            $sentinelResult = Invoke-AzResourceGraphQuery -Query $sentinelQuery -SubscriptionId $SubscriptionId -UseCache
            $sentinelCount = if ($sentinelResult.Count -gt 0) { $sentinelResult[0].Sentinel } else { 0 }
            
            # 5. Advisor Performance Recs (Unresolved as Issues)
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($perfAlertCount -eq 0) {
                $indicators += "No performance alerts for detection"
            }
            
            if ($actionGroupCount -eq 0) {
                $indicators += "No action groups for triage notifications"
            }
            
            if ($diagCount -eq 0) {
                $indicators += "No diagnostic settings for data collection"
            }
            
            if ($sentinelCount -eq 0) {
                $indicators += "No Sentinel for advanced analysis"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            $evidence = @"
Live Performance Response Assessment:
- Performance Alerts: $perfAlertCount
- Action Groups: $actionGroupCount
- Diagnostic Settings: $diagCount
- Sentinel: $sentinelCount
- Performance Recommendations: $perfRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE11' `
                    -Status 'Pass' `
                    -Message 'Effective response to live performance issues' `
                    -Metadata @{
                        PerfAlerts = $perfAlertCount
                        ActionGroups = $actionGroupCount
                        DiagSettings = $diagCount
                        Sentinel = $sentinelCount
                        PerfRecs = $perfRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE11' `
                    -Status 'Fail' `
                    -Message "Live performance response gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Slow response to issues affects efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Detection (Week 1)
1. **Create Perf Alerts**: For thresholds
2. **Set Action Groups**: For notifications
3. **Enable Diagnostics**: For triage

### Phase 2: Advanced (Weeks 2-3)
1. **Deploy Sentinel**: For analysis
2. **Address Recs**: For improvements
3. **Define Processes**: For remediation

$evidence
"@ `
                    -RemediationScript @"
# Quick Live Response Setup

# Create Perf Alert
New-AzMetricAlertRuleV2 -Name 'live-alert' -ResourceGroupName 'rg' -WindowSize (New-TimeSpan -Minutes 5) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'CpuPercentage' -Operator GreaterThan -Threshold 90)

# Create Action Group
New-AzActionGroup -Name 'pe-action' -ResourceGroupName 'rg' -ShortName 'PE' -Location 'global' -EmailReceiver @{Name='team';EmailAddress='perf@company.com'}

Write-Host "Basic response setup - add diagnostics and Sentinel"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE11' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
