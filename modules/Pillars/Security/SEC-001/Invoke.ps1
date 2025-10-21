# Example WAF Check: Security - Storage Account Encryption
# Path: modules/Pillars/Security/SEC-001/Invoke.ps1

<#
.SYNOPSIS
    Checks if Storage Accounts are using customer-managed keys for encryption.

.DESCRIPTION
    Validates that storage accounts use customer-managed keys (CMK) in Azure Key Vault
    instead of Microsoft-managed keys for enhanced security control.
#>

Register-WafCheck -CheckId 'SEC-001' `
    -Pillar 'Security' `
    -Title 'Storage Accounts should use customer-managed keys' `
    -Description 'Ensures storage accounts use CMK for encryption at rest' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('Storage', 'Encryption', 'KeyManagement') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/storage/common/customer-managed-keys-overview' `
    -ComplianceFramework 'CIS Azure 3.9, ISO 27001' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        $query = @"
Resources
| where type == 'microsoft.storage/storageaccounts'
| where subscriptionId == '$SubscriptionId'
| extend encryptionKeySource = tostring(properties.encryption.keySource)
| extend keyvaultUri = tostring(properties.encryption.keyvaultproperties.keyvaulturi)
| project id, name, location, resourceGroup, encryptionKeySource, keyvaultUri, 
    environment = tostring(tags.Environment), dataClassification = tostring(tags.DataClassification)
"@
        
        try {
            $storageAccounts = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
            
            if (!$storageAccounts -or $storageAccounts.Count -eq 0) {
                return New-WafResult -CheckId 'SEC-001' `
                    -Status 'N/A' `
                    -Message 'No storage accounts found in subscription'
            }
            
            # Filter for production or sensitive data storage accounts
            $criticalAccounts = $storageAccounts | Where-Object {
                $_.environment -match 'prod|production' -or
                $_.dataClassification -match 'confidential|sensitive|pii'
            }
            
            if ($criticalAccounts.Count -eq 0) {
                # If no critical accounts, check all accounts
                $criticalAccounts = $storageAccounts
            }
            
            $withoutCMK = $criticalAccounts | Where-Object { 
                $_.encryptionKeySource -ne 'Microsoft.Keyvault' 
            }
            
            if ($withoutCMK.Count -eq 0) {
                return New-WafResult -CheckId 'SEC-001' `
                    -Status 'Pass' `
                    -Message "All $($criticalAccounts.Count) critical storage accounts use customer-managed keys"
            }
            
            $affectedResourceIds = $withoutCMK | ForEach-Object { $_.id }
            
            $recommendation = @"
Configure customer-managed keys for storage account encryption:
1. Create or use an existing Azure Key Vault
2. Create or import an encryption key in Key Vault
3. Enable Key Vault firewall and set appropriate access policies
4. Configure the storage account to use the customer-managed key
5. Enable automatic key rotation
6. Monitor key usage and access through diagnostics

Benefits:
- Full control over encryption keys
- Ability to rotate keys on your schedule
- Ability to revoke access by deleting keys
- Meet compliance requirements for key management
"@
            
            $remediationScript = @"
# Configure Customer-Managed Key for Storage Account

# Variables
`$storageAccountName = "<storage-account-name>"
`$resourceGroup = "<resource-group>"
`$keyVaultName = "<key-vault-name>"
`$keyName = "<key-name>"

# Get Key Vault and Key
`$keyVault = Get-AzKeyVault -VaultName `$keyVaultName
`$key = Get-AzKeyVaultKey -VaultName `$keyVaultName -KeyName `$keyName

# Enable managed identity for storage account
`$storageAccount = Get-AzStorageAccount -ResourceGroupName `$resourceGroup -Name `$storageAccountName
Update-AzStorageAccount ``
    -ResourceGroupName `$resourceGroup ``
    -Name `$storageAccountName ``
    -AssignIdentity

# Grant storage account access to Key Vault
`$objectId = `$storageAccount.Identity.PrincipalId
Set-AzKeyVaultAccessPolicy ``
    -VaultName `$keyVaultName ``
    -ObjectId `$objectId ``
    -PermissionsToKeys wrapkey,unwrapkey,get

# Configure storage account to use CMK
Set-AzStorageAccount ``
    -ResourceGroupName `$resourceGroup ``
    -Name `$storageAccountName ``
    -KeyvaultEncryption ``
    -KeyName `$key.Name ``
    -KeyVersion `$key.Version ``
    -KeyVaultUri `$keyVault.VaultUri
"@
            
            return New-WafResult -CheckId 'SEC-001' `
                -Status 'Fail' `
                -Message "$($withoutCMK.Count) of $($criticalAccounts.Count) critical storage accounts do not use customer-managed keys" `
                -AffectedResources $affectedResourceIds `
                -Recommendation $recommendation `
                -RemediationScript $remediationScript `
                -Metadata @{
                    TotalStorageAccounts = $storageAccounts.Count
                    CriticalAccounts = $criticalAccounts.Count
                    AccountsWithoutCMK = $withoutCMK.Count
                    EncryptionTypes = ($withoutCMK | Group-Object encryptionKeySource | Select-Object Name, Count)
                }
                
        } catch {
            return New-WafResult -CheckId 'SEC-001' `
                -Status 'Error' `
                -Message "Failed to execute check: $_"
        }
    }
```
