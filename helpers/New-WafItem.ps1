<#
.SYNOPSIS
    Creates a new WAF check from a template.

.DESCRIPTION
    Scaffolds the directory structure and boilerplate code for a new WAF check.

.PARAMETER CheckId
    The unique check identifier (e.g., REL-050, SEC-025).

.PARAMETER Pillar
    The WAF pillar: Reliability, Security, CostOptimization, Performance, OperationalExcellence.

.PARAMETER Title
    Human-readable title for the check.

.PARAMETER Severity
    Severity level: Critical, High, Medium, Low.

.PARAMETER RemediationEffort
    Effort required: Low, Medium, High.

.PARAMETER Force
    Overwrite existing check if it exists.

.EXAMPLE
    .\New-WafItem.ps1 -CheckId 'REL-050' -Pillar 'Reliability' -Title 'App Gateways should use WAF'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(REL|SEC|COST|PERF|OPS)-\d{3}$')]
    [string]$CheckId,
    
    [Parameter(Mandatory)]
    [ValidateSet('Reliability', 'Security', 'CostOptimization', 'Performance', 'OperationalExcellence')]
    [string]$Pillar,
    
    [Parameter(Mandatory)]
    [string]$Title,
    
    [ValidateSet('Critical', 'High', 'Medium', 'Low')]
    [string]$Severity = 'Medium',
    
    [ValidateSet('Low', 'Medium', 'High')]
    [string]$RemediationEffort = 'Medium',
    
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Determine module root
$moduleRoot = Split-Path -Parent $PSScriptRoot
$pillarsPath = Join-Path $moduleRoot 'modules' 'Pillars'

# Create check directory
$checkPath = Join-Path $pillarsPath $Pillar $CheckId

if ((Test-Path $checkPath) -and !$Force) {
    Write-Error "Check $CheckId already exists at $checkPath. Use -Force to overwrite."
    return
}

Write-Host "Creating new WAF check: $CheckId" -ForegroundColor Cyan
Write-Host "Path: $checkPath" -ForegroundColor Gray

# Create directory
New-Item -ItemType Directory -Path $checkPath -Force | Out-Null

# Generate check template
$checkContent = @"
# WAF Check: $CheckId - $Title
# Path: modules/Pillars/$Pillar/$CheckId/Invoke.ps1

<#
.SYNOPSIS
    $Title

.DESCRIPTION
    TODO: Add detailed description of what this check validates and why it's important.
    
.NOTES
    Created: $(Get-Date -Format 'yyyy-MM-dd')
    Author: TODO
    Pillar: $Pillar
    Severity: $Severity
    Remediation Effort: $RemediationEffort
#>

