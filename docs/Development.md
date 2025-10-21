# Development Guide

## Architecture Overview

### Directory Structure
```
Azure-WAF-Scanner/
├── run/
│   └── Invoke-WafLocal.ps1           # Main entry point
├── modules/
│   ├── WafScanner.psm1               # Core module
│   ├── Core/
│   │   ├── Registry.ps1              # Check registration
│   │   ├── Cache.ps1                 # Caching utilities
│   │   └── Helpers.ps1               # Helper functions
│   ├── Report/
│   │   ├── New-WafHtml.ps1           # HTML report generator
│   │   ├── New-WafCsv.ps1            # CSV export
│   │   └── New-WafDocx.ps1           # Word document export
│   └── Pillars/
│       ├── Reliability/
│       │   ├── RE01/
│       │   │   └── Invoke.ps1        # Individual check
│       │   ├── RE02/
│       │   │   └── Invoke.ps1
│       │   └── ...
│       ├── Security/
│       ├── CostOptimization/
│       ├── Performance/
│       └── OperationalExcellence/
├── report-assets/
│   ├── templates/
│   │   └── enhanced.html
│   └── styles/
│       └── enhanced.css
├── helpers/
│   └── New-WafItem.ps1               # Scaffolding tool
├── tests/
│   ├── Unit/
│   └── Integration/
├── docs/
│   ├── Development.md                # This file
│   ├── CheckCatalog.md               # All checks documentation
│   └── API.md                        # API reference
├── config.json                        # Default configuration
└── README.md
```

## Core Concepts

### 1. Check Registration

Every check must call `Register-WafCheck` to register itself:
```powershell
Register-WafCheck -CheckId 'RE01' `
    -Pillar 'Reliability' `
    -Title 'VMs should use availability zones' `
    -Description 'Detailed description' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('VirtualMachines', 'HA') `
    -DocumentationUrl 'https://...' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        # Check logic here
    }
```

### 2. Check Execution

The ScriptBlock receives a `$SubscriptionId` parameter and must return one or more `New-WafResult` objects:
```powershell
-ScriptBlock {
    param([string]$SubscriptionId)
    
    # Query resources
    $resources = Invoke-AzResourceGraphQuery -Query $kqlQuery -SubscriptionId $SubscriptionId
    
    # Evaluate condition
    if ($condition) {
        return New-WafResult -CheckId 'RE01' `
            -Status 'Pass' `
            -Message 'All resources compliant'
    } else {
        return New-WafResult -CheckId 'RE01' `
            -Status 'Fail' `
            -Message 'Issues found' `
            -AffectedResources $affectedIds `
            -Recommendation 'How to fix...' `
            -RemediationScript 'Script to fix...'
    }
}
```

### 3. Result Object
```powershell
New-WafResult Parameters:
- CheckId           [Required] The check identifier
- Status            [Required] Pass|Fail|Warning|N/A|Error
- Message           [Required] Description of the finding
- AffectedResources [Optional] Array of resource IDs
- Recommendation    [Optional] How to remediate
- RemediationScript [Optional] PowerShell/CLI script
- Metadata          [Optional] Additional data (hashtable)
```

## Creating New Checks

### Step 1: Scaffold the Check
```powershell
pwsh ./helpers/New-WafItem.ps1 `
    -CheckId 'RE05' `
    -Pillar 'Reliability' `
    -Title 'My New Check'
```

This creates: `modules/Pillars/Reliability/RE05/Invoke.ps1`

### Step 2: Implement the Check Logic
```powershell
# modules/Pillars/Reliability/RE05/Invoke.ps1

Register-WafCheck -CheckId 'RE05' `
    -Pillar 'Reliability' `
    -Title 'Application Gateways should use WAF SKU' `
    -Description 'Ensures Application Gateways use WAF-enabled SKUs' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('AppGateway', 'WAF', 'Security') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/application-gateway/waf-overview' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        # 1. Query for resources
        $query = @"
