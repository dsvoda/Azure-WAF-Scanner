<#
.SYNOPSIS
    PE08 - Architecture strategies for optimizing data performance

.DESCRIPTION
    Optimize data performance by using appropriate storage types, partitioning, caching, compression, and indexing. Align data access patterns with workload requirements to enhance efficiency.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:08 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-data-performance
#>

Register-WafCheck -CheckId 'PE08' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Architecture strategies for optimizing data performance' `
    -Description 'Optimize data performance by using appropriate storage types, partitioning, caching, compression, and indexing. Align data access patterns with workload requirements to enhance efficiency.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'DataPerformance', 'Partitioning', 'Caching', 'Compression') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-data-performance' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess data performance optimization indicators
            
            # 1. Caching Services (Redis)
            $cacheQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.cache/redis'
| summarize Caches = count()
"@
            $cacheResult = Invoke-AzResourceGraphQuery -Query $cacheQuery -SubscriptionId $SubscriptionId -UseCache
            $cacheCount = if ($cacheResult.Count -gt 0) { $cacheResult[0].Caches } else { 0 }
            
            # 2. Partitioned Databases (Cosmos DB)
            $partitionQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.documentdb/databaseaccounts'
| extend 
    capabilities = properties.capabilities
| where capabilities contains 'EnablePartitioning'
| summarize PartitionedDBs = count()
"@
            $partitionResult = Invoke-AzResourceGraphQuery -Query $partitionQuery -SubscriptionId $SubscriptionId -UseCache
            $partitionCount = if ($partitionResult.Count -gt 0) { $partitionResult[0].PartitionedDBs } else { 0 }
            
            # 3. Optimized Storage Tiers/Premium
            $optStorageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    sku = tostring(sku.name)
| where sku contains 'Premium' or sku contains 'ZRS'
| summarize OptStorages = count()
"@
            $optStorageResult = Invoke-AzResourceGraphQuery -Query $optStorageQuery -SubscriptionId $SubscriptionId -UseCache
            $optStorageCount = if ($optStorageResult.Count -gt 0) { $optStorageResult[0].OptStorages } else { 0 }
            
            # Total Storage for Percent
            $totalStorageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| summarize TotalStorages = count()
"@
            $totalStorageResult = Invoke-AzResourceGraphQuery -Query $totalStorageQuery -SubscriptionId $SubscriptionId -UseCache
            $totalStorageCount = if ($totalStorageResult.Count -gt 0) { $totalStorageResult[0].TotalStorages } else { 0 }
            
            $optPercent = if ($totalStorageCount -gt 0) { [Math]::Round(($optStorageCount / $totalStorageCount) * 100, 1) } else { 0 }
            
            # 4. SQL Indexes/Performance Tiers
            $sqlOptQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| extend 
    tier = tostring(properties.currentServiceLevelObjective)
| where tier contains 'Premium' or tier contains 'BusinessCritical'
| summarize OptSQL = count()
"@
            $sqlOptResult = Invoke-AzResourceGraphQuery -Query $sqlOptQuery -SubscriptionId $SubscriptionId -UseCache
            $sqlOptCount = if ($sqlOptResult.Count -gt 0) { $sqlOptResult[0].OptSQL } else { 0 }
            
            # 5. Advisor Data Perf Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $dataRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'data|storage|database|index|partition' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($cacheCount -eq 0) {
                $indicators += "No caching services"
            }
            
            if ($partitionCount -eq 0) {
                $indicators += "No partitioned databases"
            }
            
            if ($optPercent -lt 50) {
                $indicators += "Low optimized storage usage ($optPercent%)"
            }
            
            if ($sqlOptCount -eq 0) {
                $indicators += "No optimized SQL tiers"
            }
            
            if ($dataRecs -gt 0) {
                $indicators += "Unresolved data performance recommendations ($dataRecs)"
            }
            
            $evidence = @"
Data Performance Assessment:
- Caches: $cacheCount
- Partitioned DBs: $partitionCount
- Optimized Storage: $optStorageCount / $totalStorageCount ($optPercent%)
- Optimized SQL: $sqlOptCount
- Data Recommendations: $dataRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE08' `
                    -Status 'Pass' `
                    -Message 'Optimized data performance strategies' `
                    -Metadata @{
                        Caches = $cacheCount
                        Partitioned = $partitionCount
                        OptPercent = $optPercent
                        OptSQL = $sqlOptCount
                        DataRecs = $dataRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE08' `
                    -Status 'Fail' `
                    -Message "Data performance gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Suboptimal data strategies affect efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Add Caching**: Redis
2. **Partition Data**: In Cosmos
3. **Use Optimized Tiers**: Premium

### Phase 2: Advanced (Weeks 2-3)
1. **Optimize SQL**: Indexes/tiers
2. **Address Recs**: For improvements
3. **Implement Compression**: Where applicable

$evidence
"@ `
                    -RemediationScript @"
# Quick Data Performance Setup

# Deploy Redis Cache
New-AzRedisCache -ResourceGroupName 'rg' -Name 'pe-cache' -Location 'eastus' -Sku Basic -Size C0

# Enable Partitioning in Cosmos (manual config)

Write-Host "Basic data opt - partition and index"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE08' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