Register-WafCheck -CheckId '$CheckId' ``
    -Pillar '$Pillar' ``
    -Title '$Title' ``
    -Description 'TODO: Add detailed description' ``
    -Severity '$Severity' ``
    -RemediationEffort '$RemediationEffort' ``
    -Tags @('TODO') ``
    -DocumentationUrl 'https://learn.microsoft.com/azure/' ``
    -ComplianceFramework '' ``
    -ScriptBlock {
        param([string]`$SubscriptionId)
        
        # TODO: Define your Resource Graph query
        `$query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| where subscriptionId == '`$SubscriptionId'
| project id, name, location, resourceGroup, properties
"@
        
        try {
            # Execute query
            `$resources = Invoke-AzResourceGraphQuery -Query `$query -SubscriptionId `$SubscriptionId -UseCache
            
            # Handle no resources found
            if (!`$resources -or `$resources.Count -eq 0) {
                return New-WafResult -CheckId '$CheckId' ``
                    -Status 'N/A' ``
                    -Message 'No resources found to evaluate'
            }
            
            # TODO: Implement your check logic
            # Example: Filter for non-compliant resources
            `$nonCompliant = `$resources | Where-Object {
                # TODO: Add your condition
                `$false  # Replace with actual condition
            }
            
            # Return Pass if all resources are compliant
            if (`$nonCompliant.Count -eq 0) {
                return New-WafResult -CheckId '$CheckId' ``
                    -Status 'Pass' ``
                    -Message "All `$(`$resources.Count) resources are compliant"
            }
            
            # Build affected resources list
            `$affectedResourceIds = `$nonCompliant | ForEach-Object { `$_.id }
            
            # TODO: Customize your recommendation
            `$recommendation = @"
TODO: Provide step-by-step remediation guidance:
1. Step one
2. Step two
3. Step three

Benefits:
- Benefit one
- Benefit two
"@
            
            # TODO: Customize your remediation script
            `$remediationScript = @"
# TODO: Provide PowerShell or Azure CLI commands
# Example:
`$resourceId = '<resource-id>'
# Add your remediation commands here
"@
            
            # Return Fail with details
            return New-WafResult -CheckId '$CheckId' ``
                -Status 'Fail' ``
                -Message "`$(`$nonCompliant.Count) of `$(`$resources.Count) resources are non-compliant" ``
                -AffectedResources `$affectedResourceIds ``
                -Recommendation `$recommendation ``
                -RemediationScript `$remediationScript ``
                -Metadata @{
                    TotalResources = `$resources.Count
                    NonCompliantCount = `$nonCompliant.Count
                    CompliancePercentage = [Math]::Round(((`$resources.Count - `$nonCompliant.Count) / `$resources.Count) * 100, 2)
                }
                
        } catch {
            # Handle errors gracefully
            Write-Error "Check $CheckId failed: `$_"
            
            return New-WafResult -CheckId '$CheckId' ``
                -Status 'Error' ``
                -Message "Check execution failed: `$(`$_.Exception.Message)" ``
                -Metadata @{
                    ErrorType = `$_.Exception.GetType().Name
                    StackTrace = `$_.ScriptStackTrace
                }
        }
    }
"@

# Write check file
$checkFilePath = Join-Path $checkPath 'Invoke.ps1'
$checkContent | Set-Content -Path $checkFilePath -Encoding UTF8

Write-Host "✓ Created check file: $checkFilePath" -ForegroundColor Green

# Create README for the check
$readmeContent = @"
# $CheckId - $Title

## Description
TODO: Add detailed description

## Pillar
$Pillar

## Severity
$Severity

## Remediation Effort
$RemediationEffort

## Rationale
TODO: Explain why this check is important and what risks it mitigates

## Compliance Mapping
TODO: Map to compliance frameworks (e.g., CIS Azure, ISO 27001, NIST)
- CIS Azure: X.X
- ISO 27001: A.X.X.X
- NIST CSF: XX.XX

## Implementation Details

### Resource Types Checked
- TODO: List Azure resource types

### Query Logic
TODO: Explain the query logic

### Pass Criteria
TODO: Define what makes a resource compliant

### Fail Criteria
TODO: Define what makes a resource non-compliant

## Remediation Steps

### Manual Steps
1. TODO: Step-by-step manual remediation

### Automated Remediation
TODO: Provide automation options

### Testing
TODO: How to verify the fix

## False Positives
TODO: Describe scenarios that might trigger false positives

## Exclusions
TODO: Legitimate reasons to exclude resources

## References
- [Microsoft Documentation](https://learn.microsoft.com/azure/)
- TODO: Add relevant links

## Change Log
- $(Get-Date -Format 'yyyy-MM-dd'): Initial creation
"@

$readmePath = Join-Path $checkPath 'README.md'
$readmeContent | Set-Content -Path $readmePath -Encoding UTF8

Write-Host "✓ Created README: $readmePath" -ForegroundColor Green

# Create test file template
$testContent = @"
# Unit tests for $CheckId

BeforeAll {
    Import-Module "`$PSScriptRoot/../../../WafScanner.psm1" -Force
}

Describe '$CheckId - $Title' {
    BeforeAll {
        # Load the check
        . "`$PSScriptRoot/../Invoke.ps1"
        
        # Get check from registry
        `$script:Check = `$script:CheckRegistry | Where-Object CheckId -eq '$CheckId'
    }
    
    Context 'Check Registration' {
        It 'Should be registered' {
            `$script:Check | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have correct pillar' {
            `$script:Check.Pillar | Should -Be '$Pillar'
        }
        
        It 'Should have correct severity' {
            `$script:Check.Severity | Should -Be '$Severity'
        }
    }
    
    Context 'Check Execution' {
        BeforeEach {
            # Mock Invoke-AzResourceGraphQuery
            Mock Invoke-AzResourceGraphQuery {
                # TODO: Return mock data
                return @(
                    @{ id = '/subscriptions/test/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1' }
                )
            }
        }
        
        It 'Should return Pass when all resources are compliant' {
            # TODO: Mock compliant scenario
            Mock Invoke-AzResourceGraphQuery { return @() }
            
            `$result = & `$script:Check.ScriptBlock -SubscriptionId 'test-sub'
            
            `$result.Status | Should -Be 'Pass'
        }
        
        It 'Should return Fail when non-compliant resources exist' {
            # TODO: Mock non-compliant scenario
            `$result = & `$script:Check.ScriptBlock -SubscriptionId 'test-sub'
            
            `$result.Status | Should -Be 'Fail'
            `$result.AffectedResources | Should -Not -BeNullOrEmpty
        }
        
        It 'Should return N/A when no resources exist' {
            Mock Invoke-AzResourceGraphQuery { return @() }
            
            `$result = & `$script:Check.ScriptBlock -SubscriptionId 'test-sub'
            
            `$result.Status | Should -Be 'N/A'
        }
        
        It 'Should return Error on exception' {
            Mock Invoke-AzResourceGraphQuery { throw "Test error" }
            
            `$result = & `$script:Check.ScriptBlock -SubscriptionId 'test-sub'
            
            `$result.Status | Should -Be 'Error'
        }
    }
}
"@

$testsDir = Join-Path $moduleRoot 'tests' 'Unit' $Pillar
New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

$testFilePath = Join-Path $testsDir "$CheckId.Tests.ps1"
$testContent | Set-Content -Path $testFilePath -Encoding UTF8

Write-Host "✓ Created test file: $testFilePath" -ForegroundColor Green

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Check scaffolding complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Edit the check file and implement your logic:" -ForegroundColor Gray
Write-Host "   $checkFilePath" -ForegroundColor White
Write-Host "`n2. Update the README with detailed documentation:" -ForegroundColor Gray
Write-Host "   $readmePath" -ForegroundColor White
Write-Host "`n3. Write comprehensive unit tests:" -ForegroundColor Gray
Write-Host "   $testFilePath" -ForegroundColor White
Write-Host "`n4. Test your check:" -ForegroundColor Gray
Write-Host "   pwsh ./run/Invoke-WafLocal.ps1 -ExcludedChecks @('*') -IncludedChecks @('$CheckId') -EmitJson" -ForegroundColor White
Write-Host "`n5. Run unit tests:" -ForegroundColor Gray
Write-Host "   Invoke-Pester -Path $testFilePath" -ForegroundColor White
Write-Host "`n" -NoNewline

# Open files in default editor (optional)
$openInEditor = Read-Host "Open files in default editor? (Y/n)"
if ($openInEditor -ne 'n') {
    Start-Process $checkFilePath
    Start-Sleep -Milliseconds 500
    Start-Process $readmePath
}

Write-Host "`nHappy coding! 🚀" -ForegroundColor Cyan
```
