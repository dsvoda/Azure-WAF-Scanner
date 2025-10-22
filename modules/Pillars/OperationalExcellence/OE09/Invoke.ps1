<#
.SYNOPSIS
    OE09 - Automate tasks

.DESCRIPTION
    Automate all tasks that don't benefit from the insight and adaptability of human intervention, are highly procedural, and have a shelf-life that yields a return on automation investment. When possible, choose off-the-shelf software for automation versus custom implementations.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:09 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/automate-tasks
#>

Register-WafCheck -CheckId 'OE09' `
    -Pillar 'OperationalExcellence' `
    -Title 'Automate tasks' `
    -Description 'Automate all tasks that don''t benefit from the insight and adaptability of human intervention, are highly procedural, and have a shelf-life that yields a return on automation investment. When possible, choose off-the-shelf software for automation versus custom implementations.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'Automation', 'Runbooks', 'OffTheShelf', 'ROI') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/automate-tasks' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess automation indicators
            
            # 1. Azure Automation Runbooks
            $runbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts/runbooks'
| summarize Runbooks = count()
"@
            $runbookResult = Invoke-AzResourceGraphQuery -Query $runbookQuery -SubscriptionId $SubscriptionId -UseCache
            $runbookCount = if ($runbookResult.Count -gt 0) { $runbookResult[0].Runbooks } else { 0 }
            
            # 2. Azure Functions and Logic Apps
            $serverlessQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites' and kind contains 'functionapp' or type =~ 'microsoft.logic/workflows'
| summarize ServerlessAutomation = count()
"@
            $serverlessResult = Invoke-AzResourceGraphQuery -Query $serverlessQuery -SubscriptionId $SubscriptionId -UseCache
            $serverlessCount = if ($serverlessResult.Count -gt 0) { $serverlessResult[0].ServerlessAutomation } else { 0 }
            
            # 3. Azure Update Manager
            $updateQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts' and properties.description contains 'update'
| summarize UpdateManagers = count()
"@
            $updateResult = Invoke-AzResourceGraphQuery -Query $updateQuery -SubscriptionId $SubscriptionId -UseCache
            $updateCount = if ($updateResult.Count -gt 0) { $updateResult[0].UpdateManagers } else { 0 }
            
            # 4. Deployment Environments and IaC
            $deployQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devtestlab/labs' or type =~ 'microsoft.resources/deployments'
| summarize DeployTools = count()
"@
            $deployResult = Invoke-AzResourceGraphQuery -Query $deployQuery -SubscriptionId $SubscriptionId -UseCache
            $deployCount = if ($deployResult.Count -gt 0) { $deployResult[0].DeployTools } else { 0 }
            
            # 5. Advisor Automation Recs
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $autoRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'automat|runbook|logic|function' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($runbookCount -eq 0) {
                $indicators += "No Automation runbooks detected"
            }
            
            if ($serverlessCount -eq 0) {
                $indicators += "No Functions or Logic Apps for task automation"
            }
            
            if ($updateCount -eq 0) {
                $indicators += "No Update Manager configurations"
            }
            
            if ($deployCount -eq 0) {
                $indicators += "No deployment environments or IaC"
            }
            
            if ($autoRecs -gt 0) {
                $indicators += "Unresolved automation recommendations ($autoRecs)"
            }
            
            $evidence = @"
Automation Assessment:
- Runbooks: $runbookCount
- Serverless (Functions/Logic): $serverlessCount
- Update Managers: $updateCount
- Deploy Tools/IaC: $deployCount
- Automation Recommendations: $autoRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE09' `
                    -Status 'Pass' `
                    -Message 'Effective task automation with off-the-shelf tools' `
                    -Metadata @{
                        Runbooks = $runbookCount
                        Serverless = $serverlessCount
                        Updates = $updateCount
                        Deploy = $deployCount
                        AutoRecs = $autoRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE09' `
                    -Status 'Fail' `
                    -Message "Automation gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Manual tasks reduce efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basic Automation (Week 1)
1. **Deploy Runbooks**: For procedural tasks
2. **Use Functions/Logic**: For workflows
3. **Enable Update Manager**: For patching

### Phase 2: Advanced (Weeks 2-3)
1. **Set Deployment Envs**: For consistency
2. **Address Recs**: For improvements
3. **Calculate ROI**: For automation

$evidence
"@ `
                    -RemediationScript @"
# Quick Automation Setup

# Create Runbook
New-AzAutomationRunbook -Name 'oe-auto' -ResourceGroupName 'rg' -AutomationAccountName 'auto' -Type PowerShell -Location 'eastus'

# Deploy Function App
New-AzFunctionApp -Name 'oe-function' -ResourceGroupName 'rg' -Location 'eastus' -StorageAccountName 'store' -FunctionsVersion '4' -Runtime 'PowerShell' -RuntimeVersion '7.0'

Write-Host "Basic automation - expand with custom scripts"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE09' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
