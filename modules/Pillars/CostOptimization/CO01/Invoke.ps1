<#
.SYNOPSIS
    CO01 - Create a culture of financial responsibility

.DESCRIPTION
    Equip and motivate the workload team to make prudent financial decisions, proactively seeking strategies to enhance efficiency and reduce unnecessary expenses.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/create-culture-financial-responsibility
#>

Register-WafCheck -CheckId 'CO01' `
    -Pillar 'CostOptimization' `
    -Title 'Create a culture of financial responsibility' `
    -Description 'Equip and motivate the workload team to make prudent financial decisions, proactively seeking strategies to enhance efficiency and reduce unnecessary expenses.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'FinancialResponsibility', 'Budgets', 'Tagging', 'Governance') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/create-culture-financial-responsibility' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess financial responsibility indicators
            
            # 1. Budgets in Azure Cost Management
            $budgetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.consumption/budgets'
| summarize Budgets = count()
"@
            $budgetResult = Invoke-AzResourceGraphQuery -Query $budgetQuery -SubscriptionId $SubscriptionId -UseCache
            $budgetCount = if ($budgetResult.Count -gt 0) { $budgetResult[0].Budgets } else { 0 }
            
            # 2. Cost Alerts (Action Groups linked to cost metrics)
            $costAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'cost' or properties.description contains 'budget' or properties.description contains 'spend'
| summarize CostAlerts = count()
"@
            $costAlertResult = Invoke-AzResourceGraphQuery -Query $costAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $costAlertCount = if ($costAlertResult.Count -gt 0) { $costAlertResult[0].CostAlerts } else { 0 }
            
            # 3. Tagging Coverage for Cost Allocation
            $taggedResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['costCenter']) or isnotempty(tags['department']) or isnotempty(tags['project']) or isnotempty(tags['environment'])
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
            
            # 4. Azure Policy Assignments for Cost Governance
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'cost' or properties.displayName contains 'budget' or properties.displayName contains 'tagging' or properties.displayName contains 'financial'
| summarize CostPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].CostPolicies } else { 0 }
            
            # 5. Cost Management Exports/Reports
            $exportQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.costmanagement/exports'
| summarize CostExports = count()
"@
            $exportResult = Invoke-AzResourceGraphQuery -Query $exportQuery -SubscriptionId $SubscriptionId -UseCache
            $exportCount = if ($exportResult.Count -gt 0) { $exportResult[0].CostExports } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($budgetCount -eq 0) {
                $indicators += "No budgets configured for cost transparency"
            }
            
            if ($costAlertCount -eq 0) {
                $indicators += "No cost-related alerts for proactive monitoring"
            }
            
            if ($tagPercent -lt 70) {
                $indicators += "Low tagging coverage for cost allocation ($tagPercent%)"
            }
            
            if ($policyCount -lt 3) {
                $indicators += "Limited cost governance policies ($policyCount)"
            }
            
            if ($exportCount -eq 0) {
                $indicators += "No cost exports/reports for sharing"
            }
            
            $evidence = @"
Financial Responsibility Assessment:
- Budgets: $budgetCount
- Cost Alerts: $costAlertCount
- Tagged Resources: $taggedCount / $totalCount ($tagPercent%)
- Cost Policies: $policyCount
- Cost Exports: $exportCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO01' `
                    -Status 'Pass' `
                    -Message 'Strong culture of financial responsibility with transparency and governance' `
                    -Metadata @{
                        Budgets = $budgetCount
                        CostAlerts = $costAlertCount
                        TagPercent = $tagPercent
                        Policies = $policyCount
                        Exports = $exportCount
                    }
            } else {
                return New-WafResult -CheckId 'CO01' `
                    -Status 'Fail' `
                    -Message "Financial responsibility gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of financial responsibility culture leads to overspending.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Transparency Basics (Week 1)
1. **Create Budgets**: Set thresholds
2. **Configure Alerts**: For spending
3. **Apply Tags**: For allocation

### Phase 2: Governance & Skills (Weeks 2-3)
1. **Assign Policies**: Enforce tagging
2. **Set Up Exports**: For reports
3. **Conduct Training**: On cost management

$evidence
"@ `
                    -RemediationScript @"
# Quick Financial Responsibility Setup

# Create Budget
New-AzConsumptionBudget -Name 'monthly-budget' -ResourceGroupName 'rg' -Amount 1000 -TimeGrain Monthly -StartDate (Get-Date) -EndDate (Get-Date).AddMonths(1) -Category Cost

# Cost Alert (Metric Alert on Cost)
New-AzMetricAlertRuleV2 -Name 'cost-alert' -ResourceGroupName 'rg' -WindowSize (New-TimeSpan -Days 1) -Condition (New-AzMetricAlertRuleV2Criteria -MetricName 'Cost' -Operator GreaterThan -Threshold 800)

# Tag Policy
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Require tag on resources' }
New-AzPolicyAssignment -Name 'cost-tag-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId" -PolicyParameter '{"tagName":{"value":"costCenter"}}'

Write-Host "Basic financial tools configured - expand with training and reviews"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO01' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
