<#
.SYNOPSIS
    OE04 - Standardize tools and processes

.DESCRIPTION
    Optimize software development and quality assurance processes by following industry-proven practices for development and testing.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:04 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/tools-processes
#>

Register-WafCheck -CheckId 'OE04' `
    -Pillar 'OperationalExcellence' `
    -Title 'Standardize tools and processes' `
    -Description 'Optimize software development and quality assurance processes by following industry-proven practices for development and testing.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'Standardization', 'Tools', 'Processes', 'IaC') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/tools-processes' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess standardization indicators
            
            # 1. Azure DevOps or GitHub Integrations
            $devopsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/projects' or type =~ 'microsoft.security/devopsconfigurations'
| summarize DevOpsTools = count()
"@
            $devopsResult = Invoke-AzResourceGraphQuery -Query $devopsQuery -SubscriptionId $SubscriptionId -UseCache
            $devopsCount = if ($devopsResult.Count -gt 0) { $devopsResult[0].DevOpsTools } else { 0 }
            
            # 2. IaC Usage (Template Specs, Deployments)
            $iacQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/templatespecs' or type =~ 'microsoft.resources/deployments'
| summarize IaC = count()
"@
            $iacResult = Invoke-AzResourceGraphQuery -Query $iacQuery -SubscriptionId $SubscriptionId -UseCache
            $iacCount = if ($iacResult.Count -gt 0) { $iacResult[0].IaC } else { 0 }
            
            # 3. Policies for Standards
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| summarize Policies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].Policies } else { 0 }
            
            # 4. Testing Tools (Load Testing, App Insights)
            $testingQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests' or type =~ 'microsoft.insights/components'
| summarize TestingTools = count()
"@
            $testingResult = Invoke-AzResourceGraphQuery -Query $testingQuery -SubscriptionId $SubscriptionId -UseCache
            $testingCount = if ($testingResult.Count -gt 0) { $testingResult[0].TestingTools } else { 0 }
            
            # 5. Advisor OpEx Recs
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $opExRecs = $advisor | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($devopsCount -eq 0) {
                $indicators += "No DevOps tools or integrations"
            }
            
            if ($iacCount -eq 0) {
                $indicators += "No IaC usage detected"
            }
            
            if ($policyCount -lt 5) {
                $indicators += "Limited policies for standards ($policyCount)"
            }
            
            if ($testingCount -eq 0) {
                $indicators += "No testing tools like Load Testing or App Insights"
            }
            
            if ($opExRecs -gt 5) {
                $indicators += "High unresolved OpEx recommendations ($opExRecs)"
            }
            
            $evidence = @"
Standardization Assessment:
- DevOps Tools: $devopsCount
- IaC Usage: $iacCount
- Policies: $policyCount
- Testing Tools: $testingCount
- OpEx Recommendations: $opExRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE04' `
                    -Status 'Pass' `
                    -Message 'Standardized tools and processes in place' `
                    -Metadata @{
                        DevOps = $devopsCount
                        IaC = $iacCount
                        Policies = $policyCount
                        Testing = $testingCount
                        OpExRecs = $opExRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE04' `
                    -Status 'Fail' `
                    -Message "Standardization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Non-standard tools/processes hinder efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Tools Standardization (Week 1)
1. **Adopt Azure DevOps/GitHub**: For CI/CD
2. **Implement IaC**: Bicep/Terraform
3. **Deploy Testing Tools**: Load Testing/App Insights

### Phase 2: Processes (Weeks 2-3)
1. **Assign Policies**: For enforcement
2. **Address Recs**: For improvements
3. **Train on Standards**: Branching, reviews

$evidence
"@ `
                    -RemediationScript @"
# Quick Standardization Setup

# Deploy App Insights for Testing
New-AzApplicationInsights -ResourceGroupName 'rg' -Name 'oe-test' -Location 'eastus'

# Policy for Standards
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Require IaC' }
New-AzPolicyAssignment -Name 'oe-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Basic standardization - implement IaC and CI/CD"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE04' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
