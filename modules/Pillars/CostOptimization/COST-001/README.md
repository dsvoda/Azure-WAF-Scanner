# COST-001 - Remove or attach unattached managed disks

## Description
This check identifies Azure Managed Disks that are not attached to any virtual machine and have been in an unattached state, representing unnecessary costs. Unattached disks continue to incur storage charges even when not in use, making them a common source of cloud waste.

## Pillar
Cost Optimization

## Severity
Medium

## Remediation Effort
Low

## Rationale
Unattached managed disks are a common source of unnecessary Azure spending because:

- **Continuous billing**: Disks are billed for their provisioned size regardless of attachment status
- **Forgotten resources**: Often left behind after VM deletion or testing
- **Accumulation over time**: Can grow to significant costs across multiple disks
- **Easy to overlook**: Not immediately visible without specific queries
- **No performance benefit**: Unused disks provide zero value while incurring costs
- **Storage optimization**: Removing unused disks frees up storage quota

Typical scenarios that create unattached disks:
- VMs deleted but disks retained
- Test/development cleanup incomplete
- Disk detached for troubleshooting and forgotten
- Migration projects leaving orphaned resources
- Snapshot restores that create temporary disks

## Compliance Mapping
- **FinOps Framework**: Optimize Cloud Usage and Cost
- **Azure Well-Architected Framework**: Cost Optimization pillar
- **Cloud Governance**: Resource lifecycle management

## Implementation Details

### Resource Types Checked
- `microsoft.compute/disks`

### Query Logic
The check performs the following steps:
1. Queries all managed disks in the subscription using Azure Resource Graph
2. Filters for disks where `properties.diskState == 'Unattached'`
3. Calculates estimated monthly cost based on disk type and size
4. Groups disks by type for summary reporting
5. Identifies top costly disks for prioritization

### Pass Criteria
The check passes if:
- No unattached managed disks exist in the subscription

### Fail Criteria
The check fails if:
- One or more unattached managed disks are found
- Estimated monthly waste exceeds $0.00

## Affected Resources
All managed disks with `diskState` property set to `Unattached`.

## Cost Calculation

### Pricing Estimates (USD/GB/month)
The check uses approximate pricing:
- **Premium SSD**: $0.135/GB
- **Standard SSD**: $0.075/GB
- **Ultra SSD**: $0.12/GB
- **Standard HDD**: $0.04/GB

**Note**: Actual pricing varies by region and may change. Always verify current pricing at [Azure Pricing](https://azure.microsoft.com/pricing/details/managed-disks/).

### Example Cost Impact
```
Scenario 1: Development cleanup
- 5x Premium SSD disks (128 GB each) = 640 GB
- Monthly waste: 640 GB × $0.135 = $86.40
- Annual waste: $1,036.80

Scenario 2: Large environment
- 20x Standard SSD disks (512 GB each) = 10,240 GB
- Monthly waste: 10,240 GB × $0.075 = $768.00
- Annual waste: $9,216.00
```

## Remediation Steps

### Before Taking Action
**⚠️ CRITICAL: Always verify disks are truly unneeded before deletion!**

Check the following before deleting any disk:
1. **Creation date**: Recently created disks may be part of ongoing work
2. **Resource tags**: Check for tags indicating purpose or ownership
3. **Naming conventions**: Understand naming patterns in your organization
4. **Backup status**: Verify disk is not a critical backup
5. **Disaster recovery**: Confirm disk is not part of DR plan
6. **Related resources**: Check for associated snapshots or images

### Option 1: Create Snapshot Before Deletion (Recommended)

This is the safest approach as it allows recovery if needed.
```powershell
# List all unattached disks
$unattachedDisks = Get-AzDisk | Where-Object { $_.ManagedBy -eq $null }

foreach ($disk in $unattachedDisks) {
    Write-Host "Disk: $($disk.Name)" -ForegroundColor Yellow
    Write-Host "  Resource Group: $($disk.ResourceGroupName)"
    Write-Host "  Size: $($disk.DiskSizeGB) GB"
    Write-Host "  SKU: $($disk.Sku.Name)"
    Write-Host "  Created: $($disk.TimeCreated)"
    Write-Host "  Location: $($disk.Location)"
    
    # Create snapshot
    $snapshotConfig = New-AzSnapshotConfig `
        -SourceUri $disk.Id `
        -Location $disk.Location `
        -CreateOption Copy
    
    $snapshotName = "$($disk.Name)-snapshot-$(Get-Date -Format 'yyyyMMdd')"
    
    Write-Host "  Creating snapshot: $snapshotName" -ForegroundColor Green
    
    New-AzSnapshot `
        -Snapshot $snapshotConfig `
        -SnapshotName $snapshotName `
        -ResourceGroupName $disk.ResourceGroupName
    
    Write-Host "  Snapshot created successfully!" -ForegroundColor Green
    Write-Host ""
}

# After verification, delete disks (uncomment when ready)
# foreach ($disk in $unattachedDisks) {
#     Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force
# }
```
```bash
# Using Azure CLI
# List unattached disks
az disk list --query "[?diskState=='Unattached'].{Name:name, ResourceGroup:resourceGroup, Size:diskSizeGb, SKU:sku.name}" -o table

# Create snapshot for each disk
for disk in $(az disk list --query "[?diskState=='Unattached'].name" -o tsv); do
    RG=$(az disk show --name $disk --query resourceGroup -o tsv)
    DISK_ID=$(az disk show --name $disk --resource-group $RG --query id -o tsv)
    SNAPSHOT_NAME="${disk}-snapshot-$(date +%Y%m%d)"
    
    echo "Creating snapshot: $SNAPSHOT_NAME"
    az snapshot create \
        --resource-group $RG \
        --name $SNAPSHOT_NAME \
        --source $DISK_ID
done
```

### Option 2: Direct Deletion (Use with Caution)

Only use this approach after thorough verification.
```powershell
# Delete unattached disks after confirmation
$unattachedDisks = Get-AzDisk | Where-Object { $_.ManagedBy -eq $null }

foreach ($disk in $unattachedDisks) {
    $confirmation = Read-Host "Delete disk '$($disk.Name)'? (yes/no)"
    
    if ($confirmation -eq 'yes') {
        Remove-AzDisk `
            -ResourceGroupName $disk.ResourceGroupName `
            -DiskName $disk.Name `
            -Force
        
        Write-Host "Deleted: $($disk.Name)" -ForegroundColor Green
    }
}
```
```bash
# Using Azure CLI with confirmation
az disk list --query "[?diskState=='Unattached'].[name,resourceGroup]" -o tsv | while read name rg; do
    echo "Delete disk: $name in $rg?"
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        az disk delete --name $name --resource-group $rg --yes
        echo "Deleted: $name"
    fi
