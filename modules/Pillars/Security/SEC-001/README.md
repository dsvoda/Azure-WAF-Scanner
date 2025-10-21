# SEC-001 - Storage Accounts should use customer-managed keys

## Description
This check validates that Azure Storage Accounts use customer-managed keys (CMK) stored in Azure Key Vault for encryption at rest, rather than relying on Microsoft-managed keys. Customer-managed keys provide enhanced security control and compliance capabilities by allowing organizations to manage their own encryption keys.

## Pillar
Security

## Severity
High

## Remediation Effort
Medium

## Rationale
Customer-managed keys for Azure Storage encryption provide several critical security benefits:

- **Full control over encryption keys**: Organizations maintain complete control over key lifecycle
- **Key rotation flexibility**: Rotate keys on your own schedule, not Microsoft's
- **Revocation capability**: Instantly revoke access by deleting or disabling keys
- **Compliance requirements**: Meet regulatory requirements for key management (HIPAA, PCI-DSS, GDPR)
- **Audit trail**: Complete visibility into key usage through Azure Key Vault logs
- **Data sovereignty**: Ensure encryption keys remain under organizational control
- **Enhanced security posture**: Additional layer of security for sensitive data

Without CMK, you rely entirely on Microsoft's key management, which may not meet your organization's security or compliance requirements.

## Compliance Mapping
- **CIS Azure Foundations Benchmark**: 3.9 - Ensure that 'Encryption at host' is set to 'Enabled' for Virtual Machines
- **ISO 27001**: A.10.1.1 - Policy on the use of cryptographic controls
- **NIST SP 800-53**: SC-12, SC-13 - Cryptographic Key Establishment and Management
- **PCI-DSS**: Requirement 3.5 - Protect cryptographic keys
- **HIPAA**: 164.312(a)(2)(iv) - Encryption and decryption
- **GDPR**: Article 32 - Security of processing

## Implementation Details

### Resource Types Checked
- `microsoft.storage/storageaccounts`

### Query Logic
The check performs the following steps:
1. Queries all storage accounts in the subscription using Azure Resource Graph
2. Identifies accounts tagged as production or containing sensitive data classifications
3. Checks the `properties.encryption.keySource` property
4. Reports accounts using `Microsoft.Storage` instead of `Microsoft.Keyvault`

### Pass Criteria
A storage account passes this check if:
- The `encryptionKeySource` is set to `Microsoft.Keyvault`
- AND a valid Key Vault URI is configured

### Fail Criteria
A storage account fails this check if:
- It is in production or handles sensitive data
- AND the `encryptionKeySource` is `Microsoft.Storage` (default)
- OR the Key Vault configuration is missing/invalid

## Affected Resources
Storage accounts using Microsoft-managed keys in production environments or those handling sensitive data.

## Remediation Steps

### Prerequisites
Before configuring CMK, ensure you have:
- An Azure Key Vault in the same region as the storage account
- An encryption key created or imported in Key Vault
- Proper permissions to configure storage and Key Vault

### Step 1: Create or Use Existing Key Vault
```powershell
# Create a new Key Vault
New-AzKeyVault `
    -Name "myKeyVault" `
    -ResourceGroupName "myRG" `
    -Location "eastus" `
    -EnableSoftDelete `
    -EnablePurgeProtection `
    -EnabledForDiskEncryption
```
```bash
# Using Azure CLI
az keyvault create \
    --name myKeyVault \
    --resource-group myRG \
    --location eastus \
    --enable-soft-delete true \
    --enable-purge-protection true
```

### Step 2: Create Encryption Key
```powershell
# Create a new key
Add-AzKeyVaultKey `
    -VaultName "myKeyVault" `
    -Name "storagekey" `
    -Destination "Software"

# For HSM-protected key (recommended for production)
Add-AzKeyVaultKey `
    -VaultName "myKeyVault" `
    -Name "storagekey" `
    -Destination "HSM"
```
```bash
# Using Azure CLI
az keyvault key create \
    --vault-name myKeyVault \
    --name storagekey \
    --protection software
```

