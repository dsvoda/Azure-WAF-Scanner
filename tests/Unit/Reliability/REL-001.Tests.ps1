# Unit tests for REL-001: VM Availability Zones Check

BeforeAll {
    # Import the module
    $modulePath = "$PSScriptRoot/../../../modules/WafScanner.psm1"
    Import-Module $modulePath -Force
}

Describe 'REL-001: Virtual Machines Availability Zones Check' {
    BeforeAll {
        # Load the check
        $checkPath = "$PSScriptRoot/../../../modules/Pillars/Reliability/REL-001/Invoke.ps1"
        . $checkPath
        
        # Get check from registry
        $script:Check = $script:CheckRegistry | Where-Object CheckId -eq 'REL-001'
    }
    
    Context 'Check Registration' {
        It 'Should be registered in the check registry' {
            $script:Check | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have CheckId REL-001' {
            $script:Check.CheckId | Should -Be 'REL-001'
        }
        
        It 'Should have correct pillar' {
            $script:Check.Pillar | Should -Be 'Reliability'
        }
        
        It 'Should have High severity' {
            $script:Check.Severity | Should -Be 'High'
        }
        
        It 'Should have High remediation effort' {
            $script:Check.RemediationEffort | Should -Be 'High'
        }
        
        It 'Should have a title' {
            $script:Check.Title | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have a description' {
            $script:Check.Description | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have a script block' {
            $script:Check.ScriptBlock | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Check Execution - Pass Scenarios' {
        BeforeEach {
            # Mock the Resource Graph query to return VMs with zones
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        name = 'vm1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = @('1', '2')
                        hasZones = $true
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm2'
                        name = 'vm2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = @('1')
                        hasZones = $true
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    }
                )
            }
        }
        
        It 'Should return Pass when all production VMs have availability zones' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Pass'
            $result.CheckId | Should -Be 'REL-001'
            $result.Message | Should -Match 'production VMs are configured with availability zones'
        }
    }
    
    Context 'Check Execution - Fail Scenarios' {
        BeforeEach {
            # Mock the Resource Graph query to return VMs without zones
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        name = 'vm1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = $null
                        hasZones = $false
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm2'
                        name = 'vm2'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = @('1')
                        hasZones = $true
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    }
                )
            }
        }
        
        It 'Should return Fail when some production VMs lack availability zones' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Fail'
            $result.CheckId | Should -Be 'REL-001'
            $result.AffectedResources | Should -HaveCount 1
            $result.AffectedResources[0] | Should -Match 'vm1'
        }
        
        It 'Should include recommendation when check fails' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Recommendation | Should -Not -BeNullOrEmpty
            $result.Recommendation | Should -Match 'availability zones'
        }
        
        It 'Should include remediation script when check fails' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.RemediationScript | Should -Not -BeNullOrEmpty
            $result.RemediationScript | Should -Match 'New-AzVM'
        }
        
        It 'Should include metadata with details' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Metadata | Should -Not -BeNullOrEmpty
            $result.Metadata.TotalVMs | Should -Be 2
            $result.Metadata.VMsWithoutZones | Should -Be 1
        }
    }
    
    Context 'Check Execution - N/A Scenarios' {
        BeforeEach {
            # Mock the Resource Graph query to return no VMs
            Mock Invoke-AzResourceGraphQuery {
                return @()
            }
        }
        
        It 'Should return N/A when no VMs exist in subscription' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'N/A'
            $result.CheckId | Should -Be 'REL-001'
            $result.Message | Should -Match 'No virtual machines found'
        }
    }
    
    Context 'Check Execution - Mixed Environments' {
        BeforeEach {
            # Mock with production and dev VMs
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-prod'
                        name = 'vm-prod'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = @('1')
                        hasZones = $true
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    },
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-dev'
                        name = 'vm-dev'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = $null
                        hasZones = $false
                        environment = 'dev'
                        sku = 'Standard_B2s'
                    }
                )
            }
        }
        
        It 'Should only evaluate production VMs' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Pass'
            # Dev VM should not affect the result
        }
    }
    
    Context 'Check Execution - Error Scenarios' {
        BeforeEach {
            # Mock the Resource Graph query to throw an error
            Mock Invoke-AzResourceGraphQuery {
                throw "API Error: Unable to connect to Azure Resource Graph"
            }
        }
        
        It 'Should return Error status when query fails' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Status | Should -Be 'Error'
            $result.CheckId | Should -Be 'REL-001'
        }
        
        It 'Should include error message' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            $result.Message | Should -Match 'Failed to execute check'
        }
    }
    
    Context 'Check Execution - Null Handling' {
        BeforeEach {
            # Mock with VMs that have null environment tags
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        name = 'vm1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = $null
                        hasZones = $false
                        environment = $null
                        sku = 'Standard_D2s_v3'
                    }
                )
            }
        }
        
        It 'Should handle VMs with null environment tags' {
            $result = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            # VMs without environment tags should be treated as production
            $result.Status | Should -Be 'Fail'
            $result.AffectedResources | Should -HaveCount 1
        }
    }
    
    Context 'Integration with Helper Functions' {
        BeforeEach {
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        name = 'vm1'
                        location = 'eastus'
                        resourceGroup = 'rg1'
                        zones = $null
                        hasZones = $false
                        environment = 'production'
                        sku = 'Standard_D2s_v3'
                    }
                )
            }
        }
        
        It 'Should call Invoke-AzResourceGraphQuery with correct parameters' {
            $null = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            Should -Invoke Invoke-AzResourceGraphQuery -Times 1 -ParameterFilter {
                $Query -match 'microsoft.compute/virtualmachines' -and
                $SubscriptionId -eq 'test-sub-id'
            }
        }
        
        It 'Should use caching when calling Resource Graph' {
            $null = & $script:Check.ScriptBlock -SubscriptionId 'test-sub-id'
            
            Should -Invoke Invoke-AzResourceGraphQuery -Times 1 -ParameterFilter {
                $UseCache -eq $true
            }
        }
    }
}
```