done
```

### Option 3: Re-attach Disk to VM

If the disk is needed:
```powershell
# Re-attach disk to a VM
$vm = Get-AzVM -ResourceGroupName "myRG" -Name "myVM"
$disk = Get-AzDisk -ResourceGroupName "myRG" -DiskName "myDisk"

$vm = Add-AzVMDataDisk `
    -VM $vm `
    -Name $disk.Name `
    -CreateOption Attach `
    -ManagedDiskId $disk.Id `
    -Lun 0

Update-AzVM -ResourceGroupName "myRG" -VM $vm
```

### Option 4: Set Up Automated Alerts

Prevent future accumulation:
```powershell
# Create alert for unattached disks older than 30 days
# This requires Azure Monitor configuration
$actionGroup = Get-AzActionGroup -ResourceGroupName "myRG" -Name "myActionGroup"

$criteria = New-AzActivityLogAlertCondition `
    -Field 'category' `
    -Equals 'Administrative' `
    -Field 'operationName' `
    -Equals 'Microsoft.Compute/disks/delete'

New-AzActivityLogAlert `
    -Name "UnattachedDiskAlert" `
    -ResourceGroupName "myRG" `
    -Condition $criteria `
    -ActionGroup $actionGroup
```

## Important Considerations

### Snapshot Costs
- **Snapshots incur storage costs**: Typically lower than full disks
- **Incremental snapshots**: Only changes are stored after first snapshot
- **Snapshot pricing**: ~$0.05/GB/month for standard, ~$0.12/GB/month for premium
- **Retention policy**: Establish when to delete old snapshots

### Recovery Time
If you need to restore a disk from snapshot:
- **Snapshot to disk**: 5-15 minutes depending on size
- **Disk attachment**: Immediate
- **Data accessibility**: Immediate after attachment

### Disk Types and Use Cases

**Premium SSD (Premium_LRS)**
- High-performance, production workloads
- Highest cost per GB
- Priority for cleanup

**Standard SSD (StandardSSD_LRS)**
- Development/test workloads
- Moderate cost
- Balance of performance and cost

**Standard HDD (Standard_LRS)**
- Backup, archival storage
- Lowest cost per GB
- Lower priority for cleanup

**Ultra SSD**
- Mission-critical workloads
- Very high cost
- Highest priority for cleanup

### Common Scenarios

**Scenario 1: VM Deleted, Disk Retained**
- Most common cause of unattached disks
- Occurs when VM is deleted but "Delete disks with VM" is not checked
- Solution: Review and delete if VM is permanently removed

