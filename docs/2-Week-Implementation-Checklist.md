# Azure WAF Scanner - 2-Week Implementation Checklist

**Start Date:** ____________  
**Target Completion:** ____________  

This guide provides step-by-step instructions for implementing the highest-priority improvements over the next two weeks.

---

## 📅 Week 1: Testing Infrastructure & CI/CD

### Day 1: Set Up Testing Framework

#### Step 1: Install Required Modules
```powershell
# Run in PowerShell 7+
Install-Module Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0
Install-Module PSScriptAnalyzer -Force
```

#### Step 2: Create Test Directory Structure
```powershell
# From repository root
New-Item -ItemType Directory -Path "tests" -Force
New-Item -ItemType Directory -Path "tests/Unit" -Force
New-Item -ItemType Directory -Path "tests/Integration" -Force
New-Item -ItemType Directory -Path "tests/Checks" -Force
```

#### Step 3: Create Basic Module Test
Create `tests/Unit/WafScanner.Tests.ps1`:

```powershell
BeforeAll {
    # Import module
    $ModulePath = "$PSScriptRoot/../../modules/WafScanner.psm1"
    Import-Module $ModulePath -Force -ErrorAction Stop
}

Describe 'WafScanner Module Import' {
    It 'Should import without errors' {
        { Import-Module $ModulePath -Force } | Should -Not -Throw
    }
    
    It 'Should export expected functions' {
        $expectedFunctions = @(
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
            $exportedFunctions | Should -Contain $func
        }
    }
}

Describe 'Check Registration System' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }
    
    It 'Should register checks successfully' {
        $checks = Get-RegisteredChecks
        $checks.Count | Should -BeGreaterThan 0
    }
    
    It 'Should return 60 total checks' {
        $checks = Get-RegisteredChecks
        $checks.Count | Should -Be 60
    }
    
    It 'Should have checks for all pillars' {
        $checks = Get-RegisteredChecks
        $pillars = $checks.Pillar | Select-Object -Unique | Sort-Object
        
        $pillars | Should -Contain 'Reliability'
        $pillars | Should -Contain 'Security'
        $pillars | Should -Contain 'CostOptimization'
        $pillars | Should -Contain 'PerformanceEfficiency'
        $pillars | Should -Contain 'OperationalExcellence'
    }
    
    It 'Should not have duplicate check IDs' {
        $checks = Get-RegisteredChecks
        $checkIds = $checks.CheckId
        $uniqueIds = $checkIds | Select-Object -Unique
        
        $checkIds.Count | Should -Be $uniqueIds.Count
    }
}

Describe 'New-WafResult Function' {
    It 'Should create a valid result object' {
        $result = New-WafResult -CheckId 'RE01' `
            -Status 'Pass' `
            -Message 'Test message'
        
        $result.CheckId | Should -Be 'RE01'
        $result.Status | Should -Be 'Pass'
        $result.Message | Should -Be 'Test message'
        $result.Timestamp | Should -BeOfType [DateTime]
    }
    
    It 'Should accept all valid statuses' {
        $statuses = @('Pass', 'Fail', 'Warning', 'N/A', 'Error')
        
        foreach ($status in $statuses) {
            { New-WafResult -CheckId 'RE01' -Status $status -Message 'Test' } | 
                Should -Not -Throw
        }
    }
}

Describe 'Get-RegisteredChecks Filtering' {
    It 'Should filter by pillar' {
        $securityChecks = Get-RegisteredChecks -Pillars @('Security')
        
        $securityChecks.Count | Should -BeGreaterThan 0
        $securityChecks.Pillar | Should -Not -Contain 'Reliability'
        $securityChecks.Pillar | Should -Not -Contain 'CostOptimization'
    }
    
    It 'Should exclude pillars' {
        $nonCostChecks = Get-RegisteredChecks -ExcludePillars @('CostOptimization')
        
        $nonCostChecks.Pillar | Should -Not -Contain 'CostOptimization'
    }
    
    It 'Should filter by check IDs' {
        $specific = Get-RegisteredChecks -CheckIds @('RE01', 'SE05')
        
        $specific.Count | Should -Be 2
        $specific.CheckId | Should -Contain 'RE01'
        $specific.CheckId | Should -Contain 'SE05'
    }
}

AfterAll {
    Remove-Module WafScanner -Force -ErrorAction SilentlyContinue
}
```

