<#
.SYNOPSIS
    Pester tests for WafScanner module core functionality.

.DESCRIPTION
    Tests module loading, check registration, result creation, and core functions.
#>

BeforeAll {
    # Import module
    $ModulePath = "$PSScriptRoot/../../modules/WafScanner.psm1"
    
    if (!(Test-Path $ModulePath)) {
        throw "Module not found: $ModulePath"
    }
    
    Import-Module $ModulePath -Force -ErrorAction Stop
}

Describe 'WafScanner Module Import' {
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
        
        It 'Should be loaded' {
            Get-Module WafScanner | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Exported Functions' {
        It 'Should export expected main functions' {
            $expectedFunctions = @(
                'Initialize-WafScanner',
                'Register-WafCheck',
                'Get-RegisteredChecks',
                'New-WafResult',
                'Invoke-AzResourceGraphQuery',
                'Invoke-WafCheck',
                'Invoke-WafSubscriptionScan',
                'Get-WafScanSummary',
                'Compare-WafBaseline'
            )
            
            $exportedFunctions = (Get-Command -Module WafScanner).Name
            
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func -Because "$func is a core function"
            }
        }
        
        It 'Should export utility functions' {
            $utilityFunctions = @(
                'Convert-StatusToScore',
                'Estimate-ROI',
                'Get-WafWeights',
                'Get-AzurePortalLink'
            )
            
            $exportedFunctions = (Get-Command -Module WafScanner).Name
            
            foreach ($func in $utilityFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
        
        It 'Should export Invoke-Arg alias' {
            $aliases = (Get-Alias | Where-Object { $_.Source -eq 'WafScanner' }).Name
            $aliases | Should -Contain 'Invoke-Arg'
        }
    }
}

Describe 'Check Registration System' {
    Context 'Check Registration' {
        BeforeAll {
            Import-Module $ModulePath -Force
        }
        
        It 'Should have checks registered' {
            $checks = Get-RegisteredChecks
            $checks.Count | Should -BeGreaterThan 0
        }
        
        It 'Should have exactly 60 checks' {
            $checks = Get-RegisteredChecks
            $checks.Count | Should -Be 60 -Because "WAF Scanner includes 60 checks"
        }
        
        It 'Should have checks for all pillars' {
            $checks = Get-RegisteredChecks
            $pillars = $checks.Pillar | Select-Object -Unique | Sort-Object
            
            $pillars | Should -Contain 'Reliability'
            $pillars | Should -Contain 'Security'
            $pillars | Should -Contain 'CostOptimization'
            $pillars | Should -Contain 'OperationalExcellence'
            $pillars | Should -Contain 'PerformanceEfficiency'
        }
        
        It 'Should not have duplicate check IDs' {
            $checks = Get-RegisteredChecks
            $checkIds = $checks.CheckId
            $uniqueIds = $checkIds | Select-Object -Unique
            
            $checkIds.Count | Should -Be $uniqueIds.Count -Because "Each check must have unique ID"
        }
        
        It 'Should have expected check count per pillar' {
            $checks = Get-RegisteredChecks
            $byPillar = $checks | Group-Object Pillar
            
            # Expected counts based on design
            $expectedCounts = @{
                'Reliability' = 10
                'Security' = 12
                'CostOptimization' = 14
                'OperationalExcellence' = 12
                'PerformanceEfficiency' = 12
            }
            
            foreach ($pillar in $byPillar) {
                $expected = $expectedCounts[$pillar.Name]
                $pillar.Count | Should -Be $expected `
                    -Because "$($pillar.Name) should have $expected checks"
            }
        }
    }
    
    Context 'Check Properties' {
        BeforeAll {
            $checks = Get-RegisteredChecks
        }
        
        It 'Should have all required properties' {
            foreach ($check in $checks) {
                $check.CheckId | Should -Not -BeNullOrEmpty
                $check.Pillar | Should -Not -BeNullOrEmpty
                $check.Title | Should -Not -BeNullOrEmpty
                $check.Description | Should -Not -BeNullOrEmpty
                $check.Severity | Should -BeIn @('Critical', 'High', 'Medium', 'Low')
                $check.RemediationEffort | Should -BeIn @('High', 'Medium', 'Low')
                $check.ScriptBlock | Should -BeOfType [ScriptBlock]
            }
        }
        
        It 'Should follow naming convention' {
            foreach ($check in $checks) {
                $check.CheckId | Should -Match '^(RE|SE|CO|PE|OE)\d{2}$' `
                    -Because "Check IDs must follow pattern like RE01, SE05"
            }
        }
        
        It 'Should have valid severity levels' {
            foreach ($check in $checks) {
                $check.Severity | Should -BeIn @('Critical', 'High', 'Medium', 'Low')
            }
        }
        
        It 'Should have valid remediation effort levels' {
            foreach ($check in $checks) {
                $check.RemediationEffort | Should -BeIn @('High', 'Medium', 'Low')
            }
        }
    }
    
    Context 'Check Script Blocks' {
        BeforeAll {
            $checks = Get-RegisteredChecks
        }
        
        It 'Should accept SubscriptionId parameter' {
            foreach ($check in $checks) {
                $params = $check.ScriptBlock.Ast.ParamBlock.Parameters
                $paramNames = $params.Name.VariablePath.UserPath
                
                $paramNames | Should -Contain 'SubscriptionId' `
                    -Because "Check $($check.CheckId) must accept SubscriptionId"
            }
        }
    }
}

Describe 'Get-RegisteredChecks Filtering' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    Context 'Filter by Pillar' {
        It 'Should filter by single pillar' {
            $securityChecks = Get-RegisteredChecks -Pillars @('Security')
            
            $securityChecks.Count | Should -BeGreaterThan 0
            $securityChecks.Pillar | Should -Not -Contain 'Reliability'
            $securityChecks.Pillar | Should -Not -Contain 'CostOptimization'
        }
        
        It 'Should filter by multiple pillars' {
            $checks = Get-RegisteredChecks -Pillars @('Security', 'Reliability')
            
            $checks.Count | Should -BeGreaterThan 0
            $pillars = $checks.Pillar | Select-Object -Unique
            $pillars | Should -Contain 'Security'
            $pillars | Should -Contain 'Reliability'
            $pillars | Should -Not -Contain 'CostOptimization'
        }
    }
    
    Context 'Filter by Check ID' {
        It 'Should filter by specific check IDs' {
            $specific = Get-RegisteredChecks -CheckIds @('RE01', 'SE05')
            
            $specific.Count | Should -Be 2
            $specific.CheckId | Should -Contain 'RE01'
            $specific.CheckId | Should -Contain 'SE05'
        }
    }
    
    Context 'Exclude Filters' {
        It 'Should exclude pillars' {
            $nonCostChecks = Get-RegisteredChecks -ExcludePillars @('CostOptimization')
            
            $nonCostChecks.Pillar | Should -Not -Contain 'CostOptimization'
            $nonCostChecks.Pillar | Should -Contain 'Security'
        }
        
        It 'Should exclude specific checks' {
            $excludedChecks = Get-RegisteredChecks -ExcludeCheckIds @('RE01', 'SE01')
            
            $excludedChecks.CheckId | Should -Not -Contain 'RE01'
            $excludedChecks.CheckId | Should -Not -Contain 'SE01'
        }
    }
}

Describe 'New-WafResult Function' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    Context 'Result Creation' {
        It 'Should create a valid result object' {
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Pass' `
                -Message 'Test message'
            
            $result | Should -Not -BeNullOrEmpty
            $result.CheckId | Should -Be 'RE01'
            $result.Status | Should -Be 'Pass'
            $result.Message | Should -Be 'Test message'
        }
        
        It 'Should include timestamp' {
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Pass' `
                -Message 'Test'
            
            $result.Timestamp | Should -BeOfType [DateTime]
            $result.Timestamp | Should -BeLessOrEqual (Get-Date)
        }
        
        It 'Should accept all valid statuses' {
            $statuses = @('Pass', 'Fail', 'Warning', 'N/A', 'Error')
            
            foreach ($status in $statuses) {
                $result = New-WafResult -CheckId 'RE01' -Status $status -Message 'Test'
                $result.Status | Should -Be $status
            }
        }
        
        It 'Should include check details from registry' {
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Pass' `
                -Message 'Test'
            
            $result.Pillar | Should -Not -BeNullOrEmpty
            $result.Title | Should -Not -BeNullOrEmpty
            $result.Severity | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Optional Parameters' {
        It 'Should accept affected resources' {
            $resources = @('resource1', 'resource2')
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Fail' `
                -Message 'Test' `
                -AffectedResources $resources
            
            $result.AffectedResources | Should -Be $resources
        }
        
        It 'Should accept recommendation' {
            $recommendation = 'Fix this issue'
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Fail' `
                -Message 'Test' `
                -Recommendation $recommendation
            
            $result.Recommendation | Should -Be $recommendation
        }
        
        It 'Should accept remediation script' {
            $script = 'Get-AzResource | Remove-AzResource'
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Fail' `
                -Message 'Test' `
                -RemediationScript $script
            
            $result.RemediationScript | Should -Be $script
        }
        
        It 'Should accept metadata' {
            $metadata = @{ Key1 = 'Value1'; Key2 = 'Value2' }
            $result = New-WafResult -CheckId 'RE01' `
                -Status 'Pass' `
                -Message 'Test' `
                -Metadata $metadata
            
            $result.Metadata.Key1 | Should -Be 'Value1'
            $result.Metadata.Key2 | Should -Be 'Value2'
        }
    }
}

Describe 'Get-WafScanSummary Function' {
    BeforeAll {
        Import-Module $ModulePath -Force
        
        # Create mock results
        $script:mockResults = @(
            (New-WafResult -CheckId 'RE01' -Status 'Pass' -Message 'Test1'),
            (New-WafResult -CheckId 'RE02' -Status 'Fail' -Message 'Test2'),
            (New-WafResult -CheckId 'SE01' -Status 'Warning' -Message 'Test3'),
            (New-WafResult -CheckId 'SE02' -Status 'Pass' -Message 'Test4'),
            (New-WafResult -CheckId 'CO01' -Status 'Fail' -Message 'Test5')
        )
    }
    
    Context 'Summary Statistics' {
        It 'Should calculate total checks' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.TotalChecks | Should -Be 5
        }
        
        It 'Should calculate passed count' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.Passed | Should -Be 2
        }
        
        It 'Should calculate failed count' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.Failed | Should -Be 2
        }
        
        It 'Should calculate warnings count' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.Warnings | Should -Be 1
        }
        
        It 'Should calculate compliance score' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.ComplianceScore | Should -BeGreaterThan 0
            $summary.ComplianceScore | Should -BeLessOrEqual 100
        }
    }
    
    Context 'Pillar Breakdown' {
        It 'Should group by pillar' {
            $summary = Get-WafScanSummary -Results $mockResults
            $summary.ByPillar | Should -Not -BeNullOrEmpty
        }
        
        It 'Should calculate pillar scores' {
            $summary = Get-WafScanSummary -Results $mockResults
            
            foreach ($pillar in $summary.ByPillar) {
                $pillar.ComplianceScore | Should -BeGreaterOrEqual 0
                $pillar.ComplianceScore | Should -BeLessOrEqual 100
            }
        }
    }
    
    Context 'Duration Tracking' {
        It 'Should include duration' {
            $startTime = (Get-Date).AddMinutes(-5)
            $summary = Get-WafScanSummary -Results $mockResults -StartTime $startTime
            
            $summary.Duration | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Utility Functions' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    Context 'Convert-StatusToScore' {
        It 'Should convert Pass to 100' {
            Convert-StatusToScore -Status 'Pass' | Should -Be 100
        }
        
        It 'Should convert Fail to 0' {
            Convert-StatusToScore -Status 'Fail' | Should -Be 0
        }
        
        It 'Should convert Warning to 60' {
            Convert-StatusToScore -Status 'Warning' | Should -Be 60
        }
    }
    
    Context 'Get-AzurePortalLink' {
        It 'Should generate valid portal link' {
            $resourceId = '/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1'
            $link = Get-AzurePortalLink -ResourceId $resourceId
            
            $link | Should -Match 'https://portal.azure.com'
            $link | Should -Match $resourceId
        }
        
        It 'Should return null for empty resource ID' {
            $link = Get-AzurePortalLink -ResourceId ''
            $link | Should -BeNullOrEmpty
        }
    }
    
    Context 'Estimate-ROI' {
        It 'Should calculate ROI' {
            $roi = Estimate-ROI -EstimatedMonthlySavings 1000 -EffortHours 8 -HourlyRate 150
            
            $roi | Should -Not -BeNullOrEmpty
            $roi | Should -Match 'Estimated Monthly Savings'
            $roi | Should -Match 'ROI'
        }
        
        It 'Should return null for zero savings' {
            $roi = Estimate-ROI -EstimatedMonthlySavings 0
            $roi | Should -BeNullOrEmpty
        }
    }
}

Describe 'Error Handling' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    Context 'Invalid Parameters' {
        It 'Should throw on invalid status' {
            { New-WafResult -CheckId 'RE01' -Status 'InvalidStatus' -Message 'Test' } | 
                Should -Throw
        }
        
        It 'Should throw on missing required parameters' {
            { New-WafResult -CheckId 'RE01' } | Should -Throw
        }
    }
}

AfterAll {
    Remove-Module WafScanner -Force -ErrorAction SilentlyContinue
}
