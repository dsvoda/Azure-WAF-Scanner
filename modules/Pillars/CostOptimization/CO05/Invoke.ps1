<#
.SYNOPSIS
    CO05 - Get the best rates

.DESCRIPTION
    Get the best rates by using pricing models that match your workload's usage patterns. Consider reservations, savings plans, spot instances, and Azure Hybrid Benefit to reduce costs.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:05 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/get-best-rates
#>

Register-WafCheck -CheckId 'CO05' `
    -Pillar 'CostOptimization' `
    -Title 'Get the best rates' `
    -Description 'Get the best rates by using pricing models that match your workload''s usage patterns. Consider reservations, savings plans, spot instances, and Azure Hybrid Benefit to reduce costs.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'PricingModels', 'Reservations', 'SavingsPlans', 'SpotInstances') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/get-best-rates' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess best rates indicators
            
            # 1. Azure Reservations
            $reservationQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.capacity/reservationorders'
| summarize Reservations = count()
"@
            $reservationResult = Invoke-AzResourceGraphQuery -Query $reservationQuery -SubscriptionId $SubscriptionId -UseCache
            $reservationCount = if ($reservationResult.Count -gt 0) { $reservationResult[0].Reservations } else { 0 }
            
            # 2. Azure Savings Plans
            $savingsPlanQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.billingbenefits/savingsplanorders'
| summarize SavingsPlans = count()
"@
            $savingsPlanResult = Invoke-AzResourceGraphQuery -Query $savingsPlanQuery -SubscriptionId $SubscriptionId -UseCache
            $savingsPlanCount = if ($savingsPlanResult.Count -gt 0) { $savingsPlanResult[0].SavingsPlans } else { 0 }
            
            # 3. Spot Instances
            $spotQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines' or type =~ 'microsoft.compute/virtualmachinescalesets'
| extend 
    priority = tostring(properties.priority)
| where priority == 'Spot'
| summarize SpotInstances = count()
"@
            $spotResult = Invoke-AzResourceGraphQuery -Query $spotQuery -SubscriptionId $SubscriptionId -UseCache
            $spotCount = if ($spotResult.Count -gt 0) { $spotResult[0].SpotInstances } else { 0 }
            
            # 4. Azure Hybrid Benefit
            $hybridQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| extend 
    licenseType = tostring(properties.licenseType)
| where licenseType contains 'Windows' or licenseType contains 'SQL'
| summarize HybridBenefits = count()
"@
            $hybridResult = Invoke-AzResourceGraphQuery -Query $hybridQuery -SubscriptionId $SubscriptionId -UseCache
            $hybridCount = if ($hybridResult.Count -gt 0) { $hybridResult[0].HybridBenefits } else { 0 }
            
            # Total VMs for percentage
            $totalVMQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines'
| summarize TotalVMs = count()
"@
            $totalVMResult = Invoke-AzResourceGraphQuery -Query $totalVMQuery -SubscriptionId $SubscriptionId -UseCache
            $totalVMs = if ($totalVMResult.Count -gt 0) { $totalVMResult[0].TotalVMs } else { 0 }
            
            $hybridPercent = if ($totalVMs -gt 0) { [Math]::Round(($hybridCount / $totalVMs) * 100, 1) } else { 0 }
            
            # 5. Dev/Test Subscriptions (special pricing)
            $devTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where tags['environment'] == 'dev' or tags['environment'] == 'test' or name contains 'dev' or name contains 'test'
| summarize DevTestResources = count()
"@
            $devTestResult = Invoke-AzResourceGraphQuery -Query $devTestQuery -SubscriptionId $SubscriptionId -UseCache
            $devTestCount = if ($devTestResult.Count -gt 0) { $devTestResult[0].DevTestResources } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($reservationCount -eq 0) {
                $indicators += "No reservations for committed use savings"
            }
            
            if ($savingsPlanCount -eq 0) {
                $indicators += "No savings plans for flexible savings"
            }
            
            if ($spotCount -eq 0) {
                $indicators += "No spot instances for interruptible workloads"
            }
            
            if ($hybridPercent -lt 50 -and $totalVMs -gt 0) {
                $indicators += "Low Hybrid Benefit adoption ($hybridPercent%)"
            }
            
            if ($devTestCount -eq 0) {
                $indicators += "No identified dev/test resources for special pricing"
            }
            
            $evidence = @"
Best Rates Assessment:
- Reservations: $reservationCount
- Savings Plans: $savingsPlanCount
- Spot Instances: $spotCount
- Hybrid Benefit: $hybridCount / $totalVMs ($hybridPercent%)
- Dev/Test Resources: $devTestCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO05' `
                    -Status 'Pass' `
                    -Message 'Optimal use of pricing models for best rates' `
                    -Metadata @{
                        Reservations = $reservationCount
                        SavingsPlans = $savingsPlanCount
                        Spots = $spotCount
                        HybridPercent = $hybridPercent
                        DevTest = $devTestCount
                    }
            } else {
                return New-WafResult -CheckId 'CO05' `
                    -Status 'Fail' `
                    -Message "Pricing model gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Suboptimal pricing models increase costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Reservations & Plans (Week 1)
1. **Purchase Reservations**: For predictable workloads
2. **Buy Savings Plans**: For flexible usage
3. **Use Spot**: For stateless jobs

### Phase 2: Benefits & Special Pricing (Weeks 2-3)
1. **Enable Hybrid Benefit**: For Windows/SQL
2. **Tag Dev/Test**: For reduced rates
3. **Review Usage**: Adjust models

$evidence
"@ `
                    -RemediationScript @"
# Quick Best Rates Setup

# Purchase VM Reservation
New-AzReservationOrder -ReservationOrderId (New-Guid) -Reservation (New-AzReservation -ReservedResourceType VirtualMachines -Location 'eastus' -Quantity 1 -Sku 'Standard_D2s_v3' -Term P1Y)

# Enable Hybrid Benefit on VM
Update-AzVM -ResourceGroupName 'rg' -Name 'vm' -LicenseType 'Windows_Server'

Write-Host "Basic pricing optimizations - review in Cost Management for more"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO05' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
