<#
.SYNOPSIS
    CO14 - Use consolidation

.DESCRIPTION
    Use consolidation by sharing resources or services to reduce costs. Consider multi-tenant architectures, shared databases, and consolidated infrastructure to achieve economies of scale.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:14 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/consolidation
#>

Register-WafCheck -CheckId 'CO14' `
    -Pillar 'CostOptimization' `
    -Title 'Use consolidation' `
    -Description 'Use consolidation by sharing resources or services to reduce costs. Consider multi-tenant architectures, shared databases, and consolidated infrastructure to achieve economies of scale.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'Consolidation', 'MultiTenant', 'SharedResources', 'EconomiesOfScale') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/consolidation' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess consolidation indicators
            
            # 1. Shared Databases (Elastic Pools)
            $elasticPoolQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/elasticpools'
| summarize ElasticPools = count()
"@
            $elasticPoolResult = Invoke-AzResourceGraphQuery -Query $elasticPoolQuery -SubscriptionId $SubscriptionId -UseCache
            $elasticPoolCount = if ($elasticPoolResult.Count -gt 0) { $elasticPoolResult[0].ElasticPools } else { 0 }
            
            # 2. Multi-Tenant Indicators (Tags like 'tenant')
            $multiTenantQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['tenant']) or isnotempty(tags['multiTenant']) or name contains 'shared'
| summarize MultiTenantResources = count()
"@
            $multiTenantResult = Invoke-AzResourceGraphQuery -Query $multiTenantQuery -SubscriptionId $SubscriptionId -UseCache
            $multiTenantCount = if ($multiTenantResult.Count -gt 0) { $multiTenantResult[0].MultiTenantResources } else { 0 }
            
            # 3. Shared Infrastructure (Key Vaults, Caches shared across RGs)
            $sharedInfraQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.keyvault/vaults', 'microsoft.cache/redis', 'microsoft.network/loadbalancers')
| summarize SharedInfra = count()
"@
            $sharedInfraResult = Invoke-AzResourceGraphQuery -Query $sharedInfraQuery -SubscriptionId $SubscriptionId -UseCache
            $sharedInfraCount = if ($sharedInfraResult.Count -gt 0) { $sharedInfraResult[0].SharedInfra } else { 0 }
            
            # 4. Management Groups for Consolidation
            $mgQuery = @"
ManagementGroupResources
| where subscriptionId == '$SubscriptionId'
| summarize ManagementGroups = count()
"@
            $mgResult = Invoke-AzResourceGraphQuery -Query $mgQuery -SubscriptionId $SubscriptionId -UseCache
            $mgCount = if ($mgResult.Count -gt 0) { $mgResult[0].ManagementGroups } else { 0 }
            
            # 5. Advisor Consolidation Recs
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $consolRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'consolidat|shared|multi-tenant' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($elasticPoolCount -eq 0) {
                $indicators += "No elastic pools for database consolidation"
            }
            
            if ($multiTenantCount -eq 0) {
                $indicators += "No multi-tenant tagged resources"
            }
            
            if ($sharedInfraCount -eq 0) {
                $indicators += "No shared infrastructure resources"
            }
            
            if ($mgCount -eq 0) {
                $indicators += "No management groups for organizational consolidation"
            }
            
            if ($consolRecs -gt 0) {
                $indicators += "Unresolved consolidation recommendations ($consolRecs)"
            }
            
            $evidence = @"
Consolidation Assessment:
- Elastic Pools: $elasticPoolCount
- Multi-Tenant Resources: $multiTenantCount
- Shared Infra: $sharedInfraCount
- Management Groups: $mgCount
- Consolidation Recs: $consolRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO14' `
                    -Status 'Pass' `
                    -Message 'Effective use of consolidation for economies of scale' `
                    -Metadata @{
                        ElasticPools = $elasticPoolCount
                        MultiTenant = $multiTenantCount
                        SharedInfra = $sharedInfraCount
                        ManagementGroups = $mgCount
                        ConsolRecs = $consolRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO14' `
                    -Status 'Fail' `
                    -Message "Consolidation gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of consolidation misses scale economies.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Shared Resources (Week 1)
1. **Use Elastic Pools**: For DBs
2. **Tag Multi-Tenant**: Resources
3. **Deploy Shared Infra**: KV/Cache

### Phase 2: Organization (Weeks 2-3)
1. **Create MG**: For structure
2. **Address Recs**: For savings
3. **Review Architecture**: For sharing

$evidence
"@ `
                    -RemediationScript @"
# Quick Consolidation Setup

# Create Elastic Pool
New-AzSqlElasticPool -ResourceGroupName 'rg' -ServerName 'sql' -ElasticPoolName 'shared-pool' -Edition 'Standard' -Dtu 100 -DatabaseDtuMin 10 -DatabaseDtuMax 100

# Tag for Multi-Tenant
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/store' -Tag @{'tenant' = 'shared'} -Operation Merge

Write-Host "Basic consolidation - expand with MG and shared services"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO14' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
