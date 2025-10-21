<#
.SYNOPSIS
    Tests the Azure WAF Scanner installation and functionality.

.DESCRIPTION
    Verifies that all components are properly installed and working.
    Runs a series of validation tests without requiring Azure connection.
#>

[CmdletBinding()]
param(
    [switch]$SkipModuleTests,
    [switch]$SkipAzureTests,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$script:TestResults = @()
$script:PassedTests = 0
$script:FailedTests = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed) {
        $script:PassedTests++
        Write-Host "  ✅ " -NoNewline -ForegroundColor Green
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) {
            Write-Host "     → $Message" -ForegroundColor Gray
        }
    } else {
        $script:FailedTests++
        Write-Host "  ❌ " -NoNewline -ForegroundColor Red
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) {
            Write-Host "     → $Message" -ForegroundColor Yellow
        }
    }
    
    $script:TestResults += [PSCustomObject]@{
        Test = $TestName
        Passed = $Passed
        Message = $Message
    }
}

# Banner
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                               ║" -ForegroundColor Cyan
Write-Host "║        Azure WAF Scanner - Installation Test                 ║" -ForegroundColor Cyan
Write-Host "║                                                               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Test 1: PowerShell Version
Write-TestHeader "PowerShell Environment"

try {
    $psVersion = $PSVersionTable.PSVersion
    $versionOk = $psVersion.Major -ge 7
    Write-TestResult -TestName "PowerShell Version" -Passed $versionOk `
        -Message "Version $psVersion (requires 7.0+)"
} catch {
    Write-TestResult -TestName "PowerShell Version" -Passed $false -Message $_.Exception.Message
}

# Test 2: File Structure
Write-TestHeader "File Structure"

$requiredFiles = @(
    @{ Path = "./modules/WafScanner.psm1"; Name = "Main Module" },
    @{ Path = "./modules/WafScanner.psd1"; Name = "Module Manifest" },
    @{ Path = "./run/Invoke-WafLocal.ps1"; Name = "Runner Script" },
    @{ Path = "./config/config.json"; Name = "Configuration File" },
    @{ Path = "./modules/Report/New-EnhancedWafHtml.ps1"; Name = "HTML Generator" }
)

foreach ($file in $requiredFiles) {
    $exists = Test-Path $file.Path
    Write-TestResult -TestName $file.Name -Passed $exists -Message $file.Path
}

# Test 3: Check Files
Write-TestHeader "Check Files"

try {
    $checkFiles = Get-ChildItem -Path "./modules/Pillars" -Filter "Invoke.ps1" -Recurse -ErrorAction Stop
    $checkCount = $checkFiles.Count
    Write-TestResult -TestName "Check Files Found" -Passed ($checkCount -gt 0) `
        -Message "Found $checkCount check files"
    
    # Validate check format
    $sampleCheck = Get-Content $checkFiles[0].FullName -Raw
    $hasRegister = $sampleCheck -match 'Register-WafCheck'
    Write-TestResult -TestName "Check Format" -Passed $hasRegister `
        -Message "Checks use Register-WafCheck"
        
} catch {
    Write-TestResult -TestName "Check Files" -Passed $false -Message $_.Exception.Message
}

# Test 4: Module Loading
if (!$SkipModuleTests) {
    Write-TestHeader "Module Loading"
    
    try {
        Import-Module "./modules/WafScanner.psm1" -Force -ErrorAction Stop
        Write-TestResult -TestName "Module Import" -Passed $true -Message "WafScanner.psm1 loaded"
        
        # Test exported functions
        $exportedFunctions = @(
            'Register-WafCheck',
            'Get-RegisteredChecks',
            'New-WafResult',
            'Invoke-AzResourceGraphQuery',
            'Invoke-WafSubscriptionScan',
            'Get-WafScanSummary'
        )
        
        foreach ($func in $exportedFunctions) {
            $exists = Get-Command $func -ErrorAction SilentlyContinue
            Write-TestResult -TestName "Function: $func" -Passed ($null -ne $exists)
        }
        
        # Test check registration
        $checks = Get-RegisteredChecks
        $checkCount = $checks.Count
        Write-TestResult -TestName "Checks Registered" -Passed ($checkCount -gt 0) `
            -Message "$checkCount checks loaded"
        
        # Validate check structure
        if ($checks.Count -gt 0) {
            $sample = $checks[0]
            $hasRequiredProps = ($sample.CheckId -and $sample.Pillar -and $sample.Title -and $sample.ScriptBlock)
            Write-TestResult -TestName "Check Structure" -Passed $hasRequiredProps `
                -Message "Checks have required properties"
        }
        
    } catch {
        Write-TestResult -TestName "Module Loading" -Passed $false -Message $_.Exception.Message
    }
}

# Test 5: Azure Modules
Write-TestHeader "Azure Modules"

$requiredModules = @(
    @{ Name = 'Az.Accounts'; MinVersion = '2.0.0' },
    @{ Name = 'Az.Resources'; MinVersion = '6.0.0' },
    @{ Name = 'Az.ResourceGraph'; MinVersion = '0.13.0' }
)

foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module.Name | 
        Where-Object { $_.Version -ge [version]$module.MinVersion } |
        Select-Object -First 1
    
    if ($installed) {
        Write-TestResult -TestName "$($module.Name)" -Passed $true `
            -Message "Version $($installed.Version)"
    } else {
        Write-TestResult -TestName "$($module.Name)" -Passed $false `
            -Message "Not installed (requires >= $($module.MinVersion))"
    }
}

# Test 6: Azure Connection (optional)
if (!$SkipAzureTests) {
    Write-TestHeader "Azure Connection"
    
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        if ($context) {
            Write-TestResult -TestName "Azure Context" -Passed $true `
                -Message "Connected as $($context.Account.Id)"
            
            Write-TestResult -TestName "Subscription Access" -Passed $true `
                -Message "Current: $($context.Subscription.Name)"
            
            # Test Resource Graph
            try {
                $testQuery = "Resources | take 1"
                $result = Search-AzGraph -Query $testQuery -ErrorAction Stop
                Write-TestResult -TestName "Resource Graph Query" -Passed $true `
                    -Message "API accessible"
            } catch {
                Write-TestResult -TestName "Resource Graph Query" -Passed $false `
                    -Message $_.Exception.Message
            }
            
        } else {
            Write-TestResult -TestName "Azure Context" -Passed $false `
                -Message "Not connected (run Connect-AzAccount)"
        }
        
    } catch {
        Write-TestResult -TestName "Azure Connection" -Passed $false -Message $_.Exception.Message
    }
}