Resources
| where type == 'microsoft.network/applicationgateways'
| where subscriptionId == '$SubscriptionId'
| extend skuName = tostring(sku.name)
| extend wafEnabled = sku.tier contains 'WAF'
| project id, name, location, resourceGroup, skuName, wafEnabled
"@
        
        try {
            $gateways = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
            
            # 2. Handle no resources
            if (!$gateways -or $gateways.Count -eq 0) {
                return New-WafResult -CheckId 'RE50' `
                    -Status 'N/A' `
                    -Message 'No Application Gateways found'
            }
            
            # 3. Evaluate compliance
            $nonCompliant = $gateways | Where-Object { !$_.wafEnabled }
            
            if ($nonCompliant.Count -eq 0) {
                return New-WafResult -CheckId 'RE50' `
                    -Status 'Pass' `
                    -Message "All $($gateways.Count) Application Gateways use WAF SKU"
            }
            
            # 4. Build failure result
            $affectedIds = $nonCompliant | ForEach-Object { $_.id }
            
            $recommendation = @"
Upgrade Application Gateways to WAF-enabled SKUs:
1. Plan for brief downtime during SKU change
2. Update to WAF_v2 SKU for best performance
3. Configure WAF rules after upgrade
4. Test thoroughly in staging first
"@
            
            $remediationScript = @"
# Upgrade Application Gateway to WAF SKU
`$appGwName = '<gateway-name>'
`$resourceGroup = '<resource-group>'

`$appGw = Get-AzApplicationGateway -Name `$appGwName -ResourceGroupName `$resourceGroup
`$appGw.Sku.Name = 'WAF_v2'
`$appGw.Sku.Tier = 'WAF_v2'

Set-AzApplicationGateway -ApplicationGateway `$appGw
"@
            
            return New-WafResult -CheckId 'RE50' `
                -Status 'Fail' `
                -Message "$($nonCompliant.Count) of $($gateways.Count) Application Gateways do not use WAF SKU" `
                -AffectedResources $affectedIds `
                -Recommendation $recommendation `
                -RemediationScript $remediationScript `
                -Metadata @{
                    TotalGateways = $gateways.Count
                    NonCompliantCount = $nonCompliant.Count
                    SKUsFound = ($gateways | Group-Object skuName | Select-Object Name, Count)
                }
                
        } catch {
            return New-WafResult -CheckId 'RE50' `
                -Status 'Error' `
                -Message "Check failed: $_"
        }
    }
```

### Step 3: Test Your Check
```powershell
# Test the specific check
pwsh ./run/Invoke-WafLocal.ps1 -ExcludedChecks @('*') -IncludedChecks @('RE50') -EmitJson

# Review results
Get-Content ./waf-output/latest.json | ConvertFrom-Json | Where-Object CheckId -eq 'RE50'
```

## Best Practices

### Resource Graph Queries

**DO:**
```powershell
# Use parameterized queries
$query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.compute/virtualmachines'
| project id, name, properties
"@

# Use caching for expensive queries
$results = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache

# Filter in KQL when possible (more efficient)
$query = @"
Resources
| where type == 'microsoft.storage/storageaccounts'
| where properties.encryption.keySource != 'Microsoft.Keyvault'
"@
```

**DON'T:**
```powershell
# Don't filter large result sets in PowerShell
$allResources = Invoke-AzResourceGraphQuery -Query "Resources"  # BAD: Returns everything
$vms = $allResources | Where-Object type -eq 'microsoft.compute/virtualmachines'  # BAD: Slow

