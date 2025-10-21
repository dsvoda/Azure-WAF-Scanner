# Azure Well-Architected Framework (WAF) Scanner

A comprehensive PowerShell-based tool for scanning Azure subscriptions against the Microsoft Well-Architected Framework. Generate detailed reports with actionable recommendations, remediation scripts, and compliance mappings.

![Azure WAF Scanner](https://img.shields.io/badge/Azure-WAF%20Scanner-0078D4?style=for-the-badge&logo=microsoft-azure)
![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-5391FE?style=for-the-badge&logo=powershell)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

## 🌟 Features

### Core Capabilities
- ✅ **Modular Architecture** - Each WAF checklist item has its own check file
- ✅ **Multiple Output Formats** - JSON, CSV, HTML, and Word (DOCX) reports
- ✅ **Parallel Processing** - Scan multiple subscriptions simultaneously
- ✅ **Interactive HTML Reports** - Filter, sort, and search findings with charts
- ✅ **Baseline Comparison** - Track improvements over time
- ✅ **Remediation Scripts** - Auto-generated PowerShell/CLI scripts
- ✅ **Configuration Support** - Customize thresholds, filters, and exclusions
- ✅ **Caching** - Reduce API calls with intelligent result caching
- ✅ **Retry Logic** - Handles throttling and transient errors gracefully

### Data Sources
- Azure Resource Graph (inventory and configuration)
- Azure Advisor (recommendations)
- Azure Policy Insights (compliance state)
- Microsoft Defender for Cloud (security posture)
- Azure Cost Management (spending analysis)
- Azure Monitor (metrics and diagnostics)

## 📋 Prerequisites

### Required
- **PowerShell 7.0+** ([Download](https://github.com/PowerShell/PowerShell/releases))
- **Azure PowerShell Modules** (auto-installed if missing):
  - Az.Accounts (>= 2.0.0)
  - Az.Resources (>= 6.0.0)
  - Az.ResourceGraph (>= 0.13.0)
  - Az.Advisor (>= 2.0.0)
  - Az.Security (>= 1.0.0)
  - Az.PolicyInsights (>= 1.6.0)

### Azure Permissions
Minimum required role assignments per subscription:
- **Reader** (basic resource inventory)
- **Security Reader** (Defender insights)
- **Cost Management Reader** (cost data)

## 🚀 Quick Start

### 1. Clone the Repository
```powershell
git clone https://github.com/yourusername/Azure-WAF-Scanner.git
cd Azure-WAF-Scanner
```

### 2. Connect to Azure
```powershell
Connect-AzAccount
```

### 3. Run Your First Scan
```powershell
# Scan current subscription with HTML report
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml

# Scan specific subscriptions
pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions "sub-id-1","sub-id-2" -EmitHtml -EmitCsv

# Parallel scan with all outputs
pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions "sub-1","sub-2" -Parallel -EmitHtml -EmitCsv -EmitJson
```

## 📊 Output Files

All reports are saved to `./waf-output/` by default:
```
waf-output/
├── SUBID-20251021-143052.json          # Full results
├── SUBID-20251021-143052-summary.json  # Executive summary
├── SUBID-20251021-143052.csv           # Tabular data
├── SUBID-20251021-143052.html          # Interactive report
└── .cache/                             # Cached query results
```

## ⚙️ Configuration

### Configuration File (`config.json`)

Create a `config.json` file to customize the scanner behavior:
```json
{
  "excludedPillars": [],
  "excludedChecks": ["CO05", "SE12"],
  "customThresholds": {
    "costManagement": {
      "monthlyBudgetWarningPercent": 80,
      "unusedResourceAgeDays": 30
    },
    "security": {
      "certificateExpiryDaysWarning": 30
    }
  },
  "resourceFilters": {
    "excludeTags": ["Environment=Dev", "Temporary=True"],
    "excludeResourceGroups": ["NetworkWatcherRG"]
  },
  "performance": {
    "parallelSubscriptions": true,
    "maxParallelism": 5,
    "timeoutSeconds": 300
  },
  "caching": {
    "enabled": true,
    "durationMinutes": 30
  }
}
```

### Command-Line Parameters
```powershell
# Basic usage
-Subscriptions <string[]>      # Subscription IDs or names to scan
-OutputPath <string>            # Output directory (default: ./waf-output)
-ConfigFile <string>            # Path to config file (default: ./config.json)

# Output formats
-EmitJson                       # Generate JSON output
-EmitCsv                        # Generate CSV output
-EmitHtml                       # Generate interactive HTML report
-EmitDocx                       # Generate Word document (requires PSWriteWord)

# Performance
-Parallel                       # Process subscriptions in parallel
-MaxParallelism <int>           # Max parallel threads (default: 5)
-TimeoutSeconds <int>           # Check timeout (default: 300)
-RetryAttempts <int>            # API retry attempts (default: 3)

# Filtering
-ExcludedPillars <string[]>     # Pillars to exclude
-ExcludedChecks <string[]>      # Check IDs to exclude

# Advanced
-BaselineFile <string>          # Compare with baseline scan
-DryRun                         # Show what would be scanned
-ObfuscateSensitiveData         # Remove sensitive data from reports
```

## 📖 Creating Custom Checks

### Check Structure

Place custom checks in `modules/Pillars/<Pillar>/<CheckID>/Invoke.ps1`:
```powershell
# Example: modules/Pillars/Security/SEC-099/Invoke.ps1

Register-WafCheck -CheckId 'SE99' `
    -Pillar 'Security' `
    -Title 'Custom Security Check' `
    -Description 'Description of what this checks' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -DocumentationUrl 'https://docs.microsoft.com/...' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        # Your check logic here
        $query = "Resources | where type == 'microsoft.storage/storageaccounts'"
        $resources = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId
        
        # Return result
        if ($resources.Count -eq 0) {
            return New-WafResult -CheckId 'SE99' `
                -Status 'Pass' `
                -Message 'No issues found'
        } else {
            return New-WafResult -CheckId 'SE99' `
                -Status 'Fail' `
                -Message 'Found issues' `
                -AffectedResources @($resources.id) `
                -Recommendation 'Fix these issues...' `
                -RemediationScript 'az storage account update...'
        }
    }
```

### Scaffolding New Checks

Use the helper script to create check templates:
```powershell
pwsh ./helpers/New-WafItem.ps1 -CheckId 'RE05' -Pillar 'Reliability' -Title 'New Check'
```

## 🎨 HTML Report Features

The interactive HTML reports include:

- **Executive Summary** with compliance score and key metrics
- **Visual Charts** showing compliance by pillar, status distribution, and severity
- **Baseline Comparison** (when using `-BaselineFile`)
- **Priority Recommendations** highlighting critical issues
- **Quick Wins** for easy, high-impact fixes
- **Interactive Table** with filtering, sorting, and search
- **Expandable Details** for each finding
- **CSV Export** function for further analysis
- **Responsive Design** for mobile and print

## 🔍 Example Scenarios

### Scenario 1: Regular Compliance Scan
```powershell
# Weekly scan comparing to baseline
pwsh ./run/Invoke-WafLocal.ps1 `
    -ConfigFile "./config.json" `
    -BaselineFile "./baseline-2024-10.json" `
    -EmitHtml `
    -EmitJson
```

### Scenario 2: Multi-Subscription Assessment
```powershell
# Scan all production subscriptions
$prodSubs = Get-AzSubscription | Where-Object { $_.Name -like "*-prod" }

pwsh ./run/Invoke-WafLocal.ps1 `
    -Subscriptions $prodSubs.Id `
    -Parallel `
    -MaxParallelism 10 `
    -EmitHtml
```

### Scenario 3: Cost Optimization Focus
```powershell
# Only run cost optimization checks
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedPillars @('Security','Reliability','Performance','OperationalExcellence') `
    -EmitHtml `
    -EmitCsv
```

### Scenario 4: Security Audit
```powershell
# Security-focused scan with data obfuscation for sharing
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedPillars @('CostOptimization','Performance') `
    -ObfuscateSensitiveData `
    -EmitHtml `
    -EmitDocx
```

## 📈 Continuous Improvement

### Setting a Baseline
```powershell
# Create baseline from current scan
pwsh ./run/Invoke-WafLocal.ps1 -EmitJson
Copy-Item "./waf-output/SUBID-DATE.json" "./baseline.json"
```

### Tracking Progress
```powershell
# Compare new scan against baseline
pwsh ./run/Invoke-WafLocal.ps1 -BaselineFile "./baseline.json" -EmitHtml

# The HTML report will show:
# - New failures since baseline
# - Improvements since baseline
# - Unchanged items
```

## 🛠️ Troubleshooting

### Common Issues

**Issue: "Module Az.* not found"**
```powershell
# Solution: Modules auto-install, but you can install manually:
Install-Module Az -Scope CurrentUser -Force
```

**Issue: "Access Denied" errors**
```powershell
# Solution: Verify you have required role assignments:
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id
```

**Issue: "Resource Graph throttling"**
```powershell
# Solution: Enable caching and reduce parallelism:
# In config.json:
{
  "caching": { "enabled": true },
  "performance": { "maxParallelism": 3 }
}
```

**Issue: Checks timing out**
```powershell
# Solution: Increase timeout:
pwsh ./run/Invoke-WafLocal.ps1 -TimeoutSeconds 600
```

### Debug Mode
```powershell
# Run with verbose output:
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml -Verbose

# Check logs in output directory:
Get-Content "./waf-output/scan.log"
```

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-check`)
3. Add your check following the structure in `/docs/Development.md`
4. Test thoroughly with `Invoke-Pester`
5. Submit a pull request

### Adding New Checks
See [Development Guide](./docs/Development.md) for detailed instructions.

## 📚 Additional Resources

- [Microsoft Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [Azure Resource Graph Query Language](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language)
- [Azure Advisor Documentation](https://learn.microsoft.com/azure/advisor/)
- [PowerShell 7 Documentation](https://learn.microsoft.com/powershell/)

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Microsoft Well-Architected Framework team
- Azure PowerShell team
- Community contributors

---

**Note**: This tool is a community project and is not officially endorsed by Microsoft. Always review recommendations and test changes in non-production environments first.
```
