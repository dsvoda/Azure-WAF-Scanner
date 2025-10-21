# Example WAF Check: Reliability - Virtual Machine Availability Zones
# Path: modules/Pillars/Reliability/REL-001/Invoke.ps1

<#
.SYNOPSIS
    Checks if Virtual Machines are deployed across availability zones.

.DESCRIPTION
    This check validates that production VMs are configured with availability zones
    for high availability and fault tolerance.
#>

# Register this check with the WAF Scanner
Register-WafCheck -CheckId 'REL-001' `
    -Pillar 'Reliability' `
    -Title 'Virtual Machines should use Availability Zones' `
    -Description 'Ensures VMs are distributed across availability zones for fault tolerance' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('VirtualMachines', 'HighAvailability', 'AvailabilityZones') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/virtual-machines/availability' `
    -ComplianceFramework 'CIS Azure 7.1' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        # Query for all VMs in the subscription
        $query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| where subscriptionId == '$SubscriptionId'
| extend hasZones = array_length(zones) > 0
| extend environment = tostring(tags.Environment)
| project id, name, location, resourceGroup, zones, hasZones, environment, sku = tostring(properties.hardwareProfile.vmSize)
"@
        
        try {
            $vms = Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
            
            if (!$vms -or $vms.Count -eq 0) {
                return New-WafResult -CheckId 'REL-001' `
                    -Status 'N/A' `
                    -Message 'No virtual machines found in subscription'
            }
            
            # Filter production VMs (customize based on your tagging strategy)
            $prodVMs = $vms | Where-Object { 
                $_.environment -match 'prod|production' -or 
                $null -eq $_.environment 
            }
            
            $vmsWithoutZones = $prodVMs | Where-Object { !$_.hasZones }
            
            if ($vmsWithoutZones.Count -eq 0) {
                return New-WafResult -CheckId 'REL-001' `
                    -Status 'Pass' `
                    -Message "All $($prodVMs.Count) production VMs are configured with availability zones"
            }
            
            # Failed check - some VMs don't have zones
            $affectedResourceIds = $vmsWithoutZones | ForEach-Object { $_.id }
            
            $recommendation = @"
Deploy VMs across availability zones to protect against datacenter-level failures:
1. Create new VMs with zone configuration
2. For existing VMs, you may need to recreate them with zone support
3. Consider using VM Scale Sets with zone redundancy
4. Ensure your applications support zone-aware deployments
"@
            
            $remediationScript = @"
# Example: Create a VM with availability zone support
`$vmName = "myVM"
`$resourceGroup = "myRG"
`$location = "eastus"

New-AzVM ``
    -ResourceGroupName `$resourceGroup ``
    -Name `$vmName ``
    -Location `$location ``
    -Zone @(1, 2, 3) ``
    -Size "Standard_DS2_v2" ``
    -Image "Win2022Datacenter"

# Note: Existing VMs cannot be converted to zonal VMs
# You must recreate them with zone configuration
"@
            
            return New-WafResult -CheckId 'REL-001' `
                -Status 'Fail' `
                -Message "$($vmsWithoutZones.Count) of $($prodVMs.Count) production VMs are not deployed with availability zones" `
                -AffectedResources $affectedResourceIds `
                -Recommendation $recommendation `
                -RemediationScript $remediationScript `
                -Metadata @{
                    TotalVMs = $prodVMs.Count
                    VMsWithoutZones = $vmsWithoutZones.Count
                    Locations = ($vmsWithoutZones | Select-Object -ExpandProperty location -Unique)
                }
                
        } catch {
            return New-WafResult -CheckId 'REL-001' `
                -Status 'Error' `
                -Message "Failed to execute check: $_"
        }
    }
```
