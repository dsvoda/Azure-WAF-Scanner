<#
.SYNOPSIS
    RE:01 - Simplify and optimize

.DESCRIPTION
    Validates that the workload design minimizes unnecessary complexity and 
    optimizes for simplicity to reduce failure points and operational overhead.

.NOTES
    Pillar: Reliability
    Recommendation: RE:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/simplify
#>

Register-WafCheck -CheckId 'RE01' `
    -Pillar 'Reliability' `
    -Title 'Simplify and optimize the workload design' `
    -Description 'Assess the workload design to identify and eliminate unnecessary complexity that can cause problems and increase operational overhead' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'Simplification', 'Optimization', 'Complexity') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/simplify' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess complexity indicators across the subscription
            
            # 1. Resource type diversity (more types = more complexity)
            $resourceTypesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize 
    TotalResources = count(),
    UniqueTypes = dcount(type),
    UniqueLocations = dcount(location),
    ResourceGroups = dcount(resourceGroup)
"@
            $complexity = Invoke-AzResourceGraphQuery -Query $resourceTypesQuery -SubscriptionId $SubscriptionId -UseCache
            
            # 2. Check for orphaned/unused resources
            $orphanedDisksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/disks'
| where managedBy == ''
| summarize OrphanedDisks = count()
"@
            $orphanedDisks = Invoke-AzResourceGraphQuery -Query $orphanedDisksQuery -SubscriptionId $SubscriptionId -UseCache
            
            $orphanedNicsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/networkinterfaces'
| where properties.virtualMachine == ''
| summarize OrphanedNics = count()
"@
            $orphanedNics = Invoke-AzResourceGraphQuery -Query $orphanedNicsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $orphanedPipsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/publicipaddresses'
| where properties.ipConfiguration == ''
| summarize OrphanedPips = count()
"@
            $orphanedPips = Invoke-AzResourceGraphQuery -Query $orphanedPipsQuery -SubscriptionId $SubscriptionId -UseCache
            
            # 3. Check for empty resource groups
            $emptyRgQuery = @"
ResourceContainers
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| project rgName = name, rgId = id
| join kind=leftouter (
    Resources
    | where subscriptionId == '$SubscriptionId'
    | summarize ResourceCount = count() by resourceGroup
) on `$left.rgName == `$right.resourceGroup
| where ResourceCount == 0 or isnull(ResourceCount)
| summarize EmptyResourceGroups = count()
"@
            $emptyRgs = Invoke-AzResourceGraphQuery -Query $emptyRgQuery -SubscriptionId $SubscriptionId -UseCache
            
            # 4. Check for Azure Advisor simplification recommendations
            $advisorRecs = Get-AzAdvisorRecommendation -Category Cost, OperationalExcellence -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $_.ShortDescription.Problem -match 'unused|underutilized|consolidate|simplify|optimize' 
                }
            
            # 5. Check for deployment complexity (custom scripts vs managed services)
            $customVmsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| summarize VirtualMachines = count()
"@
            $vms = Invoke-AzResourceGraphQuery -Query $customVmsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $managedServicesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ (
    'microsoft.web/sites',
    'microsoft.containerinstance/containergroups',
    'microsoft.containerservice/managedclusters',
    'microsoft.sql/servers/databases',
    'microsoft.dbforpostgresql/servers',
    'microsoft.dbformysql/servers',
    'microsoft.storage/storageaccounts'
)
| summarize ManagedServices = count()
"@
            $managedServices = Invoke-AzResourceGraphQuery -Query $managedServicesQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Calculate complexity score
            $totalResources = $complexity[0].TotalResources
            $uniqueTypes = $complexity[0].UniqueTypes
            $uniqueLocations = $complexity[0].UniqueLocations
            $resourceGroups = $complexity[0].ResourceGroups
            
            $orphanedTotal = $orphanedDisks[0].OrphanedDisks + 
                           $orphanedNics[0].OrphanedNics + 
                           $orphanedPips[0].OrphanedPips
            
            $emptyRgCount = if ($emptyRgs.Count -gt 0) { $emptyRgs[0].EmptyResourceGroups } else { 0 }
            
            $vmCount = if ($vms.Count -gt 0) { $vms[0].VirtualMachines } else { 0 }
            $managedCount = if ($managedServices.Count -gt 0) { $managedServices[0].ManagedServices } else { 0 }
            
            # Complexity indicators
            $complexityIssues = @()
            
            if ($orphanedTotal -gt 5) {
                $complexityIssues += "High number of orphaned resources ($orphanedTotal)"
            }
            
            if ($emptyRgCount -gt 2) {
                $complexityIssues += "Multiple empty resource groups ($emptyRgCount)"
            }
            
            if ($uniqueTypes -gt 20 -and $totalResources -lt 100) {
                $complexityIssues += "High resource type diversity ($uniqueTypes types for $totalResources resources)"
            }
            
            if ($uniqueLocations -gt 3) {
                $complexityIssues += "Resources spread across many regions ($uniqueLocations locations)"
            }
            
            if ($vmCount -gt $managedCount -and $managedCount -gt 0) {
                $complexityIssues += "More VMs ($vmCount) than managed services ($managedCount) - consider PaaS migration"
            }
            
            if ($advisorRecs.Count -gt 5) {
                $complexityIssues += "$($advisorRecs.Count) Advisor recommendations for optimization"
            }
            
            $evidence = @"
Complexity Assessment:
- Total Resources: $totalResources
- Unique Resource Types: $uniqueTypes
- Locations: $uniqueLocations
- Resource Groups: $resourceGroups
- Orphaned Resources: $orphanedTotal (Disks: $($orphanedDisks[0].OrphanedDisks), NICs: $($orphanedNics[0].OrphanedNics), PIPs: $($orphanedPips[0].OrphanedPips))
- Empty Resource Groups: $emptyRgCount
- Virtual Machines: $vmCount
- Managed Services: $managedCount
- Advisor Optimization Recommendations: $($advisorRecs.Count)
"@
            
            # Determine status
            if ($complexityIssues.Count -eq 0) {
                return New-WafResult -CheckId 'RE01' `
                    -Status 'Pass' `
                    -Message 'Workload design shows good simplification practices with minimal complexity indicators' `
                    -Metadata @{
                        TotalResources = $totalResources
                        UniqueTypes = $uniqueTypes
                        OrphanedResources = $orphanedTotal
                        EmptyResourceGroups = $emptyRgCount
                        VirtualMachines = $vmCount
                        ManagedServices = $managedCount
                        ComplexityScore = 'Low'
                    }
                    
            } elseif ($complexityIssues.Count -le 2) {
                return New-WafResult -CheckId 'RE01' `
                    -Status 'Warning' `
                    -Message "Workload has moderate complexity with $($complexityIssues.Count) simplification opportunities identified" `
                    -Recommendation @"
Address the following complexity issues:

$($complexityIssues | ForEach-Object { "• $_" } | Out-String)

## Simplification Recommendations:

### 1. Remove Unused Resources
- Clean up orphaned disks, NICs, and public IPs
- Delete empty resource groups
- Review and decommission unused VMs

### 2. Consolidate Resource Types
- Evaluate if multiple resource types serve similar purposes
- Consider using fewer, more capable services
- Standardize on preferred service types

### 3. Optimize Geographic Distribution
- Consolidate resources to fewer regions where possible
- Use Azure Front Door or Traffic Manager for multi-region instead of duplicating everything
- Keep resources close to users/data

### 4. Migrate to Managed Services
- Replace IaaS VMs with PaaS offerings where possible:
  - VMs → App Service, Container Apps, or AKS
  - SQL on VMs → Azure SQL Database
  - File servers → Azure Files or NetApp Files

### 5. Apply Azure Advisor Recommendations
- Review and implement Advisor suggestions for cost and operational excellence
- Set up regular reviews of Advisor recommendations

$evidence
"@ `
                    -RemediationScript @"
# Cleanup orphaned resources

# 1. Remove orphaned managed disks
`$orphanedDisks = Get-AzDisk | Where-Object { `$_.ManagedBy -eq `$null }
Write-Host "Found `$(`$orphanedDisks.Count) orphaned disks"

# Review before deletion!
`$orphanedDisks | Select-Object Name, ResourceGroupName, DiskSizeGB, @{N='MonthlyCost';E={`$_.DiskSizeGB * 0.05}} | Format-Table

# Uncomment to delete after review:
# `$orphanedDisks | Remove-AzDisk -Force

# 2. Remove orphaned NICs
`$orphanedNics = Get-AzNetworkInterface | Where-Object { `$_.VirtualMachine -eq `$null }
Write-Host "Found `$(`$orphanedNics.Count) orphaned NICs"

# Uncomment to delete:
# `$orphanedNics | Remove-AzNetworkInterface -Force

# 3. Remove unassociated public IPs
`$orphanedPips = Get-AzPublicIpAddress | Where-Object { `$_.IpConfiguration -eq `$null }
Write-Host "Found `$(`$orphanedPips.Count) orphaned public IPs"

# Uncomment to delete:
# `$orphanedPips | Remove-AzPublicIpAddress -Force

# 4. List empty resource groups
`$allRgs = Get-AzResourceGroup
`$emptyRgs = `$allRgs | Where-Object {
    `$resources = Get-AzResource -ResourceGroupName `$_.ResourceGroupName
    `$resources.Count -eq 0
}

Write-Host "Found `$(`$emptyRgs.Count) empty resource groups:"
`$emptyRgs | Select-Object ResourceGroupName, Location | Format-Table

# Uncomment to delete:
# `$emptyRgs | Remove-AzResourceGroup -Force

# 5. Export simplification analysis
@{
    AnalysisDate = Get-Date
    OrphanedDisks = `$orphanedDisks.Count
    OrphanedNICs = `$orphanedNics.Count
    OrphanedPIPs = `$orphanedPips.Count
    EmptyResourceGroups = `$emptyRgs.Count
    EstimatedMonthlySavings = (`$orphanedDisks | Measure-Object -Property DiskSizeGB -Sum).Sum * 0.05
} | ConvertTo-Json | Out-File 'simplification-analysis.json'

Write-Host "`nSimplification analysis saved to simplification-analysis.json"
Write-Host "Review the identified resources before deletion!"
"@
                    
            } else {
                return New-WafResult -CheckId 'RE01' `
                    -Status 'Fail' `
                    -Message "Workload has significant complexity with $($complexityIssues.Count) issues requiring simplification" `
                    -Recommendation @"
**CRITICAL**: High workload complexity increases failure risk and operational overhead.

Issues identified:
$($complexityIssues | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Remove Waste (Week 1)
1. **Delete orphaned resources** ($orphanedTotal total):
   - $($orphanedDisks[0].OrphanedDisks) unattached disks
   - $($orphanedNics[0].OrphanedNics) unused network interfaces
   - $($orphanedPips[0].OrphanedPips) unassociated public IPs
   
2. **Clean up empty resource groups** ($emptyRgCount groups)

3. **Review Advisor recommendations** ($($advisorRecs.Count) suggestions)

### Phase 2: Consolidate (Weeks 2-4)
1. **Reduce resource type diversity**:
   - Current: $uniqueTypes different resource types
   - Target: < 15 core types
   - Consolidate redundant services

2. **Optimize geographic distribution**:
   - Current: $uniqueLocations regions
   - Evaluate if all regions are necessary
   - Use global load balancing instead of full duplication

3. **Standardize resource organization**:
   - Current: $resourceGroups resource groups for $totalResources resources
   - Group by lifecycle and ownership
   - Use consistent naming conventions

### Phase 3: Modernize (Months 2-3)
1. **Migrate IaaS to PaaS**:
   - Current: $vmCount VMs vs $managedCount managed services
   - Target: Maximize managed service usage
   - Benefits: Reduced patching, built-in HA, lower complexity

2. **Implement Infrastructure as Code**:
   - Enforce standard architectures
   - Prevent configuration drift
   - Enable automated deployments

3. **Establish Governance**:
   - Azure Policy to prevent complexity growth
   - Required tags for ownership/purpose
   - Regular complexity audits

## Example Migration Path:
- Web apps on VMs → Azure App Service
- Databases on VMs → Azure SQL Database
- File servers → Azure Files
- Custom load balancers → Azure Load Balancer/App Gateway

$evidence
"@ `
                    -RemediationScript @"
# Comprehensive Simplification Script

# Configuration
`$WhatIf = `$true  # Set to `$false to actually delete resources
`$ReportPath = './simplification-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json'

# Initialize report
`$report = @{
    AnalysisDate = Get-Date
    Subscription = (Get-AzContext).Subscription.Name
    Actions = @()
    Savings = @{
        Storage = 0
        Compute = 0
        Network = 0
    }
}

Write-Host "=== Azure Simplification Analysis ===" -ForegroundColor Cyan
Write-Host "WhatIf Mode: `$WhatIf`n" -ForegroundColor Yellow

# 1. Orphaned Disks
Write-Host "[1/5] Analyzing orphaned disks..." -ForegroundColor Cyan
`$orphanedDisks = Get-AzDisk | Where-Object { `$_.ManagedBy -eq `$null }
`$diskCost = (`$orphanedDisks | Measure-Object -Property DiskSizeGB -Sum).Sum * 0.05

if (`$orphanedDisks.Count -gt 0) {
    `$orphanedDisks | Select-Object Name, ResourceGroupName, DiskSizeGB, 
        @{N='MonthlyCost';E={`$_.DiskSizeGB * 0.05}} | Format-Table
    
    `$report.Actions += @{
        Type = 'OrphanedDisks'
        Count = `$orphanedDisks.Count
        MonthlySavings = `$diskCost
    }
    `$report.Savings.Storage += `$diskCost
    
    if (-not `$WhatIf) {
        `$orphanedDisks | Remove-AzDisk -Force
        Write-Host "Deleted `$(`$orphanedDisks.Count) orphaned disks" -ForegroundColor Green
    }
}

# 2. Orphaned NICs
Write-Host "`n[2/5] Analyzing orphaned network interfaces..." -ForegroundColor Cyan
`$orphanedNics = Get-AzNetworkInterface | Where-Object { `$_.VirtualMachine -eq `$null }

if (`$orphanedNics.Count -gt 0) {
    `$orphanedNics | Select-Object Name, ResourceGroupName, Location | Format-Table
    
    `$report.Actions += @{
        Type = 'OrphanedNICs'
        Count = `$orphanedNics.Count
        MonthlySavings = `$orphanedNics.Count * 0.50
    }
    `$report.Savings.Network += `$orphanedNics.Count * 0.50
    
    if (-not `$WhatIf) {
        `$orphanedNics | Remove-AzNetworkInterface -Force
    }
}

# 3. Orphaned Public IPs
Write-Host "`n[3/5] Analyzing unassociated public IPs..." -ForegroundColor Cyan
`$orphanedPips = Get-AzPublicIpAddress | Where-Object { `$_.IpConfiguration -eq `$null }

if (`$orphanedPips.Count -gt 0) {
    `$orphanedPips | Select-Object Name, ResourceGroupName, PublicIpAllocationMethod | Format-Table
    
    `$pipCost = (`$orphanedPips | Where-Object PublicIpAllocationMethod -eq 'Static').Count * 3.65
    `$report.Actions += @{
        Type = 'OrphanedPublicIPs'
        Count = `$orphanedPips.Count
        MonthlySavings = `$pipCost
    }
    `$report.Savings.Network += `$pipCost
    
    if (-not `$WhatIf) {
        `$orphanedPips | Remove-AzPublicIpAddress -Force
    }
}

# 4. Empty Resource Groups
Write-Host "`n[4/5] Analyzing empty resource groups..." -ForegroundColor Cyan
`$allRgs = Get-AzResourceGroup
`$emptyRgs = @()

foreach (`$rg in `$allRgs) {
    `$resources = Get-AzResource -ResourceGroupName `$rg.ResourceGroupName
    if (`$resources.Count -eq 0) {
        `$emptyRgs += `$rg
    }
}

if (`$emptyRgs.Count -gt 0) {
    `$emptyRgs | Select-Object ResourceGroupName, Location | Format-Table
    
    `$report.Actions += @{
        Type = 'EmptyResourceGroups'
        Count = `$emptyRgs.Count
    }
    
    if (-not `$WhatIf) {
        `$emptyRgs | Remove-AzResourceGroup -Force
    }
}

# 5. PaaS Migration Opportunities
Write-Host "`n[5/5] Identifying PaaS migration opportunities..." -ForegroundColor Cyan
`$vms = Get-AzVM
`$webVms = `$vms | Where-Object { `$_.Tags.Role -match 'web|app' }
`$dbVms = `$vms | Where-Object { `$_.Tags.Role -match 'database|sql' }

Write-Host "`nPotential migrations:"
if (`$webVms.Count -gt 0) {
    Write-Host "  • `$(`$webVms.Count) web/app VMs → Azure App Service" -ForegroundColor Yellow
}
if (`$dbVms.Count -gt 0) {
    Write-Host "  • `$(`$dbVms.Count) database VMs → Azure SQL Database" -ForegroundColor Yellow
}

# Generate report
`$report.TotalMonthlySavings = `$report.Savings.Storage + `$report.Savings.Compute + `$report.Savings.Network

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total monthly savings: `$`$(`$report.TotalMonthlySavings.ToString('F2'))" -ForegroundColor Green
Write-Host "Report saved to: `$ReportPath" -ForegroundColor Gray

`$report | ConvertTo-Json -Depth 10 | Out-File `$ReportPath

if (`$WhatIf) {
    Write-Host "`nTo execute these changes, set `$WhatIf = `$false" -ForegroundColor Yellow
}
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE01' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
