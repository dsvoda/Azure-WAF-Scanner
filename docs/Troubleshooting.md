# Troubleshooting Guide

## Common Issues and Solutions

### Installation and Setup Issues

#### Issue: "Module Az.* not found"
**Symptoms:**
```
Import-Module: The specified module 'Az.Resources' was not loaded because no valid module file was found
```

**Solution:**
```powershell
# Install required modules
Install-Module Az -Scope CurrentUser -Force -AllowClobber

# Or install specific modules
$modules = @('Az.Accounts', 'Az.Resources', 'Az.ResourceGraph', 'Az.Advisor', 'Az.Security', 'Az.PolicyInsights')
foreach ($module in $modules) {
    Install-Module $module -Scope CurrentUser -Force -AllowClobber
}

# Verify installation
Get-Module Az.* -ListAvailable
```

---

#### Issue: "PowerShell version too old"
**Symptoms:**
```
#Requires -Version 7.0
The script cannot be run because it requires PowerShell version 7.0 or higher
```

**Solution:**
1. Download PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases
2. Install for your platform (Windows/Linux/macOS)
3. Verify: `pwsh --version`
4. Run scanner with: `pwsh ./run/Invoke-WafLocal.ps1`

---

### Authentication Issues

#### Issue: "Not authenticated to Azure"
**Symptoms:**
```
Get-AzContext: Run Connect-AzAccount to login
```

**Solution:**
```powershell
# Interactive login
Connect-AzAccount

# Login with service principal
$credentials = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant 'tenant-id'

# Login with managed identity (from Azure VM/Container)
Connect-AzAccount -Identity

# Verify connection
Get-AzContext
```

---

#### Issue: "Access Denied" errors during scan
**Symptoms:**
```
AuthorizationFailed: The client 'user@domain.com' does not have authorization to perform action 'Microsoft.Resources/subscriptions/resources/read'
```

**Solution:**
```powershell
# Check your current role assignments
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id

# Required minimum roles per subscription:
# - Reader (for resource inventory)
# - Security Reader (for Defender insights)
# - Cost Management Reader (for cost data)

# Request access from subscription owner:
# Owner needs to run:
$userEmail = "user@domain.com"
$subscriptionId = "sub-id"

New-AzRoleAssignment `
    -SignInName $userEmail `
    -RoleDefinitionName "Reader" `
    -Scope "/subscriptions/$subscriptionId"

New-AzRoleAssignment `
    -SignInName $userEmail `
    -RoleDefinitionName "Security Reader" `
    -Scope "/subscriptions/$subscriptionId"
```

---

### Performance Issues

#### Issue: "Scan takes too long"
**Symptoms:**
- Scan runs for hours
- Individual checks timeout
- No progress updates

**Solution:**
```powershell
# Enable parallel processing
pwsh ./run/Invoke-WafLocal.ps1 -Parallel -MaxParallelism 10 -EmitHtml

# Enable caching (in config.json)
{
  "caching": {
    "enabled": true,
    "durationMinutes": 60
  }
}

# Exclude unnecessary checks
pwsh ./run/Invoke-WafLocal.ps1 -ExcludedPillars @('Performance') -EmitHtml

# Increase timeout for slow checks
pwsh ./run/Invoke-WafLocal.ps1 -TimeoutSeconds 600 -EmitHtml

# Use dry run to estimate time
pwsh ./run/Invoke-WafLocal.ps1 -DryRun
```

---

#### Issue: "Resource Graph queries timing out"
**Symptoms:**
```
Search-AzGraph: Gateway timeout. The request took too long to complete
```

**Solution:**
```powershell
# Option 1: Reduce query scope
# Edit your check to query fewer resources at once

# Option 2: Use pagination properly
$query = "Resources | where type == 'microsoft.compute/virtualmachines'"
$allResults = @()
$skipToken = $null

do {
    $params = @{
        Query = $query
        First = 1000
    }
    if ($skipToken) { $params.SkipToken = $skipToken }
    
    $result = Search-AzGraph @params
    $allResults += $result.Data
    $skipToken = $result.SkipToken
} while ($skipToken)

# Option 3: Add summarization in KQL
$query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| summarize count() by location, sku
"@  # Much faster than returning all VMs
```

