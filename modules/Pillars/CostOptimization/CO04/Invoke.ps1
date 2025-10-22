<#
.SYNOPSIS
    CO04 - Set spending guardrails

.DESCRIPTION
    Set spending guardrails by implementing measures to control and manage your costs within a specified budget. These measures include governance policies, access controls, release gates, budget thresholds, and alerts. Automation reduces the risk of human error, improves efficiency, and assists the consistent application of spending guardrails. Prioritize platform automation over manual processes. Automation tools and services the platform provides can streamline resource provisioning, configuration, and management. Spending guardrails are measures to control and manage costs within a specified budget. They help prevent unexpected or excessive spending and promote cost-effective utilization of resources. Without spending guardrails, your workload costs might exceed your budget, leading to unplanned expenses that can strain your financial resources.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:04 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/set-spending-guardrails
#>

Register-WafCheck -CheckId 'CO04' `
    -Pillar 'CostOptimization' `
    -Title 'Set spending guardrails' `
    -Description 'Guardrails should include release gates, governance policies, resource limits, and access controls. Prioritize platform automation over manual processes.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'Guardrails', 'Budgets', 'Policies', 'RBAC') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/set-spending-guardrails' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess spending guardrails indicators
            
            # 1. Governance Policies (Azure Policy assignments for cost)
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'cost' or properties.displayName contains 'budget' or properties.displayName contains 'resource limit' or properties.displayName contains 'tagging'
| summarize GovernancePolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].GovernancePolicies } else { 0 }
            
            # 2. Budgets and Alerts
            $budgetQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.consumption/budgets'
| summarize Budgets = count()
"@
            $budgetResult = Invoke-AzResourceGraphQuery -Query $budgetQuery -SubscriptionId $SubscriptionId -UseCache
            $budgetCount = if ($budgetResult.Count -gt 0) { $budgetResult[0].Budgets } else { 0 }
            
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'cost' or properties.description contains 'budget' or properties.description contains 'spend'
| summarize CostAlerts = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].CostAlerts } else { 0 }
            
            # 3. Access Controls (RBAC assignments at appropriate scopes)
            $rbacQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roleassignments'
| summarize RBACAssignments = count()
"@
            $rbacResult = Invoke-AzResourceGraphQuery -Query $rbacQuery -SubscriptionId $SubscriptionId -UseCache
            $rbacCount = if ($rbacResult.Count -gt 0) { $rbacResult[0].RBACAssignments } else { 0 }
            
            # Custom Roles for fine-grained control
            $customRoleQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roledefinitions'
| where properties.type == 'CustomRole'
| summarize CustomRoles = count()
"@
            $customRoleResult = Invoke-AzResourceGraphQuery -Query $customRoleQuery -SubscriptionId $SubscriptionId -UseCache
            $customRoleCount = if ($customRoleResult.Count -gt 0) { $customRoleResult[0].CustomRoles } else { 0 }
            
            # 4. Automation and IaC (Automation Accounts, Pipelines as proxy)
            $automationQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts'
| summarize AutomationAccounts = count()
"@
            $automationResult = Invoke-AzResourceGraphQuery -Query $automationQuery -SubscriptionId $SubscriptionId -UseCache
            $automationCount = if ($automationResult.Count -gt 0) { $automationResult[0].AutomationAccounts } else { 0 }
            
            # Logic Apps or Functions for gates
            $logicQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.logic/workflows' or type =~ 'microsoft.web/sites/functions'
| summarize AutomationTools = count()
"@
            $logicResult = Invoke-AzResourceGraphQuery -Query $logicQuery -SubscriptionId $SubscriptionId -UseCache
            $logicCount = if ($logicResult.Count -gt 0) { $logicResult[0].AutomationTools } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($policyCount -lt 5) {
                $indicators += "Limited governance policies for cost control ($policyCount)"
            }
            
            if ($budgetCount -eq 0) {
                $indicators += "No budgets configured"
            }
            
            if ($alertCount -eq 0) {
                $indicators += "No cost alerts for monitoring"
            }
            
            if ($rbacCount -lt 10) {
                $indicators += "Limited RBAC assignments ($rbacCount)"
            }
            
            if ($customRoleCount -eq 0) {
                $indicators += "No custom roles for precise access control"
            }
            
            if ($automationCount -eq 0 && $logicCount -eq 0) {
                $indicators += "No automation tools for release gates/processes"
            }
            
            $evidence = @"
Spending Guardrails Assessment:
- Governance Policies: $policyCount
- Budgets: $budgetCount
- Cost Alerts: $alertCount
- RBAC Assignments: $rbacCount (Custom Roles: $customRoleCount)
- Automation Tools: $automationCount accounts, $logicCount workflows/functions
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO04' `
                    -Status 'Pass' `
                    -Message 'Effective spending guardrails with policies and automation' `
                    -Metadata @{
                        Policies = $policyCount
                        Budgets = $budgetCount
                        Alerts = $alertCount
                        RBAC = $rbacCount
                        CustomRoles = $customRoleCount
                        Automation = $automationCount
                        Logic = $logicCount
                    }
            } else {
                return New-WafResult -CheckId 'CO04' `
                    -Status 'Fail' `
                    -Message "Spending guardrails gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of guardrails leads to uncontrolled spending.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Implement Policies**: Using Azure Policy
2. **Set Budgets/Alerts**: In Cost Management
3. **Refine RBAC**: With custom roles

### Phase 2: Automation (Weeks 2-3)
1. **Deploy Automation**: For gates
2. **Use Pipelines**: For releases
3. **Review Regularly**: Adjust guardrails

$evidence
"@ `
                    -RemediationScript @"
# Quick Guardrails Setup

# Assign Cost Policy
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Allowed resource types' }
New-AzPolicyAssignment -Name 'cost-guardrail' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId" -ListOfAllowedResourceTypes @('microsoft.compute/virtualmachines')

# Create Budget with Alert
New-AzConsumptionBudget -Name 'guard-budget' -Amount 2000 -TimeGrain Monthly -StartDate (Get-Date) -EndDate (Get-Date).AddMonths(1) -Category Cost -NotificationKey 'email' -NotificationThreshold 80

Write-Host "Basic guardrails configured - expand with RBAC and automation"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO04' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