### Step 3: Enable Managed Identity for Storage Account
```powershell
# Enable system-assigned managed identity
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount"

Update-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount" `
    -AssignIdentity
```
```bash
# Using Azure CLI
az storage account update \
    --name mystorageaccount \
    --resource-group myRG \
    --assign-identity
```

### Step 4: Grant Storage Account Access to Key Vault
```powershell
# Get the storage account's managed identity
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount"

$principalId = $storageAccount.Identity.PrincipalId

# Grant Key Vault permissions
Set-AzKeyVaultAccessPolicy `
    -VaultName "myKeyVault" `
    -ObjectId $principalId `
    -PermissionsToKeys wrapkey,unwrapkey,get
```
```bash
# Using Azure CLI
PRINCIPAL_ID=$(az storage account show \
    --name mystorageaccount \
    --resource-group myRG \
    --query identity.principalId -o tsv)

az keyvault set-policy \
    --name myKeyVault \
    --object-id $PRINCIPAL_ID \
    --key-permissions get unwrapKey wrapKey
```

### Step 5: Configure Storage Account to Use CMK
```powershell
# Get Key Vault key details
$keyVault = Get-AzKeyVault -VaultName "myKeyVault"
$key = Get-AzKeyVaultKey -VaultName "myKeyVault" -KeyName "storagekey"

# Configure storage account encryption
Set-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount" `
    -KeyvaultEncryption `
    -KeyName $key.Name `
    -KeyVersion $key.Version `
    -KeyVaultUri $keyVault.VaultUri
```
```bash
# Using Azure CLI
KEY_VAULT_URI=$(az keyvault show --name myKeyVault --query properties.vaultUri -o tsv)
KEY_VERSION=$(az keyvault key show --vault-name myKeyVault --name storagekey --query key.kid -o tsv)

az storage account update \
    --name mystorageaccount \
    --resource-group myRG \
    --encryption-key-source Microsoft.Keyvault \
    --encryption-key-vault "$KEY_VAULT_URI" \
    --encryption-key-name storagekey \
    --encryption-key-version "$KEY_VERSION"
```

### Step 6: Enable Automatic Key Rotation (Optional but Recommended)
```powershell
# Configure automatic key rotation
Set-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount" `
    -KeyvaultEncryption `
    -KeyName $key.Name `
    -KeyVaultUri $keyVault.VaultUri
    # Omit KeyVersion to enable automatic rotation
```

### Step 7: Verify Configuration
```powershell
# Verify CMK configuration
$account = Get-AzStorageAccount `
    -ResourceGroupName "myRG" `
    -Name "mystorageaccount"

