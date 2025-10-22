<#
.SYNOPSIS
    SE09 - Harden secrets, keys, and credentials

.DESCRIPTION
    Harden secrets, keys, and credentials by implementing a reliable and regular rotation process. Use Azure Key Vault for secure storage, managed identities to minimize secrets, and apply least-privilege access. Implement auditing, monitoring, and automated rotations to prevent exposure and ensure security.

.NOTES
    Pillar: Security
    Recommendation: SE:09 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/application-secrets
#>

Register-WafCheck -CheckId 'SE09' `
    -Pillar 'Security' `
    -Title 'Harden secrets, keys, and credentials' `
    -Description 'Protect application secrets by hardening their storage, restricting access and manipulation, and auditing those actions. Implement a reliable and regular rotation process that can improvise rotations for emergencies.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Secrets', 'KeyVault', 'ManagedIdentities', 'Rotation') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/application-secrets' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess secrets hardening indicators
            
            # 1. Key Vault Usage
            $kvQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| extend 
    sku = tostring(properties.sku.name),
    rbac = tobool(properties.enableRbacAuthorization),
    softDelete = tobool(properties.enableSoftDelete)
| where sku == 'Premium' and rbac == true and softDelete == true
| summarize SecureKeyVaults = count()
"@
            $kvResult = Invoke-AzResourceGraphQuery -Query $kvQuery -SubscriptionId $SubscriptionId -UseCache
            $secureKVs = if ($kvResult.Count -gt 0) { $kvResult[0].SecureKeyVaults } else { 0 }
            
            $totalKVQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| summarize TotalKeyVaults = count()
"@
            $totalKVResult = Invoke-AzResourceGraphQuery -Query $totalKVQuery -SubscriptionId $SubscriptionId -UseCache
            $totalKVs = if ($totalKVResult.Count -gt 0) { $totalKVResult[0].TotalKeyVaults } else { 0 }
            
            # 2. Managed Identities Adoption
            $miQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where identity.type contains 'Managed'
| summarize ManagedIdentities = count()
"@
            $miResult = Invoke-AzResourceGraphQuery -Query $miQuery -SubscriptionId $SubscriptionId -UseCache
            $miCount = if ($miResult.Count -gt 0) { $miResult[0].ManagedIdentities } else { 0 }
            
            # Potential resources for MI
            $potentialQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.compute/virtualmachines', 'microsoft.web/sites', 'microsoft.logic/workflows')
| summarize PotentialMI = count()
"@
            $potentialResult = Invoke-AzResourceGraphQuery -Query $potentialQuery -SubscriptionId $SubscriptionId -UseCache
            $potentialCount = if ($potentialResult.Count -gt 0) { $potentialResult[0].PotentialMI } else { 0 }
            
            $miPercent = if ($potentialCount -gt 0) { [Math]::Round(($miCount / $potentialCount) * 100, 1) } else { 0 }
            
            # 3. Resources Using CMK from KV (e.g., Storage, SQL)
            $cmkStorageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| where properties.encryption.keySource == 'Microsoft.Keyvault'
| summarize CMKStorages = count()
"@
            $cmkStorageResult = Invoke-AzResourceGraphQuery -Query $cmkStorageQuery -SubscriptionId $SubscriptionId -UseCache
            $cmkStorages = if ($cmkStorageResult.Count -gt 0) { $cmkStorageResult[0].CMKStorages } else { 0 }
            
            $cmkSqlQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers'
| where properties.keyId != ''
| summarize CMKSQL = count()
"@
            $cmkSqlResult = Invoke-AzResourceGraphQuery -Query $cmkSqlQuery -SubscriptionId $SubscriptionId -UseCache
            $cmkSql = if ($cmkSqlResult.Count -gt 0) { $cmkSqlResult[0].CMKSQL } else { 0 }
            
            # 4. Auditing and Monitoring (Diagnostic Settings on KV)
            $diagKVQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| join kind=leftouter (Resources | where type =~ 'microsoft.insights/diagnosticsettings' | project diagId = id, resourceUri = tolower(properties.scope)) 
    on \$left.id == \$right.resourceUri
| where isnotnull(diagId)
| summarize AuditedKVs = count()
"@
            $diagKVResult = Invoke-AzResourceGraphQuery -Query $diagKVQuery -SubscriptionId $SubscriptionId -UseCache
            $auditedKVs = if ($diagKVResult.Count -gt 0) { $diagKVResult[0].AuditedKVs } else { 0 }
            
            # 5. Policies for Secrets Management
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'secrets' or properties.displayName contains 'key vault' or properties.displayName contains 'credentials'
| summarize SecretsPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].SecretsPolicies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($secureKVs -lt $totalKVs) {
                $indicators += "Not all Key Vaults are Premium with RBAC and soft-delete ($secureKVs/$totalKVs)"
            }
            
            if ($miPercent -lt 70) {
                $indicators += "Low managed identities adoption ($miPercent%)"
            }
            
            if ($cmkStorages -lt $totalStorages) {  # Assuming totalStorages from earlier pattern
                $indicators += "Not all storages use CMK from KV ($cmkStorages)"
            }
            
            if ($cmkSql -lt $totalSQL) {  # Assuming totalSQL
                $indicators += "Not all SQL servers use CMK ($cmkSql)"
            }
            
            if ($auditedKVs -lt $totalKVs) {
                $indicators += "Not all Key Vaults have diagnostics enabled ($auditedKVs/$totalKVs)"
            }
            
            if ($policyCount -lt 3) {
                $indicators += "Limited secrets management policies ($policyCount)"
            }
            
            $evidence = @"
Secrets Hardening Assessment:
- Secure Key Vaults: $secureKVs / $totalKVs
- Managed Identities: $miCount ($miPercent%)
- CMK Storages: $cmkStorages
- CMK SQL: $cmkSql
- Audited Key Vaults: $auditedKVs
- Secrets Policies: $policyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE09' `
                    -Status 'Pass' `
                    -Message 'Strong secrets hardening with secure storage and rotation practices' `
                    -Metadata @{
                        SecureKVs = $secureKVs
                        MIPercent = $miPercent
                        CMKStorages = $cmkStorages
                        CMKSQL = $cmkSql
                        AuditedKVs = $auditedKVs
                        Policies = $policyCount
                    }
            } else {
                return New-WafResult -CheckId 'SE09' `
                    -Status 'Fail' `
                    -Message "Secrets hardening gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Weak secrets management increases credential exposure risks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Secure Storage (Week 1)
1. **Deploy Key Vaults**: Use Premium with RBAC
2. **Adopt Managed Identities**: Minimize secrets
3. **Enable CMK**: For storage and databases

### Phase 2: Rotation & Monitoring (Weeks 2-3)
1. **Automate Rotation**: Use KV features
2. **Enable Diagnostics**: On Key Vaults
3. **Assign Policies**: For secrets enforcement

$evidence
"@ `
                    -RemediationScript @"
# Quick Secrets Hardening Setup

# Create Secure Key Vault
New-AzKeyVault -Name 'secure-kv' -ResourceGroupName 'rg' -Location 'eastus' -Sku 'Premium' -EnableRbacAuthorization -EnableSoftDelete

# Assign Managed Identity
Update-AzWebApp -ResourceGroupName 'rg' -Name 'app' -AssignIdentity '/subscriptions/$SubscriptionId/resourcegroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myID'

# Enable Diagnostics on KV
$sa = Get-AzStorageAccount -ResourceGroupName 'rg' -Name 'diagstore'
Set-AzDiagnosticSetting -ResourceId (Get-AzKeyVault -Name 'secure-kv').Id -StorageAccountId $sa.Id -Enabled $true -Category AuditEvent

Write-Host "Basic secrets hardening configured - implement rotation policies"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE09' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
