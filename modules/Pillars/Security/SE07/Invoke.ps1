<#
.SYNOPSIS
    SE07 - Encrypt workload data

.DESCRIPTION
    Encrypt workload data using modern industry-standard methods to protect confidentiality and integrity. Align the scope of encryption with data classifications. Prioritize native encryption mechanisms provided by the platform. Consider the performance and complexity tradeoffs, and potential recovery implications of encryption.

.NOTES
    Pillar: Security
    Recommendation: SE:07 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/encryption
#>

Register-WafCheck -CheckId 'SE07' `
    -Pillar 'Security' `
    -Title 'Encrypt workload data' `
    -Description 'Encrypt workload data using modern industry-standard methods to protect confidentiality and integrity. Align the scope of encryption with data classifications. Prioritize native encryption mechanisms provided by the platform. Consider the performance and complexity tradeoffs, and potential recovery implications of encryption.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Encryption', 'DataProtection', 'KeyManagement') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/encryption' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess encryption indicators
            
            # 1. Storage Accounts - Encryption at Rest
            $storageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    keySource = tostring(properties.encryption.keySource),
    services = properties.encryption.services
| where keySource == 'Microsoft.Keyvault' or keySource == 'Microsoft.Storage'
| summarize EncryptedStorages = count()
"@
            $storageResult = Invoke-AzResourceGraphQuery -Query $storageQuery -SubscriptionId $SubscriptionId -UseCache
            $encryptedStorages = if ($storageResult.Count -gt 0) { $storageResult[0].EncryptedStorages } else { 0 }
            
            $totalStorageQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.storage/storageaccounts'
| summarize TotalStorages = count()
"@
            $totalStorageResult = Invoke-AzResourceGraphQuery -Query $totalStorageQuery -SubscriptionId $SubscriptionId -UseCache
            $totalStorages = if ($totalStorageResult.Count -gt 0) { $totalStorageResult[0].TotalStorages } else { 0 }
            
            $storagePercent = if ($totalStorages -gt 0) { [Math]::Round(($encryptedStorages / $totalStorages) * 100, 1) } else { 0 }
            
            # 2. VM Disk Encryption
            $vmDiskQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/disks'
| extend 
    encryptionType = tostring(properties.encryption.type)
| where encryptionType != 'EncryptionAtRestWithPlatformKey'
| summarize EncryptedDisks = count()
"@
            $vmDiskResult = Invoke-AzResourceGraphQuery -Query $vmDiskQuery -SubscriptionId $SubscriptionId -UseCache
            $encryptedDisks = if ($vmDiskResult.Count -gt 0) { $vmDiskResult[0].EncryptedDisks } else { 0 }
            
            $totalDisksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/disks'
| summarize TotalDisks = count()
"@
            $totalDisksResult = Invoke-AzResourceGraphQuery -Query $totalDisksQuery -SubscriptionId $SubscriptionId -UseCache
            $totalDisks = if ($totalDisksResult.Count -gt 0) { $totalDisksResult[0].TotalDisks } else { 0 }
            
            $diskPercent = if ($totalDisks -gt 0) { [Math]::Round(($encryptedDisks / $totalDisks) * 100, 1) } else { 0 }
            
            # 3. SQL TDE
            $sqlTDEQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| extend 
    tdeStatus = tostring(properties.transparentDataEncryption.status)
| where tdeStatus == 'Enabled'
| summarize TDEDatabases = count()
"@
            $sqlTDEResult = Invoke-AzResourceGraphQuery -Query $sqlTDEQuery -SubscriptionId $SubscriptionId -UseCache
            $tdeDbs = if ($sqlTDEResult.Count -gt 0) { $sqlTDEResult[0].TDEDatabases } else { 0 }
            
            $totalSqlQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/databases'
| where name != 'master'
| summarize TotalDatabases = count()
"@
            $totalSqlResult = Invoke-AzResourceGraphQuery -Query $totalSqlQuery -SubscriptionId $SubscriptionId -UseCache
            $totalDbs = if ($totalSqlResult.Count -gt 0) { $totalSqlResult[0].TotalDatabases } else { 0 }
            
            $sqlPercent = if ($totalDbs -gt 0) { [Math]::Round(($tdeDbs / $totalDbs) * 100, 1) } else { 0 }
            
            # 4. Key Vaults with HSM/RBAC
            $kvQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| extend 
    sku = tostring(properties.sku.name),
    rbac = tobool(properties.enableRbacAuthorization)
| where sku == 'Premium' and rbac == true
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
            
            # 5. Transit Encryption: App Gateway TLS 1.2+
            $agQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgateways'
| extend 
    minTls = tostring(properties.sslPolicy.minProtocolVersion)
| where minTls == 'TLSv1_2'
| summarize SecureGateways = count()
"@
            $agResult = Invoke-AzResourceGraphQuery -Query $agQuery -SubscriptionId $SubscriptionId -UseCache
            $secureAGs = if ($agResult.Count -gt 0) { $agResult[0].SecureGateways } else { 0 }
            
            $totalAGQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/applicationgateways'
| summarize TotalGateways = count()
"@
            $totalAGResult = Invoke-AzResourceGraphQuery -Query $totalAGQuery -SubscriptionId $SubscriptionId -UseCache
            $totalAGs = if ($totalAGResult.Count -gt 0) { $totalAGResult[0].TotalGateways } else { 0 }
            
            # 6. Confidential Computing
            $ccQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| extend 
    securityType = tostring(properties.securityProfile.securityType)
| where securityType == 'ConfidentialVM'
| summarize ConfidentialVMs = count()
"@
            $ccResult = Invoke-AzResourceGraphQuery -Query $ccQuery -SubscriptionId $SubscriptionId -UseCache
            $ccVMs = if ($ccResult.Count -gt 0) { $ccResult[0].ConfidentialVMs } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($storagePercent -lt 100) {
                $indicators += "Incomplete storage encryption coverage ($storagePercent%)"
            }
            
            if ($diskPercent -lt 80) {
                $indicators += "Low VM disk encryption adoption ($diskPercent%)"
            }
            
            if ($sqlPercent -lt 100) {
                $indicators += "Not all SQL databases have TDE enabled ($sqlPercent%)"
            }
            
            if ($secureKVs -lt $totalKVs) {
                $indicators += "Not all Key Vaults using Premium HSM with RBAC ($secureKVs/$totalKVs)"
            }
            
            if ($secureAGs -lt $totalAGs) {
                $indicators += "Not all App Gateways enforcing TLS 1.2+ ($secureAGs/$totalAGs)"
            }
            
            if ($ccVMs -eq 0) {
                $indicators += "No confidential VMs for in-use encryption"
            }
            
            $evidence = @"
Encryption Assessment:
- Storage Encryption: $encryptedStorages / $totalStorages ($storagePercent%)
- VM Disk Encryption: $encryptedDisks / $totalDisks ($diskPercent%)
- SQL TDE: $tdeDbs / $totalDbs ($sqlPercent%)
- Secure Key Vaults: $secureKVs / $totalKVs
- Secure App Gateways: $secureAGs / $totalAGs
- Confidential VMs: $ccVMs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE07' `
                    -Status 'Pass' `
                    -Message 'Comprehensive encryption across rest, transit, and use' `
                    -Metadata @{
                        StoragePercent = $storagePercent
                        DiskPercent = $diskPercent
                        SQLPercent = $sqlPercent
                        SecureKVs = $secureKVs
                        SecureAGs = $secureAGs
                        CCVMs = $ccVMs
                    }
            } else {
                return New-WafResult -CheckId 'SE07' `
                    -Status 'Fail' `
                    -Message "Encryption gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate data encryption exposes sensitive information.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: At-Rest Encryption (Week 1)
1. **Enable Storage SSE**: With CMK
2. **Encrypt VM Disks**: Using ADE
3. **Activate SQL TDE**: With CMK

### Phase 2: Transit & Use (Weeks 2-3)
1. **Enforce TLS 1.2+**: On gateways
2. **Use Key Vault HSM**: For keys
3. **Deploy Confidential VMs**: For sensitive processing

$evidence
"@ `
                    -RemediationScript @"
# Quick Encryption Setup

# Storage CMK
Update-AzStorageAccount -ResourceGroupName 'rg' -Name 'store' -AssignIdentity
$kv = Get-AzKeyVault -VaultName 'kv'
Set-AzStorageAccount -ResourceGroupName 'rg' -Name 'store' -KeyvaultEncryption -KeyName 'key' -KeyVersion 'ver' -KeyVaultUri $kv.VaultUri

# VM Disk Encryption
Set-AzVMDiskEncryptionExtension -ResourceGroupName 'rg' -VMName 'vm' -DiskEncryptionKeyVaultUrl $kv.VaultUri -DiskEncryptionKeyVaultId $kv.ResourceId

Write-Host "Basic encryption configured - expand to transit and in-use"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE07' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
