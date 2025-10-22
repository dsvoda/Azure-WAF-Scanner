<#
.SYNOPSIS
    SE03 - Classify and label workload data

.DESCRIPTION
    Classify and consistently apply sensitivity labels on all workload data and systems involved in data processing. Use classification to influence workload design, implementation, and security prioritization.

.NOTES
    Pillar: Security
    Recommendation: SE:03 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/data-classification
#>

Register-WafCheck -CheckId 'SE03' `
    -Pillar 'Security' `
    -Title 'Classify and label workload data' `
    -Description 'Classify and consistently apply sensitivity labels on all workload data and systems involved in data processing. Use classification to influence workload design, implementation, and security prioritization.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'DataClassification', 'Labeling', 'Sensitivity') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/data-classification' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess data classification indicators
            
            # 1. Check for Microsoft Purview instances (unified data governance for classification)
            $purviewQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.purview/accounts'
| summarize PurviewInstances = count()
"@
            $purviewResult = Invoke-AzResourceGraphQuery -Query $purviewQuery -SubscriptionId $SubscriptionId -UseCache
            
            $purviewCount = if ($purviewResult.Count -gt 0) { $purviewResult[0].PurviewInstances } else { 0 }
            
            # 2. Check for data classification tags on key resources (storage, databases)
            # Looking for tags like 'sensitivity', 'classification', 'dataType', etc.
            $taggedResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.storage/storageaccounts', 'microsoft.sql/servers/databases', 'microsoft.synapse/workspaces', 'microsoft.documentdb/databaseaccounts')
| where isnotempty(tags['sensitivity']) or isnotempty(tags['classification']) or isnotempty(tags['dataType']) or isnotempty(tags['compliance'])
| summarize TaggedResources = count()
"@
            $taggedResult = Invoke-AzResourceGraphQuery -Query $taggedResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            
            $taggedCount = if ($taggedResult.Count -gt 0) { $taggedResult[0].TaggedResources } else { 0 }
            
            # Total data resources for percentage
            $totalDataResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.storage/storageaccounts', 'microsoft.sql/servers/databases', 'microsoft.synapse/workspaces', 'microsoft.documentdb/databaseaccounts')
| summarize TotalDataResources = count()
"@
            $totalDataResult = Invoke-AzResourceGraphQuery -Query $totalDataResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            
            $totalDataCount = if ($totalDataResult.Count -gt 0) { $totalDataResult[0].TotalDataResources } else { 0 }
            
            $tagPercent = if ($totalDataCount -gt 0) { [Math]::Round(($taggedCount / $totalDataCount) * 100, 1) } else { 0 }
            
            # 3. Check for Azure SQL data discovery & classification
            # Note: This requires iterating over SQL servers; may need Get-AzSqlServer and database checks
            $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
            $classifiedDbs = 0
            foreach ($server in $sqlServers) {
                $dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.DatabaseName -ne 'master' }
                foreach ($db in $dbs) {
                    $classification = Get-AzSqlDatabaseSensitivityLabel -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName -DatabaseName $db.DatabaseName -ErrorAction SilentlyContinue
                    if ($classification.Count -gt 0) {
                        $classifiedDbs++
                    }
                }
            }
            
            # 4. Check for Defender for Storage (data protection)
            $defenderStorage = Get-AzSecurityPricing -Name 'StorageAccounts' -ErrorAction SilentlyContinue
            $isDefenderStorageEnabled = $defenderStorage -and $defenderStorage.PricingTier -eq 'Standard'
            
            # 5. Check policies related to data classification
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'data classification' or properties.displayName contains 'sensitivity label' or properties.displayName contains 'Purview'
| summarize DataPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].DataPolicies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($purviewCount -eq 0) {
                $indicators += "No Microsoft Purview instances for data governance and classification"
            }
            
            if ($tagPercent -lt 70) {
                $indicators += "Low data classification tagging coverage ($tagPercent% of $totalDataCount data resources tagged)"
            }
            
            if ($classifiedDbs -eq 0 -and $sqlServers.Count -gt 0) {
                $indicators += "No SQL databases with sensitivity labels configured"
            }
            
            if (-not $isDefenderStorageEnabled) {
                $indicators += "Defender for Storage not enabled for data protection"
            }
            
            if ($policyCount -lt 2) {
                $indicators += "Limited policies for data classification enforcement ($policyCount)"
            }
            
            $evidence = @"
Data Classification Assessment:
- Purview Instances: $purviewCount
- Tagged Data Resources: $taggedCount / $totalDataCount ($tagPercent%)
- Classified SQL DBs: $classifiedDbs
- Defender for Storage: $isDefenderStorageEnabled
- Data Classification Policies: $policyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE03' `
                    -Status 'Pass' `
                    -Message 'Comprehensive data classification and labeling in place' `
                    -Metadata @{
                        PurviewCount = $purviewCount
                        TagPercent = $tagPercent
                        ClassifiedDbs = $classifiedDbs
                        DefenderStorage = $isDefenderStorageEnabled
                        Policies = $policyCount
                    }
            } else {
                return New-WafResult -CheckId 'SE03' `
                    -Status 'Fail' `
                    -Message "Data classification gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate data classification increases risk of improper handling.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Core Classification (Week 1)
1. **Deploy Purview**: For data discovery and labeling
2. **Tag Resources**: Apply sensitivity labels
3. **Enable SQL Classification**: Discover and label databases

### Phase 2: Protection & Policies (Weeks 2-3)
1. **Activate Defender for Storage**: For sensitive data scanning
2. **Assign Policies**: Enforce classification requirements
3. **Review & Maintain**: Regular classification audits

$evidence
"@ `
                    -RemediationScript @"
# Quick Data Classification Setup

# Deploy Purview Account
New-AzPurviewAccount -ResourceGroupName 'rg-data' -Name 'purview-classify' -Location 'eastus' -IdentityType SystemAssigned

# Example: Tag Storage Account
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/mystore' `
    -Tag @{'sensitivity' = 'confidential'; 'compliance' = 'GDPR'} -Operation Merge

# Enable SQL Classification (manual in portal or via SQL cmd)
# For Defender for Storage
Set-AzSecurityPricing -Name 'StorageAccounts' -PricingTier 'Standard'
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE03' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