#### Step 4: Run Tests
```powershell
# Run all tests
Invoke-Pester -Path ./tests -Output Detailed

# Run with code coverage
Invoke-Pester -Path ./tests -CodeCoverage ./modules/**/*.ps1 -Output Detailed
```

**✅ Checkpoint:** Tests should pass with 0 failures

---

### Day 2: Create Check Validation Tests

Create `tests/Checks/CheckValidation.Tests.ps1`:

```powershell
BeforeAll {
    $ModulePath = "$PSScriptRoot/../../modules/WafScanner.psm1"
    Import-Module $ModulePath -Force
}

Describe 'Check Implementation Validation' {
    BeforeAll {
        $checks = Get-RegisteredChecks
    }
    
    It 'Should have all checks with required properties' {
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
    
    It 'Should follow naming convention (RE01, SE05, etc)' {
        foreach ($check in $checks) {
            $check.CheckId | Should -Match '^(RE|SE|CO|PE|OE)\d{2}$'
        }
    }
    
    It 'Should have documentation URLs' {
        $checksWithoutDocs = $checks | Where-Object { 
            [string]::IsNullOrEmpty($_.DocumentationUrl) 
        }
        
        # Allow some checks without docs, but warn if too many
        if ($checksWithoutDocs.Count -gt 10) {
            Write-Warning "$($checksWithoutDocs.Count) checks missing documentation URLs"
        }
    }
}

Describe 'Check Script Block Validation' {
    BeforeAll {
        $checks = Get-RegisteredChecks
    }
    
    It 'Should accept SubscriptionId parameter' {
        foreach ($check in $checks) {
            $params = $check.ScriptBlock.Ast.ParamBlock.Parameters
            $hasSubParam = $params.Name.VariablePath.UserPath -contains 'SubscriptionId'
            
            $hasSubParam | Should -Be $true -Because "Check $($check.CheckId) must accept SubscriptionId parameter"
        }
    }
}
```

**✅ Checkpoint:** All check validation tests pass

---

### Day 3: Implement PSScriptAnalyzer

Create `.vscode/PSScriptAnalyzerSettings.psd1` (if not exists):

```powershell
@{
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingWriteHost',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidGlobalVars',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUsePSCredentialType'
    )
    
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'  # We use Write-Host for console output
    )
    
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
        }
        
        PSPlaceCloseBrace = @{
            Enable = $true
            NoEmptyLineBefore = $false
        }
        
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
        }
        
        PSUseConsistentWhitespace = @{
            Enable = $true
        }
    }
}
```

Run analyzer:
```powershell
# Analyze all PowerShell files
Invoke-ScriptAnalyzer -Path ./modules -Recurse -ReportSummary

# Fix auto-fixable issues
Invoke-ScriptAnalyzer -Path ./modules -Recurse -Fix
```

**✅ Checkpoint:** No critical PSScriptAnalyzer issues

---

### Day 4: Create GitHub Actions CI Pipeline

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Test PowerShell Module
    runs-on: windows-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup PowerShell
        shell: pwsh
        run: |
          $PSVersionTable
          
      - name: Install Dependencies
        shell: pwsh
        run: |
          Install-Module Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0
          Install-Module PSScriptAnalyzer -Force
      
      - name: Run Pester Tests
        shell: pwsh
        run: |
          $config = New-PesterConfiguration
          $config.Run.Path = './tests'
          $config.TestResult.Enabled = $true
          $config.TestResult.OutputPath = 'TestResults.xml'
          $config.TestResult.OutputFormat = 'NUnitXml'
          $config.CodeCoverage.Enabled = $true
          $config.CodeCoverage.Path = './modules/**/*.ps1'
          $config.CodeCoverage.OutputPath = 'coverage.xml'
          $config.CodeCoverage.OutputFormat = 'JaCoCo'
          $config.Output.Verbosity = 'Detailed'
          
          Invoke-Pester -Configuration $config
      
      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action/composite@v2
        if: always()
        with:
          files: TestResults.xml
      
      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: coverage.xml
          flags: unittests
          name: codecov-umbrella
      
      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          $results = Invoke-ScriptAnalyzer -Path ./modules -Recurse -ReportSummary
          
          if ($results | Where-Object Severity -eq 'Error') {
            Write-Error "PSScriptAnalyzer found errors"
            exit 1
          }

  lint:
    name: Lint PowerShell Files
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          Install-Module PSScriptAnalyzer -Force
          Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary -Settings ./.vscode/PSScriptAnalyzerSettings.psd1
