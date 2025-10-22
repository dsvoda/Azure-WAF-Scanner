<#
.SYNOPSIS
    OE11 - Implement safe deployments

.DESCRIPTION
    Implement safe deployments by using practices like blue-green deployments, canary releases, and progressive exposure to minimize risk and downtime.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:11 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments
#>

Register-WafCheck -CheckId 'OE11' `
    -Pillar 'OperationalExcellence' `
    -Title 'Implement safe deployments' `
    -Description 'Implement safe deployments by using practices like blue-green deployments, canary releases, and progressive exposure to minimize risk and downtime.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'SafeDeployments', 'BlueGreen', 'Canary', 'ProgressiveExposure') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess safe deployment indicators
            
            # 1. Traffic Manager Profiles (for routing/blue-green)
            $tmQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/trafficmanagerprofiles'
| summarize TrafficManagers = count()
"@
            $tmResult = Invoke-AzResourceGraphQuery -Query $tmQuery -SubscriptionId $SubscriptionId -UseCache
            $tmCount = if ($tmResult.Count -gt 0) { $tmResult[0].TrafficManagers } else { 0 }
            
            # 2. Application Gateways (for canary routing)
            $agQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgateways'
| summarize AppGateways = count()
"@
            $agResult = Invoke-AzResourceGraphQuery -Query $agQuery -SubscriptionId $SubscriptionId -UseCache
            $agCount = if ($agResult.Count -gt 0) { $agResult[0].AppGateways } else { 0 }
            
            # 3. A/B Testing or Feature Flags (App Config/Feature Manager as proxy)
            $featureQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.appconfiguration/configurationstores' or type =~ 'microsoft.features/featureproviders'
| summarize FeatureTools = count()
"@
            $featureResult = Invoke-AzResourceGraphQuery -Query $featureQuery -SubscriptionId $SubscriptionId -UseCache
            $featureCount = if ($featureResult.Count -gt 0) { $featureResult[0].FeatureTools } else { 0 }
            
            # 4. Deployment Slots in App Services
            $slotQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites/slots'
| summarize DeploymentSlots = count()
"@
            $slotResult = Invoke-AzResourceGraphQuery -Query $slotQuery -SubscriptionId $SubscriptionId -UseCache
            $slotCount = if ($slotResult.Count -gt 0) { $slotResult[0].DeploymentSlots } else { 0 }
            
            # 5. Advisor Deployment Recs
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $deployRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'deployment|release|canary|blue-green' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($tmCount -eq 0) {
                $indicators += "No Traffic Manager for routing strategies"
            }
            
            if ($agCount -eq 0) {
                $indicators += "No Application Gateways for canary releases"
            }
            
            if ($featureCount -eq 0) {
                $indicators += "No feature management tools for A/B testing"
            }
            
            if ($slotCount -eq 0) {
                $indicators += "No deployment slots in App Services"
            }
            
            if ($deployRecs -gt 0) {
                $indicators += "Unresolved deployment recommendations ($deployRecs)"
            }
            
            $evidence = @"
Safe Deployments Assessment:
- Traffic Managers: $tmCount
- App Gateways: $agCount
- Feature Tools: $featureCount
- Deployment Slots: $slotCount
- Deployment Recommendations: $deployRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE11' `
                    -Status 'Pass' `
                    -Message 'Effective safe deployment practices implemented' `
                    -Metadata @{
                        TrafficManagers = $tmCount
                        AppGateways = $agCount
                        FeatureTools = $featureCount
                        DeploymentSlots = $slotCount
                        DeployRecs = $deployRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE11' `
                    -Status 'Fail' `
                    -Message "Safe deployment gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unsafe deployments risk downtime.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Routing Basics (Week 1)
1. **Deploy Traffic Manager**: For blue-green
2. **Set App Gateway**: For canary
3. **Use Deployment Slots**: For swaps

### Phase 2: Advanced (Weeks 2-3)
1. **Enable Feature Flags**: For exposure
2. **Address Recs**: For improvements
3. **Test Deployments**: Validate strategies

$evidence
"@ `
                    -RemediationScript @"
# Quick Safe Deployments Setup

# Create Traffic Manager
New-AzTrafficManagerProfile -Name 'oe-tm' -ResourceGroupName 'rg' -TrafficRoutingMethod 'Weighted' -RelativeDnsName 'oe-tm' -Ttl 30 -MonitorProtocol 'HTTP' -MonitorPort 80 -MonitorPath '/'

# Add Deployment Slot
New-AzWebAppSlot -Name 'oe-app' -ResourceGroupName 'rg' -Slot 'staging'

Write-Host "Basic safe deployments - expand with canary rules"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE11' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
