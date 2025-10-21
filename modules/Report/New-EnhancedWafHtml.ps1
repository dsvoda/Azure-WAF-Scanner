<#
.SYNOPSIS
    Generates an enhanced interactive HTML report for WAF scan results.

.DESCRIPTION
    Creates a modern, interactive HTML report with filtering, sorting,
    charts, executive summary, and remediation recommendations.
#>

function New-EnhancedWafHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        
        [Parameter(Mandatory)]
        [hashtable]$Summary,
        
        [hashtable]$Comparison,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$TemplatePath = "./report-assets/templates/enhanced.html",
        [string]$StylesPath = "./report-assets/styles/enhanced.css"
    )
    
    Write-Verbose "Generating enhanced HTML report..."
    
    # Prepare data for charts
    $pillarData = $Results | Group-Object Pillar | ForEach-Object {
        $total = $_.Count
        $passed = ($_.Group | Where-Object Status -eq 'Pass').Count
        $failed = ($_.Group | Where-Object Status -eq 'Fail').Count
        $warnings = ($_.Group | Where-Object Status -eq 'Warning').Count
        
        @{
            pillar = $_.Name
            total = $total
            passed = $passed
            failed = $failed
            warnings = $warnings
            score = if ($total -gt 0) { [Math]::Round(($passed / $total) * 100, 1) } else { 0 }
        }
    }
    
    $severityData = $Results | Where-Object Status -eq 'Fail' | Group-Object Severity | ForEach-Object {
        @{
            severity = $_.Name
            count = $_.Count
        }
    }
    
    # Priority recommendations (top 10 failures by severity)
    $priorityItems = $Results | 
        Where-Object Status -eq 'Fail' | 
        Sort-Object @{Expression={
            switch ($_.Severity) {
                'Critical' { 1 }
                'High' { 2 }
                'Medium' { 3 }
                'Low' { 4 }
                default { 5 }
            }
        }} | 
        Select-Object -First 10
    
    # Quick wins (easy fixes)
    $quickWins = $Results | 
        Where-Object { $_.Status -eq 'Fail' -and $_.RemediationEffort -eq 'Low' } |
        Select-Object -First 5
    
    # Generate HTML
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure WAF Assessment Report</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #0078d4 0%, #005a9e 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .executive-summary {
            padding: 40px;
            background: #f8f9fa;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .card {
            background: white;
            padding: 25px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.2s;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        .card-icon {
            font-size: 2.5em;
            margin-bottom: 15px;
        }
        
        .card-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .card-label {
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .card.passed { border-left: 4px solid #28a745; }
        .card.passed .card-icon { color: #28a745; }
        
        .card.failed { border-left: 4px solid #dc3545; }
        .card.failed .card-icon { color: #dc3545; }
        
        .card.warnings { border-left: 4px solid #ffc107; }
        .card.warnings .card-icon { color: #ffc107; }
        
        .card.score { border-left: 4px solid #0078d4; }
        .card.score .card-icon { color: #0078d4; }
        
        .content {
            padding: 40px;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section-title {
            font-size: 1.8em;
            margin-bottom: 20px;
            color: #0078d4;
            border-bottom: 3px solid #0078d4;
            padding-bottom: 10px;
        }
        
        .charts-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }
        
        .chart-card {
            background: white;
            padding: 25px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .chart-title {
            font-size: 1.3em;
            margin-bottom: 20px;
            text-align: center;
            color: #333;
        }
        
        .filters {
            display: flex;
            gap: 15px;
            margin-bottom: 25px;
            flex-wrap: wrap;
            align-items: center;
        }
        
        .filter-group {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .filter-group label {
            font-weight: 600;
            color: #555;
        }
        
        .filter-group select,
        .filter-group input {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 0.95em;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.95em;
            transition: all 0.2s;
        }
        
        .btn-primary {
            background: #0078d4;
            color: white;
        }
        
        .btn-primary:hover {
            background: #005a9e;
        }
        
        .results-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .results-table thead {
            background: #0078d4;
            color: white;
        }
        
        .results-table th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
            cursor: pointer;
            user-select: none;
        }
        
        .results-table th:hover {
            background: #005a9e;
        }
        
        .results-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }
        
        .results-table tbody tr:hover {
            background: #f8f9fa;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-pass { background: #d4edda; color: #155724; }
        .status-fail { background: #f8d7da; color: #721c24; }
        .status-warning { background: #fff3cd; color: #856404; }
        .status-na { background: #e2e3e5; color: #383d41; }
        
        .severity-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }
        
        .severity-critical { background: #721c24; color: white; }
        .severity-high { background: #dc3545; color: white; }
        .severity-medium { background: #ffc107; color: #333; }
        .severity-low { background: #17a2b8; color: white; }
        
        .expandable {
            cursor: pointer;
        }
        
        .details-row {
            display: none;
            background: #f8f9fa;
        }
        
        .details-content {
            padding: 20px;
            border-left: 4px solid #0078d4;
        }
        
        .recommendation {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 15px;
            border-left: 4px solid #0078d4;
        }
        
        .recommendation h4 {
            color: #0078d4;
            margin-bottom: 8px;
        }
        
        .quick-win {
            background: #d4edda;
            border-left-color: #28a745;
        }
        
        .quick-win h4 {
            color: #28a745;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
        
        .comparison-section {
            background: #fff3cd;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #ffc107;
            margin-bottom: 30px;
        }
        
        .comparison-stats {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-top: 15px;
        }
        
        .comparison-stat {
            text-align: center;
            padding: 15px;
            background: white;
            border-radius: 4px;
        }
        
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
            .filters { display: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-cloud"></i> Azure Well-Architected Framework Assessment</h1>
            <p>Generated on $($Summary.Timestamp.ToString('MMMM dd, yyyy HH:mm:ss'))</p>
            <p>Duration: $($Summary.Duration)</p>
        </div>
        
        <div class="executive-summary">
            <h2 style="margin-bottom: 20px;">Executive Summary</h2>
            
            <div class="summary-cards">
                <div class="card score">
                    <div class="card-icon"><i class="fas fa-chart-line"></i></div>
                    <div class="card-value">$($Summary.ComplianceScore)%</div>
                    <div class="card-label">Compliance Score</div>
                </div>
                
                <div class="card passed">
                    <div class="card-icon"><i class="fas fa-check-circle"></i></div>
                    <div class="card-value">$($Summary.Passed)</div>
                    <div class="card-label">Passed</div>
                </div>
                
                <div class="card failed">
                    <div class="card-icon"><i class="fas fa-times-circle"></i></div>
                    <div class="card-value">$($Summary.Failed)</div>
                    <div class="card-label">Failed</div>
                </div>
                
                <div class="card warnings">
                    <div class="card-icon"><i class="fas fa-exclamation-triangle"></i></div>
                    <div class="card-value">$($Summary.Warnings)</div>
                    <div class="card-label">Warnings</div>
                </div>
            </div>
"@

    # Add comparison section if baseline provided
    if ($Comparison) {
        $html += @"
            
            <div class="comparison-section" style="margin-top: 30px;">
                <h3><i class="fas fa-balance-scale"></i> Baseline Comparison</h3>
                <div class="comparison-stats">
                    <div class="comparison-stat">
                        <div style="font-size: 2em; color: #dc3545; font-weight: bold;">$($Comparison.NewFailures.Count)</div>
                        <div style="color: #666;">New Failures</div>
                    </div>
                    <div class="comparison-stat">
                        <div style="font-size: 2em; color: #28a745; font-weight: bold;">$($Comparison.Improvements.Count)</div>
                        <div style="color: #666;">Improvements</div>
                    </div>
                    <div class="comparison-stat">
                        <div style="font-size: 2em; color: #6c757d; font-weight: bold;">$($Comparison.Unchanged.Count)</div>
                        <div style="color: #666;">Unchanged</div>
                    </div>
                </div>
            </div>
"@
    }

    $html += @"
        </div>
        
        <div class="content">
            <div class="section">
                <h2 class="section-title"><i class="fas fa-chart-bar"></i> Visual Analytics</h2>
                
                <div class="charts-container">
                    <div class="chart-card">
                        <h3 class="chart-title">Compliance by Pillar</h3>
                        <canvas id="pillarChart"></canvas>
                    </div>
                    
                    <div class="chart-card">
                        <h3 class="chart-title">Status Distribution</h3>
                        <canvas id="statusChart"></canvas>
                    </div>
                    
                    <div class="chart-card">
                        <h3 class="chart-title">Failure Severity</h3>
                        <canvas id="severityChart"></canvas>
                    </div>
                </div>
            </div>
"@

    # Priority Recommendations
    if ($priorityItems.Count -gt 0) {
        $html += @"
            <div class="section">
                <h2 class="section-title"><i class="fas fa-exclamation-circle"></i> Priority Recommendations</h2>
                <p style="margin-bottom: 20px;">Top $($priorityItems.Count) critical issues requiring immediate attention.</p>
"@
        
        foreach ($item in $priorityItems) {
            $html += @"
                <div class="recommendation">
                    <h4><i class="fas fa-flag"></i> $($item.CheckId) - $($item.Title)</h4>
                    <p><strong>Pillar:</strong> $($item.Pillar) | <strong>Severity:</strong> <span class="severity-badge severity-$($item.Severity.ToLower())">$($item.Severity)</span></p>
                    <p><strong>Issue:</strong> $($item.Message)</p>
                    <p><strong>Recommendation:</strong> $($item.Recommendation)</p>
                    $(if ($item.AffectedResources) { "<p><strong>Affected Resources:</strong> $($item.AffectedResources -join ', ')</p>" })
                </div>
"@
        }
        
        $html += "</div>"
    }

    # Quick Wins
    if ($quickWins.Count -gt 0) {
        $html += @"
            <div class="section">
                <h2 class="section-title"><i class="fas fa-bolt"></i> Quick Wins</h2>
                <p style="margin-bottom: 20px;">Easy fixes that can be implemented quickly for immediate improvement.</p>
"@
        
        foreach ($item in $quickWins) {
            $html += @"
                <div class="recommendation quick-win">
                    <h4><i class="fas fa-rocket"></i> $($item.CheckId) - $($item.Title)</h4>
                    <p><strong>Pillar:</strong> $($item.Pillar) | <strong>Effort:</strong> Low</p>
                    <p><strong>Issue:</strong> $($item.Message)</p>
                    <p><strong>Quick Fix:</strong> $($item.Recommendation)</p>
                </div>
"@
        }
        
        $html += "</div>"
    }

    # Detailed Results
    $html += @"
            <div class="section">
                <h2 class="section-title"><i class="fas fa-list-alt"></i> Detailed Results</h2>
                
                <div class="filters">
                    <div class="filter-group">
                        <label for="filterPillar">Pillar:</label>
                        <select id="filterPillar" onchange="filterResults()">
                            <option value="">All</option>
                            $(($Results | Select-Object -ExpandProperty Pillar -Unique | Sort-Object | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n")
                        </select>
                    </div>
                    
                    <div class="filter-group">
                        <label for="filterStatus">Status:</label>
                        <select id="filterStatus" onchange="filterResults()">
                            <option value="">All</option>
                            <option value="Fail">Failed</option>
                            <option value="Pass">Passed</option>
                            <option value="Warning">Warning</option>
                            <option value="N/A">N/A</option>
                        </select>
                    </div>
                    
                    <div class="filter-group">
                        <label for="filterSeverity">Severity:</label>
                        <select id="filterSeverity" onchange="filterResults()">
                            <option value="">All</option>
                            <option value="Critical">Critical</option>
                            <option value="High">High</option>
                            <option value="Medium">Medium</option>
                            <option value="Low">Low</option>
                        </select>
                    </div>
                    
                    <div class="filter-group">
                        <label for="searchBox">Search:</label>
                        <input type="text" id="searchBox" placeholder="Search..." onkeyup="filterResults()">
                    </div>
                    
                    <button class="btn btn-primary" onclick="resetFilters()">
                        <i class="fas fa-redo"></i> Reset Filters
                    </button>
                    
                    <button class="btn btn-primary" onclick="exportToCSV()">
                        <i class="fas fa-download"></i> Export CSV
                    </button>
                </div>
                
                <table class="results-table" id="resultsTable">
                    <thead>
                        <tr>
                            <th onclick="sortTable(0)">Check ID <i class="fas fa-sort"></i></th>
                            <th onclick="sortTable(1)">Pillar <i class="fas fa-sort"></i></th>
                            <th onclick="sortTable(2)">Status <i class="fas fa-sort"></i></th>
                            <th onclick="sortTable(3)">Severity <i class="fas fa-sort"></i></th>
                            <th onclick="sortTable(4)">Title <i class="fas fa-sort"></i></th>
                            <th>Details</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add table rows
    foreach ($result in $Results) {
        $statusClass = switch ($result.Status) {
            'Pass' { 'status-pass' }
            'Fail' { 'status-fail' }
            'Warning' { 'status-warning' }
            default { 'status-na' }
        }
        
        $severityClass = "severity-$($result.Severity.ToLower())"
        
        $html += @"
                        <tr class="expandable" onclick="toggleDetails(this)" 
                            data-pillar="$($result.Pillar)" 
                            data-status="$($result.Status)" 
                            data-severity="$($result.Severity)">
                            <td>$($result.CheckId)</td>
                            <td>$($result.Pillar)</td>
                            <td><span class="status-badge $statusClass">$($result.Status)</span></td>
                            <td><span class="severity-badge $severityClass">$($result.Severity)</span></td>
                            <td>$($result.Title)</td>
                            <td><i class="fas fa-chevron-down"></i></td>
                        </tr>
                        <tr class="details-row">
                            <td colspan="6">
                                <div class="details-content">
                                    <p><strong>Description:</strong> $($result.Description)</p>
                                    <p><strong>Message:</strong> $($result.Message)</p>
                                    $(if ($result.Recommendation) { "<p><strong>Recommendation:</strong> $($result.Recommendation)</p>" })
                                    $(if ($result.DocumentationUrl) { "<p><strong>Learn More:</strong> <a href='$($result.DocumentationUrl)' target='_blank'>$($result.DocumentationUrl)</a></p>" })
                                    $(if ($result.AffectedResources) { "<p><strong>Affected Resources:</strong> $($result.AffectedResources -join ', ')</p>" })
                                    $(if ($result.RemediationScript) { "<p><strong>Remediation Script:</strong><pre>$($result.RemediationScript)</pre></p>" })
                                </div>
                            </td>
                        </tr>
"@
    }

    $html += @"
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            <p>Azure Well-Architected Framework Assessment Report</p>
            <p>Generated by Azure WAF Scanner | <a href="https://docs.microsoft.com/azure/architecture/framework/" target="_blank">Learn more about WAF</a></p>
        </div>
    </div>
    
    <script>
        // Chart data from PowerShell
        const pillarData = $($pillarData | ConvertTo-Json -Compress);
        const severityData = $($severityData | ConvertTo-Json -Compress);
        const statusData = {
            passed: $($Summary.Passed),
            failed: $($Summary.Failed),
            warnings: $($Summary.Warnings),
            na: $($Summary.NotApplicable)
        };
        
        // Pillar Chart
        new Chart(document.getElementById('pillarChart'), {
            type: 'bar',
            data: {
                labels: pillarData.map(p => p.pillar),
                datasets: [{
                    label: 'Compliance Score %',
                    data: pillarData.map(p => p.score),
                    backgroundColor: 'rgba(0, 120, 212, 0.8)',
                    borderColor: 'rgba(0, 120, 212, 1)',
                    borderWidth: 1
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
        
        // Status Chart
        new Chart(document.getElementById('statusChart'), {
            type: 'doughnut',
            data: {
                labels: ['Passed', 'Failed', 'Warnings', 'N/A'],
                datasets: [{
                    data: [statusData.passed, statusData.failed, statusData.warnings, statusData.na],
                    backgroundColor: [
                        'rgba(40, 167, 69, 0.8)',
                        'rgba(220, 53, 69, 0.8)',
                        'rgba(255, 193, 7, 0.8)',
                        'rgba(108, 117, 125, 0.8)'
                    ]
                }]
            },
            options: {
                responsive: true
            }
        });
        
        // Severity Chart
        if (severityData.length > 0) {
            new Chart(document.getElementById('severityChart'), {
                type: 'pie',
                data: {
                    labels: severityData.map(s => s.severity),
                    datasets: [{
                        data: severityData.map(s => s.count),
                        backgroundColor: [
                            'rgba(114, 28, 36, 0.8)',
                            'rgba(220, 53, 69, 0.8)',
                            'rgba(255, 193, 7, 0.8)',
                            'rgba(23, 162, 184, 0.8)'
                        ]
                    }]
                },
                options: {
                    responsive: true
                }
            });
        }
        
        // Table functions
        function toggleDetails(row) {
            const detailsRow = row.nextElementSibling;
            const icon = row.querySelector('.fa-chevron-down, .fa-chevron-up');
            
            if (detailsRow.style.display === 'table-row') {
                detailsRow.style.display = 'none';
                icon.className = 'fas fa-chevron-down';
            } else {
                detailsRow.style.display = 'table-row';
                icon.className = 'fas fa-chevron-up';
            }
        }
        
        function filterResults() {
            const pillar = document.getElementById('filterPillar').value;
            const status = document.getElementById('filterStatus').value;
            const severity = document.getElementById('filterSeverity').value;
            const search = document.getElementById('searchBox').value.toLowerCase();
            
            const rows = document.querySelectorAll('#resultsTable tbody tr.expandable');
            
            rows.forEach(row => {
                const rowPillar = row.dataset.pillar;
                const rowStatus = row.dataset.status;
                const rowSeverity = row.dataset.severity;
                const rowText = row.textContent.toLowerCase();
                
                const matchPillar = !pillar || rowPillar === pillar;
                const matchStatus = !status || rowStatus === status;
                const matchSeverity = !severity || rowSeverity === severity;
                const matchSearch = !search || rowText.includes(search);
                
                if (matchPillar && matchStatus && matchSeverity && matchSearch) {
                    row.style.display = '';
                    row.nextElementSibling.style.display = 'none';
                } else {
                    row.style.display = 'none';
                    row.nextElementSibling.style.display = 'none';
                }
            });
        }
        
        function resetFilters() {
            document.getElementById('filterPillar').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('filterSeverity').value = '';
            document.getElementById('searchBox').value = '';
            filterResults();
        }
        
        function sortTable(column) {
            const table = document.getElementById('resultsTable');
            const tbody = table.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr.expandable'));
            
            rows.sort((a, b) => {
                const aValue = a.cells[column].textContent.trim();
                const bValue = b.cells[column].textContent.trim();
                return aValue.localeCompare(bValue);
            });
            
            rows.forEach((row, index) => {
                const detailsRow = row.nextElementSibling;
                tbody.appendChild(row);
                tbody.appendChild(detailsRow);
            });
        }
        
        function exportToCSV() {
            const rows = document.querySelectorAll('#resultsTable tbody tr.expandable');
            let csv = 'Check ID,Pillar,Status,Severity,Title\\n';
            
            rows.forEach(row => {
                if (row.style.display !== 'none') {
                    const cells = Array.from(row.cells).slice(0, 5);
                    csv += cells.map(cell => {
                        let text = cell.textContent.trim();
                        return '"' + text.replace(/"/g, '""') + '"';
                    }).join(',') + '\\n';
                }
            });
            
            const blob = new Blob([csv], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'waf-results.csv';
            a.click();
        }
    </script>
</body>
</html>
"@

    # Write to file
    $html | Set
    Content -Path $OutputPath -Encoding UTF8
    Write-Verbose "HTML report generated successfully at: $OutputPath"
    }
    Export-ModuleMember -Function New-EnhancedWafHtml