---

#### Issue: "API throttling errors (429)"
**Symptoms:**
```
TooManyRequests: The request was throttled. Please retry after 30 seconds
```

**Solution:**
```powershell
# Solution is built into scanner - retry logic handles this automatically
# But you can tune it:

# In config.json:
{
  "retryPolicy": {
    "maxAttempts": 5,
    "delaySeconds": 5,
    "exponentialBackoff": true
  },
  "performance": {
    "maxParallelism": 3  # Reduce parallelism
  }
}

# Or via command line:
pwsh ./run/Invoke-WafLocal.ps1 -MaxParallelism 3 -RetryAttempts 5 -EmitHtml

# Enable caching to reduce API calls:
{
  "caching": {
    "enabled": true,
    "durationMinutes": 60
  }
}
```

---

### Output Issues

#### Issue: "HTML report not generating"
**Symptoms:**
- JSON and CSV created but no HTML
- Error about missing templates

**Solution:**
```powershell
# Verify report assets exist
Test-Path ./report-assets/templates/enhanced.html
Test-Path ./report-assets/styles/enhanced.css

# If missing, check git submodules or re-clone repository

# Generate with verbose output to see errors
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml -Verbose

# Check for JavaScript errors in HTML (open browser console)
```

---

#### Issue: "Charts not displaying in HTML report"
**Symptoms:**
- HTML opens but charts are blank
- Browser console shows CDN errors

**Solution:**
```html
<!-- The scanner uses Chart.js from CDN -->
<!-- If offline or CDN blocked, download Chart.js locally -->

<!-- Edit report-assets/templates/enhanced.html -->
<!-- Change this: -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"></script>

<!-- To local file: -->
<script src="./chart.min.js"></script>

<!-- Download Chart.js to report output directory -->
```

---

#### Issue: "Word document (DOCX) export failing"
**Symptoms:**
```
Module PSWriteWord not found
```

**Solution:**
```powershell
# Install PSWriteWord module
Install-Module PSWriteWord -Scope CurrentUser -Force

# Note: PSWriteWord is outdated (last update 2019)
# Consider using HTML or PDF export instead

# Generate HTML and convert to PDF with browser:
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml
# Open HTML in browser and print to PDF (Ctrl+P)
```

---

### Check Execution Issues

#### Issue: "Check returns Error status"
**Symptoms:**
```json
{
  "CheckId": "REL-001",
  "Status": "Error",
  "Message": "Check execution failed: ..."
}
```

**Solution:**
```powershell
# Test the specific check manually
Import-Module ./modules/WafScanner.psm1 -Force
. ./modules/Pillars/Reliability/REL-001/Invoke.ps1

# Execute with error details
$ErrorActionPreference = 'Continue'
$check = $script:CheckRegistry | Where-Object CheckId -eq 'REL-001'
try {
    $result = & $check.ScriptBlock -SubscriptionId 'your-sub-id'
    $result | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

# Common causes:
# 1. Malformed Resource Graph query
# 2. Missing required permissions
# 3. Null reference in PowerShell code
# 4. API changes in Azure
```

---

#### Issue: "Check always returns N/A"
**Symptoms:**
- Check finds no resources when you know they exist
- Query returns empty results

**Solution:**
```powershell
# Test the query directly
$query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| where subscriptionId == 'your-sub-id'
"@

$result = Search-AzGraph -Query $query
$result.Data | Format-Table

# Common causes:
# 1. Wrong resource type string
# 2. Wrong subscription ID
# 3. Case-sensitive filtering
# 4. Resources in different regions not queried

# Fix: Use correct type strings (all lowercase)
# Find correct type:
Search-AzGraph -Query "Resources | distinct type | sort by type asc"
```

