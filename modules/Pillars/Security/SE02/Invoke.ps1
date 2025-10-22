<#
.SYNOPSIS
    SE02 - Maintain a secure development lifecycle

.DESCRIPTION
    Maintain a secure development lifecycle by using a hardened, mostly automated, and auditable software supply chain. Incorporate a secure design by using threat modeling to safeguard against security-defeating implementations.

.NOTES
    Pillar: Security
    Recommendation: SE:02 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/secure-development-lifecycle
    https://learn.microsoft.com/en-us/azure/well-architected/security/threat-model
#>

Register-WafCheck -CheckId 'SE02' `
    -Pillar 'Security' `
    -Title 'Maintain a secure development lifecycle' `
    -Description 'Maintain a secure development lifecycle by using a hardened, mostly automated, and auditable software supply chain. Incorporate a secure design by using threat modeling to safeguard against security-defeating implementations.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'SDL', 'DevSecOps', 'ThreatModeling', 'SupplyChain') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/secure-development-lifecycle' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess secure development indicators
            
            # 1. Check if Microsoft Defender for DevOps is enabled
            $devopsPricing = Get-AzSecurityPricing -Name 'DevOps' -ErrorAction SilentlyContinue
            $isDevOpsEnabled = $devopsPricing -and $devopsPricing.PricingTier -eq 'Standard'
            
            # 2. Check for DevOps configurations (connected repos)
            $devopsConfigsQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/devopsconfigurations'
| summarize DevOpsConfigs = count()
"@
            $configsResult = Invoke-AzResourceGraphQuery -Query $devopsConfigsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $configsCount = if ($configsResult.Count -gt 0) { $configsResult[0].DevOpsConfigs } else { 0 }
            
            # 3. Check for Azure Policy assignments related to secure dev (e.g., GitHub or DevOps policies)
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'DevOps' or properties.displayName contains 'GitHub' or properties.displayName contains 'secure code'
| summarize SecureDevPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].SecureDevPolicies } else { 0 }
            
            # 4. Check for Defender for Cloud recommendations related to devops
            $recommendations = Get-AzSecurityRecommendation -ErrorAction SilentlyContinue | 
                Where-Object { $_.RecommendationDisplayName -match 'DevOps|GitHub|code|supply chain' }
            
            $recCount = $recommendations.Count
            $resolvedRecs = $recommendations | Where-Object { $_.Status -eq 'Completed' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate score
            $indicators = @()
            
            if (-not $isDevOpsEnabled) {
                $indicators += "Microsoft Defender for DevOps not enabled"
            }
            
            if ($configsCount -eq 0) {
                $indicators += "No DevOps configurations or connected repositories found"
            }
            
            if ($policyCount -lt 3) {
                $indicators += "Limited secure dev policies assigned ($policyCount)"
            }
            
            if ($recCount -gt 0 -and $resolvedRecs / $recCount -lt 0.8) {
                $indicators += "Low resolution rate for devops security recommendations ($resolvedRecs/$recCount resolved)"
            }
            
            $evidence = @"
Secure SDL Assessment:
- Defender for DevOps Enabled: $isDevOpsEnabled
- Connected DevOps Configs: $configsCount
- Secure Dev Policies: $policyCount
- DevOps Recommendations: $recCount total, $resolvedRecs resolved
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE02' `
                    -Status 'Pass' `
                    -Message 'Strong secure development lifecycle practices in place' `
                    -Metadata @{
                        DevOpsEnabled = $isDevOpsEnabled
                        Configs = $configsCount
                        Policies = $policyCount
                        Recommendations = $recCount
                        Resolved = $resolvedRecs
                    }
            } else {
                return New-WafResult -CheckId 'SE02' `
                    -Status 'Fail' `
                    -Message "Secure SDL gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate secure development lifecycle increases vulnerability risks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Enable Core Tools (Week 1)
1. **Activate Defender for DevOps**: Enable in Defender for Cloud
2. **Connect Repos**: Add GitHub/Azure DevOps connectors
3. **Assign Policies**: Implement secure code scanning policies

### Phase 2: Implement Practices (Weeks 2-4)
1. **Threat Modeling**: Conduct for key workloads
2. **Automate Scanning**: Integrate SAST/DAST in pipelines
3. **Supply Chain Security**: Scan dependencies regularly

$evidence
"@ `
                    -RemediationScript @"
# Quick Secure SDL Setup

# Enable Defender for DevOps
Set-AzSecurityPricing -Name 'DevOps' -PricingTier 'Standard'

# Example: Connect GitHub (manual step in portal, or use API)
# For Azure DevOps, similar configuration in Defender

Write-Host "Defender for DevOps enabled - connect repositories in Defender for Cloud portal"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE02' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
