<#
.SYNOPSIS
    Azure WAF Scanner Core Module - Fixed and Production Ready
    
.DESCRIPTION
    Consolidated module with all helper functions, check registration,
    and execution logic properly integrated.
#>

#Requires -Version 7.0

# Module-level variables
$script:CheckRegistry = @()
$script:CacheStore = @{}
$script:ModuleRoot = $PSScriptRoot

#region Import Core Helper Functions

# Import all helper functions from Core directory
$coreFiles = @(
    'Connect-Context.ps1',
    'Get-Advisor.ps1',
    'Get-CostData.ps1',
    'Get-CostMonthly.ps1',
    'Get-DefenderAssessments.ps1',
    'Get-Orphans.ps1',
    'Get-PolicyState.ps1',
    'Get-Subscriptions.ps1',
    'Invoke-Arg.ps1',
    'Utils.ps1',
    'HtmlEngine.ps1'
)

foreach ($file in $coreFiles) {
    $filePath = Join-Path $PSScriptRoot "Core" $file
    if (Test-Path $filePath) {
        . $filePath
        Write-Verbose "Loaded: $file"
    } else {
        Write-Warning "Core file not found: $file"
    }
}

#endregion

#region Check Registration System

function Register-WafCheck {
    <#
    .SYNOPSIS
        Registers a WAF check to the scanner registry.
    
    .PARAMETER CheckId
        Unique identifier (e.g., "RE01", "SE05").
    
    .PARAMETER Pillar
        WAF pillar: Reliability, Security, CostOptimization, PerformanceEfficiency, OperationalExcellence.
    
    .PARAMETER Title
        Human-readable title for the check.
    
    .PARAMETER Description
        Detailed description of what this check validates.
    
    .PARAMETER Severity
        Severity level: Critical, High, Medium, Low.
    
    .PARAMETER RemediationEffort
        Estimated effort: Low, Medium, High.
    
    .PARAMETER ScriptBlock
        Check logic. Must accept [string]$SubscriptionId parameter.
    
    .PARAMETER Tags
        Optional tags for categorization.
    
    .PARAMETER DocumentationUrl
        URL to relevant documentation.
    
    .PARAMETER ComplianceFramework
        Compliance framework mapping (e.g., "CIS Azure 1.4.0").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^(RE|SE|CO|PE|OE)\d{2}$')]
        [string]$CheckId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Reliability', 'Security', 'CostOptimization', 'PerformanceEfficiency', 'OperationalExcellence')]
        [string]$Pillar,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$Severity = 'Medium',
        
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$RemediationEffort = 'Medium',
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [string[]]$Tags = @(),
        
        [string]$DocumentationUrl = '',
        
        [string]$ComplianceFramework = ''
    )
    
    # Check for duplicates
    if ($script:CheckRegistry | Where-Object CheckId -eq $CheckId) {
        Write-Warning "Check $CheckId is already registered. Skipping duplicate."
        return
    }
    
    $check = [PSCustomObject]@{
        CheckId = $CheckId
        Pillar = $Pillar
        Title = $Title
        Description = $Description
        Severity = $Severity
        RemediationEffort = $RemediationEffort
        ScriptBlock = $ScriptBlock
        Tags = $Tags
        DocumentationUrl = $DocumentationUrl
        ComplianceFramework = $ComplianceFramework
        RegisteredAt = Get-Date
    }
    
    $script:CheckRegistry += $check
    Write-Verbose "Registered check: $CheckId - $Title"
}

function Get-RegisteredChecks {
    <#
    .SYNOPSIS
        Gets all registered checks, optionally filtered.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Pillars,
        [string[]]$CheckIds,
        [string[]]$ExcludePillars,
        [string[]]$ExcludeCheckIds
    )
    
    $checks = $script:CheckRegistry
    
    # Apply filters
    if ($Pillars) {
        $checks = $checks | Where-Object { $Pillars -contains $_.Pillar }
    }
    
    if ($CheckIds) {
        $checks = $checks | Where-Object { $CheckIds -contains $_.CheckId }
    }
    
    if ($ExcludePillars) {
        $checks = $checks | Where-Object { $ExcludePillars -notcontains $_.Pillar }
    }
    
    if ($ExcludeCheckIds) {
        $checks = $checks | Where-Object { $ExcludeCheckIds -notcontains $_.CheckId }
    }
    
    return $checks
}