---

### Configuration Issues

#### Issue: "Config file not being loaded"
**Symptoms:**
- Checks that should be excluded are still running
- Custom thresholds not applied

**Solution:**
```powershell
# Verify config file path
Test-Path ./config.json

# Validate JSON syntax
Get-Content ./config.json | ConvertFrom-Json

# Specify config explicitly
pwsh ./run/Invoke-WafLocal.ps1 -ConfigFile "./config.json" -EmitHtml -Verbose

# Check for BOM or encoding issues
[System.IO.File]::ReadAllLines("./config.json")

# Common mistakes in config.json:
# 1. Missing commas between properties
# 2. Trailing commas (not allowed in JSON)
# 3. Comments (not allowed in JSON - use config.jsonc if needed)
# 4. Wrong property names (case-sensitive)
```

---

#### Issue: "Excluded checks still running"
**Symptoms:**
- Set excludedChecks in config but they still execute

**Solution:**
```json
// Correct format in config.json:
{
  "excludedChecks": ["REL-001", "SEC-005"],  // Array of strings
  "excludedPillars": ["Performance"]         // Array of strings
}

// Wrong formats:
{
  "excludedChecks": "REL-001",               // ❌ Should be array
  "excludedChecks": ["REL-*"],               // ❌ No wildcards supported
  "excludedPillars": "Performance"           // ❌ Should be array
}
```
```powershell
# Override config via command line:
pwsh ./run/Invoke-WafLocal.ps1 `
    -ExcludedChecks @('REL-001', 'SEC-005') `
    -ExcludedPillars @('Performance') `
    -EmitHtml
```

---

### Data Accuracy Issues

#### Issue: "Baseline comparison shows no changes but I fixed issues"
**Symptoms:**
- Fixed issues but comparison shows unchanged
- New scan looks identical to baseline

**Solution:**
```powershell
# Verify baseline file is correct
Get-Content ./baseline.json | ConvertFrom-Json | Select-Object -First 5

# Ensure you're comparing correct files
pwsh ./run/Invoke-WafLocal.ps1 `
    -BaselineFile "./baseline-2024-10-01.json" `  # Specify correct baseline
    -EmitHtml

# Update baseline after fixes
Copy-Item "./waf-output/latest.json" "./baseline.json"

# Common causes:
# 1. Using wrong baseline file
# 2. Caching old results (disable cache temporarily)
# 3. Comparing different subscriptions
```

---

#### Issue: "False positives in results"
**Symptoms:**
- Check reports failures for compliant resources
- Results don't match Azure portal

**Solution:**
```powershell
# Verify with Azure portal or CLI
az resource show --ids <resource-id-from-report>

# Check Resource Graph query directly
$query = "Resources | where id == '<resource-id>'"
Search-AzGraph -Query $query | ConvertTo-Json -Depth 5

# Common causes:
# 1. Cached data (disable caching)
# 2. Eventual consistency in Azure
# 3. Check logic bug
# 4. Tag-based filters excluding test resources

# Report false positives as issues on GitHub
```

---

### Memory and Resource Issues

#### Issue: "Out of memory errors"
**Symptoms:**
```
OutOfMemoryException: Insufficient memory to continue the execution of the program
```

**Solution:**
```powershell
# Reduce parallelism
pwsh ./run/Invoke-WafLocal.ps1 -MaxParallelism 3 -EmitHtml

# Process subscriptions individually
foreach ($sub in $subscriptions) {
    pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions $sub -EmitHtml
}

