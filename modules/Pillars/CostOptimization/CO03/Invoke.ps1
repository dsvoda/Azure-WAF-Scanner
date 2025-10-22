<#
.SYNOPSIS
    CO03 - Collect and review cost data

.DESCRIPTION
    Gather cost data to paint a holistic picture of your workload and ensure spending is optimized. Data collection includes all indicators of cost optimization, like billing data, resource utilization, and usage patterns.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:03 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/collect-review-cost-data
#>

Register-WafCheck -CheckId 'CO03' `
    -Pillar 'CostOptimization' `
    -Title 'Collect and review cost data' `
    -Description 'Gather cost data to paint a holistic picture of your workload and ensure spending is optimized. Data collection includes all indicators of cost optimization, like billing data, resource utilization, and usage patterns.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'CostData', 'Monitoring', 'Alerts', 'Tagging') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/collect-review-cost-data' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess cost data collection indicators
            
            # 1. Cost Exports for Collection
            $exportQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.costmanagement/exports'
| summarize CostExports = count()
"@
            $exportResult = Invoke-AzResourceGraphQuery -Query $exportQuery -SubscriptionId $SubscriptionId -UseCache
            $exportCount = if ($exportResult.Count -gt 0) { $exportResult[0].CostExports } else { 0 }
            
            # 2. Cost Alerts for Review
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'cost' or properties.description contains 'spend' or properties.description contains 'anomaly'
| summarize CostAlerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].CostAlerts } else { 0 }
            
            # 3. Tagging for Grouping
            $taggedQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['department']) or isnotempty(tags['project']) or isnotempty(tags['environment']) or isnotempty(tags['costCenter'])
| summarize TaggedResources = count()
"@
            $taggedResult = Invoke-AzResourceGraphQuery -Query $taggedQuery -SubscriptionId $SubscriptionId -UseCache
            $taggedCount = if ($taggedResult.Count -gt 0) { $taggedResult[0].TaggedResources } else { 0 }
            
            $totalQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize TotalResources = count()
"@
            $totalResult = Invoke-AzResourceGraphQuery -Query $totalQuery -SubscriptionId $SubscriptionId -UseCache
            $totalCount = if ($totalResult.Count -gt 0) { $totalResult[0].TotalResources } else { 0 }
            
            $tagPercent = if ($totalCount -gt 0) { [Math]::Round(($taggedCount / $totalCount) * 100, 1) } else { 0 }
            
            # 4. Budgets for Review Against Targets
            $budgetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.consumption/budgets'
| summarize Budgets = count()
"@
            $budgetResult = Invoke-AzResourceGraphQuery -Query $budgetQuery -SubscriptionId $SubscriptionId -UseCache
            $budgetCount = if ($budgetResult.Count -gt 0) { $budgetResult[0].Budgets } else { 0 }
            
            # 5. Azure Advisor Cost Recommendations
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $costRecs = $advisor | Where-Object { $_.Category -eq 'Cost' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($exportCount -eq 0) {
                $indicators += "No cost exports for data collection"
            }
            
            if ($alertCount -eq 0) {
                $indicators += "No cost alerts for anomaly detection"
            }
            
            if ($tagPercent -lt 70) {
                $indicators += "Low tagging for data grouping ($tagPercent%)"
            }
            
            if ($budgetCount -eq 0) {
                $indicators += "No budgets for review against targets"
            }
            
            if ($costRecs -gt 5) {
                $indicators += "High number of unresolved cost recommendations ($costRecs)"
            }
            
            $evidence = @"
Cost Data Assessment:
- Cost Exports: $exportCount
- Cost Alerts: $alertCount
- Tagged Resources: $taggedCount / $totalCount ($tagPercent%)
- Budgets: $budgetCount
- Cost Recommendations: $costRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO03' `
                    -Status 'Pass' `
                    -Message 'Effective cost data collection and review practices' `
                    -Metadata @{
                        Exports = $exportCount
                        Alerts = $alertCount
                        TagPercent = $tagPercent
                        Budgets = $budgetCount
                        CostRecs = $costRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO03' `
                    -Status 'Fail' `
                    -Message "Cost data gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate cost data collection hinders optimization.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Collection Basics (Week 1)
1. **Set Up Exports**: For reports
2. **Configure Alerts**: For anomalies
3. **Apply Tags**: For grouping

### Phase 2: Review Processes (Weeks 2-3)
1. **Create Budgets**: With thresholds
2. **Review Recommendations**: Regularly
3. **Automate Reviews**: Use Power BI/APIs

$evidence
"@ `
                    -RemediationScript @"
# Quick Cost Data Setup

# Create Cost Export
New-AzCostManagementExport -Name 'daily-export' -Scope "subscriptions/$SubscriptionId" -StorageAccountId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/store' -StorageContainer 'costs' -Timeframe MonthToDate -Format Csv -ScheduleStatus 'Active' -Recurrence 'Daily'

# Cost Anomaly Alert (example)
New-AzMetricAlertRuleV2 -Name 'anomaly-alert' -ResourceGroupName 'rg' -WindowSize (New-TimeSpan -Days 1) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'Cost' -Operator GreaterThan -Threshold 1000)

# Assign Tag
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm' -Tag @{'project' = 'workload'} -Operation Merge

Write-Host "Basic cost data tools configured - set up regular reviews"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO03' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
