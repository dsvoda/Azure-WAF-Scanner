# REL-001 - Virtual Machines should use Availability Zones

## Description
This check validates that production virtual machines are configured to use Azure Availability Zones for enhanced fault tolerance and high availability. Availability Zones are physically separate locations within an Azure region that provide redundancy and protection against datacenter-level failures.

## Pillar
Reliability

## Severity
High

## Remediation Effort
High

## Rationale
Availability Zones protect your applications and data from datacenter failures. By distributing VMs across zones, you ensure that:
- Your workloads remain available during zone-level failures
- Planned maintenance has minimal impact
- You achieve higher SLA guarantees (99.99% vs 99.95% for single VM)
- You meet business continuity requirements

Without Availability Zones, a datacenter failure can result in complete service outages, data loss, and significant business impact.

## Compliance Mapping
- **CIS Azure Foundations Benchmark**: 7.1 - Ensure that Virtual Machines are utilizing Managed Disks
- **Azure Well-Architected Framework**: Reliability pillar - Design for high availability
- **ISO 27001**: A.17.2.1 - Availability of information processing facilities

## Implementation Details

### Resource Types Checked
- `microsoft.compute/virtualmachines`

### Query Logic
The check performs the following steps:
1. Queries all virtual machines in the subscription using Azure Resource Graph
2. Identifies VMs tagged as production (or those without environment tags)
3. Checks if VMs have the `zones` property populated
4. Reports VMs without availability zone configuration

### Pass Criteria
A virtual machine passes this check if:
- It has one or more availability zones configured in the `zones` property
- OR it is not tagged as a production environment

### Fail Criteria
A virtual machine fails this check if:
- It is tagged as production (or has no environment tag)
- AND it does not have availability zones configured

## Affected Resources
Virtual machines without availability zones in production environments.

## Remediation Steps

### Option 1: Create New Zonal VMs (Recommended)
**Note**: Existing VMs cannot be converted to use availability zones. You must create new VMs.

1. **Plan the migration**:
   - Document current VM configurations
   - Identify dependencies and connected resources
   - Schedule maintenance window
   - Prepare rollback plan

2. **Create new VMs with availability zones**:
```powershell
   # Using PowerShell
   $vmConfig = New-AzVMConfig -VMName "myVM" -VMSize "Standard_D2s_v3"
   
   New-AzVM `
       -ResourceGroupName "myRG" `
       -Location "eastus" `
       -VM $vmConfig `
       -Zone @(1, 2, 3)
```
```bash
   # Using Azure CLI
   az vm create \
       --resource-group myRG \
       --name myVM \
       --image UbuntuLTS \
       --size Standard_D2s_v3 \
       --zone 1
```

3. **Migrate data and applications**:
   - Use Azure Site Recovery for migration
   - Or use backup/restore approach
   - Update DNS and load balancer configurations

4. **Test thoroughly** before decommissioning old VMs

5. **Delete old non-zonal VMs** after successful validation

### Option 2: Use VM Scale Sets with Zone Redundancy
For better scalability and management:
```powershell
New-AzVmss `
    -ResourceGroupName "myRG" `
    -VMScaleSetName "myVMSS" `
    -Location "eastus" `
    -VirtualNetworkName "myVNet" `
    -SubnetName "mySubnet" `
    -PublicIpAddressName "myPublicIP" `
    -LoadBalancerName "myLB" `
    -Zone @(1, 2, 3)
```

### Option 3: Exclude from Production
If high availability is not required:
- Tag the VM with `Environment=Dev` or `Environment=Test`
- Document the decision and business justification

### Testing Remediation
1. Verify zone configuration:
```powershell
   Get-AzVM -ResourceGroupName "myRG" -Name "myVM" | Select-Object Name, Zones
```

2. Test failover scenarios
3. Verify application connectivity during zone simulation
4. Check SLA compliance

## Important Considerations