# Don't make multiple queries when one will do
foreach ($vm in $vms) {
    $query = "Resources | where id == '$($vm.id)'"  # BAD: Many queries
    $detail = Invoke-AzResourceGraphQuery -Query $query
}
```

### Error Handling
```powershell
-ScriptBlock {
    param([string]$SubscriptionId)
    
    try {
        # Main logic
        $resources = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId
        
        # Validate data
        if ($null -eq $resources) {
            throw "Query returned null"
        }
        
        # Process results
        # ...
        
    } catch {
        # Log error details
        Write-Error "Check RE50 failed: $_"
        
        # Return error result (not throw)
        return New-WafResult -CheckId 'RE50' `
            -Status 'Error' `
            -Message "Check execution failed: $($_.Exception.Message)" `
            -Metadata @{
                ErrorType = $_.Exception.GetType().Name
                StackTrace = $_.ScriptStackTrace
            }
    }
}
```

### Performance Optimization

#### 1. Use Caching
```powershell
# Cache expensive queries
$resources = Invoke-AzResourceGraphQuery -Query $query -UseCache

# Access cache directly for repeated data
$cacheKey = "AllVMs-$SubscriptionId"
$cachedVMs = Get-CachedResult -Key $cacheKey

if (!$cachedVMs) {
    $cachedVMs = Invoke-AzResourceGraphQuery -Query $vmQuery -SubscriptionId $SubscriptionId
    Set-CachedResult -Key $cacheKey -Value $cachedVMs
}
```

#### 2. Batch Operations
```powershell
# Good: Single query with summarization
$query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| extend hasBackup = isnotnull(properties.backup)
| summarize Total = count(), WithBackup = countif(hasBackup == true), WithoutBackup = countif(hasBackup == false)
"@

# Bad: Multiple queries
$allVMs = Get-AzVM  # Many API calls
foreach ($vm in $allVMs) {
    $backup = Get-AzRecoveryServicesBackupItem -VM $vm  # Even more API calls
}
```

#### 3. Lazy Evaluation
```powershell
# Only fetch detailed data if needed
$query = "Resources | where type == 'microsoft.storage/storageaccounts' | project id, name"
$accounts = Invoke-AzResourceGraphQuery -Query $query

if ($accounts.Count -eq 0) {
    return New-WafResult -Status 'N/A' -Message 'No storage accounts'
}

# Now fetch details only for accounts that need checking
$detailedQuery = @"
Resources
| where type == 'microsoft.storage/storageaccounts'
| where id in ($($accounts.id -join "','"))
| extend encryptionKeySource = tostring(properties.encryption.keySource)
"@
```

## Testing

### Unit Tests

Create tests in `tests/Unit/`:
```powershell
# tests/Unit/RE50.Tests.ps1

Describe 'RE50: Application Gateway WAF Check' {
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../../modules/WafScanner.psm1" -Force
        
        # Mock functions
        Mock Invoke-AzResourceGraphQuery {
            return @(
                @{ id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/applicationGateways/gw1'; wafEnabled = $false }
                @{ id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/applicationGateways/gw2'; wafEnabled = $true }
            )
        }
    }
    
    It 'Should return Fail when gateways without WAF exist' {
        # Load and execute check
        . "$PSScriptRoot/../../modules/Pillars/Reliability/RE50/Invoke.ps1"
        
        $check = $script:CheckRegistry | Where-Object CheckId -eq 'RE50'
        $result = & $check.ScriptBlock -SubscriptionId 'test-sub'
        
        $result.Status | Should -Be 'Fail'
        $result.AffectedResources.Count | Should -Be 1
    }
    
    It 'Should return Pass when all gateways use WAF' {
        Mock Invoke-AzResourceGraphQuery {
            return @(
                @{ id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/applicationGateways/gw1'; wafEnabled = $true }
            )
        }
        
        . "$PSScriptRoot/../../modules/Pillars/Reliability/RE50/Invoke.ps1"
        
        $check = $script:CheckRegistry | Where-Object CheckId -eq 'RE50'
        $result = & $check.ScriptBlock -SubscriptionId 'test-sub'
        
        $result.Status | Should -Be 'Pass'
    }
    
    It 'Should return N/A when no gateways exist' {
        Mock Invoke-AzResourceGraphQuery { return @() }
        
        . "$PSScriptRoot/../../modules/Pillars/Reliability/RE50/Invoke.ps1"
        
        $check = $script:CheckRegistry | Where-Object CheckId -eq 'RE50'
        $result = & $check.ScriptBlock -SubscriptionId 'test-sub'
        
        $result.Status | Should -Be 'N/A'
    }
}
```

Run tests:
```powershell
Invoke-Pester -Path ./tests/Unit/RE50.Tests.ps1
```

### Integration Tests
```powershell
# tests/Integration/ScanWorkflow.Tests.ps1

Describe 'Full Scan Workflow' {
    It 'Should complete scan without errors' {
        $result = & ./run/Invoke-WafLocal.ps1 -DryRun
        $LASTEXITCODE | Should -Be 0
    }
    
    It 'Should generate all output formats' {
        & ./run/Invoke-WafLocal.ps1 -EmitJson -EmitCsv -EmitHtml
        
        Test-Path ./waf-output/*.json | Should -Be $true
        Test-Path ./waf-output/*.csv | Should -Be $true
        Test-Path ./waf-output/*.html | Should -Be $true
    }
}
```

## Check Naming Conventions

### Check IDs
Format: `<PILLAR>-<NUMBER>`

Examples:
- `RE01` through `RE99` - Reliability
- `SE01` through `SE99` - Security
- `CO01` through `CO99` - Cost Optimization
- `PE01` through `PE99` - Performance
- `OP01` through `OP99` - Operational Excellence

### Severity Levels

- **Critical**: Major security vulnerabilities, data loss risk, severe reliability issues
- **High**: Significant impact on security, reliability, or cost
- **Medium**: Moderate impact, best practice violations
- **Low**: Minor improvements, optimization opportunities

### Remediation Effort

- **Low**: < 1 hour, automated scripts available, no downtime
- **Medium**: 1-8 hours, some manual work, minimal downtime
- **High**: > 8 hours, complex changes, significant downtime

## Helper Functions Reference

### Invoke-AzResourceGraphQuery
```powershell
Invoke-AzResourceGraphQuery `
    -Query "Resources | where type == '...'" `
    -SubscriptionId $SubscriptionId `
    -UseCache  # Optional: use cached results
```

### Get-WafAdvisorRecommendations
```powershell
$recommendations = Get-WafAdvisorRecommendations `
    -SubscriptionId $SubscriptionId `
    -Categories @('Cost', 'Security', 'Reliability')
```

### Get-WafDefenderFindings
```powershell
$findings = Get-WafDefenderFindings `
    -SubscriptionId $SubscriptionId `
    -Severities @('High', 'Medium')
```

### Get-WafPolicyCompliance
```powershell
$nonCompliant = Get-WafPolicyCompliance -SubscriptionId $SubscriptionId
```

### Test-ResourceTag
```powershell
$hasRequiredTags = Test-ResourceTag `
    -Resource $resource `
    -RequiredTags @('Environment', 'Owner', 'CostCenter')
```

### Get-UnusedResources
```powershell
$unused = Get-UnusedResources `
    -SubscriptionId $SubscriptionId `
    -IdleDays 30
```

### Format-RemediationScript
```powershell
$script = Format-RemediationScript `
    -IssueType 'MissingTags' `
    -Context @{ ResourceId = '/subscriptions/...' }
```

## Debugging Tips

### Enable Verbose Output
```powershell
pwsh ./run/Invoke-WafLocal.ps1 -Verbose -EmitHtml
```

### Test Individual Checks
```powershell
# Load the module
Import-Module ./modules/WafScanner.psm1 -Force

# Load specific check
. ./modules/Pillars/Reliability/RE01/Invoke.ps1

# Execute manually
$check = $script:CheckRegistry | Where-Object CheckId -eq 'RE01'
$result = & $check.ScriptBlock -SubscriptionId 'your-sub-id'

# Inspect result
$result | ConvertTo-Json -Depth 10
```

### Query Testing
```powershell
# Test Resource Graph queries in isolation
$query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| project id, name, zones
"@

$results = Search-AzGraph -Query $query
$results | Format-Table
```

### Performance Profiling
```powershell
# Time individual checks
Measure-Command {
    . ./modules/Pillars/Reliability/RE01/Invoke.ps1
    $check = $script:CheckRegistry | Where-Object CheckId -eq 'RE01'
    & $check.ScriptBlock -SubscriptionId 'sub-id'
}
```

## Contribution Guidelines

### Checklist for New Checks
- [ ] Check ID follows naming convention
- [ ] Proper severity and remediation effort assigned
- [ ] Comprehensive description and documentation URL
- [ ] Error handling implemented
- [ ] Resource Graph query optimized
- [ ] Remediation script provided
- [ ] Unit tests written
- [ ] Added to CheckCatalog.md
- [ ] Tested against real subscription

### Code Review Criteria
1. **Correctness**: Logic accurately identifies issues
2. **Performance**: Queries are optimized
3. **Clarity**: Code is well-commented and readable
4. **Completeness**: Includes recommendation and remediation
5. **Testing**: Has adequate test coverage
6. **Documentation**: Check is documented

## Release Process

1. Update version in module manifest
2. Run full test suite: `Invoke-Pester`
3. Test against multiple subscriptions
4. Update CHANGELOG.md
5. Create release tag
6. Publish release notes

---

For questions or issues, please open a GitHub issue or contribute to discussions.
```