# Test 7: Configuration
Write-TestHeader "Configuration"

try {
    if (Test-Path "./config/config.json") {
        $config = Get-Content "./config/config.json" -Raw | ConvertFrom-Json
        Write-TestResult -TestName "Config File Valid" -Passed $true `
            -Message "JSON parsed successfully"
        
        $hasExclusions = $null -ne $config.excludedPillars
        Write-TestResult -TestName "Config Structure" -Passed $hasExclusions `
            -Message "Has expected properties"
    }
} catch {
    Write-TestResult -TestName "Configuration" -Passed $false -Message $_.Exception.Message
}

# Test 8: Output Directory
Write-TestHeader "Output Configuration"

try {
    $outputPath = "./waf-output"
    if (!(Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    Write-TestResult -TestName "Output Directory" -Passed $true -Message $outputPath
    
    # Test write permissions
    $testFile = Join-Path $outputPath "test-$(Get-Random).txt"
    "test" | Set-Content $testFile
    Remove-Item $testFile -Force
    Write-TestResult -TestName "Write Permissions" -Passed $true
    
} catch {
    Write-TestResult -TestName "Output Directory" -Passed $false -Message $_.Exception.Message
}

# Summary
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      TEST SUMMARY                             ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$totalTests = $script:PassedTests + $script:FailedTests
$passRate = if ($totalTests -gt 0) { [Math]::Round(($script:PassedTests / $totalTests) * 100, 1) } else { 0 }

Write-Host "  Total Tests:   " -NoNewline
Write-Host $totalTests -ForegroundColor White

Write-Host "  Passed:        " -NoNewline
Write-Host $script:PassedTests -ForegroundColor Green

Write-Host "  Failed:        " -NoNewline
Write-Host $script:FailedTests -ForegroundColor $(if ($script:FailedTests -eq 0) { 'Green' } else { 'Red' })

Write-Host "  Pass Rate:     " -NoNewline
$rateColor = if ($passRate -ge 90) { 'Green' } elseif ($passRate -ge 70) { 'Yellow' } else { 'Red' }
Write-Host "$passRate%" -ForegroundColor $rateColor

Write-Host ""

# Final verdict
if ($script:FailedTests -eq 0) {
    Write-Host "  ✅ All tests passed! Scanner is ready to use." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Connect to Azure: " -NoNewline -ForegroundColor Gray
    Write-Host "Connect-AzAccount" -ForegroundColor White
    Write-Host "  2. Run first scan: " -NoNewline -ForegroundColor Gray
    Write-Host "pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml" -ForegroundColor White
    Write-Host "  3. View results: " -NoNewline -ForegroundColor Gray
    Write-Host "Open ./waf-output/*.html" -ForegroundColor White
    exit 0
} else {
    Write-Host "  ⚠️  Some tests failed. Review errors above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Common fixes:" -ForegroundColor Cyan
    
    if ($script:TestResults | Where-Object { $_.Test -like "*Azure*" -and !$_.Passed }) {
        Write-Host "  - Install Az modules: " -NoNewline -ForegroundColor Gray
        Write-Host "Install-Module Az -Scope CurrentUser" -ForegroundColor White
    }
    
    if ($script:TestResults | Where-Object { $_.Test -like "*File*" -and !$_.Passed }) {
        Write-Host "  - Verify file paths and permissions" -ForegroundColor Gray
    }
    
    if ($script:TestResults | Where-Object { $_.Test -like "*Module*" -and !$_.Passed }) {
        Write-Host "  - Check WafScanner.psm1 for syntax errors" -ForegroundColor Gray
    }
    
    exit 1
}

Write-Host ""
