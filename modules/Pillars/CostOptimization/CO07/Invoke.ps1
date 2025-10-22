<#
.SYNOPSIS
    CO07 - Optimize workload component costs

.DESCRIPTION
    Optimize the costs of individual workload components by selecting the most cost-effective resources that meet performance requirements. Use autoscaling, right-sizing, and efficient data storage strategies.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:07 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-component-costs
#>

Register-WafCheck -CheckId 'CO07' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize workload component costs' `
    -Description 'Optimize the costs of individual workload components by selecting the most cost-effective resources that meet performance requirements. Use autoscaling, right-sizing, and efficient data storage strategies.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'RightSizing', 'Autoscaling', 'StorageTiers', 'Serverless') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-component-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess component optimization indicators
            
            # 1. Autoscaling Enabled
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize AutoscaleSettings = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].AutoscaleSettings } else { 0 }
            
            # 2. Advisor Right-Sizing Recommendations (Unresolved)
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $rightSizeRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'underutilized|resize|right-size' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # 3. Efficient Storage Tiers (Cool/Archive Usage)
            $storageTierQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts/blobservices/containers'
| extend 
    tier = tostring(properties.accessTier)
| where tier == 'Cool' or tier == 'Archive'
| summarize EfficientTiers = count()
"@
            $storageTierResult = Invoke-AzResourceGraphQuery -Query $storageTierQuery -SubscriptionId $SubscriptionId -UseCache
            $efficientTiers = if ($storageTierResult.Count -gt 0) { $storageTierResult[0].EfficientTiers } else { 0 }
            
            $totalContainersQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts/blobservices/containers'
| summarize TotalContainers = count()
"@
            $totalContainersResult = Invoke-AzResourceGraphQuery -Query $totalContainersQuery -SubscriptionId $SubscriptionId -UseCache
            $totalContainers = if ($totalContainersResult.Count -gt 0) { $totalContainersResult[0].TotalContainers } else { 0 }
            
            $tierPercent = if ($totalContainers -gt 0) { [Math]::Round(($efficientTiers / $totalContainers) * 100, 1) } else { 0 }
            
            # 4. Serverless Resources (Functions, Logic Apps)
            $serverlessQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites' and kind contains 'functionapp' or type =~ 'microsoft.logic/workflows'
| summarize ServerlessResources = count()
"@
            $serverlessResult = Invoke-AzResourceGraphQuery -Query $serverlessQuery -SubscriptionId $SubscriptionId -UseCache
            $serverlessCount = if ($serverlessResult.Count -gt 0) { $serverlessResult[0].ServerlessResources } else { 0 }
            
            # 5. Database Optimization (Elastic Pools, Serverless DBs)
            $dbOptQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/elasticpools' or (type =~ 'microsoft.sql/servers/databases' and properties.computeModel == 'Serverless')
| summarize OptimizedDBs = count()
"@
            $dbOptResult = Invoke-AzResourceGraphQuery -Query $dbOptQuery -SubscriptionId $SubscriptionId -UseCache
            $dbOptCount = if ($dbOptResult.Count -gt 0) { $dbOptResult[0].OptimizedDBs } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling for dynamic optimization"
            }
            
            if ($rightSizeRecs -gt 5) {
                $indicators += "High unresolved right-sizing recommendations ($rightSizeRecs)"
            }
            
            if ($tierPercent -lt 30) {
                $indicators += "Low usage of efficient storage tiers ($tierPercent%)"
            }
            
            if ($serverlessCount -eq 0) {
                $indicators += "No serverless resources for pay-per-use"
            }
            
            if ($dbOptCount -eq 0) {
                $indicators += "No optimized databases (elastic/serverless)"
            }
            
            $evidence = @"
Component Optimization Assessment:
- Autoscaling Settings: $autoscaleCount
- Right-Size Recommendations: $rightSizeRecs
- Efficient Storage Tiers: $efficientTiers / $totalContainers ($tierPercent%)
- Serverless Resources: $serverlessCount
- Optimized Databases: $dbOptCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO07' `
                    -Status 'Pass' `
                    -Message 'Optimized workload components for cost-efficiency' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        RightSizeRecs = $rightSizeRecs
                        TierPercent = $tierPercent
                        Serverless = $serverlessCount
                        DbOpt = $dbOptCount
                    }
            } else {
                return New-WafResult -CheckId 'CO07' `
                    -Status 'Fail' `
                    -Message "Component cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Suboptimal components increase unnecessary costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Scaling & Sizing (Week 1)
1. **Enable Autoscaling**: Where appropriate
2. **Right-Size Resources**: Per recommendations
3. **Use Efficient Tiers**: For storage

### Phase 2: Advanced Optimization (Weeks 2-3)
1. **Adopt Serverless**: For variable loads
2. **Optimize Databases**: Use elastic/serverless
3. **Monitor Utilization**: Adjust as needed

$evidence
"@ `
                    -RemediationScript @"
# Quick Component Optimization Setup

# Enable Autoscaling on VMSS
New-AzAutoscaleSetting -Name 'opt-scale' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1)

# Change Storage Tier
Set-AzStorageBlobTier -Container 'container' -Blob 'blob' -Tier 'Cool' -Context (New-AzStorageContext -StorageAccountName 'store' -StorageAccountKey 'key')

Write-Host "Basic optimizations - review Advisor for more"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO07' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
