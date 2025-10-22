<#
.SYNOPSIS
    SE10 - Monitor and respond to threats

.DESCRIPTION
    Implement a holistic monitoring strategy that leverages modern threat detection mechanisms integrated with the Azure platform. These mechanisms should reliably alert for triage and feed signals into existing SecOps processes. Focus on security monitoring to detect threats, predict incidents, and support post-incident analysis.

.NOTES
    Pillar: Security
    Recommendation: SE:10 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/monitor-threats
#>

Register-WafCheck -CheckId 'SE10' `
    -Pillar 'Security' `
    -Title 'Monitor and respond to threats' `
    -Description 'Implement a holistic monitoring strategy that leverages modern threat detection mechanisms integrated with the Azure platform. These mechanisms should reliably alert for triage and feed signals into existing SecOps processes.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Monitoring', 'ThreatDetection', 'Alerts', 'SIEM') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/monitor-threats' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess monitoring indicators
            
            # 1. Azure Monitor Diagnostic Settings
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| summarize DiagSettings = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagSettings } else { 0 }
            
            # 2. Microsoft Defender for Cloud Enablement
            $defenderQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/pricings'
| where properties.pricingTier == 'Standard'
| summarize DefenderPlans = count()
"@
            $defenderResult = Invoke-AzResourceGraphQuery -Query $defenderQuery -SubscriptionId $SubscriptionId -UseCache
            $defenderPlans = if ($defenderResult.Count -gt 0) { $defenderResult[0].DefenderPlans } else { 0 }
            
            # Security Alerts from Defender
            $alertQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/alerts'
| summarize Alerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].Alerts } else { 0 }
            
            # 3. Microsoft Sentinel Workspaces
            $sentinelQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationsmanagement/solutions'
| where name contains 'SecurityInsights'
| summarize SentinelInstances = count()
"@
            $sentinelResult = Invoke-AzResourceGraphQuery -Query $sentinelQuery -SubscriptionId $SubscriptionId -UseCache
            $sentinelCount = if ($sentinelResult.Count -gt 0) { $sentinelResult[0].SentinelInstances } else { 0 }
            
            # 4. Network Watcher and Flow Logs
            $nwQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networkwatchers'
| summarize NetworkWatchers = count()
"@
            $nwResult = Invoke-AzResourceGraphQuery -Query $nwQuery -SubscriptionId $SubscriptionId -UseCache
            $nwCount = if ($nwResult.Count -gt 0) { $nwResult[0].NetworkWatchers } else { 0 }
            
            $flowLogQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networksecuritygroups/flowlogs'
| where properties.enabled == true
| summarize FlowLogs = count()
"@
            $flowLogResult = Invoke-AzResourceGraphQuery -Query $flowLogQuery -SubscriptionId $SubscriptionId -UseCache
            $flowLogCount = if ($flowLogResult.Count -gt 0) { $flowLogResult[0].FlowLogs } else { 0 }
            
            # 5. Activity Log Exports (for auditing)
            $activityExportQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/activitylogalerts'
| summarize ActivityAlerts = count()
"@
            $activityResult = Invoke-AzResourceGraphQuery -Query $activityExportQuery -SubscriptionId $SubscriptionId -UseCache
            $activityCount = if ($activityResult.Count -gt 0) { $activityResult[0].ActivityAlerts } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($diagCount -lt 10) {
                $indicators += "Limited diagnostic settings ($diagCount) - insufficient logging coverage"
            }
            
            if ($defenderPlans -lt 5) {
                $indicators += "Limited Defender for Cloud plans enabled ($defenderPlans) - enable for key workloads"
            }
            
            if ($sentinelCount -eq 0) {
                $indicators += "No Microsoft Sentinel instances for SIEM capabilities"
            }
            
            if ($nwCount -eq 0) {
                $indicators += "No Network Watchers deployed for traffic monitoring"
            }
            
            if ($flowLogCount -eq 0) {
                $indicators += "No NSG flow logs enabled for network forensics"
            }
            
            if ($activityCount -lt 5) {
                $indicators += "Limited activity log alerts ($activityCount) for auditing"
            }
            
            $evidence = @"
Threat Monitoring Assessment:
- Diagnostic Settings: $diagCount
- Defender Plans: $defenderPlans (Alerts: $alertCount)
- Sentinel Instances: $sentinelCount
- Network Watchers: $nwCount
- Flow Logs: $flowLogCount
- Activity Alerts: $activityCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE10' `
                    -Status 'Pass' `
                    -Message 'Comprehensive threat monitoring and response capabilities' `
                    -Metadata @{
                        DiagSettings = $diagCount
                        DefenderPlans = $defenderPlans
                        Sentinel = $sentinelCount
                        NetworkWatchers = $nwCount
                        FlowLogs = $flowLogCount
                        ActivityAlerts = $activityCount
                    }
            } else {
                return New-WafResult -CheckId 'SE10' `
                    -Status 'Fail' `
                    -Message "Threat monitoring gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate monitoring hinders threat detection and response.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Enable Core Monitoring (Week 1)
1. **Set Up Diagnostics**: For key resources
2. **Activate Defender**: For workloads
3. **Deploy Sentinel**: For SIEM

### Phase 2: Advanced Detection (Weeks 2-3)
1. **Enable Network Watcher**: With flow logs
2. **Configure Alerts**: For anomalies
3. **Integrate UEBA**: For behavior analysis

$evidence
"@ `
                    -RemediationScript @"
# Quick Threat Monitoring Setup

# Enable Defender for Cloud
Set-AzSecurityPricing -Name 'VirtualMachines' -PricingTier 'Standard'
Set-AzSecurityPricing -Name 'SqlServers' -PricingTier 'Standard'

# Enable Sentinel (requires Log Analytics workspace)
$workspace = New-AzOperationalInsightsWorkspace -Location 'eastus' -Name 'sentinel-ws' -ResourceGroupName 'rg' -Sku 'PerGB2018'
New-AzSentinelSolution -WorkspaceName $workspace.Name -ResourceGroupName 'rg' -Kind 'SecurityInsights'

# Enable Flow Logs
$nsg = Get-AzNetworkSecurityGroup -Name 'nsg'
New-AzNetworkWatcherFlowLog -Name 'flowlog' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId $nsg.Id -StorageId (Get-AzStorageAccount -Name 'store' -ResourceGroupName 'rg').Id -Enabled $true

Write-Host "Basic monitoring configured - expand with alerts and integrations"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE10' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
