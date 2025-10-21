<#
.SYNOPSIS
    Azure Well-Architected Framework Scanner - Production Ready
    
.DESCRIPTION
    Scans Azure subscriptions against the Microsoft Well-Architected Framework.
    Produces JSON/CSV/HTML reports with baseline comparison.

.PARAMETER Subscriptions
    Array of subscription IDs or names to scan.

.PARAMETER OutputPath
    Output directory for reports. Default: ./waf-output

.PARAMETER EmitJson
    Generate JSON output files.

.PARAMETER EmitCsv
    Generate CSV output files.

.PARAMETER EmitHtml
    Generate HTML report.

.PARAMETER ConfigFile
    Path to configuration file. Default: ./config/config.json

.PARAMETER BaselineFile
    Path to baseline scan results for comparison.

.PARAMETER ExcludedPillars
    Array of pillar names to exclude.

.PARAMETER ExcludedChecks
    Array of check IDs to exclude.

.PARAMETER Parallel
    Process subscriptions in parallel.

.PARAMETER MaxParallelism
    Maximum parallel threads. Default: 5

.EXAMPLE
    .\Invoke-WafLocal.ps1 -EmitHtml
    
.EXAMPLE
    .\Invoke-WafLocal.ps1 -Subscriptions "sub1","sub2" -Parallel -EmitHtml -EmitCsv
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string[]]$Subscriptions,
    
    [string]$OutputPath = "./waf-output",
    
    [switch]$EmitJson,
    [switch]$EmitCsv,
    [switch]$EmitHtml,
    
    [string]$ConfigFile = "./config/config.json",
    
    [string]$BaselineFile,
    
    [string[]]$ExcludedPillars = @(),
    [string[]]$ExcludedChecks = @(),
    
    [switch]$Parallel,
    
    [ValidateRange(1, 20)]
    [int]$MaxParallelism = 5
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date

#region Helper Functions