#endregion

#region Result Creation

function New-WafResult {
    <#
    .SYNOPSIS
        Creates a standardized WAF check result object.
    
    .PARAMETER CheckId
        The check identifier.
    
    .PARAMETER Status
        Result status: Pass, Fail, Warning, N/A, Error.
    
    .PARAMETER Message
        Result message describing the finding.
    
    .PARAMETER AffectedResources
        Array of affected resource IDs or names.
    
    .PARAMETER Recommendation
        Remediation recommendation.
    
    .PARAMETER RemediationScript
        Optional PowerShell/CLI script for remediation.
    
    .PARAMETER Metadata
        Additional metadata as hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CheckId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Fail', 'Warning', 'N/A', 'Error')]
        [string]$Status,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string[]]$AffectedResources = @(),
        
        [string]$Recommendation = '',
        
        [string]$RemediationScript = '',
        
        [hashtable]$Metadata = @{}
    )
    
    # Get check details from registry
    $checkInfo = $script:CheckRegistry | Where-Object CheckId -eq $CheckId | Select-Object -First 1
    
    if (!$checkInfo) {
        Write-Warning "Check $CheckId not found in registry"
        $checkInfo = [PSCustomObject]@{
            Pillar = 'Unknown'
            Title = 'Unknown'
            Description = ''
            Severity = 'Medium'
            RemediationEffort = 'Medium'
            DocumentationUrl = ''
        }
    }
    
    return [PSCustomObject]@{
        CheckId = $CheckId
        Pillar = $checkInfo.Pillar
        Title = $checkInfo.Title
        Description = $checkInfo.Description
        Severity = $checkInfo.Severity
        RemediationEffort = $checkInfo.RemediationEffort
        Status = $Status
        Message = $Message
        AffectedResources = $AffectedResources
        Recommendation = $Recommendation
        RemediationScript = $RemediationScript
        DocumentationUrl = $checkInfo.DocumentationUrl
        Timestamp = Get-Date
        Metadata = $Metadata
    }
}

#endregion

#region Azure Resource Graph Queries

function Invoke-AzResourceGraphQuery {
    <#
    .SYNOPSIS
        Executes Azure Resource Graph query with retry logic and pagination.
    
    .PARAMETER Query
        KQL query to execute.
    
    .PARAMETER SubscriptionId
        Target subscription ID.
    
    .PARAMETER MaxRetries
        Maximum retry attempts.
    
    .PARAMETER UseCache
        Whether to use cached results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [string]$SubscriptionId,
        
        [int]$MaxRetries = 3,
        
        [switch]$UseCache
    )
    
    $cacheKey = "$SubscriptionId-$($Query.GetHashCode())"
    
    # Check cache
    if ($UseCache -and $script:CacheStore.ContainsKey($cacheKey)) {
        $cached = $script:CacheStore[$cacheKey]
        $age = (Get-Date) - $cached.Timestamp
        
        if ($age.TotalMinutes -lt 30) {
            Write-Verbose "Using cached Resource Graph result (age: $($age.TotalMinutes.ToString('F1')) min)"
            return $cached.Data
        }
    }
    
    $attempt = 0
    $allResults = @()
    
    while ($attempt -lt $MaxRetries) {
        try {
            $params = @{
                Query = $Query
                First = 1000
            }
            
            if ($SubscriptionId) {
                $params.Subscription = $SubscriptionId
            }
            
            $skipToken = $null
            
            do {
                if ($skipToken) {
                    $params.SkipToken = $skipToken
                }
                
                $result = Search-AzGraph @params
                
                if ($result.Data) {
                    $allResults += $result.Data
                }
                
                $skipToken = $result.SkipToken
                
            } while ($skipToken)
            
            # Cache the result
            if ($UseCache) {
                $script:CacheStore[$cacheKey] = @{
                    Data = $allResults
                    Timestamp = Get-Date
                }
            }
            
            return $allResults
            
        } catch {
            $attempt++
            
            if ($_.Exception.Message -match "429|throttl" -and $attempt -lt $MaxRetries) {
                $delay = [Math]::Pow(2, $attempt)
                Write-Warning "Resource Graph throttled. Retrying in $delay seconds... (Attempt $attempt/$MaxRetries)"
                Start-Sleep -Seconds $delay
            } else {
                Write-Error "Resource Graph query failed after $MaxRetries attempts: $_"
                throw
            }
        }
    }
}