### Prerequisites
- Azure region must support Availability Zones
- Check region availability: [Azure regions with Availability Zones](https://learn.microsoft.com/azure/reliability/availability-zones-service-support)
- Supported regions include: East US, West Europe, Southeast Asia, and others

### Limitations
- **No in-place conversion**: Existing VMs cannot be converted to zonal VMs
- **Regional support**: Not all regions support Availability Zones
- **VM sizes**: Some older VM sizes may not support zones
- **Managed disks required**: VMs must use managed disks for zone support
- **Cost implications**: Some regions charge for zone-redundant configurations

### Network Considerations
- Use zone-redundant load balancers
- Configure zone-redundant public IP addresses
- Ensure Virtual Network spans multiple zones
- Plan for cross-zone bandwidth costs

### Application Architecture
- Design applications for distributed deployment
- Implement proper health checks and monitoring
- Use zone-aware load balancing
- Consider data replication and consistency
- Plan for cross-zone latency (typically < 2ms)

## False Positives

### Development/Test VMs
**Scenario**: Development or test VMs that don't require high availability
**Solution**: 
- Tag these VMs with `Environment=Dev` or `Environment=Test`
- The check will exclude non-production VMs

### Stateless Workloads
**Scenario**: Stateless VMs that can be quickly recreated
**Solution**: 
- Document the business decision
- Consider using Azure App Services or containers instead
- If acceptable risk, tag appropriately

### Legacy Applications
**Scenario**: Applications that cannot support distributed architecture
**Solution**:
- Document technical limitations
- Implement alternative disaster recovery strategy
- Plan migration to zone-aware architecture

## Cost Impact

### Additional Costs
- **None for zone selection**: Choosing an availability zone has no additional cost
- **Bandwidth charges**: Cross-zone data transfer may incur charges in some regions
- **Premium SKUs**: Some services require premium SKUs for zone redundancy

### Cost Optimization
- Use zone-redundant services only where needed
- Minimize cross-zone data transfer
- Consider reserved instances for cost savings

## Exclusions

### Valid Reasons to Exclude
1. **Region limitations**: Region doesn't support Availability Zones
2. **VM size constraints**: Specific VM size not available in zones
3. **Development environments**: Non-production workloads
4. **Legacy migrations**: Temporary state during migration
5. **Disaster recovery replicas**: Secondary VMs in DR sites

### How to Exclude
Add the appropriate tag to the VM:
```powershell
$tags = @{"Environment"="Dev"; "ExcludeFromWAF"="REL-001"}
Set-AzResource -ResourceId $vmId -Tag $tags -Force
```

## Monitoring and Alerting

### Recommended Alerts
1. **VM availability**: Alert when VM becomes unavailable
2. **Zone health**: Monitor Azure Service Health for zone issues
3. **Application health**: Implement application-level health checks

### Azure Monitor Queries
```kusto
// Find VMs without availability zones
AzureActivity
| where ResourceProvider == "Microsoft.Compute"
| where ResourceType == "virtualMachines"
| where Properties !contains "zones"
```

## Related Checks
- **REL-002**: Virtual Machine Scale Sets should use Availability Zones
- **REL-003**: Load Balancers should be zone-redundant
- **REL-004**: Managed Disks should use zone-redundant storage

## References
- [What are Availability Zones?](https://learn.microsoft.com/azure/reliability/availability-zones-overview)
- [Azure VM SLA](https://azure.microsoft.com/support/legal/sla/virtual-machines/)
- [Regions and Availability Zones](https://learn.microsoft.com/azure/reliability/availability-zones-region-support)
- [Migrate VMs to Availability Zones](https://learn.microsoft.com/azure/site-recovery/move-azure-vms-avset-azone)
- [Azure Well-Architected Framework - Reliability](https://learn.microsoft.com/azure/architecture/framework/resiliency/overview)

## Change Log
- 2024-10-21: Initial creation
- 2024-10-21: Added comprehensive documentation
``
