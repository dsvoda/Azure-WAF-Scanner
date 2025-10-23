# Azure WAF Scanner - Development Guide

**Version:** 1.0.0  
**Last Updated:** October 22, 2025  
**For Contributors and Developers**

---

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Project Structure](#project-structure)
3. [Creating Custom Checks](#creating-custom-checks)
4. [Code Style Guide](#code-style-guide)
5. [Testing Requirements](#testing-requirements)
6. [Pull Request Process](#pull-request-process)
7. [Release Process](#release-process)
8. [Debugging Tips](#debugging-tips)

---

## Development Environment Setup

### Prerequisites

```powershell
# 1. PowerShell 7.0 or later
$PSVersionTable.PSVersion  # Should be 7.0+

# 2. Install required Az modules
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Force
Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force
Install-Module -Name Az.Advisor -Scope CurrentUser -Force
Install-Module -Name Az.Security -Scope CurrentUser -Force
Install-Module -Name Az.PolicyInsights -Scope CurrentUser -Force

# 3. Install development tools
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module -Name platyPS -Scope CurrentUser -Force  # For documentation
```

### Clone and Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/Azure-WAF-Scanner.git
cd Azure-WAF-Scanner

# Add upstream remote
git remote add upstream https://github.com/dsvoda/Azure-WAF-Scanner.git

# Create a feature branch
git checkout -b feature/my-new-check
```

### IDE Setup

#### Visual Studio Code (Recommended)

1. **Install Extensions:**
   - PowerShell
   - Azure Account
   - GitLens
   - Better Comments

2. **Configure Settings:**
   ```json
   {
     "powershell.scriptAnalysis.enable": true,
     "powershell.codeFormatting.preset": "OTBS",
     "editor.formatOnSave": true,
     "files.trimTrailingWhitespace": true
   }
   ```

3. **Launch Configuration:**
   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "type": "PowerShell",
         "request": "launch",
         "name": "Run WAF Scanner",
         "script": "${workspaceFolder}/run/Invoke-WafLocal.ps1",
         "args": ["-DryRun", "-Verbose"]
       }
     ]
   }
   ```

#### PowerShell ISE

- Set execution policy: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Enable script analyzer warnings
- Configure auto-save

---

## Project Structure

```
Azure-WAF-Scanner/
│
├── run/                          # Entry points
│   └── Invoke-WafLocal.ps1       # Main scanner script
│
├── modules/                      # Core modules
│   ├── Core/                     # Core functionality
│   │   ├── CheckLoader.ps1       # Check discovery and loading
│   │   ├── QueryEngine.ps1       # Azure Resource Graph queries
│   │   ├── CacheManager.ps1      # Query result caching
│   │   ├── ReportEngine.ps1      # Report generation
│   │   └── HelperFunctions.ps1   # Shared utilities
│   │
│   ├── Pillars/                  # Check implementations
│   │   ├── Reliability/
│   │   │   ├── RE01/
│   │   │   │   └── Invoke.ps1   # Individual check
│   │   │   ├── RE02/
│   │   │   └── ...
│   │   ├── Security/
│   │   ├── CostOptimization/
│   │   ├── OperationalExcellence/
│   │   └── PerformanceEfficiency/
│   │
│   └── Export/                   # Report exporters
│       ├── HtmlExporter.ps1
│       ├── JsonExporter.ps1
│       ├── CsvExporter.ps1
│       └── DocxExporter.ps1
│
├── helpers/                      # Helper scripts
│   └── New-WafItem.ps1          # Check template generator
│
├── tests/                        # Test suite
│   ├── Unit/                    # Unit tests
│   ├── Integration/             # Integration tests
│   └── TestHelpers.ps1          # Test utilities
│
├── docs/                         # Documentation
│   ├── Architecture.md
│   ├── Development.md           # This file
│   ├── Configuration.md
│   └── ...
│
├── config.json                   # Default configuration
├── .gitignore
├── LICENSE
└── README.md
```

### Key Files to Know

| File | Purpose | Modify Frequency |
|------|---------|------------------|
| `Invoke-WafLocal.ps1` | Main entry point | Rarely |
| `CheckLoader.ps1` | Check discovery | Rarely |
| `modules/Pillars/*/Invoke.ps1` | Check implementations | Often |
| `config.json` | Default config | Occasionally |
| `tests/**/*.Tests.ps1` | Tests | Always (with code changes) |

---

## Creating Custom Checks

### Step 1: Plan Your Check

Before writing code, define:

1. **Check ID:** Follow format `XX##` (e.g., `SE13` for Security check 13)
2. **Pillar:** Reliability, Security, CostOptimization, OperationalExcellence, PerformanceEfficiency
3. **Purpose:** What does this check validate?
4. **Query:** What Azure Resource Graph query is needed?
5. **Pass Criteria:** When does the check pass?
6. **Fail Criteria:** When does the check fail?
7. **Remediation:** How to fix failures?

### Step 2: Use the Check Generator

```powershell
# Generate check template
./helpers/New-WafItem.ps1 `
    -CheckId 'SE13' `
    -Pillar 'Security' `
    -Title 'Validate Key Vault Soft Delete' `
    -Description 'Ensures all Key Vaults have soft delete enabled' `
    -Severity 'High'

# This creates:
# modules/Pillars/Security/SE13/Invoke.ps1
```

### Step 3: Implement Check Logic

Edit the generated `Invoke.ps1`:

```powershell
<#
.SYNOPSIS
    SE13 - Validate Key Vault Soft Delete

.DESCRIPTION
    Ensures all Key Vaults have soft delete enabled to protect against 
    accidental or malicious deletion of secrets and keys.

.NOTES
    Pillar: Security
    Recommendation: SE:13 (Custom)
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/key-vault/general/soft-delete-overview
#>

Register-WafCheck -CheckId 'SE13' `
    -Pillar 'Security' `
    -Title 'Validate Key Vault Soft Delete' `
    -Description 'Ensures all Key Vaults have soft delete enabled' `
    -Severity 'High' `
    -RemediationEffort 'Low' `
    -Tags @('Security', 'KeyVault', 'DataProtection') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/key-vault/general/soft-delete-overview' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Build Resource Graph query
            $query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| where properties.enableSoftDelete != true or isnull(properties.enableSoftDelete)
| project id, name, resourceGroup, location, 
    softDeleteEnabled = tostring(properties.enableSoftDelete)
"@
            
            # Execute query with caching
            $results = Invoke-AzResourceGraphQuery `
                -Query $query `
                -SubscriptionId $SubscriptionId `
                -UseCache
            
            # Analyze results
            if ($results.Count -eq 0) {
                # No Key Vaults without soft delete - PASS
                return New-WafResult -CheckId 'SE13' `
                    -Status 'Pass' `
                    -Message 'All Key Vaults have soft delete enabled' `
                    -Metadata @{
                        KeyVaultsScanned = (Invoke-AzResourceGraphQuery `
                            -Query "Resources | where type =~ 'microsoft.keyvault/vaults'" `
                            -SubscriptionId $SubscriptionId `
                            -UseCache).Count
                    }
            } else {
                # Found Key Vaults without soft delete - FAIL
                return New-WafResult -CheckId 'SE13' `
                    -Status 'Fail' `
                    -Message "Found $($results.Count) Key Vault(s) without soft delete enabled" `
                    -AffectedResources $results.id `
                    -Recommendation @"
**CRITICAL**: Key Vaults without soft delete are vulnerable to permanent data loss.

Affected Key Vaults:
$($results | ForEach-Object { "• $($_.name) in $($_.resourceGroup)" } | Out-String)

## Immediate Actions:

1. **Enable soft delete on all Key Vaults:**
   - Soft delete allows recovery of deleted vaults and objects
   - Default retention period is 90 days
   - This is a one-way operation (cannot be disabled once enabled)

2. **Consider enabling purge protection:**
   - Prevents permanent deletion during retention period
   - Required for some compliance standards

3. **Document recovery procedures:**
   - Train team on recovery process
   - Test recovery in non-production

## Impact:
- **Low** - No impact on existing operations
- **Protection** - Prevents accidental/malicious permanent deletion
"@ `
                    -RemediationScript @"
# Enable soft delete on affected Key Vaults

# Get all Key Vaults without soft delete
`$vaults = Get-AzKeyVault | Where-Object { -not `$_.EnableSoftDelete }

foreach (`$vault in `$vaults) {
    Write-Host "Enabling soft delete on `$(`$vault.VaultName)..." -ForegroundColor Yellow
    
    # Enable soft delete (90-day retention)
    Update-AzKeyVault ``
        -VaultName `$vault.VaultName ``
        -ResourceGroupName `$vault.ResourceGroupName ``
        -EnableSoftDelete
    
    # Optional: Enable purge protection
    # Update-AzKeyVault ``
    #     -VaultName `$vault.VaultName ``
    #     -ResourceGroupName `$vault.ResourceGroupName ``
    #     -EnablePurgeProtection
    
    Write-Host "✓ Soft delete enabled on `$(`$vault.VaultName)" -ForegroundColor Green
}

Write-Host "`nSoft delete enabled on `$(`$vaults.Count) Key Vault(s)" -ForegroundColor Green
"@
            }
            
        } catch {
            # Error handling
            return New-WafResult -CheckId 'SE13' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
```

### Step 4: Test Your Check

```powershell
# Test against a subscription
./run/Invoke-WafLocal.ps1 `
    -Subscriptions "your-test-sub" `
    -ExcludedPillars @('Reliability','CostOptimization','OperationalExcellence','PerformanceEfficiency') `
    -Verbose

# Verify output
Get-ChildItem ./waf-output/*.html | Select-Object -First 1 | Invoke-Item
```

### Step 5: Write Unit Tests

Create `tests/Unit/Security/SE13.Tests.ps1`:

```powershell
BeforeAll {
    # Import test helpers
    . "$PSScriptRoot/../../TestHelpers.ps1"
    
    # Import check
    . "$PSScriptRoot/../../../modules/Pillars/Security/SE13/Invoke.ps1"
}

Describe "SE13 - Validate Key Vault Soft Delete" {
    
    Context "When all Key Vaults have soft delete enabled" {
        BeforeAll {
            # Mock the query to return empty (all compliant)
            Mock Invoke-AzResourceGraphQuery {
                return @()
            }
        }
        
        It "Should return Pass status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Status | Should -Be 'Pass'
        }
        
        It "Should include metadata about vaults scanned" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Metadata.KeyVaultsScanned | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "When Key Vaults are missing soft delete" {
        BeforeAll {
            # Mock the query to return non-compliant vaults
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    @{ 
                        id = '/subscriptions/test/resourceGroups/rg1/providers/Microsoft.KeyVault/vaults/kv1'
                        name = 'kv1'
                        resourceGroup = 'rg1'
                        softDeleteEnabled = 'false'
                    },
                    @{ 
                        id = '/subscriptions/test/resourceGroups/rg2/providers/Microsoft.KeyVault/vaults/kv2'
                        name = 'kv2'
                        resourceGroup = 'rg2'
                        softDeleteEnabled = $null
                    }
                )
            }
        }
        
        It "Should return Fail status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Status | Should -Be 'Fail'
        }
        
        It "Should include affected resource IDs" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.AffectedResources.Count | Should -Be 2
        }
        
        It "Should include remediation script" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.RemediationScript | Should -Not -BeNullOrEmpty
        }
        
        It "Should include recommendation text" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Recommendation | Should -Match 'soft delete'
        }
    }
    
    Context "When query fails" {
        BeforeAll {
            Mock Invoke-AzResourceGraphQuery {
                throw "API Error: Throttled"
            }
        }
        
        It "Should return Error status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Status | Should -Be 'Error'
        }
        
        It "Should include error details" {
            $result = & $CheckScriptBlock -SubscriptionId "test-sub-id"
            $result.Message | Should -Match 'failed'
        }
    }
}
```

### Step 6: Run Tests

```powershell
# Run all tests
Invoke-Pester

# Run just your check's tests
Invoke-Pester -Path tests/Unit/Security/SE13.Tests.ps1

# Run with code coverage
Invoke-Pester -CodeCoverage modules/Pillars/Security/SE13/Invoke.ps1
```

### Step 7: Document Your Check

Update `docs/CheckID-Registry.md`:

```markdown
| **SE13** | SE:13 | Validate Key Vault Soft Delete | High | ✅ Implemented |
```

### Step 8: Submit Pull Request

```bash
# Stage changes
git add modules/Pillars/Security/SE13/
git add tests/Unit/Security/SE13.Tests.ps1
git add docs/CheckID-Registry.md

# Commit with descriptive message
git commit -m "Add SE13: Validate Key Vault Soft Delete

- Checks all Key Vaults for soft delete enablement
- Includes remediation script
- Adds comprehensive unit tests
- Updates check registry"

# Push to your fork
git push origin feature/se13-keyvault-softdelete

# Create PR on GitHub
```

---

## Code Style Guide

### PowerShell Style Conventions

#### Naming Conventions

```powershell
# Functions: PascalCase with approved verbs
function Get-WafCheckResults { }
function Invoke-WafScan { }
function New-WafResult { }

# Variables: camelCase
$subscriptionId = "..."
$checkResults = @()
$isCompliant = $true

# Constants: PascalCase with 'C' prefix
$CMaxRetries = 3
$CTimeoutSeconds = 300

# Private functions: PascalCase with underscore prefix
function _InternalHelper { }
```

#### Formatting

```powershell
# Indentation: 4 spaces (no tabs)
function Get-Example {
    param(
        [string]$Parameter1,
        [int]$Parameter2
    )
    
    if ($Parameter2 -gt 0) {
        Write-Output "Value: $Parameter1"
    }
}

# Line length: 120 characters max
# Break long lines at logical points
$query = "Resources | where type == 'microsoft.compute/virtualmachines' " +
         "| where location == 'eastus' " +
         "| project id, name"

# Spacing around operators
$sum = $a + $b
$result = ($value -gt 10) -and ($status -eq 'Active')

# Opening braces on same line
if ($condition) {
    # code
} else {
    # code
}
```

#### Comments

```powershell
# Single-line comment for brief explanations

<#
Multi-line comment for:
- Complex logic explanations
- Algorithm descriptions
- Important notes
#>

<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description of what this function does

.PARAMETER ParameterName
    Description of the parameter

.EXAMPLE
    Example usage

.NOTES
    Additional information
#>
function Get-Example {
    # Function body
}
```

#### Error Handling

```powershell
# Always use try-catch for checks
try {
    # Check logic
    $result = Get-AzResource
    
    # Explicit error conditions
    if ($null -eq $result) {
        throw "No resources found"
    }
    
    return New-WafResult -Status 'Pass'
}
catch [SpecificException] {
    # Handle specific exception types
    Write-Warning "Specific error: $_"
    return New-WafResult -Status 'Error'
}
catch {
    # Generic error handler
    return New-WafResult -Status 'Error' `
        -Message $_.Exception.Message
}
finally {
    # Cleanup
    Remove-Variable temp -ErrorAction SilentlyContinue
}
```

### Resource Graph Query Best Practices

```powershell
# ✅ Good: Specific type, subscription filter, projection
$query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.hardwareProfile.vmSize startswith 'Standard_D'
| project id, name, resourceGroup, location, vmSize = properties.hardwareProfile.vmSize
"@

# ❌ Bad: No subscription filter, returns all columns
$query = @"
Resources
| where type =~ 'microsoft.compute/virtualmachines'
"@

# ✅ Good: Use extend for calculations
$query = @"
Resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend tier = tostring(sku.tier)
| where tier == 'Premium'
"@

# ✅ Good: Summarize when counting
$query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/disks'
| where isnull(managedBy)
| summarize OrphanedDisks = count()
"@
```

---

## Testing Requirements

### Test Structure

```
tests/
├── Unit/                          # Unit tests (fast, isolated)
│   ├── Reliability/
│   │   ├── RE01.Tests.ps1
│   │   └── RE02.Tests.ps1
│   ├── Security/
│   ├── CostOptimization/
│   ├── OperationalExcellence/
│   └── PerformanceEfficiency/
│
├── Integration/                   # Integration tests (slower, real Azure)
│   ├── FullScan.Tests.ps1
│   └── ReportGeneration.Tests.ps1
│
└── TestHelpers.ps1               # Shared test utilities
```

### Unit Test Template

```powershell
BeforeAll {
    # Setup - runs once before all tests
    . "$PSScriptRoot/../../TestHelpers.ps1"
    . "$PSScriptRoot/../../../modules/Pillars/Pillar/CHECKID/Invoke.ps1"
}

Describe "CHECKID - Check Title" {
    
    Context "When condition is met (Pass scenario)" {
        BeforeAll {
            # Setup mocks for this context
            Mock Invoke-AzResourceGraphQuery { return @() }
        }
        
        It "Should return Pass status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-id"
            $result.Status | Should -Be 'Pass'
        }
    }
    
    Context "When condition is not met (Fail scenario)" {
        BeforeAll {
            Mock Invoke-AzResourceGraphQuery {
                return @( @{ id = "resource-1" } )
            }
        }
        
        It "Should return Fail status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-id"
            $result.Status | Should -Be 'Fail'
        }
        
        It "Should include affected resources" {
            $result = & $CheckScriptBlock -SubscriptionId "test-id"
            $result.AffectedResources.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "When error occurs" {
        BeforeAll {
            Mock Invoke-AzResourceGraphQuery { throw "API Error" }
        }
        
        It "Should return Error status" {
            $result = & $CheckScriptBlock -SubscriptionId "test-id"
            $result.Status | Should -Be 'Error'
        }
    }
}
```

### Running Tests

```powershell
# Install Pester if needed
Install-Module Pester -MinimumVersion 5.0 -Force

# Run all tests
Invoke-Pester

# Run specific test file
Invoke-Pester -Path tests/Unit/Security/SE01.Tests.ps1

# Run with detailed output
Invoke-Pester -Output Detailed

# Run with code coverage
Invoke-Pester -CodeCoverage 'modules/Pillars/**/*.ps1' -CodeCoverageOutputFile coverage.xml

# Run only tests matching tag
Invoke-Pester -Tag 'Security'
```

### Code Coverage Requirements

- **Minimum:** 80% code coverage for new checks
- **Target:** 90%+ code coverage
- **Critical paths:** 100% coverage for error handling

---

## Pull Request Process

### Before Submitting

- [ ] Code follows style guide
- [ ] All tests pass (`Invoke-Pester`)
- [ ] Code analysis passes (`Invoke-ScriptAnalyzer`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)
- [ ] No merge conflicts with main branch

### PR Checklist

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New check
- [ ] Enhancement
- [ ] Documentation
- [ ] Breaking change

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guide
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass
- [ ] No linting errors

## Related Issues
Fixes #123
```

### Review Process

1. **Automated Checks:**
   - Linting (PSScriptAnalyzer)
   - Unit tests
   - Code coverage

2. **Peer Review:**
   - Code quality
   - Logic correctness
   - Test coverage
   - Documentation

3. **Approval & Merge:**
   - Minimum 1 approval required
   - Squash and merge preferred
   - Delete branch after merge

---

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR:** Breaking changes
- **MINOR:** New features (backwards compatible)
- **PATCH:** Bug fixes

### Release Checklist

- [ ] Update version in all files
- [ ] Update CHANGELOG.md
- [ ] Update README.md (if needed)
- [ ] Run full test suite
- [ ] Create release branch
- [ ] Tag release
- [ ] Create GitHub release
- [ ] Update documentation

### Release Script

```powershell
# Example release script
$version = "1.2.0"

# Update version files
(Get-Content README.md) -replace 'Version: \d+\.\d+\.\d+', "Version: $version" | Set-Content README.md

# Create tag
git tag -a "v$version" -m "Release v$version"
git push origin "v$version"

# Create release notes
gh release create "v$version" --title "v$version" --notes-file CHANGELOG.md
```

---

## Debugging Tips

### Enable Verbose Logging

```powershell
# Run with verbose output
./run/Invoke-WafLocal.ps1 -Verbose

# Debug specific check
$VerbosePreference = 'Continue'
./run/Invoke-WafLocal.ps1 -ExcludedPillars @('Reliability','CostOptimization','OperationalExcellence','PerformanceEfficiency')
```

### Inspect Query Results

```powershell
# Test Resource Graph query
$query = @"
Resources
| where type =~ 'microsoft.keyvault/vaults'
| take 5
"@

$results = Search-AzGraph -Query $query
$results | Format-Table
$results | ConvertTo-Json -Depth 10
```

### Debug Check Execution

```powershell
# Load check manually
. ./modules/Pillars/Security/SE13/Invoke.ps1

# Execute check directly
$result = & $CheckScriptBlock -SubscriptionId "your-sub-id"

# Inspect result
$result | Format-List *
$result | ConvertTo-Json -Depth 10
```

### Common Issues

**Issue:** "Register-WafCheck not recognized"
```powershell
# Solution: Load helper functions
. ./modules/Core/HelperFunctions.ps1
```

**Issue:** "Query returns no results"
```powershell
# Solution: Test query in Azure Resource Graph Explorer
# https://portal.azure.com/#view/HubsExtension/ArgQueryBlade
```

**Issue:** "Test mocks not working"
```powershell
# Solution: Verify mock scope
BeforeAll {
    # Mocks in BeforeAll apply to entire Describe block
    Mock Invoke-AzResourceGraphQuery { return @() }
}
```

---

## Additional Resources

### PowerShell Learning

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/)
- [Approved PowerShell Verbs](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)

### Azure Resource Graph

- [Query Language Reference](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language)
- [Sample Queries](https://learn.microsoft.com/azure/governance/resource-graph/samples/starter)
- [Query Best Practices](https://learn.microsoft.com/azure/governance/resource-graph/concepts/guidance-for-throttled-requests)

### Testing

- [Pester Documentation](https://pester.dev/)
- [Unit Testing Best Practices](https://pester.dev/docs/usage/test-lifecycle)
- [Mocking in Pester](https://pester.dev/docs/usage/mocking)

---

## Getting Help

- 📖 **Documentation:** Check [docs/](../docs/)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/dsvoda/Azure-WAF-Scanner/discussions)
- 🐛 **Issues:** [GitHub Issues](https://github.com/dsvoda/Azure-WAF-Scanner/issues)
- 📧 **Email:** Contact maintainers

---

**Happy Coding!** 🚀

---

**Document Version:** 1.0.0  
**Last Updated:** October 22, 2025  
**Next Review:** January 2026
