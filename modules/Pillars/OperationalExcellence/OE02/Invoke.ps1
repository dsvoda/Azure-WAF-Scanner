<#
.SYNOPSIS
    OE02 - Formalize operations tasks

.DESCRIPTION
    Formalize the way you run routine, as needed, and emergency operational tasks by using documentation, checklists, or automation. Strive for consistency and predictability for team processes and deliverables by adopting industry-leading practices and approaches, such as a shift left approach.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:02 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-operations-tasks
#>

Register-WafCheck -CheckId 'OE02' `
    -Pillar 'OperationalExcellence' `
    -Title 'Formalize operations tasks' `
    -Description 'Formalize the way you run routine, as needed, and emergency operational tasks by using documentation, checklists, or automation. Strive for consistency and predictability for team processes and deliverables by adopting industry-leading practices and approaches, such as a shift left approach.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'OperationsTasks', 'Automation', 'Runbooks', 'ShiftLeft') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-operations-tasks' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess operations formalization indicators
            
            # 1. Azure Automation Runbooks
            $runbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts/runbooks'
| summarize Runbooks = count()
"@
            $runbookResult = Invoke-AzResourceGraphQuery -Query $runbookQuery -SubscriptionId $SubscriptionId -UseCache
            $runbookCount = if ($runbookResult.Count -gt 0) { $runbookResult[0].Runbooks } else { 0 }
            
            # 2. Microsoft Sentinel Playbooks
            $playbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.logic/workflows' and tags['Sentinel'] == 'true'
| summarize Playbooks = count()
"@
            $playbookResult = Invoke-AzResourceGraphQuery -Query $playbookQuery -SubscriptionId $SubscriptionId -UseCache
            $playbookCount = if ($playbookResult.Count -gt 0) { $playbookResult[0].Playbooks } else { 0 }
            
            # 3. Azure Policy Assignments for Standards
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| summarize Policies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].Policies } else { 0 }
            
            # 4. DevOps Pipelines (for shift-left)
            $pipelineQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/pipelines'
| summarize Pipelines = count()
"@
            $pipelineResult = Invoke-AzResourceGraphQuery -Query $pipelineQuery -SubscriptionId $SubscriptionId -UseCache
            $pipelineCount = if ($pipelineResult.Count -gt 0) { $pipelineResult[0].Pipelines } else { 0 }
            
            # 5. Advisor OpEx Recs
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $opExRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($runbookCount -eq 0) {
                $indicators += "No runbooks for formalized tasks"
            }
            
            if ($playbookCount -eq 0) {
                $indicators += "No playbooks for emergency response"
            }
            
            if ($policyCount -lt 5) {
                $indicators += "Limited policies for standards ($policyCount)"
            }
            
            if ($pipelineCount -eq 0) {
                $indicators += "No DevOps pipelines for shift-left"
            }
            
            if ($opExRecs -gt 5) {
                $indicators += "High unresolved OpEx recommendations ($opExRecs)"
            }
            
            $evidence = @"
Operations Formalization Assessment:
- Runbooks: $runbookCount
- Playbooks: $playbookCount
- Policies: $policyCount
- Pipelines: $pipelineCount
- OpEx Recommendations: $opExRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE02' `
                    -Status 'Pass' `
                    -Message 'Formalized operations with automation and standards' `
                    -Metadata @{
                        Runbooks = $runbookCount
                        Playbooks = $playbookCount
                        Policies = $policyCount
                        Pipelines = $pipelineCount
                        OpExRecs = $opExRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE02' `
                    -Status 'Fail' `
                    -Message "Operations formalization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Informal operations lead to inconsistencies.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Automation Basics (Week 1)
1. **Create Runbooks**: For routine tasks
2. **Set Playbooks**: For emergencies
3. **Assign Policies**: For standards

### Phase 2: Shift-Left (Weeks 2-3)
1. **Deploy Pipelines**: For processes
2. **Address Recs**: For improvements
3. **Document SOPs**: With checklists

$evidence
"@ `
                    -RemediationScript @"
# Quick Operations Formalization Setup

# Create Runbook
New-AzAutomationRunbook -Name 'ops-routine' -ResourceGroupName 'rg' -AutomationAccountName 'auto' -Type PowerShell -Location 'eastus'

# Policy Assignment
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Audit VMs' }
New-AzPolicyAssignment -Name 'ops-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Basic ops setup - create checklists and playbooks"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE02' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
