<#
.SYNOPSIS
    OE08 - Develop an emergency response plan

.DESCRIPTION
    Develop an effective emergency operations practice. Ensure that your workload emits meaningful health signals across infrastructure and code. Collect the resulting data and use it to generate actionable alerts that enact emergency responses via dashboards and queries. Clearly define human responsibilities, such as on-call rotations, incident management, emergency resource access, and running postmortems.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:08 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/emergency-response
#>

Register-WafCheck -CheckId 'OE08' `
    -Pillar 'OperationalExcellence' `
    -Title 'Develop an emergency response plan' `
    -Description 'Develop an effective emergency operations practice. Ensure that your workload emits meaningful health signals across infrastructure and code. Collect the resulting data and use it to generate actionable alerts that enact emergency responses via dashboards and queries. Clearly define human responsibilities, such as on-call rotations, incident management, emergency resource access, and running postmortems.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'EmergencyResponse', 'IncidentManagement', 'OnCall', 'Postmortem') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/emergency-response' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess emergency response indicators
            
            # 1. Azure Monitor Alerts
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts' or type =~ 'microsoft.insights/activitylogalerts'
| summarize Alerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].Alerts } else { 0 }
            
            # 2. Microsoft Sentinel for Incident Management
            $sentinelQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationsmanagement/solutions' and name contains 'SecurityInsights'
| summarize Sentinel = count()
"@
            $sentinelResult = Invoke-AzResourceGraphQuery -Query $sentinelQuery -SubscriptionId $SubscriptionId -UseCache
            $sentinelCount = if ($sentinelResult.Count -gt 0) { $sentinelResult[0].Sentinel } else { 0 }
            
            # 3. Action Groups for Notifications
            $actionGroupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/actiongroups'
| summarize ActionGroups = count()
"@
            $actionGroupResult = Invoke-AzResourceGraphQuery -Query $actionGroupQuery -SubscriptionId $SubscriptionId -UseCache
            $actionGroupCount = if ($actionGroupResult.Count -gt 0) { $actionGroupResult[0].ActionGroups } else { 0 }
            
            # 4. Recovery Services Vaults for DR
            $recoveryQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults'
| summarize RecoveryVaults = count()
"@
            $recoveryResult = Invoke-AzResourceGraphQuery -Query $recoveryQuery -SubscriptionId $SubscriptionId -UseCache
            $recoveryCount = if ($recoveryResult.Count -gt 0) { $recoveryResult[0].RecoveryVaults } else { 0 }
            
            # 5. Advisor High Availability Recs (for resiliency)
            $advisor = Get-AzAdvisorRecommendation -Category HighAvailability -ErrorAction SilentlyContinue
            $haRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($alertCount -eq 0) {
                $indicators += "No alerts for detection"
            }
            
            if ($sentinelCount -eq 0) {
                $indicators += "No Sentinel for incident management"
            }
            
            if ($actionGroupCount -eq 0) {
                $indicators += "No action groups for notifications"
            }
            
            if ($recoveryCount -eq 0) {
                $indicators += "No recovery vaults for DR"
            }
            
            if ($haRecs -gt 5) {
                $indicators += "High unresolved HA recommendations ($haRecs)"
            }
            
            $evidence = @"
Emergency Response Assessment:
- Alerts: $alertCount
- Sentinel: $sentinelCount
- Action Groups: $actionGroupCount
- Recovery Vaults: $recoveryCount
- HA Recommendations: $haRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE08' `
                    -Status 'Pass' `
                    -Message 'Effective emergency response plan in place' `
                    -Metadata @{
                        Alerts = $alertCount
                        Sentinel = $sentinelCount
                        ActionGroups = $actionGroupCount
                        Recovery = $recoveryCount
                        HARecs = $haRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE08' `
                    -Status 'Fail' `
                    -Message "Emergency response gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: No emergency plan leads to chaos.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Detection & Notification (Week 1)
1. **Create Alerts**: For signals
2. **Set Action Groups**: For on-call
3. **Deploy Sentinel**: For incidents

### Phase 2: Response & Recovery (Weeks 2-3)
1. **Set Up Recovery**: Vaults/DR
2. **Address HA Recs**: For resiliency
3. **Conduct Drills**: Test plan

$evidence
"@ `
                    -RemediationScript @"
# Quick Emergency Response Setup

# Create Alert
New-AzMetricAlertRuleV2 -Name 'emergency-alert' -ResourceGroupName 'rg' -WindowSize (New-TimeSpan -Minutes 5) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'CPU' -Operator GreaterThan -Threshold 90)

# Action Group
New-AzActionGroup -Name 'emergency-group' -ResourceGroupName 'rg' -ShortName 'EM' -Location 'global' -EmailReceiver @{Name='team';EmailAddress='ops@company.com'}

Write-Host "Basic emergency setup - develop full plan"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE08' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
