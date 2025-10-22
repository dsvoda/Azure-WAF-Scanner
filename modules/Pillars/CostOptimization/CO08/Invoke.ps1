<#
.SYNOPSIS
    CO08 - Optimize environment costs

.DESCRIPTION
    Optimize environment costs by aligning spending to prioritize preproduction, production, operations, and disaster recovery environments. For each environment, consider the required availability, licensing, operating hours and conditions, and security. Nonproduction environments should emulate the production environment. Implement strategic tradeoffs into nonproduction environments.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:08 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-environment-costs
#>

Register-WafCheck -CheckId 'CO08' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize environment costs' `
    -Description 'Optimize environment costs by aligning spending to prioritize preproduction, production, operations, and disaster recovery environments. For each environment, consider the required availability, licensing, operating hours and conditions, and security. Nonproduction environments should emulate the production environment. Implement strategic tradeoffs into nonproduction environments.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'Environments', 'NonProd', 'DR', 'Preproduction') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-environment-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess environment optimization indicators
            
            # 1. Tagging for Environments
            $envTaggedQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['environment']) or isnotempty(tags['Environment'])
| extend envTag = coalesce(tags['environment'], tags['Environment'])
| summarize TaggedResources = count(), UniqueEnvs = dcount(envTag)
"@
            $envTaggedResult = Invoke-AzResourceGraphQuery -Query $envTaggedQuery -SubscriptionId $SubscriptionId -UseCache
            $envTaggedCount = if ($envTaggedResult.Count -gt 0) { $envTaggedResult[0].TaggedResources } else { 0 }
            $uniqueEnvs = if ($envTaggedResult.Count -gt 0) { $envTaggedResult[0].UniqueEnvs } else { 0 }
            
            $totalResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize TotalResources = count()
"@
            $totalResult = Invoke-AzResourceGraphQuery -Query $totalResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            $totalCount = if ($totalResult.Count -gt 0) { $totalResult[0].TotalResources } else { 0 }
            
            $envTagPercent = if ($totalCount -gt 0) { [Math]::Round(($envTaggedCount / $totalCount) * 100, 1) } else { 0 }
            
            # 2. Non-Prod Scheduling/Automation
            $nonProdQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where tags['environment'] in~ ('dev', 'test', 'staging', 'qa', 'uat') or tags['Environment'] in~ ('dev', 'test', 'staging', 'qa', 'uat')
| summarize NonProdResources = count()
"@
            $nonProdResult = Invoke-AzResourceGraphQuery -Query $nonProdQuery -SubscriptionId $SubscriptionId -UseCache
            $nonProdCount = if ($nonProdResult.Count -gt 0) { $nonProdResult[0].NonProdResources } else { 0 }
            
            $scheduledQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where (tags['environment'] in~ ('dev', 'test', 'staging', 'qa', 'uat') or tags['Environment'] in~ ('dev', 'test', 'staging', 'qa', 'uat')) 
  and (tags['shutdownSchedule'] != '' or tags['autoShutdown'] != '' or name contains 'schedule')
| summarize ScheduledNonProd = count()
"@
            $scheduledResult = Invoke-AzResourceGraphQuery -Query $scheduledQuery -SubscriptionId $SubscriptionId -UseCache
            $scheduledCount = if ($scheduledResult.Count -gt 0) { $scheduledResult[0].ScheduledNonProd } else { 0 }
            
            $nonProdScheduledPercent = if ($nonProdCount -gt 0) { [Math]::Round(($scheduledCount / $nonProdCount) * 100, 1) } else { 0 }
            
            # 3. DR Configurations (Backup/Recovery Vaults)
            $drQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults'
| summarize RecoveryVaults = count()
"@
            $drResult = Invoke-AzResourceGraphQuery -Query $drQuery -SubscriptionId $SubscriptionId -UseCache
            $drCount = if ($drResult.Count -gt 0) { $drResult[0].RecoveryVaults } else { 0 }
            
            # 4. Dev/Test Pricing SKUs
            $devTestSkuQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where (tags['environment'] in~ ('dev', 'test') or tags['Environment'] in~ ('dev', 'test')) 
  and (sku.name contains 'dev' or sku.name contains 'test' or properties.licenseType contains 'dev')
| summarize DevTestSKUs = count()
"@
            $devTestSkuResult = Invoke-AzResourceGraphQuery -Query $devTestSkuQuery -SubscriptionId $SubscriptionId -UseCache
            $devTestSkuCount = if ($devTestSkuResult.Count -gt 0) { $devTestSkuResult[0].DevTestSKUs } else { 0 }
            
            # 5. Policies for Environment Constraints
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'environment' or properties.displayName contains 'nonprod' or properties.displayName contains 'dr' or properties.displayName contains 'preproduction'
| summarize EnvPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].EnvPolicies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($envTagPercent -lt 70) {
                $indicators += "Low environment tagging coverage ($envTagPercent%)"
            }
            
            if ($nonProdScheduledPercent -lt 70) {
                $indicators += "Low scheduling on non-prod resources ($nonProdScheduledPercent%)"
            }
            
            if ($drCount -eq 0) {
                $indicators += "No recovery vaults for DR optimization"
            }
            
            if ($devTestSkuCount -eq 0) {
                $indicators += "No dev/test SKUs for pricing optimization"
            }
            
            if ($policyCount -eq 0) {
                $indicators += "No policies for environment constraints"
            }
            
            $evidence = @"
Environment Cost Assessment:
- Environment Tagging: $envTaggedCount / $totalCount ($envTagPercent%), Unique Envs: $uniqueEnvs
- Non-Prod Resources: $nonProdCount (Scheduled: $nonProdScheduledPercent%)
- Recovery Vaults: $drCount
- Dev/Test SKUs: $devTestSkuCount
- Environment Policies: $policyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO08' `
                    -Status 'Pass' `
                    -Message 'Optimized environment costs with proper prioritization' `
                    -Metadata @{
                        EnvTagPercent = $envTagPercent
                        UniqueEnvs = $uniqueEnvs
                        NonProdScheduled = $nonProdScheduledPercent
                        DRVaults = $drCount
                        DevTestSKUs = $devTestSkuCount
                        Policies = $policyCount
                    }
            } else {
                return New-WafResult -CheckId 'CO08' `
                    -Status 'Fail' `
                    -Message "Environment cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unoptimized environments lead to wasted spending.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Tagging & Scheduling (Week 1)
1. **Tag Environments**: Prod/non-prod
2. **Schedule Non-Prod**: Shutdowns
3. **Set Up DR**: Optimized configs

### Phase 2: Advanced (Weeks 2-3)
1. **Use Dev/Test Pricing**: For SKUs
2. **Enforce Policies**: Per env
3. **Review Value/Costs**: Align spending

$evidence
"@ `
                    -RemediationScript @"
# Quick Environment Optimization Setup

# Tag Resource for Environment
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm' -Tag @{'environment' = 'dev'} -Operation Merge

# Schedule Shutdown for Non-Prod
New-AzAutomationSchedule -AutomationAccountName 'auto' -Name 'dev-shutdown' -StartTime (Get-Date).AddHours(1) -TimeZone 'UTC' -ResourceGroupName 'rg' -Recurrence 'Daily'

Write-Host "Basic env optimization - expand with DR and policies"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO08' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
