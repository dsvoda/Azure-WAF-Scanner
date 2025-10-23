<#
.SYNOPSIS
    Generates professional DOCX reports from WAF scan results.

.DESCRIPTION
    Creates formatted Word documents with executive summary, charts, detailed findings,
    and remediation recommendations using PSWriteWord module.

.PARAMETER Results
    Array of WAF check results.

.PARAMETER Summary
    Summary statistics from Get-WafScanSummary.

.PARAMETER OutputPath
    Path where DOCX file will be saved.

.PARAMETER Comparison
    Optional baseline comparison data.

.PARAMETER CompanyName
    Company name for report branding.

.PARAMETER ReportTitle
    Custom report title.

.PARAMETER IncludeRemediationScripts
    Include remediation scripts in appendix.

.EXAMPLE
    New-WafDocx -Results $results -Summary $summary -OutputPath "./report.docx"

.NOTES
    Requires PSWriteWord module: Install-Module PSWriteWord -Scope CurrentUser
#>

function New-WafDocx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter(Mandatory)]
        [object]$Summary,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [object]$Comparison,
        
        [string]$CompanyName = "Your Organization",
        
        [string]$ReportTitle = "Azure Well-Architected Framework Assessment",
        
        [switch]$IncludeRemediationScripts,
        
        [string]$LogoPath
    )
    
    Write-Verbose "Starting DOCX report generation..."
    
    # Check for PSWriteWord module
    if (!(Get-Module -ListAvailable -Name PSWriteWord)) {
        Write-Warning "PSWriteWord module not found. Attempting to install..."
        try {
            Install-Module PSWriteWord -Scope CurrentUser -Force -AllowClobber
            Write-Host "✓ PSWriteWord installed successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to install PSWriteWord: $_"
            Write-Error "Install manually with: Install-Module PSWriteWord -Scope CurrentUser"
            return $null
        }
    }
    
    Import-Module PSWriteWord -ErrorAction Stop
    
    # Create document
    $doc = New-WordDocument -FilePath $OutputPath
    
    Write-Verbose "Building document structure..."
    
    # ═══════════════════════════════════════════════════════════
    # COVER PAGE
    # ═══════════════════════════════════════════════════════════
    
    if ($LogoPath -and (Test-Path $LogoPath)) {
        Add-WordPicture -WordDocument $doc -ImagePath $LogoPath -Alignment center
        Add-WordText -WordDocument $doc -Text "" -LineBreak
    }
    
    Add-WordText -WordDocument $doc -Text $ReportTitle `
        -FontSize 28 -Bold -Alignment center -Color Blue
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text $CompanyName `
        -FontSize 20 -Alignment center
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Assessment Date: $($Summary.Timestamp.ToString('MMMM dd, yyyy'))" `
        -FontSize 14 -Alignment center -Color DarkGray
    
    Add-WordText -WordDocument $doc -Text "Duration: $($Summary.Duration)" `
        -FontSize 12 -Alignment center -Color DarkGray
    
    # Page break
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # TABLE OF CONTENTS
    # ═══════════════════════════════════════════════════════════
    
    Add-WordText -WordDocument $doc -Text "Table of Contents" `
        -FontSize 20 -Bold -UnderlineStyle single
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    $tocItems = @(
        "1. Executive Summary",
        "2. Compliance Overview",
        "3. Critical Findings",
        "4. Quick Wins",
        "5. Detailed Results by Pillar",
        "6. Baseline Comparison",
        "7. Recommendations",
        "8. Appendices"
    )
    
    foreach ($item in $tocItems) {
        Add-WordText -WordDocument $doc -Text $item -FontSize 12
    }
    
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # EXECUTIVE SUMMARY
    # ═══════════════════════════════════════════════════════════
    
    Add-WordText -WordDocument $doc -Text "1. Executive Summary" `
        -FontSize 20 -Bold -UnderlineStyle single
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Overall assessment text
    $assessmentText = if ($Summary.ComplianceScore -ge 90) {
        "Excellent: Your Azure environment demonstrates strong alignment with the Well-Architected Framework. Continue monitoring and addressing any remaining findings to maintain this high standard."
    } elseif ($Summary.ComplianceScore -ge 75) {
        "Good: Your Azure environment is well-architected with some areas for improvement. Focus on addressing high-severity findings to achieve excellence."
    } elseif ($Summary.ComplianceScore -ge 60) {
        "Fair: Significant improvements are needed to align with Well-Architected Framework best practices. Prioritize critical and high-severity findings for immediate action."
    } else {
        "Needs Attention: Your Azure environment requires substantial improvements across multiple pillars. Immediate action is strongly recommended on all critical findings."
    }
    
    Add-WordText -WordDocument $doc -Text $assessmentText `
        -FontSize 12 -Italic
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Summary statistics table
    $summaryTableData = @(
        [PSCustomObject]@{ Metric = "Compliance Score"; Value = "$($Summary.ComplianceScore)%" },
        [PSCustomObject]@{ Metric = "Total Checks Performed"; Value = $Summary.TotalChecks },
        [PSCustomObject]@{ Metric = "Passed Checks"; Value = $Summary.Passed },
        [PSCustomObject]@{ Metric = "Failed Checks"; Value = $Summary.Failed },
        [PSCustomObject]@{ Metric = "Warnings"; Value = $Summary.Warnings },
        [PSCustomObject]@{ Metric = "Not Applicable"; Value = $Summary.NotApplicable },
        [PSCustomObject]@{ Metric = "Errors"; Value = $Summary.Errors }
    )
    
    Add-WordTable -WordDocument $doc -DataTable $summaryTableData `
        -Design LightGridAccent1 -AutoFit Window
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Key findings summary
    Add-WordText -WordDocument $doc -Text "Key Findings:" -FontSize 14 -Bold
    
    $criticalCount = ($Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'Critical' }).Count
    $highCount = ($Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'High' }).Count
    
    Add-WordText -WordDocument $doc -Text "• Critical Issues: $criticalCount" `
        -FontSize 12 -Color $(if ($criticalCount -gt 0) { 'Red' } else { 'Green' })
    
    Add-WordText -WordDocument $doc -Text "• High Priority Issues: $highCount" `
        -FontSize 12 -Color $(if ($highCount -gt 0) { 'Orange' } else { 'Green' })
    
    $quickWinsCount = ($Results | Where-Object { $_.Status -eq 'Fail' -and $_.RemediationEffort -eq 'Low' }).Count
    Add-WordText -WordDocument $doc -Text "• Quick Win Opportunities: $quickWinsCount" `
        -FontSize 12 -Color Blue
    
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # COMPLIANCE OVERVIEW BY PILLAR
    # ═══════════════════════════════════════════════════════════
    
    Add-WordText -WordDocument $doc -Text "2. Compliance Overview" `
        -FontSize 20 -Bold -UnderlineStyle single
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "The Well-Architected Framework consists of five pillars. Below is the compliance status for each pillar:" `
        -FontSize 12
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Pillar scores table
    $pillarTableData = foreach ($pillar in $Summary.ByPillar) {
        [PSCustomObject]@{
            Pillar = $pillar.Pillar
            'Compliance Score' = "$($pillar.ComplianceScore)%"
            Passed = $pillar.Passed
            Failed = $pillar.Failed
            Total = $pillar.Total
        }
    }
    
    Add-WordTable -WordDocument $doc -DataTable $pillarTableData `
        -Design LightGridAccent1 -AutoFit Window
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    # Pillar descriptions
    foreach ($pillar in $Summary.ByPillar | Sort-Object ComplianceScore) {
        $icon = switch ($pillar.Pillar) {
            'Reliability' { '🛡️' }
            'Security' { '🔐' }
            'CostOptimization' { '💰' }
            'OperationalExcellence' { '🔧' }
            'PerformanceEfficiency' { '⚡' }
            default { '📋' }
        }
        
        Add-WordText -WordDocument $doc -Text "$icon $($pillar.Pillar)" `
            -FontSize 14 -Bold
        
        $scoreColor = if ($pillar.ComplianceScore -ge 80) { 'Green' }
                     elseif ($pillar.ComplianceScore -ge 60) { 'Orange' }
                     else { 'Red' }
        
        Add-WordText -WordDocument $doc -Text "Score: $($pillar.ComplianceScore)% | Passed: $($pillar.Passed)/$($pillar.Total)" `
            -FontSize 12 -Color $scoreColor
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
    }
    
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # CRITICAL FINDINGS
    # ═══════════════════════════════════════════════════════════
    
    $criticalFindings = $Results | Where-Object { 
        $_.Status -eq 'Fail' -and $_.Severity -in @('Critical', 'High') 
    } | Sort-Object @{Expression={
        if ($_.Severity -eq 'Critical') { 1 } else { 2 }
    }} | Select-Object -First 10
    
    if ($criticalFindings.Count -gt 0) {
        Add-WordText -WordDocument $doc -Text "3. Critical & High Priority Findings" `
            -FontSize 20 -Bold -UnderlineStyle single
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        Add-WordText -WordDocument $doc -Text "The following issues require immediate attention:" `
            -FontSize 12 -Bold -Color Red
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        $findingNumber = 1
        foreach ($finding in $criticalFindings) {
            # Finding header
            Add-WordText -WordDocument $doc -Text "$findingNumber. $($finding.CheckId): $($finding.Title)" `
                -FontSize 14 -Bold
            
            # Metadata bar
            $metaText = "Pillar: $($finding.Pillar) | Severity: $($finding.Severity) | Effort: $($finding.RemediationEffort)"
            Add-WordText -WordDocument $doc -Text $metaText `
                -FontSize 11 -Color DarkGray
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
            
            # Issue description
            Add-WordText -WordDocument $doc -Text "Issue:" -FontSize 12 -Bold
            Add-WordText -WordDocument $doc -Text $finding.Message -FontSize 11
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
            
            # Recommendation
            if ($finding.Recommendation) {
                Add-WordText -WordDocument $doc -Text "Recommendation:" -FontSize 12 -Bold
                Add-WordText -WordDocument $doc -Text $finding.Recommendation -FontSize 11
                
                Add-WordText -WordDocument $doc -Text "" -LineBreak
            }
            
            # Affected resources
            if ($finding.AffectedResources -and $finding.AffectedResources.Count -gt 0) {
                Add-WordText -WordDocument $doc -Text "Affected Resources ($($finding.AffectedResources.Count)):" `
                    -FontSize 12 -Bold
                
                $resourcePreview = ($finding.AffectedResources | Select-Object -First 3) -join "`n"
                Add-WordText -WordDocument $doc -Text $resourcePreview `
                    -FontSize 10 -FontFamily 'Consolas'
                
                if ($finding.AffectedResources.Count -gt 3) {
                    Add-WordText -WordDocument $doc -Text "... and $($finding.AffectedResources.Count - 3) more" `
                        -FontSize 10 -Italic -Color DarkGray
                }
                
                Add-WordText -WordDocument $doc -Text "" -LineBreak
            }
            
            # Documentation link
            if ($finding.DocumentationUrl) {
                Add-WordText -WordDocument $doc -Text "Learn More: $($finding.DocumentationUrl)" `
                    -FontSize 10 -Color Blue -Underline
            }
            
            Add-WordText -WordDocument $doc -Text "─────────────────────────────────────────────────────────────" `
                -FontSize 10 -Color LightGray
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
            
            $findingNumber++
        }
        
        Add-WordPageBreak -WordDocument $doc
    }
    
    # ═══════════════════════════════════════════════════════════
    # QUICK WINS
    # ═══════════════════════════════════════════════════════════
    
    $quickWins = $Results | Where-Object { 
        $_.Status -eq 'Fail' -and $_.RemediationEffort -eq 'Low' 
    } | Select-Object -First 5
    
    if ($quickWins.Count -gt 0) {
        Add-WordText -WordDocument $doc -Text "4. Quick Wins" `
            -FontSize 20 -Bold -UnderlineStyle single
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        Add-WordText -WordDocument $doc -Text "These issues can be resolved quickly for immediate improvement:" `
            -FontSize 12 -Color Green -Bold
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        foreach ($win in $quickWins) {
            Add-WordText -WordDocument $doc -Text "✓ $($win.CheckId): $($win.Title)" `
                -FontSize 12 -Bold
            
            Add-WordText -WordDocument $doc -Text "Pillar: $($win.Pillar)" `
                -FontSize 11 -Color DarkGray
            
            Add-WordText -WordDocument $doc -Text $win.Message -FontSize 11
            
            if ($win.Recommendation) {
                Add-WordText -WordDocument $doc -Text "Quick Fix: $($win.Recommendation)" `
                    -FontSize 11 -Color Green
            }
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
        
        Add-WordPageBreak -WordDocument $doc
    }
    
    # ═══════════════════════════════════════════════════════════
    # DETAILED RESULTS BY PILLAR
    # ═══════════════════════════════════════════════════════════
    
    Add-WordText -WordDocument $doc -Text "5. Detailed Results by Pillar" `
        -FontSize 20 -Bold -UnderlineStyle single
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    $pillars = $Results | Select-Object -ExpandProperty Pillar -Unique | Sort-Object
    
    foreach ($pillar in $pillars) {
        $pillarResults = $Results | Where-Object Pillar -eq $pillar
        
        Add-WordText -WordDocument $doc -Text $pillar -FontSize 18 -Bold -Color Blue
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        # Create detailed table
        $detailTableData = $pillarResults | ForEach-Object {
            [PSCustomObject]@{
                'Check ID' = $_.CheckId
                Status = $_.Status
                Severity = $_.Severity
                Title = $_.Title
            }
        }
        
        Add-WordTable -WordDocument $doc -DataTable $detailTableData `
            -Design LightGridAccent1 -AutoFit Window
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
    }
    
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # BASELINE COMPARISON (if provided)
    # ═══════════════════════════════════════════════════════════
    
    if ($Comparison) {
        Add-WordText -WordDocument $doc -Text "6. Baseline Comparison" `
            -FontSize 20 -Bold -UnderlineStyle single
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        Add-WordText -WordDocument $doc -Text "Comparison with previous assessment:" `
            -FontSize 12
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        $compTableData = @(
            [PSCustomObject]@{ Metric = "New Failures (Regressions)"; Count = $Comparison.NewFailures.Count },
            [PSCustomObject]@{ Metric = "Improvements"; Count = $Comparison.Improvements.Count },
            [PSCustomObject]@{ Metric = "Unchanged"; Count = $Comparison.Unchanged.Count }
        )
        
        Add-WordTable -WordDocument $doc -DataTable $compTableData `
            -Design ColorfulList -AutoFit Window
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        if ($Comparison.NewFailures.Count -gt 0) {
            Add-WordText -WordDocument $doc -Text "New Failures:" -FontSize 14 -Bold -Color Red
            
            foreach ($fail in $Comparison.NewFailures) {
                Add-WordText -WordDocument $doc -Text "• $($fail.CheckId): $($fail.Title)" `
                    -FontSize 11 -Color Red
            }
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
        
        if ($Comparison.Improvements.Count -gt 0) {
            Add-WordText -WordDocument $doc -Text "Improvements:" -FontSize 14 -Bold -Color Green
            
            foreach ($improve in $Comparison.Improvements) {
                Add-WordText -WordDocument $doc -Text "• $($improve.CheckId): $($improve.Title)" `
                    -FontSize 11 -Color Green
            }
        }
        
        Add-WordPageBreak -WordDocument $doc
    }
    
    # ═══════════════════════════════════════════════════════════
    # RECOMMENDATIONS
    # ═══════════════════════════════════════════════════════════
    
    Add-WordText -WordDocument $doc -Text "7. Recommendations" `
        -FontSize 20 -Bold -UnderlineStyle single
    
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Implementation Roadmap:" -FontSize 14 -Bold
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Phase 1: Critical Issues (Weeks 1-2)" `
        -FontSize 12 -Bold -Color Red
    Add-WordText -WordDocument $doc -Text "Address all critical and high-priority findings immediately." `
        -FontSize 11
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Phase 2: Quick Wins (Weeks 3-4)" `
        -FontSize 12 -Bold -Color Green
    Add-WordText -WordDocument $doc -Text "Implement low-effort fixes to boost compliance score quickly." `
        -FontSize 11
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Phase 3: Medium Priority (Months 2-3)" `
        -FontSize 12 -Bold -Color Orange
    Add-WordText -WordDocument $doc -Text "Plan and execute medium-effort improvements systematically." `
        -FontSize 11
    Add-WordText -WordDocument $doc -Text "" -LineBreak
    
    Add-WordText -WordDocument $doc -Text "Phase 4: Optimization (Month 4+)" `
        -FontSize 12 -Bold -Color Blue
    Add-WordText -WordDocument $doc -Text "Continuous improvement and optimization initiatives." `
        -FontSize 11
    
    Add-WordPageBreak -WordDocument $doc
    
    # ═══════════════════════════════════════════════════════════
    # APPENDICES
    # ═══════════════════════════════════════════════════════════
    
    if ($IncludeRemediationScripts) {
        Add-WordText -WordDocument $doc -Text "8. Appendices" `
            -FontSize 20 -Bold -UnderlineStyle single
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        Add-WordText -WordDocument $doc -Text "A. Remediation Scripts" `
            -FontSize 16 -Bold
        
        Add-WordText -WordDocument $doc -Text "" -LineBreak
        
        $failedChecks = $Results | Where-Object { 
            $_.Status -eq 'Fail' -and $_.RemediationScript 
        } | Select-Object -First 10
        
        foreach ($check in $failedChecks) {
            Add-WordText -WordDocument $doc -Text "$($check.CheckId): $($check.Title)" `
                -FontSize 12 -Bold
            
            Add-WordText -WordDocument $doc -Text "Remediation Script:" `
                -FontSize 11 -Italic
            
            # Add script as table for better formatting
            $scriptTable = @(
                [PSCustomObject]@{ Script = $check.RemediationScript }
            )
            
            Add-WordTable -WordDocument $doc -DataTable $scriptTable `
                -Design PlainTable1 -AutoFit Window
            
            Add-WordText -WordDocument $doc -Text "" -LineBreak
        }
    }
    
    # ═══════════════════════════════════════════════════════════
    # SAVE DOCUMENT
    # ═══════════════════════════════════════════════════════════
    
    try {
        Save-WordDocument -WordDocument $doc
        Write-Host "✓ DOCX report generated successfully: $OutputPath" -ForegroundColor Green
        return $OutputPath
    } catch {
        Write-Error "Failed to save DOCX document: $_"
        return $null
    }
}

# Export function
Export-ModuleMember -Function New-WafDocx
