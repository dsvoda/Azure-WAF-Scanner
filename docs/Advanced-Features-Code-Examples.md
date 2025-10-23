# Advanced Features - Code Examples

This document provides ready-to-implement code for advanced features you can add to Azure WAF Scanner after completing the initial distribution and testing improvements.

---

## 🎯 Feature 1: DOCX Report Generation

### Implementation using PSWriteWord

```powershell
# File: modules/Report/New-WafDocx.ps1

<#
.SYNOPSIS
    Generates professional DOCX reports from WAF scan results.

.DESCRIPTION
    Creates formatted Word documents with executive summary, detailed findings,
    charts, and remediation recommendations.
#>

function New-WafDocx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter(Mandatory)]
        [hashtable]$Summary,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [hashtable]$Comparison,
        
        [string]$CompanyName = "Your Organization",
        [string]$ReportTitle = "Azure Well-Architected Framework Assessment"
    )
    
    # Check for PSWriteWord module
    if (!(Get-Module -ListAvailable -Name PSWriteWord)) {
        Write-Warning "PSWriteWord module not found. Installing..."
        Install-Module PSWriteWord -Scope CurrentUser -Force
    }
    
    Import-Module PSWriteWord
    
    Write-Verbose "Creating DOCX report at: $OutputPath"
    
    # Create new document
    $doc = New-WordDocument -FilePath $OutputPath
    
    # === COVER PAGE ===
    Add-WordText -WordDocument $doc -Text $ReportTitle -FontSize 28 -Bold -Alignment Center
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    Add-WordText -WordDocument $doc -Text $CompanyName -FontSize 20 -Alignment Center
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    Add-WordText -WordDocument $doc -Text "Generated: $($Summary.Timestamp.ToString('MMMM dd, yyyy'))" -FontSize 14 -Alignment Center
    Add-WordPageBreak -WordDocument $doc
    
    # === EXECUTIVE SUMMARY ===
    Add-WordText -WordDocument $doc -Text "Executive Summary" -FontSize 20 -Bold -UnderlineStyle Single
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Summary table
    $summaryData = @(
        @{ Metric = "Compliance Score"; Value = "$($Summary.ComplianceScore)%" }
        @{ Metric = "Total Checks"; Value = $Summary.TotalChecks }
        @{ Metric = "Passed"; Value = $Summary.Passed; Color = "Green" }
        @{ Metric = "Failed"; Value = $Summary.Failed; Color = "Red" }
        @{ Metric = "Warnings"; Value = $Summary.Warnings; Color = "Orange" }
        @{ Metric = "Not Applicable"; Value = $Summary.NotApplicable }
        @{ Metric = "Errors"; Value = $Summary.Errors }
        @{ Metric = "Scan Duration"; Value = $Summary.Duration }
    )
    
    $table = Add-WordTable -WordDocument $doc -DataTable $summaryData -Design LightGridAccent1 -AutoFit Window
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Overall assessment
    $assessmentText = if ($Summary.ComplianceScore -ge 90) {
        "Excellent: Your Azure environment demonstrates strong alignment with the Well-Architected Framework. Continue monitoring and addressing any remaining findings."
    } elseif ($Summary.ComplianceScore -ge 75) {
        "Good: Your Azure environment is well-architected with some areas for improvement. Focus on addressing high-severity findings."
    } elseif ($Summary.ComplianceScore -ge 60) {
        "Fair: Significant improvements needed to align with Well-Architected Framework best practices. Prioritize critical and high-severity findings."
    } else {
        "Needs Attention: Your Azure environment requires substantial improvements across multiple pillars. Immediate action recommended on critical findings."
    }
    
    Add-WordText -WordDocument $doc -Text "Overall Assessment" -FontSize 14 -Bold
    Add-WordText -WordDocument $doc -Text $assessmentText
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # === COMPLIANCE BY PILLAR ===
    Add-WordPageBreak -WordDocument $doc
    Add-WordText -WordDocument $doc -Text "Compliance by Pillar" -FontSize 20 -Bold -UnderlineStyle Single
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    foreach ($pillar in $Summary.ByPillar) {
        Add-WordText -WordDocument $doc -Text $pillar.Pillar -FontSize 16 -Bold
        
        $pillarScore = "$($pillar.ComplianceScore)%"
        $pillarDetails = "Passed: $($pillar.Passed) | Failed: $($pillar.Failed) | Total: $($pillar.Total)"
        
        Add-WordText -WordDocument $doc -Text "Score: $pillarScore" -FontSize 12
        Add-WordText -WordDocument $doc -Text $pillarDetails -FontSize 11 -Color Gray
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        # Progress bar simulation with table
        $passPercent = [Math]::Round(($pillar.Passed / $pillar.Total) * 100)
        $passChars = [Math]::Floor($passPercent / 5)
        $failChars = 20 - $passChars
        
        $progressBar = "█" * $passChars + "░" * $failChars
        Add-WordText -WordDocument $doc -Text $progressBar -FontSize 10 -Color Green
        Add-WordText -WordDocument $doc -Text "" -LineBreak
    }
    
    # === CRITICAL FINDINGS ===
    $criticalFailures = $Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -in @('Critical', 'High') }
    
    if ($criticalFailures.Count -gt 0) {
        Add-WordPageBreak -WordDocument $doc
        Add-WordText -WordDocument $doc -Text "Critical & High Priority Findings" -FontSize 20 -Bold -UnderlineStyle Single
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        Add-WordText -WordDocument $doc -Text "$($criticalFailures.Count) issues requiring immediate attention" -FontSize 12 -Italic
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        foreach ($finding in ($criticalFailures | Select-Object -First 10)) {
            # Finding header
            Add-WordText -WordDocument $doc -Text "$($finding.CheckId): $($finding.Title)" -FontSize 14 -Bold
            
            # Metadata
            $metaText = "Pillar: $($finding.Pillar) | Severity: $($finding.Severity) | Effort: $($finding.RemediationEffort)"
            Add-WordText -WordDocument $doc -Text $metaText -FontSize 11 -Color DarkGray
            
            # Issue description
            Add-WordText -WordDocument $doc -Text "Issue:" -FontSize 12 -Bold
            Add-WordText -WordDocument $doc -Text $finding.Message -FontSize 11
            
            # Recommendation
            if ($finding.Recommendation) {
                Add-WordText -WordDocument $doc -Text "" -LineBreak
                Add-WordText -WordDocument $doc -Text "Recommendation:" -FontSize 12 -Bold
                Add-WordText -WordDocument $doc -Text $finding.Recommendation -FontSize 11
            }
            
            # Affected resources
            if ($finding.AffectedResources -and $finding.AffectedResources.Count -gt 0) {
                Add-WordText -WordDocument $doc -Text "" -LineBreak
                Add-WordText -WordDocument $doc -Text "Affected Resources ($($finding.AffectedResources.Count)):" -FontSize 12 -Bold
                
                $resourceList = ($finding.AffectedResources | Select-Object -First 5) -join "`n• "
                Add-WordText -WordDocument $doc -Text "• $resourceList" -FontSize 10 -FontFamily Consolas
                
                if ($finding.AffectedResources.Count -gt 5) {
                    Add-WordText -WordDocument $doc -Text "... and $($finding.AffectedResources.Count - 5) more" -FontSize 10 -Italic
                }
            }
            
            # Documentation link
            if ($finding.DocumentationUrl) {
                Add-WordText -WordDocument $doc -Text "" -LineBreak
                Add-WordText -WordDocument $doc -Text "Learn more: $($finding.DocumentationUrl)" -FontSize 10 -Color Blue
            }
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
            Add-WordText -WordDocument $doc -Text "─────────────────────────────────────────" -FontSize 10 -Color LightGray
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
    }
    
    # === DETAILED RESULTS BY PILLAR ===
    Add-WordPageBreak -WordDocument $doc
    Add-WordText -WordDocument $doc -Text "Detailed Findings by Pillar" -FontSize 20 -Bold -UnderlineStyle Single
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    $pillars = $Results | Select-Object -ExpandProperty Pillar -Unique | Sort-Object
    
    foreach ($pillar in $pillars) {
        $pillarResults = $Results | Where-Object Pillar -eq $pillar
        
        Add-WordText -WordDocument $doc -Text $pillar -FontSize 18 -Bold
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        # Create table data
        $tableData = $pillarResults | ForEach-Object {
            [PSCustomObject]@{
                'Check ID' = $_.CheckId
                'Status' = $_.Status
                'Severity' = $_.Severity
                'Title' = $_.Title
            }
        }
        
        $table = Add-WordTable -WordDocument $doc -DataTable $tableData -Design LightGridAccent1 -AutoFit Window
        Add-WordText -WordDocument $doc -Text "" -LineBreak
    }
    
    # === BASELINE COMPARISON (if provided) ===
    if ($Comparison) {
        Add-WordPageBreak -WordDocument $doc
        Add-WordText -WordDocument $doc -Text "Baseline Comparison" -FontSize 20 -Bold -UnderlineStyle Single
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        $comparisonData = @(
            @{ Metric = "New Failures"; Value = $Comparison.NewFailures.Count; Trend = "↓" }
            @{ Metric = "Improvements"; Value = $Comparison.Improvements.Count; Trend = "↑" }
            @{ Metric = "Unchanged"; Value = $Comparison.Unchanged.Count; Trend = "→" }
        )
        
        Add-WordTable -WordDocument $doc -DataTable $comparisonData -Design ColorfulList
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        if ($Comparison.NewFailures.Count -gt 0) {
            Add-WordText -WordDocument $doc -Text "New Failures (Regressions):" -FontSize 14 -Bold -Color Red
            
            foreach ($failure in $Comparison.NewFailures) {
                Add-WordText -WordDocument $doc -Text "• $($failure.CheckId): $($failure.Title)" -FontSize 11
            }
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
        
        if ($Comparison.Improvements.Count -gt 0) {
            Add-WordText -WordDocument $doc -Text "Improvements:" -FontSize 14 -Bold -Color Green
            
            foreach ($improvement in $Comparison.Improvements) {
                Add-WordText -WordDocument $doc -Text "• $($improvement.CheckId): $($improvement.Title)" -FontSize 11
            }
        }
    }
    
    # === APPENDIX: RECOMMENDATIONS ===
    Add-WordPageBreak -WordDocument $doc
    Add-WordText -WordDocument $doc -Text "Appendix: Remediation Recommendations" -FontSize 20 -Bold -UnderlineStyle Single
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    $failedChecks = $Results | Where-Object Status -eq 'Fail'
    
    foreach ($check in $failedChecks) {
        if ($check.RemediationScript) {
            Add-WordText -WordDocument $doc -Text "$($check.CheckId): $($check.Title)" -FontSize 12 -Bold
            Add-WordText -WordDocument $doc -Text "Remediation Script:" -FontSize 11 -Italic
            
            # Code block (using table for formatting)
            $codeTable = @(
                @{ Code = $check.RemediationScript }
            )
            
            Add-WordTable -WordDocument $doc -DataTable $codeTable -Design PlainTable1 -AutoFit Window
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
    }
    
    # === SAVE DOCUMENT ===
    Save-WordDocument -WordDocument $doc
    
    Write-Verbose "DOCX report generated: $OutputPath"
    return $OutputPath
}

# Export function
Export-ModuleMember -Function New-WafDocx
```

### Usage Example

```powershell
# After running scan
$results = Invoke-WafSubscriptionScan -SubscriptionId $subId
$summary = Get-WafScanSummary -Results $results

# Generate DOCX report
New-WafDocx -Results $results `
    -Summary $summary `
    -OutputPath "./reports/WAF-Assessment-$(Get-Date -Format 'yyyyMMdd').docx" `
    -CompanyName "Contoso Inc" `
    -ReportTitle "Azure Production Environment Assessment"
```

---

## 🏢 Feature 2: Multi-Tenant Support

### Implementation

```powershell
# File: modules/Core/Invoke-MultiTenantScan.ps1

<#
.SYNOPSIS
    Scans multiple Azure tenants and generates consolidated reports.

.DESCRIPTION
    Authenticates to multiple tenants and runs WAF scans across all subscriptions,
    with tenant-specific and consolidated reporting.
#>

function Invoke-MultiTenantScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Tenants,  # Array of @{ TenantId, Name, Subscriptions }
        
        [string]$OutputPath = "./waf-output/multi-tenant",
        
        [switch]$ConsolidatedReport,
        [switch]$EmitHtml,
        [switch]$EmitJson,
        [switch]$EmitCsv,
        
        [string[]]$ExcludedPillars = @(),
        [string[]]$ExcludedChecks = @()
    )
    
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       Azure WAF Scanner - Multi-Tenant Assessment            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $allResults = @()
    $tenantSummaries = @()
    $startTime = Get-Date
    
    # Create output directory
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    foreach ($tenant in $Tenants) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "Tenant: $($tenant.Name)" -ForegroundColor Cyan
        Write-Host "Tenant ID: $($tenant.TenantId)" -ForegroundColor Gray
        Write-Host ""
        
        try {
            # Connect to tenant
            Write-Host "  Authenticating to tenant..." -ForegroundColor Yellow
            
            $context = Connect-AzAccount -Tenant $tenant.TenantId -ErrorAction Stop
            
            if (!$context) {
                Write-Warning "Failed to connect to tenant: $($tenant.Name)"
                continue
            }
            
            Write-Host "  ✓ Connected as: $($context.Context.Account.Id)" -ForegroundColor Green
            Write-Host ""
            
            # Get subscriptions for this tenant
            $subscriptions = if ($tenant.Subscriptions) {
                $tenant.Subscriptions
            } else {
                # Scan all accessible subscriptions in tenant
                (Get-AzSubscription -TenantId $tenant.TenantId).Id
            }
            
            Write-Host "  Subscriptions to scan: $($subscriptions.Count)" -ForegroundColor Cyan
            Write-Host ""
            
            # Scan each subscription
            $tenantResults = @()
            
            foreach ($subId in $subscriptions) {
                Write-Host "    Scanning subscription: $subId" -ForegroundColor Gray
                
                $subResults = Invoke-WafSubscriptionScan -SubscriptionId $subId `
                    -ExcludePillars $ExcludedPillars `
                    -ExcludeCheckIds $ExcludedChecks `
                    -ErrorAction Continue
                
                if ($subResults) {
                    # Add tenant metadata
                    $subResults | ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue $tenant.TenantId -Force
                        $_ | Add-Member -NotePropertyName 'TenantName' -NotePropertyValue $tenant.Name -Force
                    }
                    
                    $tenantResults += $subResults
                }
            }
            
            # Generate tenant-specific summary
            $tenantSummary = Get-WafScanSummary -Results $tenantResults -StartTime $startTime
            $tenantSummary | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue $tenant.TenantId
            $tenantSummary | Add-Member -NotePropertyName 'TenantName' -NotePropertyValue $tenant.Name
            $tenantSummary | Add-Member -NotePropertyName 'SubscriptionCount' -NotePropertyValue $subscriptions.Count
            
            $tenantSummaries += $tenantSummary
            $allResults += $tenantResults
            
            # Generate tenant-specific reports
            $tenantOutputPath = Join-Path $OutputPath $tenant.Name
            
            if (!(Test-Path $tenantOutputPath)) {
                New-Item -ItemType Directory -Path $tenantOutputPath -Force | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            
            if ($EmitJson) {
                $tenantResults | ConvertTo-Json -Depth 10 | 
                    Set-Content -Path (Join-Path $tenantOutputPath "results-$timestamp.json")
            }
            
            if ($EmitCsv) {
                $tenantResults | Export-Csv -Path (Join-Path $tenantOutputPath "results-$timestamp.csv") -NoTypeInformation
            }
            
            if ($EmitHtml) {
                $htmlPath = Join-Path $tenantOutputPath "report-$timestamp.html"
                New-EnhancedWafHtml -Results $tenantResults -Summary $tenantSummary -OutputPath $htmlPath
            }
            
            Write-Host ""
            Write-Host "  ✓ Tenant scan complete" -ForegroundColor Green
            Write-Host "    Compliance Score: $($tenantSummary.ComplianceScore)%" -ForegroundColor $(
                if ($tenantSummary.ComplianceScore -ge 80) { 'Green' }
                elseif ($tenantSummary.ComplianceScore -ge 60) { 'Yellow' }
                else { 'Red' }
            )
            Write-Host ""
            
        } catch {
            Write-Error "Failed to scan tenant $($tenant.Name): $_"
            continue
        }
    }
    
    # Generate consolidated report
    if ($ConsolidatedReport -and $allResults.Count -gt 0) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "Generating Consolidated Report" -ForegroundColor Cyan
        Write-Host ""
        
        $consolidatedSummary = Get-WafScanSummary -Results $allResults -StartTime $startTime
        
        # Add tenant comparison data
        $consolidatedSummary | Add-Member -NotePropertyName 'TenantSummaries' -NotePropertyValue $tenantSummaries
        
        # Create consolidated HTML report with tenant comparison
        if ($EmitHtml) {
            $htmlPath = Join-Path $OutputPath "consolidated-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            New-MultiTenantHtmlReport -Results $allResults `
                -Summary $consolidatedSummary `
                -TenantSummaries $tenantSummaries `
                -OutputPath $htmlPath
        }
        
        if ($EmitJson) {
            $jsonPath = Join-Path $OutputPath "consolidated-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            @{
                Summary = $consolidatedSummary
                TenantSummaries = $tenantSummaries
                Results = $allResults
            } | ConvertTo-Json -Depth 15 | Set-Content $jsonPath
        }
        
        # Display consolidated summary
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "CONSOLIDATED SUMMARY" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Total Tenants Scanned:  $($tenantSummaries.Count)" -ForegroundColor White
        Write-Host "  Total Subscriptions:    $($tenantSummaries | Measure-Object -Property SubscriptionCount -Sum).Sum)" -ForegroundColor White
        Write-Host "  Total Checks Run:       $($consolidatedSummary.TotalChecks)" -ForegroundColor White
        Write-Host "  Overall Compliance:     $($consolidatedSummary.ComplianceScore)%" -ForegroundColor $(
            if ($consolidatedSummary.ComplianceScore -ge 80) { 'Green' }
            elseif ($consolidatedSummary.ComplianceScore -ge 60) { 'Yellow' }
            else { 'Red' }
        )
        Write-Host ""
        
        Write-Host "  Tenant Breakdown:" -ForegroundColor Cyan
        foreach ($ts in $tenantSummaries | Sort-Object ComplianceScore) {
            $scoreColor = if ($ts.ComplianceScore -ge 80) { 'Green' }
                         elseif ($ts.ComplianceScore -ge 60) { 'Yellow' }
                         else { 'Red' }
            
            Write-Host "    $($ts.TenantName.PadRight(30)) " -NoNewline -ForegroundColor Gray
            Write-Host "$($ts.ComplianceScore.ToString().PadLeft(5))%" -ForegroundColor $scoreColor
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    }
    
    return @{
        AllResults = $allResults
        TenantSummaries = $tenantSummaries
        ConsolidatedSummary = $consolidatedSummary
    }
}

