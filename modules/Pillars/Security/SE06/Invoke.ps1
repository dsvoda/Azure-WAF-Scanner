<#
.SYNOPSIS
    SE06 - Isolate, filter, and control network traffic

.DESCRIPTION
    Isolate, filter, and control network traffic across both ingress and egress flows. Apply defense in depth principles by using localized network controls at all available network boundaries across both east-west and north-south traffic.

.NOTES
    Pillar: Security
    Recommendation: SE:06 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/networking
#>

Register-WafCheck -CheckId 'SE06' `
    -Pillar 'Security' `
    -Title 'Isolate, filter, and control network traffic' `
    -Description 'Isolate, filter, and control network traffic across both ingress and egress flows. Apply defense in depth principles by using localized network controls at all available network boundaries across both east-west and north-south traffic.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'NetworkSecurity', 'Segmentation', 'Firewall', 'DDoS') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/networking' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess network security indicators
            
            # 1. Virtual Networks and Subnets with NSGs
            $vnetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/virtualnetworks'
| summarize VNetCount = count()
"@
            $vnetResult = Invoke-AzResourceGraphQuery -Query $vnetQuery -SubscriptionId $SubscriptionId -UseCache
            $vnetCount = if ($vnetResult.Count -gt 0) { $vnetResult[0].VNetCount } else { 0 }
            
            $subnetNSGQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/virtualnetworks/subnets'
| where isnotempty(properties.networkSecurityGroup)
| summarize SubnetsWithNSG = count()
"@
            $subnetNSGResult = Invoke-AzResourceGraphQuery -Query $subnetNSGQuery -SubscriptionId $SubscriptionId -UseCache
            $subnetsWithNSG = if ($subnetNSGResult.Count -gt 0) { $subnetNSGResult[0].SubnetsWithNSG } else { 0 }
            
            $totalSubnetsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/virtualnetworks/subnets'
| summarize TotalSubnets = count()
"@
            $totalSubnetsResult = Invoke-AzResourceGraphQuery -Query $totalSubnetsQuery -SubscriptionId $SubscriptionId -UseCache
            $totalSubnets = if ($totalSubnetsResult.Count -gt 0) { $totalSubnetsResult[0].TotalSubnets } else { 0 }
            
            $nsgCoveragePercent = if ($totalSubnets -gt 0) { [Math]::Round(($subnetsWithNSG / $totalSubnets) * 100, 1) } else { 0 }
            
            # 2. Azure Firewalls
            $firewallQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/azurefirewalls'
| summarize FirewallCount = count()
"@
            $firewallResult = Invoke-AzResourceGraphQuery -Query $firewallQuery -SubscriptionId $SubscriptionId -UseCache
            $firewallCount = if ($firewallResult.Count -gt 0) { $firewallResult[0].FirewallCount } else { 0 }
            
            # 3. DDoS Protection
            $ddosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/ddosprotectionplans'
| summarize DDoSPlans = count()
"@
            $ddosResult = Invoke-AzResourceGraphQuery -Query $ddosQuery -SubscriptionId $SubscriptionId -UseCache
            $ddosCount = if ($ddosResult.Count -gt 0) { $ddosResult[0].DDoSPlans } else { 0 }
            
            # Public IPs without DDoS
            $publicIPQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/publicipaddresses'
| where isnull(properties.ddosSettings) or properties.ddosSettings.protectionMode != 'Enabled'
| summarize UnprotectedPublicIPs = count()
"@
            $publicIPResult = Invoke-AzResourceGraphQuery -Query $publicIPQuery -SubscriptionId $SubscriptionId -UseCache
            $unprotectedIPs = if ($publicIPResult.Count -gt 0) { $publicIPResult[0].UnprotectedPublicIPs } else { 0 }
            
            # 4. Web Application Firewalls (WAF)
            $wafQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgatewaywebapplicationfirewallpolicies' or type =~ 'microsoft.cdn/frontdoorwebapplicationfirewallpolicies'
| summarize WAFPolicies = count()
"@
            $wafResult = Invoke-AzResourceGraphQuery -Query $wafQuery -SubscriptionId $SubscriptionId -UseCache
            $wafCount = if ($wafResult.Count -gt 0) { $wafResult[0].WAFPolicies } else { 0 }
            
            # 5. Private Endpoints for PaaS
            $privateEndpointQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/privateendpoints'
| summarize PrivateEndpoints = count()
"@
            $peResult = Invoke-AzResourceGraphQuery -Query $privateEndpointQuery -SubscriptionId $SubscriptionId -UseCache
            $peCount = if ($peResult.Count -gt 0) { $peResult[0].PrivateEndpoints } else { 0 }
            
            # 6. Diagnostic Logging on Network Resources
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.network/virtualnetworks', 'microsoft.network/networksecuritygroups', 'microsoft.network/azurefirewalls')
| join kind=leftouter (Resources | where type =~ 'microsoft.insights/diagnosticsettings' | project diagId = tolower(id), resourceUri = properties.scope) 
    on \$left.id == \$right.resourceUri
| where isnotnull(diagId)
| summarize DiagEnabled = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagEnabled } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($vnetCount -eq 0) {
                $indicators += "No virtual networks for basic segmentation"
            } elseif ($nsgCoveragePercent -lt 80) {
                $indicators += "Low NSG coverage on subnets ($nsgCoveragePercent%)"
            }
            
            if ($firewallCount -eq 0) {
                $indicators += "No Azure Firewalls for advanced filtering"
            }
            
            if ($ddosCount -eq 0 -and $unprotectedIPs -gt 0) {
                $indicators += "No DDoS plans and $unprotectedIPs unprotected public IPs"
            }
            
            if ($wafCount -eq 0) {
                $indicators += "No WAF policies for web traffic protection"
            }
            
            if ($peCount -eq 0) {
                $indicators += "No private endpoints for PaaS isolation"
            }
            
            if ($diagCount -lt ($vnetCount + $firewallCount)) {
                $indicators += "Insufficient diagnostic logging on network resources ($diagCount enabled)"
            }
            
            $evidence = @"
Network Security Assessment:
- Virtual Networks: $vnetCount
- Subnets with NSG: $subnetsWithNSG / $totalSubnets ($nsgCoveragePercent%)
- Azure Firewalls: $firewallCount
- DDoS Plans: $ddosCount (Unprotected IPs: $unprotectedIPs)
- WAF Policies: $wafCount
- Private Endpoints: $peCount
- Diagnostic Enabled: $diagCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE06' `
                    -Status 'Pass' `
                    -Message 'Comprehensive network security with defense-in-depth' `
                    -Metadata @{
                        VNetCount = $vnetCount
                        NSGCoverage = $nsgCoveragePercent
                        FirewallCount = $firewallCount
                        DDoSCount = $ddosCount
                        WAFCount = $wafCount
                        PECount = $peCount
                        DiagCount = $diagCount
                    }
            } else {
                return New-WafResult -CheckId 'SE06' `
                    -Status 'Fail' `
                    -Message "Network security gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Weak network controls increase exposure to threats.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basic Controls (Week 1)
1. **Apply NSGs**: To all subnets
2. **Deploy Firewall**: For ingress/egress
3. **Enable DDoS**: On public endpoints

### Phase 2: Advanced Protection (Weeks 2-3)
1. **Add WAF**: For web traffic
2. **Use Private Endpoints**: For PaaS
3. **Enable Diagnostics**: For monitoring

$evidence
"@ `
                    -RemediationScript @"
# Quick Network Security Setup

# Create NSG and Associate
$nsg = New-AzNetworkSecurityGroup -Name 'secure-nsg' -ResourceGroupName 'rg-net' -Location 'eastus'
Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name 'deny-internet' -Description 'Deny inbound internet' -Access Deny -Protocol * -Direction Inbound -Priority 4096 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

# Enable DDoS on VNet
Update-AzVirtualNetwork -ResourceGroupName 'rg-net' -Name 'secure-vnet' -DdosProtectionPlanId (New-AzDdosProtectionPlan -ResourceGroupName 'rg-net' -Name 'ddos-plan' -Location 'eastus').Id -EnableDdosProtection $true

Write-Host "Basic network controls configured - expand with Firewall and WAF"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE06' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
