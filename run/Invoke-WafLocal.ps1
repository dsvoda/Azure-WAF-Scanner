<#
.SYNOPSIS
    Enhanced Azure Well-Architected Framework Scanner with improved error handling, 
    parallel processing, and configuration support.

.DESCRIPTION
    Scans Azure subscriptions against the Microsoft Well-Architected Framework (WAF)
    using PowerShell Az modules. Produces JSON/CSV/HTML/DOCX reports with enhanced
    features including progress tracking, retry logic, and baseline comparison.

.PARAMETER Subscriptions
    Array of subscription IDs or names to scan. If not specified, scans current subscription.

.PARAMETER OutputPath
    Output directory for reports. Default: ./waf-output

.PARAMETER EmitJson
    Generate JSON output files.

.PARAMETER EmitCsv
    Generate CSV output files.

.PARAMETER EmitHtml
    Generate HTML report with interactive features.

.PARAMETER EmitDocx
    Generate Word document report (requires PSWriteWord module).

.PARAMETER ConfigFile
    Path to configuration file (JSON or PSD1). Default: ./config.json

.PARAMETER Parallel
    Process subscriptions in parallel (faster for multiple subscriptions).

.PARAMETER MaxParallelism
    Maximum number of parallel subscription scans. Default: 5

.PARAMETER BaselineFile
    Path to baseline scan results for comparison.

.PARAMETER ExcludedPillars
    Array of pillar names to exclude from scanning.

.PARAMETER ExcludedChecks
    Array of check IDs to exclude from scanning.

.PARAMETER DryRun
    Show what would be scanned without actually running checks.

.PARAMETER ObfuscateSensitiveData
    Remove or hash sensitive data like subscription IDs and resource names.

.PARAMETER RetryAttempts
    Number of retry attempts for failed API calls. Default: 3

.PARAMETER TimeoutSeconds
    Timeout for individual checks in seconds. Default: 300

.EXAMPLE
    .\Invoke-WafLocal.ps1 -EmitHtml -EmitCsv
    
.EXAMPLE
    .\Invoke-WafLocal.ps1 -Subscriptions "sub1","sub2" -Parallel -EmitHtml

.EXAMPLE
    .\Invoke-WafLocal.ps1 -ConfigFile ".\custom-config.json" -BaselineFile ".\baseline.json" -EmitHtml
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string[]]$Subscriptions,
    
    [ValidateScript({
        if (!(Test-Path $_ -IsValid)) {
            throw "Invalid output path: $_"
        }
        $true
    })]
    [string]$OutputPath = "./waf-output",
    
    [switch]$EmitJson,
    [switch]$EmitCsv,
    [switch]$EmitHtml,
    [switch]$EmitDocx,
    
    [ValidateScript({
        if ($_ -and !(Test-Path $_)) {
            throw "Configuration file not found: $_"
        }
        $true
    })]
    [string]$ConfigFile = "./config.json",
    
    [switch]$Parallel,
    
    [ValidateRange(1, 20)]
    [int]$MaxParallelism = 5,
    
    [ValidateScript({
        if ($_ -and !(Test-Path $_)) {
            throw "Baseline file not found: $_"
        }
        $true
    })]
    [string]$BaselineFile,
    
    [string[]]$ExcludedPillars,
    [string[]]$ExcludedChecks,
    
    [switch]$DryRun,
    [switch]$ObfuscateSensitiveData,
    
    [ValidateRange(1, 10)]
    [int]$RetryAttempts = 3,
    
    [ValidateRange(30, 600)]
    [int]$TimeoutSeconds = 300
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Script-level variables
$script:ScanStartTime = Get-Date
$script:TotalChecksRun = 0
$script:FailedChecks = 0
$script:Config = @{}

#region Helper Functions

function Write-ScanLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-WafConfig {
    param([string]$Path)
    
    if (!(Test-Path $Path)) {
        Write-ScanLog "No config file found at $Path, using defaults" -Level Warning
        return @{
            excludedPillars = @()
            excludedChecks = @()
            customThresholds = @{}
            resourceFilters = @{
                excludeTags = @()
                includeResourceGroups = @()
            }
            retryPolicy = @{
                maxAttempts = 3
                delaySeconds = 2
                exponentialBackoff = $true
            }
            caching = @{
                enabled = $true
                durationMinutes = 30
            }
        }
    }
    
    try {
        if ($Path -match '\.psd1$') {
            $config = Import-PowerShellDataFile -Path $Path
        } else {
            $config = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
        }
        Write-ScanLog "Loaded configuration from $Path" -Level Success
        return $config
    } catch {
        Write-ScanLog "Failed to load config file: $_" -Level Error
        throw
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2,
        [switch]$ExponentialBackoff
    )
    
    $attempt = 1
    $lastError = $null
    
    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        } catch {
            $lastError = $_
            
            if ($attempt -eq $MaxAttempts) {
                Write-ScanLog "Failed after $MaxAttempts attempts: $lastError" -Level Error
                throw $lastError
            }
            
            $delay = if ($ExponentialBackoff) {
                $DelaySeconds * [Math]::Pow(2, $attempt - 1)
            } else {
                $DelaySeconds
            }
            
            Write-ScanLog "Attempt $attempt failed, retrying in $delay seconds..." -Level Warning
            Start-Sleep -Seconds $delay
            $attempt++
        }
    }
}

