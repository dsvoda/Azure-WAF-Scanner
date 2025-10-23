<#
.SYNOPSIS
    Utility functions for Azure WAF Scanner.

.DESCRIPTION
    Helper functions for scoring, ROI estimation, weighting, and portal links.
    Core result creation functions are in WafScanner.psm1.
#>

function Convert-StatusToScore {
    <#
    .SYNOPSIS
        Converts a check status to a numeric score.
    
    .PARAMETER Status
        The status value (Pass, Fail, Warning, N/A, Error).
    
    .RETURNS
        Numeric score (0-100).
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Fail', 'Warning', 'N/A', 'Error')]
        [string]$Status
    )
    
    switch ($Status) {
        'Pass' { 100 }
        'Warning' { 60 }
        'Fail' { 0 }
        'N/A' { 50 }
        'Error' { 0 }
        default { 50 }
    }
}

function Estimate-ROI {
    <#
    .SYNOPSIS
        Estimates ROI for a remediation action.
    
    .PARAMETER EstimatedMonthlySavings
        Expected monthly cost savings.
    
    .PARAMETER EffortHours
        Estimated hours to implement.
    
    .PARAMETER HourlyRate
        Cost per hour for implementation.
    
    .RETURNS
        ROI description string.
    #>
    param(
        [Parameter(Mandatory)]
        [decimal]$EstimatedMonthlySavings,
        
        [int]$EffortHours = 8,
        
        [decimal]$HourlyRate = 150
    )
    
    if ($EstimatedMonthlySavings -le 0) {
        return $null
    }
    
    $implementationCost = $EffortHours * $HourlyRate
    $paybackDays = [Math]::Round(($implementationCost / $EstimatedMonthlySavings) * 30, 1)
    $annualSavings = $EstimatedMonthlySavings * 12
    $roi = [Math]::Round((($annualSavings - $implementationCost) / $implementationCost) * 100, 0)
    
    return @"
Estimated Monthly Savings: `$$($EstimatedMonthlySavings.ToString('N2'))
Annual Savings: `$$($annualSavings.ToString('N2'))
Implementation Cost: `$$($implementationCost.ToString('N2'))
Payback Period: $paybackDays days
ROI: $roi%
"@
}

function Get-WafWeights {
    <#
    .SYNOPSIS
        Gets pillar and control weighting configuration.
    
    .DESCRIPTION
        Loads weighting configuration from weights.json file.
        Returns default weights if file not found.
    
    .RETURNS
        Hashtable with pillar weights and control weights.
    #>
    $configPath = Join-Path $PSScriptRoot '..\..\config\weights.json'
    
    if (Test-Path $configPath) {
        try {
            $weights = Get-Content $configPath -Raw | ConvertFrom-Json
            return $weights
        } catch {
            Write-Warning "Failed to load weights.json: $_. Using defaults."
        }
    }
    
    # Default weights (all equal)
    return [PSCustomObject]@{
        Reliability = 1.0
        Security = 1.0
        CostOptimization = 1.0
        OperationalExcellence = 1.0
        PerformanceEfficiency = 1.0
        Controls = @{}
    }
}

function New-WafPortfolioSummary {
    <#
    .SYNOPSIS
        Creates a portfolio-level summary across multiple subscriptions.
    
    .PARAMETER Results
        Array of WAF check results from multiple subscriptions.
    
    .RETURNS
        Portfolio summary with per-subscription and overall scores.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )
    
    if ($Results.Count -eq 0) {
        return [PSCustomObject]@{
            PortfolioScore = 0
            Subscriptions = @()
            Generated = (Get-Date).ToString('o')
        }
    }
    
    $weights = Get-WafWeights
    
    # Group by subscription
    $bySubscription = $Results | Group-Object -Property {
        if ($_.PSObject.Properties.Name -contains 'SubscriptionId') {
            $_.SubscriptionId
        } elseif ($_.Metadata -and $_.Metadata.SubscriptionId) {
            $_.Metadata.SubscriptionId
        } else {
            'Unknown'
        }
    }
    
    $subscriptionSummaries = foreach ($subGroup in $bySubscription) {
        $subId = $subGroup.Name
        
        # Group by pillar
        $byPillar = $subGroup.Group | Group-Object Pillar
        
        $pillarScores = @{}
        $weightedSum = 0
        $weightedCount = 0
        
        foreach ($pillarGroup in $byPillar) {
            $pillarName = $pillarGroup.Name
            
            # Calculate pillar score
            $scores = foreach ($result in $pillarGroup.Group) {
                $score = Convert-StatusToScore -Status $result.Status
                
                # Apply control-specific weight if available
                $controlWeight = 1.0
                if ($weights.Controls -and $weights.Controls.$($result.CheckId)) {
                    $controlWeight = [double]$weights.Controls.$($result.CheckId)
                }
                
                $score * $controlWeight
            }
            
            $pillarScore = if ($scores.Count -gt 0) {
                [Math]::Round(($scores | Measure-Object -Sum).Sum / $scores.Count, 0)
            } else {
                0
            }
            
            $pillarScores[$pillarName] = $pillarScore
            
            # Apply pillar weight
            $pillarWeight = 1.0
            if ($weights.$pillarName) {
                $pillarWeight = [double]$weights.$pillarName
            }
            
            $weightedSum += $pillarScore * $pillarWeight
            $weightedCount += $pillarWeight
        }
        
        $overallScore = if ($weightedCount -gt 0) {
            [Math]::Round($weightedSum / $weightedCount, 0)
        } else {
            0
        }
        
        [PSCustomObject]@{
            SubscriptionId = $subId
            PillarScores = $pillarScores
            OverallScore = $overallScore
            CheckCount = $subGroup.Count
            Timestamp = (Get-Date).ToString('o')
        }
    }
    
    # Calculate portfolio score
    $portfolioScore = if ($subscriptionSummaries.Count -gt 0) {
        [Math]::Round(($subscriptionSummaries | Measure-Object -Property OverallScore -Average).Average, 0)
    } else {
        0
    }
    
    return [PSCustomObject]@{
        PortfolioScore = $portfolioScore
        Subscriptions = $subscriptionSummaries
        TotalSubscriptions = $subscriptionSummaries.Count
        TotalChecks = $Results.Count
        Generated = (Get-Date).ToString('o')
    }
}

function Get-AzurePortalLink {
    <#
    .SYNOPSIS
        Generates an Azure Portal link for a resource.
    
    .PARAMETER ResourceId
        The Azure resource ID.
    
    .RETURNS
        Azure Portal URL for the resource.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ResourceId
    )
    
    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return $null
    }
    
    # Ensure resource ID starts with /
    $resourceId = $ResourceId.TrimStart('/')
    
    return "https://portal.azure.com/#@/resource/$resourceId"
}

function Format-WafEvidence {
    <#
    .SYNOPSIS
        Formats evidence data into a readable string.
    
    .PARAMETER Evidence
        Hashtable or object containing evidence data.
    
    .RETURNS
        Formatted evidence string.
    #>
    param(
        [Parameter(Mandatory)]
        $Evidence
    )
    
    if ($Evidence -is [string]) {
        return $Evidence
    }
    
    if ($Evidence -is [hashtable] -or $Evidence -is [PSCustomObject]) {
        $lines = foreach ($key in $Evidence.Keys) {
            "- ${key}: $($Evidence[$key])"
        }
        return $lines -join "`n"
    }
    
    return $Evidence | ConvertTo-Json -Depth 3
}

