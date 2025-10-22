<#
.SYNOPSIS
    CO02 - Develop a cost model

.DESCRIPTION
    Develop a cost model that maps your workload's technical components to financial costs. Use the model to understand, forecast, and optimize expenses while aligning with business objectives.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:02 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/cost-model
#>

Register-WafCheck -CheckId 'CO02' `
    -Pillar 'CostOptimization' `
    -Title 'Develop a cost model' `
    -Description 'Develop a cost model that maps your workload''s technical components to financial costs. Use the model to understand, forecast, and optimize expenses while aligning with business objectives.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'CostModel', 'Forecasting', 'Reservations', 'CostAnalysis') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/cost-model' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess cost model indicators
            
            # 1. Cost Analysis and Forecasts (Indirect: Scheduled Exports as proxy for regular review)
            $exportQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.costmanagement/exports'
| summarize CostExports = count()
"@
            $exportResult = Invoke-AzResourceGraphQuery -Query $exportQuery -SubscriptionId $SubscriptionId -UseCache
            $exportCount = if ($exportResult.Count -gt 0) { $exportResult[0].CostExports } else { 0 }
            
            # 2. Budgets with Thresholds
            $budgetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.consumption/budgets'
| summarize Budgets = count()
"@
            $budgetResult = Invoke-AzResourceGraphQuery -Query $budgetQuery -SubscriptionId $SubscriptionId -UseCache
            $budgetCount = if ($budgetResult.Count -gt 0) { $budgetResult[0].Budgets } else { 0 }
            
            # 3. Reservations Usage
            $reservationQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.capacity/reservations'
| summarize Reservations = count()
"@
            $reservationResult = Invoke-AzResourceGraphQuery -Query $reservationQuery -SubscriptionId $SubscriptionId -UseCache
            $reservationCount = if ($reservationResult.Count -gt 0) { $reservationResult[0].Reservations } else { 0 }
            
            # 4. Tagging for Cost Allocation
            $taggedResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['costCenter']) or isnotempty(tags['project']) or isnotempty(tags['department']) or isnotempty(tags['workload'])
| summarize TaggedResources = count()
"@
            $taggedResult = Invoke-AzResourceGraphQuery -Query $taggedResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            $taggedCount = if ($taggedResult.Count -gt 0) { $taggedResult[0].TaggedResources } else { 0 }
            
            $totalResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize TotalResources = count()
"@
            $totalResult = Invoke-AzResourceGraphQuery -Query $totalResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            $totalCount = if ($totalResult.Count -gt 0) { $totalResult[0].TotalResources } else { 0 }
            
            $tagPercent = if ($totalCount -gt 0) { [Math]::Round(($taggedCount / $totalCount) * 100, 1) } else { 0 }
            
            # 5. Governance Policies for Cost
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'cost' or properties.displayName contains 'budget' or properties.displayName contains 'reservation' or properties.displayName contains 'tagging'
| summarize CostPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].CostPolicies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($exportCount -eq 0) {
                $indicators += "No cost exports for analysis and forecasting"
            }
            
            if ($budgetCount -eq 0) {
                $indicators += "No budgets configured for cost planning"
            }
            
            if ($reservationCount -eq 0) {
                $indicators += "No reservations for cost optimization"
            }
            
            if ($tagPercent -lt 70) {
                $indicators += "Low tagging coverage for cost allocation ($tagPercent%)"
            }
            
            if ($policyCount -lt 3) {
                $indicators += "Limited cost governance policies ($policyCount)"
            }
            
            $evidence = @"
Cost Model Assessment:
- Cost Exports: $exportCount
- Budgets: $budgetCount
- Reservations: $reservationCount
- Tagged Resources: $taggedCount / $totalCount ($tagPercent%)
- Cost Policies: $policyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO02' `
                    -Status 'Pass' `
                    -Message 'Well-developed cost model with forecasting and optimization' `
                    -Metadata @{
                        Exports = $exportCount
                        Budgets = $budgetCount
                        Reservations = $reservationCount
                        TagPercent = $tagPercent
                        Policies = $policyCount
                    }
            } else {
                return New-WafResult -CheckId 'CO02' `
                    -Status 'Fail' `
                    -Message "Cost model gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of cost model leads to inaccurate forecasting and overspending.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Create Budgets**: With alerts
2. **Set Up Exports**: For analysis
3. **Apply Tags**: For allocation

### Phase 2: Optimization (Weeks 2-3)
1. **Purchase Reservations**: For savings
2. **Assign Policies**: For governance
3. **Generate Forecasts**: Review regularly

$evidence
"@ `
                    -RemediationScript @"
# Quick Cost Model Setup

# Create Cost Export
New-AzCostManagementExport -Name 'monthly-export' -Scope "subscriptions/$SubscriptionId" -StorageAccountId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/store' -StorageContainer 'exports' -Timeframe MonthToDate -Format Csv -ScheduleStatus 'Active' -Recurrence 'Monthly'

# Create Budget
New-AzConsumptionBudget -Name 'cost-model-budget' -Amount 5000 -TimeGrain Monthly -StartDate (Get-Date) -EndDate (Get-Date).AddMonths(1) -Category Cost

# Purchase Reservation (example for VM)
New-AzReservationOrder -ReservationOrderId (New-Guid) -Reservation (New-AzReservation -ReservedResourceType VirtualMachines -Location 'eastus' -Quantity 1 -Sku 'Standard_D2s_v3' -Term P1Y)

Write-Host "Basic cost model tools configured - build full model in Cost Management"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO02' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