**Scenario 2: Disk Detached for Troubleshooting**
- Temporarily detached for repair or data recovery
- May be forgotten after resolution
- Solution: Document temporary detachments, set calendar reminders

**Scenario 3: Development/Testing**
- Created for experiments and not cleaned up
- Multiple disks from testing different configurations
- Solution: Implement automated cleanup policies for dev/test

**Scenario 4: Migration Projects**
- Source disks left behind after migration
- Redundant copies created during migration
- Solution: Formal cleanup checklist for migration projects

## False Positives

### Recently Detached Disks
**Scenario**: Disk detached moments ago for maintenance
**Solution**: 
- Check creation/modification date
- Wait 24-48 hours before deleting
- Implement grace period in automation

### Disaster Recovery Disks
**Scenario**: Intentionally unattached disks kept for DR purposes
**Solution**:
- Tag with `Purpose=DisasterRecovery`
- Document in runbook
- Regular review schedule

### Temporary Storage
**Scenario**: Disk used for periodic batch processing
**Solution**:
- Tag with `Usage=Periodic`
- Schedule-based attachment
- Consider alternatives (Azure Batch, temp storage)

## Monitoring and Alerting

### Recommended Monitoring

1. **Weekly reports**: List of unattached disks and costs
2. **Monthly trends**: Track unattached disk growth
3. **Budget alerts**: Alert when unattached disk costs exceed threshold
4. **Age tracking**: Report disks unattached > 30, 60, 90 days

### Azure Monitor Query
```kusto
// Find unattached disks with details
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COMPUTE"
| where ResourceType == "DISKS"
| where properties_s contains "Unattached"
| extend DiskSize = toint(properties_s.diskSizeGB)
| extend DiskTier = tostring(properties_s.sku.name)
| project TimeGenerated, Resource, DiskSize, DiskTier, ResourceGroup
| summarize Count=count(), TotalGB=sum(DiskSize) by DiskTier
```

### Cost Management

Create a budget alert:
```powershell
# Example budget for unattached disks
New-AzConsumptionBudget `
    -Name "UnattachedDisksBudget" `
    -Amount 100 `
    -Category "Cost" `
    -TimeGrain "Monthly" `
    -StartDate (Get-Date) `
    -EndDate (Get-Date).AddYears(1)
```

## Automation Options

### Azure Automation Runbook
```powershell
# Automated cleanup runbook (example)
param(
    [int]$DaysUnattached = 30
)

# Get all unattached disks
$unattachedDisks = Get-AzDisk | Where-Object { 
    $_.ManagedBy -eq $null -and 
    (Get-Date) - $_.TimeCreated -gt [TimeSpan]::FromDays($DaysUnattached)
}

foreach ($disk in $unattachedDisks) {
    # Create snapshot
    $snapshotName = "$($disk.Name)-auto-snapshot"
    # ... snapshot logic ...
    
    # Send notification
    # ... notification logic ...
    
    # Delete disk (optional, requires approval)
    # Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force
}
```

### Azure Policy

Create a policy to enforce tagging:
```json
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Compute/disks"
      },
      {
        "field": "tags['Purpose']",
        "exists": "false"
      }
    ]
  },
  "then": {
    "effect": "audit"
  }
}
```

## Best Practices

1. **Tag all disks** with purpose, owner, and expiration date
2. **Implement lifecycle policies** for automatic cleanup
3. **Regular reviews** (weekly or monthly) of unattached disks
4. **Document exceptions** (DR, periodic use, etc.)
5. **Snapshot before delete** as a safety measure
6. **Set retention policies** for snapshots (e.g., 90 days)
7. **Use Azure Policy** to enforce tagging
8. **Automate reporting** to stakeholders
9. **Include in offboarding** process to delete user-owned disks
10. **Cost allocation** to teams to increase accountability

## Related Checks
- **COST-002**: Unused public IP addresses
- **COST-003**: Unassociated network interfaces
- **COST-004**: Idle virtual machines
- **COST-005**: Oversized virtual machines

## References
- [Azure Managed Disks pricing](https://azure.microsoft.com/pricing/details/managed-disks/)
- [Find and delete unattached disks](https://learn.microsoft.com/azure/virtual-machines/disks-find-unattached)
- [Azure disk snapshots](https://learn.microsoft.com/azure/virtual-machines/snapshot-copy-managed-disk)
- [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/)
- [FinOps Framework](https://www.finops.org/framework/)

## Change Log
- 2024-10-21: Initial creation
- 2024-10-21: Added comprehensive cost analysis and remediation steps
```
