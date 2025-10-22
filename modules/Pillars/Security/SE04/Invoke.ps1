<#
.SYNOPSIS
    SE04 - Create intentional segmentation

.DESCRIPTION
    Create intentional segmentation and perimeters in your architecture design and workload footprint. The segmentation strategy must include networks, roles and responsibilities, workload identities, and resource organization.

.NOTES
    Pillar: Security
    Recommendation: SE:04 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/segmentation
#>

Register-WafCheck -CheckId 'SE04' `
    -Pillar 'Security' `
    -Title 'Create intentional segmentation' `
    -Description 'Create intentional segmentation and perimeters in your architecture design and workload footprint. The segmentation strategy must include networks, roles and responsibilities, workload identities, and resource organization.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Segmentation', 'NetworkIsolation', 'RBAC', 'Perimeters') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/segmentation' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess segmentation indicators
            
            # 1. Network Segmentation: Check VNets and NSGs
            $vnetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/virtualnetworks'
| summarize VNetCount = count()
"@
            $vnetResult = Invoke-AzResourceGraphQuery -Query $vnetQuery -SubscriptionId $SubscriptionId -UseCache
            $vnetCount = if ($vnetResult.Count -gt 0) { $vnetResult[0].VNetCount } else { 0 }
            
            $nsgQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networksecuritygroups'
| summarize NSGCount = count()
"@
            $nsgResult = Invoke-AzResourceGraphQuery -Query $nsgQuery -SubscriptionId $SubscriptionId -UseCache
            $nsgCount = if ($nsgResult.Count -gt 0) { $nsgResult[0].NSGCount } else { 0 }
            
            # Check NSG associations (subnets/VMs)
            $associatedNSGQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networkinterfaces' or type =~ 'microsoft.network/virtualnetworks/subnets'
| where isnotempty(properties.networkSecurityGroup)
| summarize AssociatedNSGs = count()
"@
            $assocResult = Invoke-AzResourceGraphQuery -Query $associatedNSGQuery -SubscriptionId $SubscriptionId -UseCache
            $assocCount = if ($assocResult.Count -gt 0) { $assocResult[0].AssociatedNSGs } else { 0 }
            
            # 2. ASGs for micro-segmentation
            $asgQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationsecuritygroups'
| summarize ASGCount = count()
"@
            $asgResult = Invoke-AzResourceGraphQuery -Query $asgQuery -SubscriptionId $SubscriptionId -UseCache
            $asgCount = if ($asgResult.Count -gt 0) { $asgResult[0].ASGCount } else { 0 }
            
            # 3. Azure Firewall for advanced filtering
            $firewallQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/azurefirewalls'
| summarize FirewallCount = count()
"@
            $firewallResult = Invoke-AzResourceGraphQuery -Query $firewallQuery -SubscriptionId $SubscriptionId -UseCache
            $firewallCount = if ($firewallResult.Count -gt 0) { $firewallResult[0].FirewallCount } else { 0 }
            
            # 4. RBAC Segmentation: Check role assignments
            $rbacQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roleassignments'
| summarize RBACAssignments = count()
"@
            $rbacResult = Invoke-AzResourceGraphQuery -Query $rbacQuery -SubscriptionId $SubscriptionId -UseCache
            $rbacCount = if ($rbacResult.Count -gt 0) { $rbacResult[0].RBACAssignments } else { 0 }
            
            # Check for custom roles (indicating fine-grained segmentation)
            $customRoleQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roledefinitions'
| where properties.type == 'CustomRole'
| summarize CustomRoles = count()
"@
            $customRoleResult = Invoke-AzResourceGraphQuery -Query $customRoleQuery -SubscriptionId $SubscriptionId -UseCache
            $customRoleCount = if ($customRoleResult.Count -gt 0) { $customRoleResult[0].CustomRoles } else { 0 }
            
            # 5. Resource Organization: Management Groups and Tagged RGs
            $mgQuery = @"
ManagementGroupResources
| where subscriptionId == '$SubscriptionId'
| summarize MGCount = count()
"@
            $mgResult = Invoke-AzResourceGraphQuery -Query $mgQuery -SubscriptionId $SubscriptionId -UseCache
            $mgCount = if ($mgResult.Count -gt 0) { $mgResult[0].MGCount } else { 0 }
            
            $taggedRGQuery = @"
ResourceContainers
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| where isnotempty(tags['owner']) or isnotempty(tags['environment']) or isnotempty(tags['workload'])
| summarize TaggedRGs = count()
"@
            $taggedRGResult = Invoke-AzResourceGraphQuery -Query $taggedRGQuery -SubscriptionId $SubscriptionId -UseCache
            $taggedRGCount = if ($taggedRGResult.Count -gt 0) { $taggedRGResult[0].TaggedRGs } else { 0 }
            
            $totalRGQuery = @"
ResourceContainers
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| summarize TotalRGs = count()
"@
            $totalRGResult = Invoke-AzResourceGraphQuery -Query $totalRGQuery -SubscriptionId $SubscriptionId -UseCache
            $totalRGCount = if ($totalRGResult.Count -gt 0) { $totalRGResult[0].TotalRGs } else { 0 }
            
            $rgTagPercent = if ($totalRGCount -gt 0) { [Math]::Round(($taggedRGCount / $totalRGCount) * 100, 1) } else { 0 }
            
            # 6. Traffic Analytics for monitoring
            $trafficAnalyticsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networkwatchers'
| where properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled == true
| summarize TrafficAnalytics = count()
"@
            $taResult = Invoke-AzResourceGraphQuery -Query $trafficAnalyticsQuery -SubscriptionId $SubscriptionId -UseCache
            $taCount = if ($taResult.Count -gt 0) { $taResult[0].TrafficAnalytics } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($vnetCount -lt 1) {
                $indicators += "No virtual networks for segmentation"
            } elseif ($nsgCount -lt $vnetCount) {
                $indicators += "Insufficient NSGs for VNets ($nsgCount NSGs for $vnetCount VNets)"
            } elseif ($assocCount -lt ($vnetCount * 0.8)) {
                $indicators += "Low NSG association coverage ($assocCount associations)"
            }
            
            if ($asgCount -eq 0) {
                $indicators += "No Application Security Groups for micro-segmentation"
            }
            
            if ($firewallCount -eq 0) {
                $indicators += "No Azure Firewalls for advanced traffic control"
            }
            
            if ($rbacCount -lt 10) {
                $indicators += "Limited RBAC assignments ($rbacCount) - potential over-privileging"
            }
            
            if ($customRoleCount -eq 0) {
                $indicators += "No custom roles defined for fine-grained segmentation"
            }
            
            if ($mgCount -eq 0) {
                $indicators += "No management groups for organizational segmentation"
            }
            
            if ($rgTagPercent -lt 70) {
                $indicators += "Low resource group tagging for ownership/segmentation ($rgTagPercent%)"
            }
            
            if ($taCount -eq 0) {
                $indicators += "No Traffic Analytics enabled for segmentation monitoring"
            }
            
            $evidence = @"
Segmentation Assessment:
- Virtual Networks: $vnetCount
- NSGs: $nsgCount (Associations: $assocCount)
- ASGs: $asgCount
- Azure Firewalls: $firewallCount
- RBAC Assignments: $rbacCount (Custom Roles: $customRoleCount)
- Management Groups: $mgCount
- Tagged Resource Groups: $taggedRGCount / $totalRGCount ($rgTagPercent%)
- Traffic Analytics: $taCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE04' `
                    -Status 'Pass' `
                    -Message 'Strong intentional segmentation across networks, identities, and resources' `
                    -Metadata @{
                        VNetCount = $vnetCount
                        NSGCount = $nsgCount
                        ASGCount = $asgCount
                        FirewallCount = $firewallCount
                        RBACCount = $rbacCount
                        CustomRoles = $customRoleCount
                        MGCount = $mgCount
                        RGTagsPercent = $rgTagPercent
                        TrafficAnalytics = $taCount
                    }
            } else {
                return New-WafResult -CheckId 'SE04' `
                    -Status 'Fail' `
                    -Message "Segmentation gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of intentional segmentation increases blast radius risks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Network Perimeters (Week 1)
1. **Deploy VNets/NSGs**: Isolate workloads
2. **Add ASGs**: For micro-segmentation
3. **Enable Firewalls**: For traffic filtering

### Phase 2: Identity & Organization (Weeks 2-3)
1. **Refine RBAC**: Use custom roles
2. **Organize Resources**: With MGs and tags
3. **Monitor Traffic**: Enable Analytics

$evidence
"@ `
                    -RemediationScript @"
# Quick Segmentation Setup

# Create VNet with NSG
New-AzVirtualNetwork -Name 'seg-vnet' -ResourceGroupName 'rg-seg' -Location 'eastus' -AddressPrefix '10.0.0.0/16'
$nsg = New-AzNetworkSecurityGroup -Name 'seg-nsg' -ResourceGroupName 'rg-seg' -Location 'eastus'
Add-AzVirtualNetworkSubnetConfig -Name 'default' -VirtualNetwork (Get-AzVirtualNetwork -Name 'seg-vnet' -ResourceGroupName 'rg-seg') -AddressPrefix '10.0.0.0/24' -NetworkSecurityGroup $nsg

# Custom RBAC Role
$roleDef = New-AzRoleDefinition -Role (New-Object Microsoft.Azure.Commands.Resources.Models.Authorization.RoleDefinitionProperties) 
$roleDef.Name = 'Custom Seg Role'
$roleDef.Description = 'Custom role for segmentation'
$roleDef.Actions = @('Microsoft.Network/*/read')
Set-AzRoleDefinition -Role $roleDef

Write-Host "Basic segmentation configured - expand with more controls"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE04' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