function New-MultiTenantHtmlReport {
    [CmdletBinding()]
    param(
        [array]$Results,
        [object]$Summary,
        [array]$TenantSummaries,
        [string]$OutputPath
    )
    
    # Enhanced HTML with tenant comparison charts
    # Implementation similar to New-EnhancedWafHtml but with multi-tenant sections
    
    # Add tenant comparison section
    $tenantComparisonHtml = @"
<div class="section">
    <h2 class="section-title">🏢 Tenant Comparison</h2>
    
    <div class="charts-container">
        <div class="chart-card">
            <h3 class="chart-title">Compliance by Tenant</h3>
            <canvas id="tenantComparisonChart"></canvas>
        </div>
    </div>
    
    <table class="results-table">
        <thead>
            <tr>
                <th>Tenant</th>
                <th>Subscriptions</th>
                <th>Compliance Score</th>
                <th>Passed</th>
                <th>Failed</th>
                <th>Warnings</th>
            </tr>
        </thead>
        <tbody>
"@
    
    foreach ($ts in ($TenantSummaries | Sort-Object ComplianceScore -Descending)) {
        $tenantComparisonHtml += @"
            <tr>
                <td>$($ts.TenantName)</td>
                <td>$($ts.SubscriptionCount)</td>
                <td><span class="status-badge $(if($ts.ComplianceScore -ge 80){'status-pass'}elseif($ts.ComplianceScore -ge 60){'status-warning'}else{'status-fail'})">$($ts.ComplianceScore)%</span></td>
                <td>$($ts.Passed)</td>
                <td>$($ts.Failed)</td>
                <td>$($ts.Warnings)</td>
            </tr>
"@
    }
    
    $tenantComparisonHtml += @"
        </tbody>
    </table>
</div>
"@
    
    # Generate full HTML (combine with existing New-EnhancedWafHtml logic)
    # Add tenant comparison JavaScript
    $tenantChartScript = @"
const tenantData = $(ConvertTo-Json -Compress @($TenantSummaries | ForEach-Object { 
    @{ name = $_.TenantName; score = $_.ComplianceScore }
}));

new Chart(document.getElementById('tenantComparisonChart'), {
    type: 'bar',
    data: {
        labels: tenantData.map(t => t.name),
        datasets: [{
            label: 'Compliance Score %',
            data: tenantData.map(t => t.score),
            backgroundColor: tenantData.map(t => 
                t.score >= 80 ? 'rgba(40, 167, 69, 0.8)' :
                t.score >= 60 ? 'rgba(255, 193, 7, 0.8)' :
                'rgba(220, 53, 69, 0.8)'
            )
        }]
    },
    options: {
        responsive: true,
        scales: {
            y: {
                beginAtZero: true,
                max: 100
            }
        }
    }
});
"@
    
    # Full HTML generation implementation here
    # (Similar to New-EnhancedWafHtml but with tenant sections)
    
    Write-Verbose "Multi-tenant HTML report saved: $OutputPath"
}