$account.Encryption
```

## Important Considerations

### Key Vault Requirements
- **Same region**: Key Vault and Storage Account must be in the same Azure region
- **Soft delete**: Enable soft delete on Key Vault to prevent accidental key deletion
- **Purge protection**: Enable purge protection for production workloads
- **Access policies**: Use principle of least privilege for Key Vault access
- **Networking**: Configure Key Vault firewall if using private endpoints

### Performance Impact
- **Minimal overhead**: CMK has negligible performance impact on most workloads
- **First access**: Initial key retrieval may add slight latency
- **Caching**: Azure caches encryption keys to minimize performance impact

### High Availability
- **Key availability**: Ensure Key Vault is highly available
- **Backup keys**: Export and securely store key backups
- **Disaster recovery**: Plan for Key Vault recovery scenarios
- **Multiple keys**: Consider using multiple keys for different storage accounts

### Key Rotation
- **Manual rotation**: Requires creating new key version and updating storage account
- **Automatic rotation**: Enable by omitting key version in configuration
- **Zero downtime**: Key rotation does not impact storage account availability
- **Rotation schedule**: Establish regular rotation schedule (e.g., every 90 days)

### Cost Considerations
- **Key Vault costs**: Standard tier ~$0.03 per 10,000 operations
- **HSM costs**: Premium tier with HSM ~$1/key/month + operations
- **Storage costs**: No additional storage costs for using CMK
- **Operations**: Key wrap/unwrap operations charged separately

## False Positives

### Development/Test Environments
**Scenario**: Storage accounts used for development or testing
**Solution**: 
- Tag with `Environment=Dev` or `Environment=Test`
- The check excludes non-production accounts

### Public Data Storage
**Scenario**: Storage accounts containing only public, non-sensitive data
**Solution**:
- Tag with `DataClassification=Public`
- Document business justification
- Consider if Microsoft-managed keys are acceptable

### Legacy Applications
**Scenario**: Applications that cannot support CMK (very rare)
**Solution**:
- Document technical limitations
- Plan migration timeline
- Implement compensating controls

## Exclusions

### Valid Reasons to Exclude
1. **Non-production environments**: Dev/test storage accounts
2. **Public data**: Storage containing only public information
3. **Temporary storage**: Short-lived storage accounts
4. **Service limitations**: Some Azure services may not support CMK
5. **Cost constraints**: Small organizations with limited budget

### How to Exclude
Add appropriate tags:
```powershell
$tags = @{
    "Environment" = "Dev"
    "DataClassification" = "Public"
    "ExcludeFromWAF" = "SEC-001"
}
Set-AzResource -ResourceId $storageAccountId -Tag $tags -Force
```

## Troubleshooting

### Common Issues

**Issue: "Access denied to Key Vault"**
- Verify managed identity is enabled
- Check Key Vault access policies
- Ensure network firewall rules allow access

**Issue: "Key not found"**
- Verify key exists and is enabled
- Check key name and version
- Ensure soft-delete hasn't removed key

**Issue: "Cannot configure CMK for existing data"**
- CMK only encrypts new data
- Existing data remains encrypted with old keys
- Copy data to re-encrypt with new key

## Monitoring and Alerting

### Key Metrics to Monitor
1. **Key Vault availability**: Monitor Key Vault health
2. **Key access failures**: Alert on authentication failures
3. **Key rotation status**: Track last rotation date
4. **Encryption status**: Monitor encryption configuration changes

### Azure Monitor Queries
```kusto
// Storage accounts without CMK
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where Category == "StorageRead" or Category == "StorageWrite"
| extend EncryptionType = tostring(parse_json(properties_s).encryption.keySource)
| where EncryptionType != "Microsoft.Keyvault"
| summarize count() by Resource
```

### Recommended Alerts
1. Alert when CMK configuration is changed
2. Alert on Key Vault access failures
3. Alert when key is approaching expiration
4. Alert on Key Vault availability issues

## Security Best Practices

1. **Use HSM-backed keys** for production workloads
2. **Enable Key Vault firewall** and restrict access
3. **Implement RBAC** instead of access policies where possible
4. **Enable logging** for all Key Vault operations
5. **Regular key rotation** (every 90 days recommended)
6. **Backup keys** to secure offline storage
7. **Multi-region redundancy** for Key Vault
8. **Principle of least privilege** for all access

## Related Checks
- **SEC-002**: Key Vault should have soft delete enabled
- **SEC-003**: Key Vault should have purge protection enabled
- **SEC-004**: Storage accounts should restrict network access
- **SEC-005**: Storage accounts should use private endpoints

## References
- [Customer-managed keys for Azure Storage encryption](https://learn.microsoft.com/azure/storage/common/customer-managed-keys-overview)
- [Configure customer-managed keys](https://learn.microsoft.com/azure/storage/common/customer-managed-keys-configure-key-vault)
- [Azure Key Vault security](https://learn.microsoft.com/azure/key-vault/general/security-features)
- [Encryption at rest in Azure](https://learn.microsoft.com/azure/security/fundamentals/encryption-atrest)
- [Azure Storage encryption](https://learn.microsoft.com/azure/storage/common/storage-service-encryption)

## Change Log
- 2024-10-21: Initial creation
- 2024-10-21: Added comprehensive documentation with step-by-step remediation
```
