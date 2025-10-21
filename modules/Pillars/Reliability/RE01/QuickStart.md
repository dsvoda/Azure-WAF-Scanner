# Azure WAF Scanner - Quick Start Guide

## 🚀 Quick Start (5 minutes)

### 1. Prerequisites Check

```powershell
# Check PowerShell version (requires 7.0+)
$PSVersionTable.PSVersion

# If < 7.0, install from: https://github.com/PowerShell/PowerShell/releases
```

### 2. Install Required Modules

```powershell
# Install Azure PowerShell modules
$modules = @('Az.Accounts', 'Az.Resources', 'Az.ResourceGraph', 'Az.Advisor', 'Az.Security', 'Az.PolicyInsights')

foreach ($module in $modules) {
    if (!(Get-Module $module -ListAvailable)) {
        Write-Host "Installing $module..." -ForegroundColor Yellow
        Install-Module $module -Scope CurrentUser -Force -AllowClobber
    }
}
```

### 3. Connect to Azure

```powershell
# Connect to Azure
Connect-AzAccount

# Verify connection
Get-AzContext

# (Optional) Switch to specific subscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

### 4. Run Your First Scan

```powershell
# Navigate to the scanner directory
cd Azure-WAF-Scanner

# Run scan with HTML report
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml

# Results will be in ./waf-output/
```

### 5. View Results

```powershell
# Open HTML report in browser
$latestReport = Get-ChildItem ./waf-output/*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Start-Process $latestReport.FullName
```

---

## 📊 Common Usage Patterns

### Scan Multiple Subscriptions

```powershell
# Get all your subscriptions
$subs = Get-AzSubscription | Select-Object -ExpandProperty Id

# Scan all in parallel
pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions $subs -Parallel -MaxParallelism 5 -EmitHtml
```

### Focus on Specific Pillars

```powershell
# Only scan Security and Reliability
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedPillars @('CostOptimization', 'PerformanceEfficiency', 'OperationalExcellence') `
    -EmitHtml
```

### Cost Optimization Focus

```powershell
# Only cost checks with CSV export
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedPillars @('Security', 'Reliability', 'PerformanceEfficiency', 'OperationalExcellence') `
    -EmitHtml `
    -EmitCsv
```

### Security Audit

```powershell
# Security checks only
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedPillars @('CostOptimization', 'Reliability', 'PerformanceEfficiency', 'OperationalExcellence') `
    -EmitHtml
```

### Track Progress Over Time

```powershell
# First scan - create baseline
pwsh ./run/Invoke-WafLocal.ps1 -EmitJson
Copy-Item ./waf-output/*.json ./baseline.json

# Later scans - compare with baseline
pwsh ./run/Invoke-WafLocal.ps1 -BaselineFile ./baseline.json -EmitHtml

# The HTML report will show:
# - New failures since baseline
# - Improvements since baseline  
# - Unchanged items
```

---

## ⚙️ Configuration

### Create Custom Configuration

```powershell
# Copy default config
Copy-Item ./config/config.json ./config/custom-config.json

# Edit as needed
code ./config/custom-config.json

# Use custom config
pwsh ./run/Invoke-WafLocal.ps1 -ConfigFile ./config/custom-config.json -EmitHtml
```

### Exclude Specific Checks

```json
{
  "excludedChecks": ["RE01", "SE05", "CO03"],
  "excludedPillars": []
}
```

### Exclude Resources by Tags

```json
{
  "resourceFilters": {
    "excludeTags": [
      "Environment=Dev",
      "Temporary=True",
      "WAF-Exempt=True"
    ]
  }
}
```

---

## 🎯 Understanding Results

### Compliance Scores

- **Pass**: Resource meets WAF best practices ✅
- **Fail**: Resource does not meet requirements ❌
- **Warning**: Potential issue, review recommended ⚠️
- **N/A**: Check not applicable to this subscription
- **Error**: Check failed to execute (permissions/timeout)

### Severity Levels

- **Critical**: Immediate action required (security/data loss risk)
- **High**: Address within 30 days (significant impact)
- **Medium**: Address within 90 days (best practice violation)
- **Low**: Nice to have (minor optimization)

### Remediation Effort

- **Low**: < 1 hour, automated scripts available
- **Medium**: 1-8 hours, some manual work required
- **High**: > 8 hours, complex changes needed

---

## 🛠️ Troubleshooting

### "Module not found" Error

```powershell
# Install missing module
Install-Module Az.ResourceGraph -Scope CurrentUser -Force
```

### "Access Denied" Error

```powershell
# Check your permissions
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# Required roles:
# - Reader (for resource inventory)
# - Security Reader (for Defender insights)
# - Cost Management Reader (for cost data)
```

### Checks Timing Out

```powershell
# Increase timeout (default is 300 seconds)
pwsh ./run/Invoke-WafLocal.ps1 -TimeoutSeconds 600 -EmitHtml
```

### Throttling Errors

```powershell
# Reduce parallelism
pwsh ./run/Invoke-WafLocal.ps1 -Parallel -MaxParallelism 3 -EmitHtml

# Or enable caching (in config.json)
{
  "caching": {
    "enabled": true,
    "durationMinutes": 60
  }
}
```

---

## 📈 Scheduled Scans

### Windows Task Scheduler

```powershell
# Create scheduled task to run weekly
$action = New-ScheduledTaskAction -Execute 'pwsh' `
    -Argument '-File "C:\Azure-WAF-Scanner\run\Invoke-WafLocal.ps1" -EmitHtml'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am

Register-ScheduledTask -TaskName "Azure WAF Scan" `
    -Action $action `
    -Trigger $trigger `
    -Description "Weekly Azure WAF compliance scan"
```

### Linux Cron

```bash
# Add to crontab (run every Monday at 6am)
0 6 * * 1 /usr/bin/pwsh /opt/Azure-WAF-Scanner/run/Invoke-WafLocal.ps1 -EmitHtml
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  schedules:
  - cron: "0 6 * * 1"  # Every Monday at 6am
    displayName: Weekly WAF Scan
    branches:
      include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'FilePath'
    scriptPath: './run/Invoke-WafLocal.ps1'
    scriptArguments: '-EmitHtml -EmitCsv'
    azurePowerShellVersion: 'LatestVersion'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: './waf-output'
    artifactName: 'waf-reports'
```

---

## 🎓 Next Steps

1. **Review HTML Report**: Open the generated HTML report and review findings
2. **Prioritize Actions**: Focus on Critical and High severity failures first
3. **Quick Wins**: Implement Low effort fixes for immediate improvement
4. **Create Baseline**: Save first scan as baseline for tracking progress
5. **Schedule Regular Scans**: Set up weekly/monthly automated scans
6. **Customize Checks**: Add custom checks for your organization's requirements

---

## 📚 Additional Resources

- [Full README](./README.md) - Comprehensive documentation
- [Development Guide](./docs/Development.md) - Creating custom checks
- [Troubleshooting Guide](./docs/Troubleshooting.md) - Common issues and solutions
- [Microsoft WAF Documentation](https://learn.microsoft.com/azure/architecture/framework/)

---

## 💬 Getting Help

- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions and share tips
- **Documentation**: Check docs/ folder for detailed guides

---

**Happy Scanning! 🎉**