function Write-ScanLog {
    param(
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
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
    Write-Host "[$Level]".PadRight(10) -NoNewline -ForegroundColor $color
    Write-Host $Message
}

function Get-WafConfig {
    param([string]$Path)
    
    if (!(Test-Path $Path)) {
        Write-ScanLog "No config file found, using defaults" -Level Warning
        return @{
            excludedPillars = @()
            excludedChecks = @()
        }
    }
    
    try {
        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
        Write-ScanLog "Loaded configuration from $Path" -Level Success
        return $config
    } catch {
        Write-ScanLog "Failed to load config: $_" -Level Error
        throw
    }
}

function Export-WafResults {
    param(
        [array]$Results,
        [object]$Summary,
        [string]$OutputPath,
        [string]$SubscriptionId,
        [string]$Timestamp
    )
    
    $baseFileName = "$SubscriptionId-$Timestamp"
    
    # JSON
    if ($EmitJson -or (!$EmitCsv -and !$EmitHtml)) {
        $jsonPath = Join-Path $OutputPath "$baseFileName.json"
        $Results | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        Write-ScanLog "JSON saved: $jsonPath" -Level Success
        
        $summaryPath = Join-Path $OutputPath "$baseFileName-summary.json"
        $Summary | ConvertTo-Json -Depth 10 | Set-Content $summaryPath -Encoding UTF8
        Write-ScanLog "Summary saved: $summaryPath" -Level Success
    }
    
    # CSV
    if ($EmitCsv) {
        $csvPath = Join-Path $OutputPath "$baseFileName.csv"
        $Results | Select-Object CheckId, Pillar, Title, Status, Severity, Message, Recommendation | 
            Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-ScanLog "CSV saved: $csvPath" -Level Success
    }
    
    # HTML
    if ($EmitHtml) {
        $htmlPath = Join-Path $OutputPath "$baseFileName.html"
        
        # Import HTML generation function
        $htmlScript = Join-Path $PSScriptRoot "../modules/Report/New-EnhancedWafHtml.ps1"
        if (Test-Path $htmlScript) {
            . $htmlScript
            
            $comparison = if ($BaselineFile) {
                Compare-WafBaseline -CurrentResults $Results -BaselinePath $BaselineFile
            } else {
                $null
            }
            
            New-EnhancedWafHtml -Results $Results -Summary $Summary -Comparison $comparison -OutputPath $htmlPath
            Write-ScanLog "HTML saved: $htmlPath" -Level Success
        } else {
            Write-ScanLog "HTML generator not found: $htmlScript" -Level Warning
        }
    }
}

#endregion

#region Main Execution

try {
    # Banner
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                               ║" -ForegroundColor Cyan
    Write-Host "║        Azure Well-Architected Framework Scanner              ║" -ForegroundColor Cyan
    Write-Host "║                                                               ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-ScanLog "Scan started" -Level Info
    
    # Create output directory
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-ScanLog "Created output directory: $OutputPath" -Level Success
    }
    
    # Load configuration
    $config = Get-WafConfig -Path $ConfigFile
    
    # Merge parameters with config
    if ($ExcludedPillars) { $config.excludedPillars = $ExcludedPillars }
    if ($ExcludedChecks) { $config.excludedChecks = $ExcludedChecks }
    
    # Load WAF Scanner module
    $modulePath = Join-Path $PSScriptRoot "../modules/WafScanner.psm1"
    
    if (!(Test-Path $modulePath)) {
        throw "WafScanner module not found: $modulePath"
    }
    
    Write-ScanLog "Loading WAF Scanner module..." -Level Info
    Import-Module $modulePath -Force -Verbose:$false
    
    $checkCount = (Get-RegisteredChecks).Count
    Write-ScanLog "Loaded $checkCount checks" -Level Success
    
    # Check Azure connection
    Write-ScanLog "Checking Azure connection..." -Level Info
    
    try {
        $context = Get-AzContext -ErrorAction Stop
    } catch {
        Write-ScanLog "Not connected to Azure. Connecting..." -Level Warning
        Connect-AzAccount | Out-Null
        $context = Get-AzContext
    }
    
    if (!$context) {
        throw "Failed to establish Azure connection"
    }
    
    Write-ScanLog "Connected as: $($context.Account.Id)" -Level Success
    
    # Determine subscriptions to scan
    if (!$Subscriptions) {
        $Subscriptions = @($context.Subscription.Id)
        Write-ScanLog "Using current subscription: $($context.Subscription.Name)" -Level Info
    } else {
        Write-ScanLog "Target subscriptions: $($Subscriptions.Count)" -Level Info
    }
    
    # Scan subscriptions
    $allResults = @()
    
    if ($Parallel -and $Subscriptions.Count -gt 1) {
        Write-ScanLog "Running parallel scans (parallelism: $MaxParallelism)" -Level Info
        
        $allResults = $Subscriptions | ForEach-Object -Parallel {
            $sub = $_
            $modulePath = $using:modulePath
            $excludePillars = $using:config.excludedPillars
            $excludeChecks = $using:config.excludedChecks
            
            # Import module in parallel runspace
            Import-Module $modulePath -Force -Verbose:$false
            
            # Run scan
            Invoke-WafSubscriptionScan -SubscriptionId $sub -ExcludePillars $excludePillars -ExcludeCheckIds $excludeChecks
            
        } -ThrottleLimit $MaxParallelism
        
    } else {
        foreach ($sub in $Subscriptions) {
            $results = Invoke-WafSubscriptionScan -SubscriptionId $sub `
                -ExcludePillars $config.excludedPillars `
                -ExcludeCheckIds $config.excludedChecks
            
            if ($results) {
                $allResults += $results
            }
        }
    }
    
    # Generate summary
    Write-Host ""
    Write-ScanLog "Generating summary..." -Level Info
    
    $summary = Get-WafScanSummary -Results $allResults -StartTime $script:StartTime
    
    # Compare with baseline if provided
    $comparison = $null
    if ($BaselineFile) {
        Write-ScanLog "Comparing with baseline..." -Level Info
        $comparison = Compare-WafBaseline -CurrentResults $allResults -BaselinePath $BaselineFile
    }
    
    # Export results
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $primarySubId = $Subscriptions[0] -replace '/.*  # Clean subscription ID
    
    Export-WafResults -Results $allResults -Summary $summary -OutputPath $OutputPath `
        -SubscriptionId $primarySubId -Timestamp $timestamp
    
    # Display summary
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                       SCAN SUMMARY                            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total Checks:      " -NoNewline
    Write-Host $summary.TotalChecks -ForegroundColor White
    
    Write-Host "  Passed:            " -NoNewline
    Write-Host $summary.Passed -ForegroundColor Green
    
    Write-Host "  Failed:            " -NoNewline
    Write-Host $summary.Failed -ForegroundColor Red
    
    Write-Host "  Warnings:          " -NoNewline
    Write-Host $summary.Warnings -ForegroundColor Yellow
    
    Write-Host "  N/A:               " -NoNewline
    Write-Host $summary.NotApplicable -ForegroundColor Gray
    
    Write-Host "  Errors:            " -NoNewline
    Write-Host $summary.Errors -ForegroundColor Red
    
    Write-Host ""
    Write-Host "  Compliance Score:  " -NoNewline
    $scoreColor = if ($summary.ComplianceScore -ge 80) { 'Green' } 
                  elseif ($summary.ComplianceScore -ge 60) { 'Yellow' } 
                  else { 'Red' }
    Write-Host "$($summary.ComplianceScore)%" -ForegroundColor $scoreColor
    
    Write-Host "  Duration:          " -NoNewline
    Write-Host $summary.Duration -ForegroundColor White
    Write-Host ""
    
    # Show by pillar
    Write-Host "  By Pillar:" -ForegroundColor Cyan
    foreach ($pillar in $summary.ByPillar) {
        $pillarName = $pillar.Pillar.PadRight(25)
        $score = "$($pillar.ComplianceScore)%".PadLeft(6)
        $details = "($($pillar.Passed)/$($pillar.Total) passed)"
        
        $pillarColor = if ($pillar.ComplianceScore -ge 80) { 'Green' }
                       elseif ($pillar.ComplianceScore -ge 60) { 'Yellow' }
                       else { 'Red' }
        
        Write-Host "    $pillarName" -NoNewline
        Write-Host $score -NoNewline -ForegroundColor $pillarColor
        Write-Host "  $details" -ForegroundColor Gray
    }
    
    # Show critical failures
    Write-Host ""
    $criticalFailures = $allResults | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'Critical' }
    
    if ($criticalFailures.Count -gt 0) {
        Write-Host "  ⚠️  CRITICAL ISSUES: $($criticalFailures.Count)" -ForegroundColor Red
        Write-Host ""
        foreach ($failure in $criticalFailures | Select-Object -First 5) {
            Write-Host "    • " -NoNewline -ForegroundColor Red
            Write-Host "$($failure.CheckId): " -NoNewline -ForegroundColor Yellow
            Write-Host $failure.Title -ForegroundColor White
        }
        if ($criticalFailures.Count -gt 5) {
            Write-Host "    ... and $($criticalFailures.Count - 5) more" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    SCAN COMPLETED                             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-ScanLog "Scan completed successfully!" -Level Success
    
} catch {
    Write-Host ""
    Write-ScanLog "FATAL ERROR: $_" -Level Error
    Write-ScanLog $_.ScriptStackTrace -Level Error
    throw
} finally {
    Write-Progress -Activity "Scanning" -Completed
}

#endregion