# Clear cache periodically
Remove-Item ./waf-output/.cache/* -Force

# Increase available memory (if running in container/VM)
```

---

### Debugging Tips

#### Enable Verbose Logging
```powershell
$VerbosePreference = 'Continue'
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml -Verbose
```

#### Enable Debug Mode
```powershell
$DebugPreference = 'Continue'
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml -Debug
```

#### Capture Full Error Details
```powershell
$ErrorActionPreference = 'Continue'
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml 2>&1 | Tee-Object -FilePath scan-errors.log
```

#### Test Individual Components
```powershell
# Test connection
Get-AzContext

# Test Resource Graph
Search-AzGraph -Query "Resources | take 5"

# Test module import
Import-Module ./modules/WafScanner.psm1 -Force -Verbose

# List registered checks
$script:CheckRegistry | Select-Object CheckId, Pillar, Title | Format-Table
```

---

## FAQ

### General Questions

**Q: How long does a typical scan take?**
A: Depends on subscription size and number of resources:
- Small (< 100 resources): 2-5 minutes
- Medium (100-1000 resources): 5-15 minutes
- Large (1000+ resources): 15-60 minutes
- Parallel processing can reduce time by 50-70%

**Q: Can I scan multiple Azure tenants?**
A: Yes, connect to each tenant separately:
```powershell
# Scan tenant 1
Connect-AzAccount -Tenant 'tenant-1-id'
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml

# Scan tenant 2
Connect-AzAccount -Tenant 'tenant-2-id'
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml
```

**Q: Does the scanner make any changes to my environment?**
A: No! The scanner is read-only. It queries data but never modifies resources. Remediation scripts are provided but must be run manually.

**Q: Can I schedule automated scans?**
A: Yes! Use Azure Automation, GitHub Actions, or cron jobs:
```yaml
# .github/workflows/waf-scan.yml
name: Weekly WAF Scan
on:
  schedule:
    - cron: '0 0 * * 1'  # Every Monday
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v1
      - run: pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml
```

**Q: How do I scan only production subscriptions?**
A: Use naming conventions or tags:
```powershell
$prodSubs = Get-AzSubscription | Where-Object { $_.Name -like "*-prod" }
pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions $prodSubs.Id -EmitHtml
```

**Q: Can I customize the HTML report branding?**
A: Yes! Edit `report-assets/templates/enhanced.html` and `report-assets/styles/enhanced.css` to add your logo, colors, and styling.

**Q: How do I export results to Azure Monitor or Log Analytics?**
A: Parse the JSON output and send to Log Analytics:
```powershell
# After scan completes
$results = Get-Content ./waf-output/latest.json | ConvertFrom-Json

# Send to Log Analytics (requires workspace ID and key)
foreach ($result in $results) {
    # Use Invoke-RestMethod to post to Log Analytics ingestion API
}
```

---

## Getting Help

### Before Opening an Issue
1. Check this troubleshooting guide
2. Search existing GitHub issues
3. Review the documentation
4. Try running with `-Verbose` flag
5. Test with a minimal reproduction case

### Opening a Good Issue
Include:
- Scanner version
- PowerShell version: `$PSVersionTable`
- Azure module versions: `Get-Module Az.* -ListAvailable`
- Operating system
- Error messages (full stack trace)
- Steps to reproduce
- Relevant configuration (sanitized)

### Community Support
- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share tips
- Pull Requests: Contribute improvements

---

## Performance Optimization Checklist

- [ ] Enable caching in config.json
- [ ] Use parallel processing for multiple subscriptions
- [ ] Exclude unnecessary pillars/checks
- [ ] Set appropriate timeout values
- [ ] Run during off-peak hours
- [ ] Use Azure Cloud Shell for better network performance
- [ ] Clean up old cache files periodically
- [ ] Monitor memory usage and adjust parallelism

---

## Security Considerations

**Credential Management:**
- Never commit credentials or subscription IDs to version control
- Use Azure managed identities when possible
- Rotate service principal secrets regularly
- Use Azure Key Vault for sensitive configuration

**Report Sharing:**
- Use `-ObfuscateSensitiveData` when sharing reports externally
- Review reports for sensitive information before sharing
- Consider using private report storage
- Implement access controls on output directories

**Permissions:**
- Follow principle of least privilege
- Use read-only roles only
- Audit scanner usage regularly
- Remove access when no longer needed

---

*Last Updated: October 2025*
```
