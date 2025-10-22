<#
.SYNOPSIS
    CO13 - Optimize personnel time

.DESCRIPTION
    Optimize personnel time by aligning the time personnel spends on tasks with the priority of the task. The goal is to reduce time spent on tasks without degrading outcomes, including minimizing noise, reducing build times, enabling high fidelity debugging, and using production mocking.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:13 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-personnel-time
#>

Register-WafCheck -CheckId 'CO13' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize personnel time' `
    -Description 'Optimize personnel time by aligning the time personnel spends on tasks with the priority of the task. The goal is to reduce time spent on tasks without degrading outcomes, including minimizing noise, reducing build times, enabling high fidelity debugging, and using production mocking.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'PersonnelTime', 'Automation', 'BuildOptimization', 'NoiseReduction') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-personnel-time' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess personnel time optimization indicators
            
            # 1. Automation Runbooks (for reducing manual tasks)
            $runbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts/runbooks'
| summarize Runbooks = count()
"@
            $runbookResult = Invoke-AzResourceGraphQuery -Query $runbookQuery -SubscriptionId $SubscriptionId -UseCache
            $runbookCount = if ($runbookResult.Count -gt 0) { $runbookResult[0].Runbooks } else { 0 }
            
            # 2. Azure DevOps Pipelines (for build optimization)
            $devopsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/pipelines'
| summarize Pipelines = count()
"@
            $devopsResult = Invoke-AzResourceGraphQuery -Query $devopsQuery -SubscriptionId $SubscriptionId -UseCache
            $pipelineCount = if ($devopsResult.Count -gt 0) { $devopsResult[0].Pipelines } else { 0 }
            
            # 3. Azure Monitor Alerts (for noise reduction)
            $alertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/alertrules'
| summarize AlertRules = count()
"@
            $alertResult = Invoke-AzResourceGraphQuery -Query $alertQuery -SubscriptionId $SubscriptionId -UseCache
            $alertCount = if ($alertResult.Count -gt 0) { $alertResult[0].AlertRules } else { 0 }
            
            # 4. Azure Policy Assignments (for governance and standards)
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| summarize Policies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].Policies } else { 0 }
            
            # 5. Advisor Operational Excellence Recommendations
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $opExRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($runbookCount -eq 0) {
                $indicators += "No automation runbooks for task reduction"
            }
            
            if ($pipelineCount -eq 0) {
                $indicators += "No DevOps pipelines for build optimization"
            }
            
            if ($alertCount -lt 5) {
                $indicators += "Limited alert rules ($alertCount) for noise reduction"
            }
            
            if ($policyCount -lt 5) {
                $indicators += "Limited policies ($policyCount) for standards"
            }
            
            if ($opExRecs -gt 5) {
                $indicators += "High unresolved OpEx recommendations ($opExRecs)"
            }
            
            $evidence = @"
Personnel Time Assessment:
- Automation Runbooks: $runbookCount
- DevOps Pipelines: $pipelineCount
- Alert Rules: $alertCount
- Policies: $policyCount
- OpEx Recommendations: $opExRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO13' `
                    -Status 'Pass' `
                    -Message 'Optimized personnel time with efficient processes' `
                    -Metadata @{
                        Runbooks = $runbookCount
                        Pipelines = $pipelineCount
                        Alerts = $alertCount
                        Policies = $policyCount
                        OpExRecs = $opExRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO13' `
                    -Status 'Fail' `
                    -Message "Personnel time gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inefficient processes waste personnel time.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Automation Basics (Week 1)
1. **Deploy Runbooks**: For tasks
2. **Set Up Pipelines**: For builds
3. **Configure Alerts**: For signals

### Phase 2: Standards & Reviews (Weeks 2-3)
1. **Implement Policies**: For governance
2. **Address OpEx Recs**: For efficiency
3. **Conduct Retrospectives**: Learn from incidents

$evidence
"@ `
                    -RemediationScript @"
# Quick Personnel Optimization Setup

# Create Runbook
New-AzAutomationRunbook -Name 'task-auto' -ResourceGroupName 'rg' -AutomationAccountName 'auto' -Type PowerShell -Location 'eastus'

# Example Policy
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Audit resource creation' }
New-AzPolicyAssignment -Name 'op-ex-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Basic setup - focus on training and retros"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO13' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
