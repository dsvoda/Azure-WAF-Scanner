# Example WAF Check: Cost Optimization - Unattached Disks
# Path: modules/Pillars/CostOptimization/COST-001/Invoke.ps1

<#
.SYNOPSIS
    Identifies unattached managed disks that are incurring costs.

.DESCRIPTION
    Finds managed disks that are not attached to any VM and have been in
    that state for an extended period, representing potential cost savings.
#>

Register-WafCheck -CheckId 'COST-001' `
    -Pillar 'CostOptimization' `
    -Title 'Remove or attach unattached managed disks' `
    -Description 'Identifies managed disks not attached to VMs that are generating unnecessary costs' `
    -Severity 'Medium' `
    -RemediationEffort 'Low' `
    -Tags @('ManagedDisks', 'CostOptimization', 'Waste') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/virtual-machines/disks-find-unattached' `
    -ComplianceFramework 'FinOps' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        $query = @"
Resources
| where type == 'microsoft.compute/disks'
| where subscriptionId == '$SubscriptionId'
| where properties.diskState == 'Unattached'
| extend diskSizeGB = toint(properties.diskSizeGB)
| extend diskTier = tostring(sku.name)
| extend diskType = case(
    diskTier contains 'Premium', 'Premium SSD',
    diskTier contains 'StandardSSD', 'Standard SSD',
    diskTier contains 'UltraSSD', 'Ultra SSD',
    'Standard HDD'
)
| project id, name, location, resourceGroup, diskSizeGB, diskTier, diskType, 
    createdTime = tostring(properties.timeCreated)
"@
        
        try {
            $unattachedDisks = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
            
            if (!$unattachedDisks -or $unattachedDisks.Count -eq 0) {
                return New-WafResult -CheckId 'COST-001' `
                    -Status 'Pass' `
                    -Message 'No unattached managed disks found'
            }
            
            # Calculate estimated monthly cost (approximate)
            $estimatedMonthlyCost = 0
            $costByDisk = @{}
            
            foreach ($disk in $unattachedDisks) {
                $monthlyCostPerGB = switch ($disk.diskType) {
                    'Premium SSD' { 0.135 }  # Approximate cost per GB
                    'Standard SSD' { 0.075 }
                    'Ultra SSD' { 0.12 }
                    default { 0.04 }  # Standard HDD
                }
                
                $diskCost = $disk.diskSizeGB * $monthlyCostPerGB
                $estimatedMonthlyCost += $diskCost
                $costByDisk[$disk.id] = $diskCost
            }
            
            $affectedResourceIds = $unattachedDisks | ForEach-Object { $_.id }
            
            # Group by disk type for summary
            $disksByType = $unattachedDisks | Group-Object diskType
            $summaryByType = $disksByType | ForEach-Object {
                $totalSize = ($_.Group | Measure-Object -Property diskSizeGB -Sum).Sum
                "$($_.Count) x $($_.Name) ($totalSize GB)"
            }
            
            $recommendation = @"
Review and remove unattached disks to optimize costs:

1. Verify disks are truly unneeded (check creation date, tags, backups)
2. Take snapshots of important disks before deletion
3. Delete unattached disks that are no longer required
4. Implement automated alerts for long-running unattached disks

Summary:
- Total unattached disks: $($unattachedDisks.Count)
- Breakdown: $($summaryByType -join ', ')
- Estimated monthly waste: `$$($estimatedMonthlyCost.ToString('F2'))
- Annual potential savings: `$$($($estimatedMonthlyCost * 12).ToString('F2'))

Important: Verify disks are not part of disaster recovery plans before deletion.
"@
            
            $remediationScript = @"
# Review and remove unattached managed disks

# List all unattached disks
`$unattachedDisks = Get-AzDisk | Where-Object { `$_.ManagedBy -eq `$null }

foreach (`$disk in `$unattachedDisks) {
    Write-Host "Disk: `$(`$disk.Name)"
    Write-Host "  Resource Group: `$(`$disk.ResourceGroupName)"
    Write-Host "  Size: `$(`$disk.DiskSizeGB) GB"
    Write-Host "  Tier: `$(`$disk.Sku.Name)"
    Write-Host "  Created: `$(`$disk.TimeCreated)"
    Write-Host ""
    
    # OPTION 1: Create snapshot before deletion (recommended)
    `$snapshotConfig = New-AzSnapshotConfig ``
        -SourceUri `$disk.Id ``
        -Location `$disk.Location ``
        -CreateOption Copy
    
    `$snapshotName = "`$(`$disk.Name)-snapshot-`$(Get-Date -Format 'yyyyMMdd')"
    
    # Uncomment to create snapshot
    # New-AzSnapshot -Snapshot `$snapshotConfig -SnapshotName `$snapshotName -ResourceGroupName `$disk.ResourceGroupName
    
    # OPTION 2: Delete disk (after verification)
    # Remove-AzDisk -ResourceGroupName `$disk.ResourceGroupName -DiskName `$disk.Name -Force
}

# OPTION 3: Set up alert for unattached disks older than 30 days
# This can be done via Azure Monitor alerts
"@
            
            # Determine severity based on cost
            $severity = if ($estimatedMonthlyCost -gt 500) { 'High' }
                        elseif ($estimatedMonthlyCost -gt 100) { 'Medium' }
                        else { 'Low' }
            
            return New-WafResult -CheckId 'COST-001' `
                -Status 'Fail' `
                -Message "Found $($unattachedDisks.Count) unattached managed disks wasting ~`$$($estimatedMonthlyCost.ToString('F2'))/month" `
                -AffectedResources $affectedResourceIds `
                -Recommendation $recommendation `
                -RemediationScript $remediationScript `
                -Metadata @{
                    TotalDisks = $unattachedDisks.Count
                    TotalSizeGB = ($unattachedDisks | Measure-Object -Property diskSizeGB -Sum).Sum
                    EstimatedMonthlyCost = $estimatedMonthlyCost
                    EstimatedAnnualSavings = $estimatedMonthlyCost * 12
                    DisksByType = $disksByType | Select-Object Name, Count
                    TopCostlyDisks = ($unattachedDisks | Sort-Object { $costByDisk[$_.id] } -Descending | Select-Object -First 5 | ForEach-Object { "$($_.name) (`$$($costByDisk[$_.id].ToString('F2'))/mo)" })
                }
                
        } catch {
            return New-WafResult -CheckId 'COST-001' `
                -Status 'Error' `
                -Message "Failed to execute check: $_"
        }
    }
```
