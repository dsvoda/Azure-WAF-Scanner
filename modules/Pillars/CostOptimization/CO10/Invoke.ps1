<#
.SYNOPSIS
    CO10 - Optimize data costs

.DESCRIPTION
    Optimize data costs by using data lifecycle management, compression, deduplication, and tiering. Use the appropriate storage account type, access tier, replication strategy, and performance tier for your workload.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:10 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-data-costs
#>

Register-WafCheck -CheckId 'CO10' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize data costs' `
    -Description 'Optimize data costs by using data lifecycle management, compression, deduplication, and tiering. Use the appropriate storage account type, access tier, replication strategy, and performance tier for your workload.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'DataStorage', 'Tiering', 'Replication', 'Lifecycle') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-data-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess data cost optimization indicators
            
            # 1. Storage Access Tiers (Cool/Archive for optimization)
            $tierQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    tier = tostring(properties.accessTier)
| where tier == 'Cool' or tier == 'Archive'
| summarize OptimizedTiers = count()
"@
            $tierResult = Invoke-AzResourceGraphQuery -Query $tierQuery -SubscriptionId $SubscriptionId -UseCache
            $optimizedTiers = if ($tierResult.Count -gt 0) { $tierResult[0].OptimizedTiers } else { 0 }
            
            $totalStorageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| summarize TotalStorage = count()
"@
            $totalStorageResult = Invoke-AzResourceGraphQuery -Query $totalStorageQuery -SubscriptionId $SubscriptionId -UseCache
            $totalStorage = if ($totalStorageResult.Count -gt 0) { $totalStorageResult[0].TotalStorage } else { 0 }
            
            $tierPercent = if ($totalStorage -gt 0) { [Math]::Round(($optimizedTiers / $totalStorage) * 100, 1) } else { 0 }
            
            # 2. Lifecycle Management Policies
            $lifecycleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts/managementpolicies'
| summarize LifecyclePolicies = count()
"@
            $lifecycleResult = Invoke-AzResourceGraphQuery -Query $lifecycleQuery -SubscriptionId $SubscriptionId -UseCache
            $lifecycleCount = if ($lifecycleResult.Count -gt 0) { $lifecycleResult[0].LifecyclePolicies } else { 0 }
            
            # 3. Replication Strategy (LRS/ZRS for cost vs GRS/RA-GRS)
            $replQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    sku = tostring(sku.name)
| where sku contains 'LRS' or sku contains 'ZRS'
| summarize LowCostRepl = count()
"@
            $replResult = Invoke-AzResourceGraphQuery -Query $replQuery -SubscriptionId $SubscriptionId -UseCache
            $lowCostRepl = if ($replResult.Count -gt 0) { $replResult[0].LowCostRepl } else { 0 }
            
            # 4. Backup Optimization (Vaults with policies)
            $backupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults/backuppolicies'
| summarize BackupPolicies = count()
"@
            $backupResult = Invoke-AzResourceGraphQuery -Query $backupQuery -SubscriptionId $SubscriptionId -UseCache
            $backupCount = if ($backupResult.Count -gt 0) { $backupResult[0].BackupPolicies } else { 0 }
            
            # 5. Advisor Data Cost Recs
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $dataRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'storage|data|backup|tier|replication' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($tierPercent -lt 30) {
                $indicators += "Low usage of optimized tiers ($tierPercent%)"
            }
            
            if ($lifecycleCount -eq 0) {
                $indicators += "No lifecycle policies for data management"
            }
            
            if ($lowCostRepl -lt $totalStorage) {
                $indicators += "Not all storage using low-cost replication ($lowCostRepl/$totalStorage)"
            }
            
            if ($backupCount -eq 0) {
                $indicators += "No backup policies for optimized retention"
            }
            
            if ($dataRecs -gt 0) {
                $indicators += "Unresolved data cost recommendations ($dataRecs)"
            }
            
            $evidence = @"
Data Cost Assessment:
- Optimized Tiers: $optimizedTiers / $totalStorage ($tierPercent%)
- Lifecycle Policies: $lifecycleCount
- Low-Cost Replication: $lowCostRepl / $totalStorage
- Backup Policies: $backupCount
- Data Recommendations: $dataRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO10' `
                    -Status 'Pass' `
                    -Message 'Optimized data costs with efficient management' `
                    -Metadata @{
                        TierPercent = $tierPercent
                        Lifecycle = $lifecycleCount
                        LowRepl = $lowCostRepl
                        Backups = $backupCount
                        DataRecs = $dataRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO10' `
                    -Status 'Fail' `
                    -Message "Data cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unoptimized data leads to high storage costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Tiering & Lifecycle (Week 1)
1. **Set Access Tiers**: Cool/Archive
2. **Enable Lifecycle**: For auto-tiering
3. **Use Low-Cost Repl**: LRS/ZRS

### Phase 2: Advanced (Weeks 2-3)
1. **Optimize Backups**: Retention policies
2. **Compress/Dedup**: Data
3. **Address Recommendations**: For savings

$evidence
"@ `
                    -RemediationScript @"
# Quick Data Optimization Setup

# Set Storage Tier
Update-AzStorageAccount -ResourceGroupName 'rg' -Name 'store' -AccessTier 'Cool'

# Create Lifecycle Policy
$rule = New-AzStorageAccountManagementPolicyRule -Name 'tier-rule' -Enabled $true -Filter (New-AzStorageAccountManagementPolicyFilter -PrefixMatch @('container/') -TierToCoolAfterDaysSinceModificationGreaterThan 30)
$action = New-AzStorageAccountManagementPolicyAction -BaseBlob (New-AzStorageAccountManagementPolicyBaseBlob -TierToCoolAfterDaysSinceModificationGreaterThan 30)
New-AzStorageAccountManagementPolicy -ResourceGroupName 'rg' -StorageAccountName 'store' -Policy (New-AzStorageAccountManagementPolicy -Rule $rule -Action $action)

Write-Host "Basic data optimization - expand with compression and dedup"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO10' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
