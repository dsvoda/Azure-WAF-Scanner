<#
.SYNOPSIS
    CO09 - Optimize flow costs

.DESCRIPTION
    Optimize costs for data movement between regions, availability zones, VNets, and on-premises locations. Consider data transfer volume, direction, and bandwidth to minimize expenses.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:09 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-flow-costs
#>

Register-WafCheck -CheckId 'CO09' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize flow costs' `
    -Description 'Optimize costs for data movement between regions, availability zones, VNets, and on-premises locations. Consider data transfer volume, direction, and bandwidth to minimize expenses.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'DataTransfer', 'Networking', 'Egress', 'VNetPeering') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-flow-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess flow cost optimization indicators
            
            # 1. Multi-Region Resources (potential cross-region transfer)
            $regionQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize UniqueRegions = dcount(location)
"@
            $regionResult = Invoke-AzResourceGraphQuery -Query $regionQuery -SubscriptionId $SubscriptionId -UseCache
            $uniqueRegions = if ($regionResult.Count -gt 0) { $regionResult[0].UniqueRegions } else { 0 }
            
            # 2. Public IPs (egress costs)
            $publicIPQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/publicipaddresses'
| summarize PublicIPs = count()
"@
            $publicIPResult = Invoke-AzResourceGraphQuery -Query $publicIPQuery -SubscriptionId $SubscriptionId -UseCache
            $publicIPCount = if ($publicIPResult.Count -gt 0) { $publicIPResult[0].PublicIPs } else { 0 }
            
            # 3. VNet Peering (intra-region free, cross-region charged)
            $peeringQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/virtualnetworks'
| mvexpand peering = properties.virtualNetworkPeerings
| where peering.properties.remoteVirtualNetwork.id != ''
| extend remoteSub = split(peering.properties.remoteVirtualNetwork.id, '/')[2]
| where remoteSub != '$SubscriptionId' or location != split(peering.properties.remoteVirtualNetwork.id, '/')[8]
| summarize CrossPeering = count()
"@
            $peeringResult = Invoke-AzResourceGraphQuery -Query $peeringQuery -SubscriptionId $SubscriptionId -UseCache
            $crossPeering = if ($peeringResult.Count -gt 0) { $peeringResult[0].CrossPeering } else { 0 }
            
            # 4. ExpressRoute/VPN Gateways (on-prem connectivity)
            $gatewayQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/expressroutegateways' or type =~ 'microsoft.network/virtualnetworkgateways'
| summarize Gateways = count()
"@
            $gatewayResult = Invoke-AzResourceGraphQuery -Query $gatewayQuery -SubscriptionId $SubscriptionId -UseCache
            $gatewayCount = if ($gatewayResult.Count -gt 0) { $gatewayResult[0].Gateways } else { 0 }
            
            # 5. Traffic Analytics Enabled (for flow monitoring)
            $taQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networkwatchers/flowanalyticsconfigurations'
| where properties.enabled == true
| summarize TrafficAnalytics = count()
"@
            $taResult = Invoke-AzResourceGraphQuery -Query $taQuery -SubscriptionId $SubscriptionId -UseCache
            $taCount = if ($taResult.Count -gt 0) { $taResult[0].TrafficAnalytics } else { 0 }
            
            # 6. Advisor Networking Cost Recs
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $netRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'network|egress|data transfer|bandwidth' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($uniqueRegions -gt 1) {
                $indicators += "Multiple regions deployed ($uniqueRegions) - potential cross-region transfer costs"
            }
            
            if ($publicIPCount -gt 10) {
                $indicators += "High number of public IPs ($publicIPCount) - review for egress optimization"
            }
            
            if ($crossPeering -gt 0) {
                $indicators += "Cross-region/sub peering detected ($crossPeering) - charged transfers"
            }
            
            if ($gatewayCount -gt 0 && $taCount -eq 0) {
                $indicators += "Gateways present ($gatewayCount) but no Traffic Analytics for flow monitoring"
            }
            
            if ($netRecs -gt 0) {
                $indicators += "Unresolved networking cost recommendations ($netRecs)"
            }
            
            $evidence = @"
Flow Cost Assessment:
- Unique Regions: $uniqueRegions
- Public IPs: $publicIPCount
- Cross-Region Peering: $crossPeering
- Connectivity Gateways: $gatewayCount
- Traffic Analytics: $taCount
- Networking Recs: $netRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO09' `
                    -Status 'Pass' `
                    -Message 'Optimized flow costs with minimal transfer expenses' `
                    -Metadata @{
                        Regions = $uniqueRegions
                        PublicIPs = $publicIPCount
                        CrossPeering = $crossPeering
                        Gateways = $gatewayCount
                        TrafficAnalytics = $taCount
                        NetRecs = $netRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO09' `
                    -Status 'Fail' `
                    -Message "Flow cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unoptimized flows lead to high data transfer costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Reduce Transfers (Week 1)
1. **Consolidate Regions**: Minimize cross-region
2. **Optimize Public IPs**: Use private endpoints
3. **Review Peering**: Avoid cross-region

### Phase 2: Monitoring & Connectivity (Weeks 2-3)
1. **Enable Traffic Analytics**: Analyze flows
2. **Use Gateways Efficiently**: For on-prem
3. **Address Recommendations**: For savings

$evidence
"@ `
                    -RemediationScript @"
# Quick Flow Optimization Setup

# Enable Private Endpoint (example for Storage)
New-AzPrivateEndpoint -Name 'pe-store' -ResourceGroupName 'rg' -Location 'eastus' -Subnet (Get-AzVirtualNetworkSubnetConfig -Name 'subnet' -VirtualNetwork (Get-AzVirtualNetwork -Name 'vnet')) -PrivateLinkServiceConnection (New-AzPrivateLinkServiceConnection -Name 'plc' -PrivateLinkServiceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/store' -GroupId 'blob')

# Enable Traffic Analytics
Update-AzNetworkWatcherConfig -NetworkWatcherName 'nw' -ResourceGroupName 'rg' -EnableFlowLogs $true -StorageId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/store'

Write-Host "Basic flow optimization - monitor in Network Watcher"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO09' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