```

**✅ Checkpoint:** CI pipeline runs successfully

---

### Day 5: Add Status Badges and Documentation

#### Update README.md

Add badges at the top:
```markdown
# Azure Well-Architected Framework Scanner

![CI Status](https://github.com/dsvoda/Azure-WAF-Scanner/workflows/CI/badge.svg)
![Code Coverage](https://codecov.io/gh/dsvoda/Azure-WAF-Scanner/branch/main/graph/badge.svg)
![PowerShell Gallery](https://img.shields.io/powershellgallery/v/AzureWAFScanner.svg)
![Downloads](https://img.shields.io/powershellgallery/dt/AzureWAFScanner.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
```

#### Create CONTRIBUTING.md

Create `.github/CONTRIBUTING.md`:

```markdown
# Contributing to Azure WAF Scanner

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs
- Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include PowerShell version, Azure module versions, and error messages
- Provide steps to reproduce the issue

### Suggesting Features
- Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md)
- Explain the use case and expected behavior
- Consider implementation complexity

### Contributing Code

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Add tests** for your changes
5. **Run tests locally**: `Invoke-Pester -Path ./tests`
6. **Run PSScriptAnalyzer**: `Invoke-ScriptAnalyzer -Path ./modules -Recurse`
7. **Commit**: `git commit -m 'Add amazing feature'`
8. **Push**: `git push origin feature/amazing-feature`
9. **Open a Pull Request**

### Code Style

- Follow PowerShell best practices
- Use proper indentation (4 spaces)
- Add inline comments for complex logic
- Use descriptive variable names
- Follow the existing code structure

### Testing Requirements

- All new code must have tests
- Tests must pass before PR is merged
- Aim for >70% code coverage
- Test both success and failure scenarios

### Adding New Checks

See [Development Guide](docs/Development.md) for detailed instructions on creating new checks.

Quick template:
\`\`\`powershell
Register-WafCheck -CheckId 'XX01' `
    -Pillar 'PillarName' `
    -Title 'Check Title' `
    -Description 'What this checks' `
    -Severity 'Medium' `
    -RemediationEffort 'Low' `
    -DocumentationUrl 'https://...' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Your check logic
            
            return New-WafResult -CheckId 'XX01' `
                -Status 'Pass/Fail/Warning' `
                -Message 'Result message'
        } catch {
            return New-WafResult -CheckId 'XX01' `
                -Status 'Error' `
                -Message "Check failed: $($_.Exception.Message)"
        }
    }
\`\`\`

## Questions?

Open a [Discussion](https://github.com/dsvoda/Azure-WAF-Scanner/discussions) or reach out to the maintainers.

Thank you for contributing! 🎉
```

#### Create Issue Templates

Create `.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Bug Report
about: Report a bug or issue
title: '[BUG] '
labels: bug
assignees: ''
---

## Description
A clear description of the bug.

## Steps to Reproduce
1. Run command: `...`
2. See error

## Expected Behavior
What should have happened

## Actual Behavior
What actually happened

## Environment
- PowerShell Version: [e.g., 7.4.0]
- Az Module Version: [e.g., 11.0.0]
- Operating System: [e.g., Windows 11, Ubuntu 22.04]
- WAF Scanner Version: [e.g., 1.0.0]

## Error Messages
\`\`\`
Paste error messages here
\`\`\`

## Additional Context
Any other relevant information
```

Create `.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
---
name: Feature Request
about: Suggest a new feature
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Feature Description
Clear description of the feature

## Use Case
Why is this feature needed? What problem does it solve?

## Proposed Solution
How should this work?

## Alternatives Considered
Other ways to achieve the same goal

## Additional Context
Screenshots, examples, etc.
```

**✅ Checkpoint:** Community files in place, CI working

---

## 📅 Week 2: PowerShell Gallery & Distribution

### Day 1-2: Prepare Module for PowerShell Gallery

#### Update Module Manifest

Update `modules/AzureWAFScanner.psd1`:

```powershell
@{
    # Script module or binary module file associated with this manifest
    RootModule = 'WafScanner.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'YOUR-GUID-HERE'  # Generate with [guid]::NewGuid()
    
    # Author of this module
    Author = 'Your Name'
    
    # Company or vendor of this module
    CompanyName = 'Unknown'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 Your Name. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Azure Well-Architected Framework Scanner - Comprehensive assessment tool for Azure subscriptions with 60+ checks across all five WAF pillars.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' },
        @{ ModuleName = 'Az.ResourceGraph'; ModuleVersion = '0.13.0' },
        @{ ModuleName = 'Az.Advisor'; ModuleVersion = '2.0.0' }
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Register-WafCheck',
        'Get-RegisteredChecks',
        'New-WafResult',
        'Invoke-AzResourceGraphQuery',
        'Invoke-WafCheck',
        'Invoke-WafSubscriptionScan',
        'Get-WafScanSummary',
        'Compare-WafBaseline',
        'Initialize-WafScanner'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @('Invoke-Arg')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Azure', 'WAF', 'Well-Architected', 'Assessment', 'Security', 'Compliance', 'Best-Practices', 'Cloud')
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/dsvoda/Azure-WAF-Scanner/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/dsvoda/Azure-WAF-Scanner'
            
            # A URL to an icon representing this module
            IconUri = 'https://raw.githubusercontent.com/dsvoda/Azure-WAF-Scanner/main/docs/images/icon.png'
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release with 60 checks covering all five WAF pillars.'
            
            # Prerelease string of this module
            # Prerelease = 'alpha'
            
            # Flag to indicate whether the module requires explicit user acceptance for install/update
            # RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }
}
```

#### Test Module Manifest

```powershell
# Test manifest is valid
Test-ModuleManifest -Path ./modules/AzureWAFScanner.psd1

# Test module imports
Import-Module ./modules/AzureWAFScanner.psd1 -Force

# Verify exported functions
Get-Command -Module AzureWAFScanner
```

**✅ Checkpoint:** Module manifest is valid and imports correctly

---

### Day 3: Create Publishing Scripts

Create `build/Publish-PSGallery.ps1`:

```powershell
<#
.SYNOPSIS
    Publishes the Azure WAF Scanner module to PowerShell Gallery.

.DESCRIPTION
    Builds and publishes the module to PSGallery with proper validation.

.PARAMETER ApiKey
    PowerShell Gallery API key.

.PARAMETER WhatIf
    Show what would be published without actually publishing.

.EXAMPLE
    ./build/Publish-PSGallery.ps1 -ApiKey $env:PSGALLERY_API_KEY
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ApiKey,
    
    [string]$ModulePath = "./modules",
    [string]$Repository = "PSGallery"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== PowerShell Gallery Publishing Script ===" -ForegroundColor Cyan
Write-Host ""

# Validate module
Write-Host "[1/5] Validating module manifest..." -ForegroundColor Cyan
$manifestPath = Join-Path $ModulePath "AzureWAFScanner.psd1"

if (!(Test-Path $manifestPath)) {
    throw "Module manifest not found: $manifestPath"
}

$manifest = Test-ModuleManifest -Path $manifestPath
Write-Host "  ✓ Module: $($manifest.Name) v$($manifest.Version)" -ForegroundColor Green
Write-Host "  ✓ Author: $($manifest.Author)" -ForegroundColor Green
Write-Host ""

# Run tests
Write-Host "[2/5] Running tests..." -ForegroundColor Cyan
$testResult = Invoke-Pester -Path ./tests -PassThru -Output Minimal

if ($testResult.FailedCount -gt 0) {
    throw "Tests failed! Fix tests before publishing."
}
Write-Host "  ✓ All tests passed" -ForegroundColor Green
Write-Host ""

# Run PSScriptAnalyzer
Write-Host "[3/5] Running PSScriptAnalyzer..." -ForegroundColor Cyan
$analysisResults = Invoke-ScriptAnalyzer -Path $ModulePath -Recurse

$errors = $analysisResults | Where-Object Severity -eq 'Error'
$warnings = $analysisResults | Where-Object Severity -eq 'Warning'

if ($errors) {
    Write-Error "PSScriptAnalyzer found errors:"
    $errors | Format-Table -AutoSize
    throw "Fix errors before publishing"
}

if ($warnings) {
    Write-Warning "PSScriptAnalyzer found $($warnings.Count) warnings (non-blocking)"
}

Write-Host "  ✓ No critical issues found" -ForegroundColor Green
Write-Host ""

# Create temp directory for publishing
Write-Host "[4/5] Preparing module for publishing..." -ForegroundColor Cyan
$tempPath = Join-Path $env:TEMP "AzureWAFScanner-Publish"

if (Test-Path $tempPath) {
    Remove-Item $tempPath -Recurse -Force
}

New-Item -ItemType Directory -Path $tempPath | Out-Null

# Copy module files
Copy-Item -Path "$ModulePath/*" -Destination $tempPath -Recurse -Exclude @('.git', 'tests', 'docs')

Write-Host "  ✓ Module prepared in: $tempPath" -ForegroundColor Green
Write-Host ""

# Publish
Write-Host "[5/5] Publishing to PowerShell Gallery..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("AzureWAFScanner v$($manifest.Version)", "Publish to PSGallery")) {
    try {
        Publish-Module -Path $tempPath `
            -NuGetApiKey $ApiKey `
            -Repository $Repository `
            -Verbose
        
        Write-Host ""
        Write-Host "✓ Successfully published!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Module URL: https://www.powershellgallery.com/packages/AzureWAFScanner/$($manifest.Version)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Users can now install with:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name AzureWAFScanner" -ForegroundColor White
        Write-Host ""
        
    } catch {
        Write-Error "Failed to publish: $_"
        throw
    } finally {
        # Cleanup
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Recurse -Force
        }
    }
} else {
    Write-Host "WhatIf: Would publish module to PSGallery" -ForegroundColor Yellow
    Write-Host "Module files in: $tempPath" -ForegroundColor Gray
}
```

**✅ Checkpoint:** Publishing script created and tested with -WhatIf

---

### Day 4: Publish to PowerShell Gallery

#### Register for PowerShell Gallery API Key

1. Go to https://www.powershellgallery.com/
2. Sign in with Microsoft account
3. Click your username → API Keys
4. Create new API key with permissions:
   - Push new packages and package versions
   - Push only new package versions
5. Copy API key

#### Test Publishing

```powershell
# Test with WhatIf first
./build/Publish-PSGallery.ps1 -ApiKey "YOUR_API_KEY" -WhatIf