# Alias for backward compatibility with existing checks
Set-Alias -Name Invoke-Arg -Value Invoke-AzResourceGraphQuery

#endregion

#region Check Execution

function Invoke-WafCheck {
    <#
    .SYNOPSIS
        Executes a single WAF check with timeout and error handling.
    
    .PARAMETER Check
        The check object from the registry.
    
    .PARAMETER SubscriptionId
        Target subscription ID.
    
    .PARAMETER TimeoutSeconds
        Timeout for check execution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Check,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [int]$TimeoutSeconds = 300
    )
    
    Write-Verbose "Executing check: $($Check.CheckId) - $($Check.Title)"
    
    try {
        # Execute check with timeout
        $job = Start-Job -ScriptBlock {
            param($CheckScript, $SubId)
            & $CheckScript -SubscriptionId $SubId
        } -ArgumentList $Check.ScriptBlock, $SubscriptionId
        
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            return $result
        } else {
            Stop-Job -Job $job
            Remove-Job -Job $job
            
            # Return timeout error
            return New-WafResult -CheckId $Check.CheckId `
                -Status 'Error' `
                -Message "Check execution timed out after $TimeoutSeconds seconds" `
                -Recommendation "Increase timeout or optimize check query"
        }
    } catch {
        Write-Error "Check $($Check.CheckId) failed: $_"
        
        return New-WafResult -CheckId $Check.CheckId `
            -Status 'Error' `
            -Message "Check execution failed: $($_.Exception.Message)" `
            -Metadata @{
                ErrorType = $_.Exception.GetType().Name
                StackTrace = $_.ScriptStackTrace
            }
    }
}

function Invoke-WafSubscriptionScan {
    <#
    .SYNOPSIS
        Scans a single subscription with all registered checks.
    
    .PARAMETER SubscriptionId
        Target subscription ID.
    
    .PARAMETER ExcludePillars
        Pillars to exclude.
    
    .PARAMETER ExcludeCheckIds
        Specific checks to exclude.
    
    .PARAMETER TimeoutSeconds
        Timeout per check.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [string[]]$ExcludePillars = @(),
        [string[]]$ExcludeCheckIds = @(),
        [int]$TimeoutSeconds = 300
    )
    
    Write-Host "Scanning subscription: $SubscriptionId" -ForegroundColor Cyan
    
    # Get filtered checks
    $checks = Get-RegisteredChecks -ExcludePillars $ExcludePillars -ExcludeCheckIds $ExcludeCheckIds
    
    Write-Host "  Total checks to run: $($checks.Count)" -ForegroundColor Gray
    
    $results = @()
    $currentCheck = 0
    
    foreach ($check in $checks) {
        $currentCheck++
        $percentComplete = [Math]::Round(($currentCheck / $checks.Count) * 100)
        
        Write-Progress -Activity "Scanning: $SubscriptionId" `
                       -Status "Check $currentCheck of $($checks.Count): $($check.CheckId)" `
                       -PercentComplete $percentComplete
        
        $result = Invoke-WafCheck -Check $check -SubscriptionId $SubscriptionId -TimeoutSeconds $TimeoutSeconds
        
        if ($result) {
            $results += $result
            
            # Show status in console
            $statusColor = switch ($result.Status) {
                'Pass' { 'Green' }
                'Fail' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'Gray' }
            }
            Write-Host "    [$($result.Status)]".PadRight(12) -NoNewline -ForegroundColor $statusColor
            Write-Host "$($check.CheckId) - $($check.Title)" -ForegroundColor Gray
        }
    }
    
    Write-Progress -Activity "Scanning: $SubscriptionId" -Completed
    
    return $results
}

#endregion

#region Reporting Helpers