function Test-WafConfigSchema {
    <#
    .SYNOPSIS
        Validates a WAF Scanner configuration file.
    
    .PARAMETER ConfigPath
        Path to the configuration file.
    
    .RETURNS
        Boolean indicating if configuration is valid.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    
    if (!(Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return $false
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Basic validation
        $requiredProps = @('excludedPillars', 'excludedChecks')
        $valid = $true
        
        foreach ($prop in $requiredProps) {
            if ($null -eq $config.$prop) {
                Write-Warning "Configuration missing property: $prop"
                $valid = $false
            }
        }
        
        return $valid
        
    } catch {
        Write-Error "Failed to parse configuration: $_"
        return $false
    }
}

function Get-WafCheckById {
    <#
    .SYNOPSIS
        Gets a registered check by its ID.
    
    .PARAMETER CheckId
        The check ID (e.g., 'RE01', 'SE05').
    
    .RETURNS
        Check object if found, null otherwise.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CheckId
    )
    
    $checks = Get-RegisteredChecks -CheckIds @($CheckId)
    
    if ($checks.Count -gt 0) {
        return $checks[0]
    }
    
    return $null
}

function Export-WafResultsToCsv {
    <#
    .SYNOPSIS
        Exports WAF results to CSV with standard columns.
    
    .PARAMETER Results
        Array of WAF check results.
    
    .PARAMETER OutputPath
        Path for the CSV file.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    $Results | Select-Object -Property `
        CheckId,
        Pillar,
        Title,
        Status,
        Severity,
        RemediationEffort,
        Message,
        Recommendation,
        @{Name='AffectedResourceCount'; Expression={ if ($_.AffectedResources) { $_.AffectedResources.Count } else { 0 } }},
        @{Name='AffectedResources'; Expression={ if ($_.AffectedResources) { $_.AffectedResources -join '; ' } else { '' } }},
        DocumentationUrl,
        Timestamp |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Verbose "Exported $($Results.Count) results to: $OutputPath"
}

function Export-WafResultsToJson {
    <#
    .SYNOPSIS
        Exports WAF results to JSON.
    
    .PARAMETER Results
        Array of WAF check results.
    
    .PARAMETER OutputPath
        Path for the JSON file.
    
    .PARAMETER IncludeSummary
        Include summary statistics in output.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [switch]$IncludeSummary
    )
    
    $output = if ($IncludeSummary) {
        $summary = Get-WafScanSummary -Results $Results
        @{
            Summary = $summary
            Results = $Results
            Exported = (Get-Date).ToString('o')
        }
    } else {
        @{
            Results = $Results
            Exported = (Get-Date).ToString('o')
        }
    }
    
    $output | ConvertTo-Json -Depth 15 | Set-Content -Path $OutputPath -Encoding UTF8
    
    Write-Verbose "Exported $($Results.Count) results to: $OutputPath"
}

# Export functions
Export-ModuleMember -Function @(
    'Convert-StatusToScore',
    'Estimate-ROI',
    'Get-WafWeights',
    'New-WafPortfolioSummary',
    'Get-AzurePortalLink',
    'Format-WafEvidence',
    'Test-WafConfigSchema',
    'Get-WafCheckById',
    'Export-WafResultsToCsv',
    'Export-WafResultsToJson'
)