# Actually publish
./build/Publish-PSGallery.ps1 -ApiKey "YOUR_API_KEY"
```

#### Verify Publication

```powershell
# Wait a few minutes, then test
Find-Module -Name AzureWAFScanner

# Install in clean environment
Install-Module -Name AzureWAFScanner -Scope CurrentUser

# Test it works
Import-Module AzureWAFScanner
Get-Command -Module AzureWAFScanner
```

#### Update README

```markdown
## 🚀 Installation

### From PowerShell Gallery (Recommended)
\`\`\`powershell
Install-Module -Name AzureWAFScanner -Scope CurrentUser
Import-Module AzureWAFScanner
\`\`\`

### From Source
\`\`\`powershell
git clone https://github.com/dsvoda/Azure-WAF-Scanner.git
cd Azure-WAF-Scanner
Import-Module ./modules/WafScanner.psm1
\`\`\`

## 💻 Quick Start

\`\`\`powershell
# Connect to Azure
Connect-AzAccount

# Run scan
Invoke-WafSubscriptionScan -SubscriptionId "your-sub-id" | 
    Export-Csv -Path "waf-results.csv"
\`\`\`
```

**✅ Checkpoint:** Module published and installable from PSGallery!

---

### Day 5: Docker Support

Create `Dockerfile`:

```dockerfile
# Use official PowerShell image
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# Set labels
LABEL maintainer="your-email@example.com"
LABEL description="Azure Well-Architected Framework Scanner"
LABEL version="1.0.0"

# Install Azure modules
RUN pwsh -Command " \
    Install-Module -Name Az.Accounts -Force -Scope AllUsers; \
    Install-Module -Name Az.Resources -Force -Scope AllUsers; \
    Install-Module -Name Az.ResourceGraph -Force -Scope AllUsers; \
    Install-Module -Name Az.Advisor -Force -Scope AllUsers; \
    "

# Copy application files
WORKDIR /app
COPY modules/ ./modules/
COPY run/ ./run/
COPY config/ ./config/
COPY LICENSE README.md ./

# Create output directory
RUN mkdir -p /app/output

# Set default command
ENTRYPOINT ["pwsh", "./run/Invoke-WafLocal.ps1"]
CMD ["-EmitJson", "-OutputPath", "/app/output"]

# Volume for output
VOLUME ["/app/output"]
```

Create `.dockerignore`:

```
.git
.github
tests
docs
.vscode
*.md
!README.md
!LICENSE
```

Build and test:

```bash
# Build image
docker build -t azurewafscan:1.0.0 .

# Test run (requires Azure credentials)
docker run -it --rm \
    -v $(pwd)/output:/app/output \
    -e ARM_SUBSCRIPTION_ID=your-sub-id \
    azurewafscan:1.0.0 -EmitHtml -EmitJson

# View results
ls -la ./output/
```

