<#
.SYNOPSIS
    OE01 - Create a DevOps culture

.DESCRIPTION
    Create a DevOps culture by empowering teams with shared goals, modern tools, and processes. Focus on collaboration, automation, and continuous improvement to enhance operational excellence.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/devops-culture
#>

Register-WafCheck -CheckId 'OE01' `
    -Pillar 'OperationalExcellence' `
    -Title 'Create a DevOps culture' `
    -Description 'Create a DevOps culture by empowering teams with shared goals, modern tools, and processes. Focus on collaboration, automation, and continuous improvement to enhance operational excellence.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'DevOps', 'Automation', 'CI/CD', 'Collaboration') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/devops-culture' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess DevOps culture indicators
            
            # 1. Azure DevOps Projects or GitHub Integrations
            $devopsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/projects' or (type =~ 'microsoft.security/devopsconfigurations' and properties.type contains 'GitHub')
| summarize DevOpsTools = count()
"@
            $devopsResult = Invoke-AzResourceGraphQuery -Query $devopsQuery -SubscriptionId $SubscriptionId -UseCache
            $devopsCount = if ($devopsResult.Count -gt 0) { $devopsResult[0].DevOpsTools } else { 0 }
            
            # 2. Automation Accounts for CI/CD
            $automationQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts'
| summarize AutomationAccounts = count()
"@
            $automationResult = Invoke-AzResourceGraphQuery -Query $automationQuery -SubscriptionId $SubscriptionId -UseCache
            $automationCount = if ($automationResult.Count -gt 0) { $automationResult[0].AutomationAccounts } else { 0 }
            
            # 3. IaC Usage (Bicep/ARM Templates)
            $iacQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/templatespecs' or type =~ 'microsoft.resources/deployments'
| summarize IaCDeployments = count()
"@
            $iacResult = Invoke-AzResourceGraphQuery -Query $iacQuery -SubscriptionId $SubscriptionId -UseCache
            $iacCount = if ($iacResult.Count -gt 0) { $iacResult[0].IaCDeployments } else { 0 }
            
            # 4. Collaboration Tools (e.g., Microsoft Teams integrations, but hard to query; use Sentinel/Insights as proxy for monitoring/collaboration)
            $collabQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/components' or type =~ 'microsoft.operationsmanagement/solutions'
| summarize CollabTools = count()
"@
            $collabResult = Invoke-AzResourceGraphQuery -Query $collabQuery -SubscriptionId $SubscriptionId -UseCache
            $collabCount = if ($collabResult.Count -gt 0) { $collabResult[0].CollabTools } else { 0 }
            
            # 5. Advisor OpEx Recs for Processes
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $opExRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($devopsCount -eq 0) {
                $indicators += "No DevOps tools or integrations detected"
            }
            
            if ($automationCount -eq 0) {
                $indicators += "No automation accounts for CI/CD"
            }
            
            if ($iacCount -eq 0) {
                $indicators += "No IaC deployments detected"
            }
            
            if ($collabCount -eq 0) {
                $indicators += "No monitoring tools for collaboration"
            }
            
            if ($opExRecs -gt 5) {
                $indicators += "High unresolved OpEx recommendations ($opExRecs)"
            }
            
            $evidence = @"
DevOps Culture Assessment:
- DevOps Tools: $devopsCount
- Automation Accounts: $automationCount
- IaC Deployments: $iacCount
- Collab Tools: $collabCount
- OpEx Recommendations: $opExRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE01' `
                    -Status 'Pass' `
                    -Message 'Strong DevOps culture with tools and processes' `
                    -Metadata @{
                        DevOps = $devopsCount
                        Automation = $automationCount
                        IaC = $iacCount
                        Collab = $collabCount
                        OpExRecs = $opExRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE01' `
                    -Status 'Fail' `
                    -Message "DevOps culture gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Weak DevOps culture hinders efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Tools Setup (Week 1)
1. **Deploy DevOps**: Projects/repos
2. **Set Automation**: For CI/CD
3. **Use IaC**: Bicep/ARM

### Phase 2: Culture Building (Weeks 2-3)
1. **Enable Monitoring**: For insights
2. **Address Recs**: For improvements
3. **Train Teams**: On DevOps

$evidence
"@ `
                    -RemediationScript @"
# Quick DevOps Setup

# Create Automation Account
New-AzAutomationAccount -ResourceGroupName 'rg' -Name 'devops-auto' -Location 'eastus'

Write-Host "Basic DevOps tools - integrate with Azure DevOps/GitHub"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE01' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
