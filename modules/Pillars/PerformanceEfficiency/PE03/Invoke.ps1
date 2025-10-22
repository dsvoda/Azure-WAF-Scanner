<#
.SYNOPSIS
    PE03 - Select appropriate services

.DESCRIPTION
    Select the right services. The services, infrastructure, and tier selections must support your ability to reach the workload's performance targets and accommodate expected capacity changes. The selections should also weigh the benefits of using platform features or building a custom implementation.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:03 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/select-services
#>

Register-WafCheck -CheckId 'PE03' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Select appropriate services' `
    -Description 'Select the right services. The services, infrastructure, and tier selections must support your ability to reach the workload''s performance targets and accommodate expected capacity changes. The selections should also weigh the benefits of using platform features or building a custom implementation.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'ServiceSelection', 'Infrastructure', 'Networking', 'Compute') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/select-services' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess service selection indicators
            
            # 1. Use of Managed/PaaS Services (over IaaS)
            $paasQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.web/sites', 'microsoft.sql/servers/databases', 'microsoft.cosmosdb/databaseaccounts', 'microsoft.cache/redis')
| summarize PaaSServices = count()
"@
            $paasResult = Invoke-AzResourceGraphQuery -Query $paasQuery -SubscriptionId $SubscriptionId -UseCache
            $paasCount = if ($paasResult.Count -gt 0) { $paasResult[0].PaaSServices } else { 0 }
            
            $iaasQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| summarize IaaSVMs = count()
"@
            $iaasResult = Invoke-AzResourceGraphQuery -Query $iaasQuery -SubscriptionId $SubscriptionId -UseCache
            $iaasCount = if ($iaasResult.Count -gt 0) { $iaasResult[0].IaaSVMs } else { 0 }
            
            $paasRatio = if ($paasCount + $iaasCount -gt 0) { [Math]::Round(($paasCount / ($paasCount + $iaasCount)) * 100, 1) } else { 0 }
            
            # 2. Networking Services (Load Balancers, CDNs)
            $netQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.network/loadbalancers', 'microsoft.cdn/profiles', 'microsoft.network/applicationgateways')
| summarize NetworkingServices = count()
"@
            $netResult = Invoke-AzResourceGraphQuery -Query $netQuery -SubscriptionId $SubscriptionId -UseCache
            $netCount = if ($netResult.Count -gt 0) { $netResult[0].NetworkingServices } else { 0 }
            
            # 3. Appropriate SKUs/Tiers (Premium/High Perf)
            $premiumQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where sku.name contains 'Premium' or sku.name contains 'HighPerformance' or sku.tier == 'Premium'
| summarize PremiumTiers = count()
"@
            $premiumResult = Invoke-AzResourceGraphQuery -Query $premiumQuery -SubscriptionId $SubscriptionId -UseCache
            $premiumCount = if ($premiumResult.Count -gt 0) { $premiumResult[0].PremiumTiers } else { 0 }
            
            # 4. Advisor Performance Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $perfRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # 5. Load Tests for Validation
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| summarize LoadTests = count()
"@
            $loadTestResult = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $loadTestCount = if ($loadTestResult.Count -gt 0) { $loadTestResult[0].LoadTests } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($paasRatio -lt 50) {
                $indicators += "Low PaaS adoption ratio ($paasRatio%) - prefer managed services"
            }
            
            if ($netCount -eq 0) {
                $indicators += "No networking services for load distribution"
            }
            
            if ($premiumCount -eq 0) {
                $indicators += "No premium/high-performance tiers selected"
            }
            
            if ($perfRecs -gt 5) {
                $indicators += "High unresolved performance recommendations ($perfRecs)"
            }
            
            if ($loadTestCount -eq 0) {
                $indicators += "No load testing services for validation"
            }
            
            $evidence = @"
Service Selection Assessment:
- PaaS Ratio: $paasCount PaaS / $iaasCount IaaS ($paasRatio%)
- Networking Services: $netCount
- Premium Tiers: $premiumCount
- Performance Recommendations: $perfRecs
- Load Tests: $loadTestCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE03' `
                    -Status 'Pass' `
                    -Message 'Appropriate services selected for performance' `
                    -Metadata @{
                        PaaSRatio = $paasRatio
                        Networking = $netCount
                        PremiumTiers = $premiumCount
                        PerfRecs = $perfRecs
                        LoadTests = $loadTestCount
                    }
            } else {
                return New-WafResult -CheckId 'PE03' `
                    -Status 'Fail' `
                    -Message "Service selection gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inappropriate services impact performance.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Service Review (Week 1)
1. **Adopt PaaS**: Over IaaS
2. **Add Networking**: LBs/CDNs
3. **Use Premium Tiers**: Where needed

### Phase 2: Validation (Weeks 2-3)
1. **Run Load Tests**: For assessment
2. **Address Recs**: For improvements
3. **Align with Targets**: Review choices

$evidence
"@ `
                    -RemediationScript @"
# Quick Service Selection Setup

# Deploy PaaS (example SQL DB)
New-AzSqlDatabase -ResourceGroupName 'rg' -ServerName 'sql' -DatabaseName 'pe-db' -Edition 'Standard'

# Add Load Balancer
New-AzLoadBalancer -ResourceGroupName 'rg' -Name 'pe-lb' -Location 'eastus' -Sku 'Standard'

Write-Host "Basic services - evaluate for workload"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE03' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