function Get-WafScanSummary {
    <#
    .SYNOPSIS
        Generates summary statistics from scan results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [datetime]$StartTime = (Get-Date)
    )
    
    $summary = @{
        TotalChecks = $Results.Count
        Passed = ($Results | Where-Object Status -eq 'Pass').Count
        Failed = ($Results | Where-Object Status -eq 'Fail').Count
        Warnings = ($Results | Where-Object Status -eq 'Warning').Count
        NotApplicable = ($Results | Where-Object Status -eq 'N/A').Count
        Errors = ($Results | Where-Object Status -eq 'Error').Count
        Duration = ((Get-Date) - $StartTime).ToString("hh\:mm\:ss")
        Timestamp = $StartTime
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
        $pillarTotal = $_.Count
        $pillarPassed = ($_.Group | Where-Object Status -eq 'Pass').Count
        $pillarFailed = ($_.Group | Where-Object Status -eq 'Fail').Count
        
        @{
            Pillar = $_.Name
            Total = $pillarTotal
            Passed = $pillarPassed
            Failed = $pillarFailed
            ComplianceScore = if ($pillarTotal -gt 0) { 
                [Math]::Round(($pillarPassed / $pillarTotal) * 100, 1) 
            } else { 0 }
        }
    }
    
    # Group by severity (failures only)
    $summary.BySeverity = $Results | 
        Where-Object Status -eq 'Fail' | 
        Group-Object Severity | 
        ForEach-Object {
            @{
                Severity = $_.Name
                Count = $_.Count
            }
        }
    
    return [PSCustomObject]$summary
}

function Compare-WafBaseline {
    <#
    .SYNOPSIS
        Compares current results with baseline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$CurrentResults,
        
        [Parameter(Mandatory)]
        [string]$BaselinePath
    )
    
    if (!(Test-Path $BaselinePath)) {
        Write-Warning "Baseline file not found: $BaselinePath"
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
                # New check or new failure
                if ($current.Status -eq 'Fail') {
                    $comparison.NewFailures += $current
                }
            } elseif ($baselineCheck.Status -ne $current.Status) {
                # Status changed
                if ($current.Status -eq 'Pass' -and $baselineCheck.Status -ne 'Pass') {
                    $comparison.Improvements += $current
                } elseif ($current.Status -eq 'Fail' -and $baselineCheck.Status -eq 'Pass') {
                    $comparison.NewFailures += $current
                }
            } else {
                $comparison.Unchanged += $current
            }
        }
        
        Write-Host "`nBaseline Comparison:" -ForegroundColor Cyan
        Write-Host "  New Failures:  $($comparison.NewFailures.Count)" -ForegroundColor Red
        Write-Host "  Improvements:  $($comparison.Improvements.Count)" -ForegroundColor Green
        Write-Host "  Unchanged:     $($comparison.Unchanged.Count)" -ForegroundColor Gray
        
        return [PSCustomObject]$comparison
    } catch {
        Write-Error "Failed to compare with baseline: $_"
        return $null
    }
}

#endregion

#region Module Initialization

function Initialize-WafScanner {
    <#
    .SYNOPSIS
        Initializes the WAF Scanner module and loads all checks.
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing Azure WAF Scanner..."
    
    # Check required modules
    $requiredModules = @(
        @{ Name = 'Az.Accounts'; MinVersion = '2.0.0' }
        @{ Name = 'Az.Resources'; MinVersion = '6.0.0' }
        @{ Name = 'Az.ResourceGraph'; MinVersion = '0.13.0' }
    )
    
    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | 
            Where-Object { $_.Version -ge [version]$module.MinVersion } |
            Select-Object -First 1
        
        if (!$installed) {
            Write-Warning "Required module $($module.Name) (>= $($module.MinVersion)) not found"
            Write-Host "Install with: Install-Module $($module.Name) -MinimumVersion $($module.MinVersion) -Scope CurrentUser" -ForegroundColor Yellow
        }
    }
    
    # Load check files
    $checkPath = Join-Path $script:ModuleRoot "Pillars"
    
    if (Test-Path $checkPath) {
        $checkFiles = Get-ChildItem -Path $checkPath -Filter "Invoke.ps1" -Recurse
        
        Write-Verbose "Found $($checkFiles.Count) check files"
        
        foreach ($checkFile in $checkFiles) {
            try {
                . $checkFile.FullName
                Write-Verbose "Loaded check: $($checkFile.FullName)"
            } catch {
                Write-Warning "Failed to load check from $($checkFile.FullName): $_"
            }
        }
    } else {
        Write-Warning "Check directory not found: $checkPath"
    }
    
    Write-Verbose "WAF Scanner initialized with $($script:CheckRegistry.Count) checks"
}

#endregion

# Export module members
Export-ModuleMember -Function @(
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

Export-ModuleMember -Alias @(
    'Invoke-Arg'
)

# Auto-initialize on module import
Initialize-WafScanner