Export-ModuleMember -Function Invoke-MultiTenantScan, New-MultiTenantHtmlReport
```

### Usage Example

```powershell
# Define tenants to scan
$tenants = @(
    @{
        TenantId = 'tenant-id-1'
        Name = 'Production Tenant'
        Subscriptions = @('sub1', 'sub2')
    },
    @{
        TenantId = 'tenant-id-2'
        Name = 'Development Tenant'
        # Omit Subscriptions to scan all accessible
    }
)

# Run multi-tenant scan
$results = Invoke-MultiTenantScan -Tenants $tenants `
    -ConsolidatedReport `
    -EmitHtml `
    -EmitJson `
    -OutputPath "./reports/multi-tenant"
```

---

## 📊 Feature 3: Continuous Monitoring

### Implementation

```powershell
# File: modules/Monitoring/Start-WafMonitoring.ps1

<#
.SYNOPSIS
    Starts continuous WAF monitoring with scheduled scans and alerting.

.DESCRIPTION
    Runs periodic scans, tracks trends, and sends notifications on critical findings.
#>

function Start-WafMonitoring {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Subscriptions,
        
        [ValidateSet('Hourly', 'Daily', 'Weekly', 'Monthly')]
        [string]$Schedule = 'Daily',
        
        [string]$OutputPath = "./waf-monitoring",
        
        [string[]]$EmailRecipients,
        [string]$SmtpServer,
        [int]$SmtpPort = 587,
        [PSCredential]$SmtpCredential,
        
        [string]$WebhookUrl,
        
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$AlertThreshold = 'Critical',
        
        [switch]$TrackTrends,
        [switch]$GenerateReports,
        
        [int]$RetentionDays = 90
    )
    
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         Azure WAF Scanner - Continuous Monitoring            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Create monitoring directory structure
    $scanPath = Join-Path $OutputPath "scans"
    $trendPath = Join-Path $OutputPath "trends"
    $alertPath = Join-Path $OutputPath "alerts"
    
    @($scanPath, $trendPath, $alertPath) | ForEach-Object {
        if (!(Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    # Calculate scan interval
    $interval = switch ($Schedule) {
        'Hourly' { New-TimeSpan -Hours 1 }
        'Daily' { New-TimeSpan -Days 1 }
        'Weekly' { New-TimeSpan -Days 7 }
        'Monthly' { New-TimeSpan -Days 30 }
    }
    
    Write-Host "Monitoring Configuration:" -ForegroundColor Cyan
    Write-Host "  Subscriptions: $($Subscriptions.Count)" -ForegroundColor Gray
    Write-Host "  Schedule: $Schedule" -ForegroundColor Gray
    Write-Host "  Alert Threshold: $AlertThreshold" -ForegroundColor Gray
    Write-Host "  Track Trends: $TrackTrends" -ForegroundColor Gray
    Write-Host ""
    
    $iteration = 0
    $lastScan = $null
    
    # Main monitoring loop
    while ($true) {
        $iteration++
        $scanStart = Get-Date
        
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Scan Iteration: $iteration" -ForegroundColor Cyan
        Write-Host "Time: $($scanStart.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        try {
            # Run scan
            $allResults = @()
            
            foreach ($sub in $Subscriptions) {
                Write-Host "Scanning: $sub" -ForegroundColor Yellow
                
                $results = Invoke-WafSubscriptionScan -SubscriptionId $sub -ErrorAction Continue
                
                if ($results) {
                    $allResults += $results
                }
            }
            
            # Generate summary
            $summary = Get-WafScanSummary -Results $allResults -StartTime $scanStart
            
            # Save scan results
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $scanFile = Join-Path $scanPath "scan-$timestamp.json"
            
            @{
                Timestamp = $scanStart
                Summary = $summary
                Results = $allResults
            } | ConvertTo-Json -Depth 10 | Set-Content $scanFile
            
            Write-Host ""
            Write-Host "Scan completed:" -ForegroundColor Green
            Write-Host "  Compliance Score: $($summary.ComplianceScore)%" -ForegroundColor White
            Write-Host "  Failed Checks: $($summary.Failed)" -ForegroundColor $(if ($summary.Failed -gt 0) { 'Red' } else { 'Green' })
            Write-Host ""
            
            # Check for critical findings
            $criticalFindings = $allResults | Where-Object {
                $_.Status -eq 'Fail' -and
                switch ($AlertThreshold) {
                    'Critical' { $_.Severity -eq 'Critical' }
                    'High' { $_.Severity -in @('Critical', 'High') }
                    'Medium' { $_.Severity -in @('Critical', 'High', 'Medium') }
                    'Low' { $true }
                }
            }
            
            if ($criticalFindings.Count -gt 0) {
                Write-Host "⚠️  $($criticalFindings.Count) critical findings detected!" -ForegroundColor Red
                
                # Generate alert
                $alert = @{
                    Timestamp = $scanStart
                    FindingsCount = $criticalFindings.Count
                    Findings = $criticalFindings
                    Summary = $summary
                }
                
                $alertFile = Join-Path $alertPath "alert-$timestamp.json"
                $alert | ConvertTo-Json -Depth 10 | Set-Content $alertFile
                
                # Send notifications
                if ($EmailRecipients) {
                    Send-WafAlert -Alert $alert `
                        -Recipients $EmailRecipients `
                        -SmtpServer $SmtpServer `
                        -SmtpPort $SmtpPort `
                        -Credential $SmtpCredential
                }
                
                if ($WebhookUrl) {
                    Invoke-WafWebhook -Alert $alert -WebhookUrl $WebhookUrl
                }
            }
            
            # Track trends
            if ($TrackTrends -and $lastScan) {
                $comparison = Compare-WafBaseline -CurrentResults $allResults -BaselinePath $lastScan
                
                if ($comparison) {
                    $trendFile = Join-Path $trendPath "trend-$timestamp.json"
                    $comparison | ConvertTo-Json -Depth 10 | Set-Content $trendFile
                    
                    if ($comparison.NewFailures.Count -gt 0) {
                        Write-Host "📉 $($comparison.NewFailures.Count) new failures (regressions)" -ForegroundColor Red
                    }
                    
                    if ($comparison.Improvements.Count -gt 0) {
                        Write-Host "📈 $($comparison.Improvements.Count) improvements" -ForegroundColor Green
                    }
                }
            }
            
            # Generate periodic report
            if ($GenerateReports) {
                $reportPath = Join-Path $OutputPath "reports"
                
                if (!(Test-Path $reportPath)) {
                    New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
                }
                
                $htmlFile = Join-Path $reportPath "report-$timestamp.html"
                New-EnhancedWafHtml -Results $allResults -Summary $summary -OutputPath $htmlFile
            }
            
            # Cleanup old scans
            if ($RetentionDays -gt 0) {
                $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
                
                Get-ChildItem -Path $scanPath -Filter "scan-*.json" | 
                    Where-Object CreationTime -lt $cutoffDate |
                    Remove-Item -Force
                    
                Write-Host "Cleaned up scans older than $RetentionDays days" -ForegroundColor Gray
            }
            
            # Store this scan as baseline for next iteration
            $lastScan = $scanFile
            
        } catch {
            Write-Error "Scan iteration failed: $_"
            
            # Log error
            $errorFile = Join-Path $OutputPath "errors.log"
            "$($scanStart.ToString('yyyy-MM-dd HH:mm:ss')) - $($_.Exception.Message)" | 
                Add-Content $errorFile
        }
        
        # Calculate next scan time
        $nextScan = $scanStart.Add($interval)
        $waitTime = $nextScan - (Get-Date)
        
        if ($waitTime.TotalSeconds -gt 0) {
            Write-Host ""
            Write-Host "Next scan scheduled: $($nextScan.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
            Write-Host "Waiting $($waitTime.ToString('hh\:mm\:ss'))..." -ForegroundColor Gray
            Write-Host ""
            
            Start-Sleep -Seconds $waitTime.TotalSeconds
        }
    }
}

function Send-WafAlert {
    param(
        $Alert,
        [string[]]$Recipients,
        [string]$SmtpServer,
        [int]$SmtpPort,
        [PSCredential]$Credential
    )
    
    $subject = "🚨 Azure WAF Alert - $($Alert.FindingsCount) Critical Findings"
    
    $body = @"
<html>
<body>
<h2>Azure WAF Assessment Alert</h2>
<p><strong>Time:</strong> $($Alert.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))</p>
<p><strong>Critical Findings:</strong> $($Alert.FindingsCount)</p>
<p><strong>Compliance Score:</strong> $($Alert.Summary.ComplianceScore)%</p>

<h3>Findings:</h3>
<table border="1" cellpadding="5">
<tr>
    <th>Check ID</th>
    <th>Severity</th>
    <th>Title</th>
    <th>Message</th>
</tr>
"@
    
    foreach ($finding in ($Alert.Findings | Select-Object -First 10)) {
        $body += @"
<tr>
    <td>$($finding.CheckId)</td>
    <td style="color: $(if ($finding.Severity -eq 'Critical') { 'red' } else { 'orange' })">$($finding.Severity)</td>
    <td>$($finding.Title)</td>
    <td>$($finding.Message)</td>
</tr>
"@
    }
    
    $body += @"
</table>
<p><em>Generated by Azure WAF Scanner</em></p>
</body>
</html>
"@
    
    $params = @{
        To = $Recipients
        From = "waf-scanner@company.com"
        Subject = $subject
        Body = $body
        BodyAsHtml = $true
        SmtpServer = $SmtpServer
        Port = $SmtpPort
    }
    
    if ($Credential) {
        $params.Credential = $Credential
        $params.UseSsl = $true
    }
    
    try {
        Send-MailMessage @params
        Write-Host "✓ Alert email sent to $($Recipients.Count) recipients" -ForegroundColor Green
    } catch {
        Write-Error "Failed to send alert email: $_"
    }
}