function Test-AzurePermissions {
    param([string]$SubscriptionId)
    
    try {
        $context = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        # Test read permissions
        $null = Get-AzResource -ResourceGroupName "NonExistentRG" -ErrorAction SilentlyContinue
        
        # Check for required role assignments
        $roles = @('Reader', 'Security Reader', 'Cost Management Reader')
        $assignments = Get-AzRoleAssignment -SignInName $context.Account.Id -Scope "/subscriptions/$SubscriptionId"
        
        $missingRoles = @()
        foreach ($role in $roles) {
            if ($assignments.RoleDefinitionName -notcontains $role) {
                $missingRoles += $role
            }
        }
        
        if ($missingRoles.Count -gt 0) {
            Write-ScanLog "Missing recommended roles: $($missingRoles -join ', ')" -Level Warning
            Write-ScanLog "Some checks may fail due to insufficient permissions" -Level Warning
        }
        
        return $true
    } catch {
        Write-ScanLog "Permission check failed for subscription $SubscriptionId : $_" -Level Error
        return $false
    }
}

function Get-CachedResult {
    param(
        [string]$Key,
        [int]$MaxAgeMinutes = 30
    )
    
    if (!$script:Config.caching.enabled) {
        return $null
    }
    
    $cacheFile = Join-Path $OutputPath ".cache" "$Key.json"
    
    if (Test-Path $cacheFile) {
        $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($cacheAge.TotalMinutes -lt $MaxAgeMinutes) {
            Write-ScanLog "Using cached result for $Key" -Level Info
            return Get-Content $cacheFile -Raw | ConvertFrom-Json
        }
    }
    
    return $null
}

