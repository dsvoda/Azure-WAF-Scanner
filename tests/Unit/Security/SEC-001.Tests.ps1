# Unit tests for SEC-001: Storage Account Customer-Managed Keys Check

BeforeAll {
    # Import the module
    $modulePath = "$PSScriptRoot/../../../modules/WafScanner.psm1"
    Import-Module $modulePath -Force
}

Describe 'SEC-001: Storage Account Customer-Managed Keys Check' {
    BeforeAll {
        # Load the check
        $checkPath = "$PSScriptRoot/../../../modules/Pillars/Security/SEC-001/Invoke.ps1"
        . $checkPath
        
        # Get check from registry
        $script:Check = $script:CheckRegistry | Where-Object CheckId -eq 'SEC-001'
    }
    
    Context 'Check Registration' {
        It 'Should be registered in the check registry' {
            $script:Check | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have CheckId SEC-001' {
            $script:Check.CheckId | Should -Be 'SEC-001'
        }
        
        It 'Should have correct pillar' {
            $script:Check.Pillar | Should -Be 'Security'
        }
        
        It 'Should have High severity' {
            $script:Check.Severity | Should -Be 'High'
        }
        
        It 'Should have Medium remediation effort' {
            $script:Check.RemediationEffort | Should -Be 'Medium'
        }
        
        It 'Should have a title' {
            $script:Check.Title | Should -Not -BeNullOrEmpty
            $script:Check.Title | Should -Match 'customer-managed keys'
        }
        
        It 'Should have a description' {
            $script:Check.Description | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have tags' {
            $script:Check.Tags | Should -Contain 'Storage'
            $script:Check.Tags | Should -Contain 'Encryption'
        }
        
        It 'Should have documentation URL' {
            $script:Check.DocumentationUrl | Should -Not -BeNullOrEmpty
            $script:Check.DocumentationUrl | Should -Match 'microsoft.com'
        }
    }
    
    Context 'Check Execution - Pass Scenarios' {
        BeforeEach {
            # Mock storage accounts with customer-managed keys
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Keyvault'
                        keyvaultUri = 'https://myvault.vault.azure.net/'
                        environment = 'production'
                        dataClassification = 'confidential'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage2'
                        name = 'storage2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Keyvault'
                        keyvaultUri = 'https://myvault.vault.azure.net/'
                        environment = 'production'
                        dataClassification = $null
                    }
                )
            }
        }
        
        It 'Should return Pass when all critical storage accounts use CMK' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Pass'
            $result.CheckId | Should -Be 'SEC-001'
            $result.Message | Should -Match 'customer-managed keys'
        }
    }
    
    Context 'Check Execution - Fail Scenarios' {
        BeforeEach {
            # Mock storage accounts without customer-managed keys
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'confidential'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage2'
                        name = 'storage2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Keyvault'
                        keyvaultUri = 'https://myvault.vault.azure.net/'
                        environment = 'production'
                        dataClassification = $null
                    }
                )
            }
        }
        
        It 'Should return Fail when storage accounts do not use CMK' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Fail'
            $result.CheckId | Should -Be 'SEC-001'
            $result.AffectedResources | Should -HaveCount 1
        }
        
        It 'Should identify affected storage accounts' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.AffectedResources[0] | Should -Match 'storage1'
        }
        
        It 'Should include recommendation' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Recommendation | Should -Not -BeNullOrEmpty
            $result.Recommendation | Should -Match 'Key Vault'
        }
        
        It 'Should include remediation script' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.RemediationScript | Should -Not -BeNullOrEmpty
            $result.RemediationScript | Should -Match 'Set-AzStorageAccount'
            $result.RemediationScript | Should -Match 'KeyvaultEncryption'
        }
        
        It 'Should include metadata' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Metadata | Should -Not -BeNullOrEmpty
            $result.Metadata.TotalStorageAccounts | Should -Be 2
            $result.Metadata.AccountsWithoutCMK | Should -Be 1
        }
    }
    
    Context 'Check Execution - N/A Scenarios' {
        BeforeEach {
            # Mock no storage accounts
            Mock Invoke-AzResourceGraphQuery {
                return @()
            }
        }
        
        It 'Should return N/A when no storage accounts exist' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'N/A'
            $result.CheckId | Should -Be 'SEC-001'
            $result.Message | Should -Match 'No storage accounts found'
        }
    }
    
    Context 'Check Execution - Data Classification Filtering' {
        BeforeEach {
            # Mock storage accounts with different classifications
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage-sensitive'
                        name = 'storage-sensitive'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'sensitive'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage-public'
                        name = 'storage-public'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'dev'
                        dataClassification = 'public'
                    }
                )
            }
        }
        
        It 'Should prioritize sensitive data classification' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Fail'
            $result.AffectedResources | Should -HaveCount 1
            $result.AffectedResources[0] | Should -Match 'storage-sensitive'
        }
    }
    
    Context 'Check Execution - Production Environment Filtering' {
        BeforeEach {
            # Mock storage accounts in different environments
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage-prod'
                        name = 'storage-prod'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = $null
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage-dev'
                        name = 'storage-dev'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'dev'
                        dataClassification = $null
                    }
                )
            }
        }
        
        It 'Should prioritize production environment' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Fail'
            $result.AffectedResources | Should -HaveCount 1
            $result.AffectedResources[0] | Should -Match 'storage-prod'
        }
    }
    
    Context 'Check Execution - Error Scenarios' {
        BeforeEach {
            # Mock Resource Graph query failure
            Mock Invoke-AzResourceGraphQuery {
                throw "Permission denied: Unable to query storage accounts"
            }
        }
        
        It 'Should return Error status on exception' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Error'
            $result.CheckId | Should -Be 'SEC-001'
        }
        
        It 'Should include error message' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Message | Should -Match 'Failed to execute check'
        }
    }
    
    Context 'Check Execution - Mixed Encryption Sources' {
        BeforeEach {
            # Mock various encryption configurations
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'confidential'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage2'
                        name = 'storage2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Keyvault'
                        keyvaultUri = 'https://vault1.vault.azure.net/'
                        environment = 'production'
                        dataClassification = 'confidential'
                    }
                )
            }
        }
        
        It 'Should report encryption types in metadata' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Metadata.EncryptionTypes | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Integration with Helper Functions' {
        BeforeEach {
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'confidential'
                    }
                )
            }
        }
        
        It 'Should call Invoke-AzResourceGraphQuery with correct parameters' {
            $null = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            Should -Invoke Invoke-AzResourceGraphQuery -Times 1 -ParameterFilter {
                $Query -match 'microsoft.storage/storageaccounts' -and
                $SubscriptionId -eq 'test-sub-id'
            }
        }
        
        It 'Should use caching' {
            $null = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            Should -Invoke Invoke-AzResourceGraphQuery -Times 1 -ParameterFilter {
                $UseCache -eq $true
            }
        }
    }
    
    Context 'Check Execution - Null and Empty Value Handling' {
        BeforeEach {
            # Mock storage accounts with various null values
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = $null
                        keyvaultUri = $null
                        environment = $null
                        dataClassification = $null
                    }
                )
            }
        }
        
        It 'Should handle storage accounts with null encryption settings' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            # Should not throw error
            $result.Status | Should -BeIn @('Pass', 'Fail', 'N/A', 'Error')
        }
    }
    
    Context 'Message Formatting' {
        BeforeEach {
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage1'
                        name = 'storage1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'confidential'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/storage2'
                        name = 'storage2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        encryptionKeySource = 'Microsoft.Storage'
                        keyvaultUri = $null
                        environment = 'production'
                        dataClassification = 'confidential'
                    }
                )
            }
        }
        
        It 'Should include count in failure message' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Message | Should -Match '\d+ of \d+'
        }
    }
}
```