function Invoke-WafWebhook {
    param(
        $Alert,
        [string]$WebhookUrl
    )
    
    $payload = @{
        timestamp = $Alert.Timestamp.ToString('o')
        severity = 'critical'
        findings_count = $Alert.FindingsCount
        compliance_score = $Alert.Summary.ComplianceScore
        findings = $Alert.Findings | Select-Object -First 5 | ForEach-Object {
            @{
                check_id = $_.CheckId
                severity = $_.Severity
                title = $_.Title
                message = $_.Message
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType 'application/json'
        Write-Host "✓ Webhook invoked successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to invoke webhook: $_"
    }
}

Export-ModuleMember -Function Start-WafMonitoring, Send-WafAlert, Invoke-WafWebhook
```

### Usage Example

```powershell
# Start continuous monitoring
Start-WafMonitoring -Subscriptions @('sub1', 'sub2') `
    -Schedule Daily `
    -EmailRecipients @('admin@company.com') `
    -SmtpServer 'smtp.office365.com' `
    -SmtpPort 587 `
    -SmtpCredential (Get-Credential) `
    -WebhookUrl 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL' `
    -AlertThreshold High `
    -TrackTrends `
    -GenerateReports `
    -RetentionDays 90
```

---

## 🎯 Implementation Priority

1. **DOCX Reporting** (Week 3-4)
   - Install PSWriteWord
   - Implement New-WafDocx
   - Test with sample data
   - Add to main workflow

2. **Multi-Tenant Support** (Month 2)
   - Implement Invoke-MultiTenantScan
   - Create consolidated HTML report
   - Test with multiple tenants
   - Document usage

3. **Continuous Monitoring** (Month 3)
   - Implement monitoring loop
   - Add alerting (email + webhook)
   - Implement trend tracking
   - Create monitoring dashboard

---

**Next Steps:** Choose which feature to implement first based on your user needs and business priorities!