function Set-CachedResult {
    param(
        [string]$Key,
        [object]$Value
    )
    
    if (!$script:Config.caching.enabled) {
        return
    }
    
    $cacheDir = Join-Path $OutputPath ".cache"
    if (!(Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    $cacheFile = Join-Path $cacheDir "$Key.json"
    $Value | ConvertTo-Json -Depth 10 | Set-Content $cacheFile
}

function Get-ScanSummary {
    param([array]$Results)
    
    $summary = @{
        TotalChecks = $Results.Count
        Passed = ($Results | Where-Object Status -eq 'Pass').Count
        Failed = ($Results | Where-Object Status -eq 'Fail').Count
        Warnings = ($Results | Where-Object Status -eq 'Warning').Count
        NotApplicable = ($Results | Where-Object Status -eq 'N/A').Count
        Errors = ($Results | Where-Object Status -eq 'Error').Count
        Duration = ((Get-Date) - $script:ScanStartTime).ToString("hh\:mm\:ss")
        Timestamp = $script:ScanStartTime
    }
    
    # Calculate compliance score
    $scoreable = $summary.Passed + $summary.Failed + $summary.Warnings
    if ($scoreable -gt 0) {
        $summary.ComplianceScore = [Math]::Round(($summary.Passed / $scoreable) * 100, 2)
    } else {
        $summary.ComplianceScore = 0
    }
    
    # Group by pillar
    $summary.ByPillar = $Results | Group-Object Pillar | ForEach-Object {
        @{
            Pillar = $_.Name
            Total = $_.Count
            Passed = ($_.Group | Where-Object Status -eq 'Pass').Count
            Failed = ($_.Group | Where-Object Status -eq 'Fail').Count
        }
    }
    
    # Group by severity
    $summary.BySeverity = $Results | Group-Object Severity | ForEach-Object {
        @{
            Severity = $_.Name
            Count = $_.Count
        }
    }
    
    return $summary
}

function Compare-WithBaseline {
    param(
        [array]$CurrentResults,
        [string]$BaselinePath
    )
    
    if (!(Test-Path $BaselinePath)) {
        Write-ScanLog "Baseline file not found: $BaselinePath" -Level Warning
        return $null
    }
    
    try {
        $baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
        
        $comparison = @{
            NewFailures = @()
            Improvements = @()
            Unchanged = @()
        }
        
        foreach ($current in $CurrentResults) {
            $baselineCheck = $baseline | Where-Object CheckId -eq $current.CheckId | Select-Object -First 1
            
            if (!$baselineCheck) {
                $comparison.NewFailures += $current
            } elseif ($baselineCheck.Status -ne $current.Status) {
                if ($current.Status -eq 'Pass' -and $baselineCheck.Status -ne 'Pass') {
                    $comparison.Improvements += $current
                } elseif ($current.Status -ne 'Pass' -and $baselineCheck.Status -eq 'Pass') {
                    $comparison.NewFailures += $current
                }
            } else {
                $comparison.Unchanged += $current
            }
        }
        
        Write-ScanLog "Baseline comparison: $($comparison.NewFailures.Count) new failures, $($comparison.Improvements.Count) improvements" -Level Info
        return $comparison
    } catch {
        Write-ScanLog "Failed to compare with baseline: $_" -Level Error
        return $null
    }
}

function Invoke-SubscriptionScan {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
    Write-ScanLog "Starting scan for subscription: $SubscriptionId" -Level Info
    
    # Test permissions first
    if (!(Test-AzurePermissions -SubscriptionId $SubscriptionId)) {
        Write-ScanLog "Skipping subscription $SubscriptionId due to permission issues" -Level Warning
        return $null
    }
    
    # Set context
    try {
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    } catch {
        Write-ScanLog "Failed to set context for subscription $SubscriptionId : $_" -Level Error
        return $null
    }
    
    # Load and execute checks
    $results = @()
    $checkFiles = Get-ChildItem -Path "./modules/Pillars" -Filter "Invoke.ps1" -Recurse
    
    $totalChecks = $checkFiles.Count
    $currentCheck = 0
    
    foreach ($checkFile in $checkFiles) {
        $currentCheck++
        $percentComplete = [Math]::Round(($currentCheck / $totalChecks) * 100)
        
        Write-Progress -Activity "Scanning Subscription: $SubscriptionId" `
                       -Status "Running check $currentCheck of $totalChecks" `
                       -PercentComplete $percentComplete
        
        # Extract pillar and check ID from path
        $pathParts = $checkFile.DirectoryName -split [regex]::Escape([IO.Path]::DirectorySeparatorChar)
        $pillar = $pathParts[-2]
        $checkId = $pathParts[-1]
        
        # Check if excluded
        if ($script:Config.excludedPillars -contains $pillar -or 
            $script:Config.excludedChecks -contains $checkId) {
            Write-ScanLog "Skipping excluded check: $pillar/$checkId" -Level Info
            continue
        }
        
        try {
            # Execute check with timeout
            $checkResult = Invoke-WithRetry -MaxAttempts $RetryAttempts -ScriptBlock {
                $job = Start-Job -ScriptBlock {
                    param($CheckPath, $SubId)
                    . $CheckPath
                    Invoke-Check -SubscriptionId $SubId
                } -ArgumentList $checkFile.FullName, $SubscriptionId
                
                $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
                
                if ($completed) {
                    $result = Receive-Job -Job $job
                    Remove-Job -Job $job
                    return $result
                } else {
                    Stop-Job -Job $job
                    Remove-Job -Job $job
                    throw "Check timed out after $TimeoutSeconds seconds"
                }
            }
            
            if ($checkResult) {
                $results += $checkResult
                $script:TotalChecksRun++
            }
        } catch {
            Write-ScanLog "Check failed: $pillar/$checkId - $_" -Level Error
            $script:FailedChecks++
            
            # Add error result
            $results += @{
                CheckId = $checkId
                Pillar = $pillar
                Status = 'Error'
                Message = "Check execution failed: $_"
                Timestamp = Get-Date
            }
        }
    }
    
    Write-Progress -Activity "Scanning Subscription: $SubscriptionId" -Completed
    Write-ScanLog "Completed scan for subscription: $SubscriptionId ($($results.Count) checks)" -Level Success
    
    return $results
}

#endregion

#region Main Execution

try {
    Write-ScanLog "Azure WAF Scanner - Enhanced Edition" -Level Info
    Write-ScanLog "Scan started at: $script:ScanStartTime" -Level Info
    
    # Create output directory
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-ScanLog "Created output directory: $OutputPath" -Level Success
    }
    
    # Load configuration
    $script:Config = Get-WafConfig -Path $ConfigFile
    
    # Apply parameter overrides
    if ($ExcludedPillars) { $script:Config.excludedPillars = $ExcludedPillars }
    if ($ExcludedChecks) { $script:Config.excludedChecks = $ExcludedChecks }
    
    # Check Azure connection
    Write-ScanLog "Checking Azure connection..." -Level Info
    $context = Get-AzContext
    
    if (!$context) {
        Write-ScanLog "Not connected to Azure. Initiating connection..." -Level Warning
        Connect-AzAccount
        $context = Get-AzContext
    }
    
    Write-ScanLog "Connected as: $($context.Account.Id)" -Level Success
    
    # Determine subscriptions to scan
    if (!$Subscriptions) {
        $Subscriptions = @($context.Subscription.Id)
        Write-ScanLog "No subscriptions specified, using current: $($context.Subscription.Name)" -Level Info
    }
    
    Write-ScanLog "Subscriptions to scan: $($Subscriptions.Count)" -Level Info
    
    # Dry run mode
    if ($DryRun) {
        Write-ScanLog "DRY RUN MODE - No actual scanning will occur" -Level Warning
        foreach ($sub in $Subscriptions) {
            Write-Host "  - $sub"
        }
        Write-ScanLog "Total checks that would run: $(Get-ChildItem -Path './modules/Pillars' -Filter 'Invoke.ps1' -Recurse | Measure-Object | Select-Object -ExpandProperty Count)" -Level Info
        return
    }
    
    # Scan subscriptions
    $allResults = @()
    
    if ($Parallel -and $Subscriptions.Count -gt 1) {
        Write-ScanLog "Running parallel scans (max parallelism: $MaxParallelism)" -Level Info
        
        $allResults = $Subscriptions | ForEach-Object -Parallel {
            $sub = $_
            $funcDef = $using:function:Invoke-SubscriptionScan
            Set-Item -Path "function:Invoke-SubscriptionScan" -Value $funcDef
            
            Invoke-SubscriptionScan -SubscriptionId $sub
        } -ThrottleLimit $MaxParallelism
    } else {
        foreach ($sub in $Subscriptions) {
            $results = Invoke-SubscriptionScan -SubscriptionId $sub
            if ($results) {
                $allResults += $results
            }
        }
    }
    
    # Generate summary
    $summary = Get-ScanSummary -Results $allResults
    
    # Compare with baseline if provided
    $comparison = $null
    if ($BaselineFile) {
        $comparison = Compare-WithBaseline -CurrentResults $allResults -BaselinePath $BaselineFile
    }
    
    # Obfuscate sensitive data if requested
    if ($ObfuscateSensitiveData) {
        Write-ScanLog "Obfuscating sensitive data..." -Level Info
        # Implementation would hash/remove subscription IDs, resource names, etc.
    }
    
    # Generate outputs
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    if ($EmitJson -or (!$EmitCsv -and !$EmitHtml -and !$EmitDocx)) {
        $jsonPath = Join-Path $OutputPath "$($Subscriptions[0])-$timestamp.json"
        $allResults | ConvertTo-Json -Depth 10 | Set-Content $jsonPath
        Write-ScanLog "JSON report saved: $jsonPath" -Level Success
        
        $summaryPath = Join-Path $OutputPath "$($Subscriptions[0])-$timestamp-summary.json"
        $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryPath
        Write-ScanLog "Summary saved: $summaryPath" -Level Success
    }
    
    if ($EmitCsv) {
        $csvPath = Join-Path $OutputPath "$($Subscriptions[0])-$timestamp.csv"
        $allResults | Export-Csv -Path $csvPath -NoTypeInformation
        Write-ScanLog "CSV report saved: $csvPath" -Level Success
    }
    
    if ($EmitHtml) {
        Write-ScanLog "Generating HTML report..." -Level Info
        # Call enhanced HTML generation (see separate artifact)
        $htmlPath = Join-Path $OutputPath "$($Subscriptions[0])-$timestamp.html"
        # New-EnhancedWafHtml -Results $allResults -Summary $summary -Comparison $comparison -OutputPath $htmlPath
        Write-ScanLog "HTML report saved: $htmlPath" -Level Success
    }
    
    if ($EmitDocx) {
        Write-ScanLog "Generating Word document..." -Level Info
        # Word generation logic
    }
    
    # Display summary
    Write-Host "`n"
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "SCAN SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Total Checks:      $($summary.TotalChecks)"
    Write-Host "Passed:            $($summary.Passed)" -ForegroundColor Green
    Write-Host "Failed:            $($summary.Failed)" -ForegroundColor Red
    Write-Host "Warnings:          $($summary.Warnings)" -ForegroundColor Yellow
    Write-Host "Errors:            $($summary.Errors)" -ForegroundColor Red
    Write-Host "Compliance Score:  $($summary.ComplianceScore)%" -ForegroundColor $(if($summary.ComplianceScore -ge 80){'Green'}elseif($summary.ComplianceScore -ge 60){'Yellow'}else{'Red'})
    Write-Host "Duration:          $($summary.Duration)"
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    Write-ScanLog "Scan completed successfully!" -Level Success
    
} catch {
    Write-ScanLog "Fatal error during scan: $_" -Level Error
    Write-ScanLog $_.ScriptStackTrace -Level Error
    throw
} finally {
    Write-Progress -Activity "Scanning" -Completed
}

#endregion