Create automated Docker build:

`.github/workflows/docker-publish.yml`:

```yaml
name: Docker

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=ref,event=branch
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

**✅ Checkpoint:** Docker image builds successfully

---

## ✅ Final Checklist

### Week 1 Complete
- [ ] Pester tests created and passing
- [ ] PSScriptAnalyzer configured and passing
- [ ] GitHub Actions CI pipeline running
- [ ] Code coverage reporting configured
- [ ] CONTRIBUTING.md created
- [ ] Issue templates created
- [ ] PR template created
- [ ] Status badges added to README

### Week 2 Complete
- [ ] Module manifest updated for PSGallery
- [ ] Publishing script created and tested
- [ ] Module published to PowerShell Gallery
- [ ] Installation instructions updated
- [ ] Docker image created and tested
- [ ] Automated Docker builds configured
- [ ] Documentation updated

---

## 🎉 Success Criteria

After completing these two weeks, you should have:

1. **Professional Testing** - Automated tests with >70% coverage
2. **CI/CD Pipeline** - Every commit tested automatically
3. **Easy Installation** - `Install-Module AzureWAFScanner`
4. **Container Support** - Docker image for easy deployment
5. **Community Ready** - All contribution guidelines in place

---

## 📝 Notes

- Replace `YOUR-GUID-HERE` with actual GUID: `[guid]::NewGuid()`
- Store PSGallery API key securely (GitHub Secrets)
- Test everything in a clean environment before publishing
- Consider creating a v0.9.0 preview release first

---

## 🆘 Troubleshooting

### Tests Failing
```powershell
# Run specific test with verbose output
Invoke-Pester -Path ./tests/Unit/WafScanner.Tests.ps1 -Output Detailed
```

### Module Not Importing
```powershell
# Check manifest
Test-ModuleManifest -Path ./modules/AzureWAFScanner.psd1 -Verbose

# Check required modules
Get-Module -ListAvailable Az.*
```

### Docker Build Failing
```bash
# Build with debug output
docker build --progress=plain --no-cache -t azurewafscan:debug .

# Check specific layer
docker run -it mcr.microsoft.com/powershell:7.4-ubuntu-22.04 /bin/bash
```

---

**Need Help?** Review the main analysis document or reach out for guidance on any step!
