<#
.SYNOPSIS
    OE05 - Design for infrastructure as code

.DESCRIPTION
    Prepare resources and their configurations by using a standardized infrastructure as code (IaC) approach. Like other code, design IaC with consistent styles, appropriate modularization, and quality assurance. Prefer a declarative approach when possible.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:05 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/infrastructure-as-code-design
#>

Register-WafCheck -CheckId 'OE05' `
    -Pillar 'OperationalExcellence' `
    -Title 'Design for infrastructure as code' `
    -Description 'Prepare resources and their configurations by using a standardized infrastructure as code (IaC) approach. Like other code, design IaC with consistent styles, appropriate modularization, and quality assurance. Prefer a declarative approach when possible.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'IaC', 'Declarative', 'Modularization', 'QualityAssurance') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/infrastructure-as-code-design' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess IaC design indicators
            
            # 1. IaC Deployments (ARM/Bicep/Template Specs)
            $iacQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/deployments' or type =~ 'microsoft.resources/templatespecs'
| summarize IaCDeployments = count()
"@
            $iacResult = Invoke-AzResourceGraphQuery -Query $iacQuery -SubscriptionId $SubscriptionId -UseCache
            $iacCount = if ($iacResult.Count -gt 0) { $iacResult[0].IaCDeployments } else { 0 }
            
            # 2. Template Specs for Modularization
            $templateQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/templatespecs'
| summarize TemplateSpecs = count()
"@
            $templateResult = Invoke-AzResourceGraphQuery -Query $templateQuery -SubscriptionId $SubscriptionId -UseCache
            $templateCount = if ($templateResult.Count -gt 0) { $templateResult[0].TemplateSpecs } else { 0 }
            
            # 3. Policies Enforcing IaC Standards
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'IaC' or properties.displayName contains 'template' or properties.displayName contains 'deployment'
| summarize IaCPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].IaCPolicies } else { 0 }
            
            # 4. Third-Party IaC (Terraform as proxy via configs)
            $terraformQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.security/devopsconfigurations' and properties.type contains 'Terraform'
| summarize TerraformConfigs = count()
"@
            $terraformResult = Invoke-AzResourceGraphQuery -Query $terraformQuery -SubscriptionId $SubscriptionId -UseCache
            $terraformCount = if ($terraformResult.Count -gt 0) { $terraformResult[0].TerraformConfigs } else { 0 }
            
            # 5. Advisor Recs for IaC/Deployments
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $iacRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'IaC|deployment|template' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($iacCount -eq 0) {
                $indicators += "No IaC deployments detected"
            }
            
            if ($templateCount -eq 0) {
                $indicators += "No template specs for modularization"
            }
            
            if ($policyCount -eq 0) {
                $indicators += "No policies enforcing IaC standards"
            }
            
            if ($terraformCount -gt 0) {
                $indicators += "Third-party IaC detected ($terraformCount) - ensure consistency"
            }
            
            if ($iacRecs -gt 0) {
                $indicators += "Unresolved IaC recommendations ($iacRecs)"
            }
            
            $evidence = @"
IaC Design Assessment:
- IaC Deployments: $iacCount
- Template Specs: $templateCount
- IaC Policies: $policyCount
- Terraform Configs: $terraformCount
- IaC Recommendations: $iacRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE05' `
                    -Status 'Pass' `
                    -Message 'Effective IaC design with standardization' `
                    -Metadata @{
                        IaCDeployments = $iacCount
                        TemplateSpecs = $templateCount
                        Policies = $policyCount
                        Terraform = $terraformCount
                        IaCRecs = $iacRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE05' `
                    -Status 'Fail' `
                    -Message "IaC design gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Poor IaC design leads to inconsistencies.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: IaC Basics (Week 1)
1. **Adopt Bicep/ARM**: For declarative
2. **Use Template Specs**: For modules
3. **Prefer Native Tools**: Over third-party

### Phase 2: Quality & Standards (Weeks 2-3)
1. **Enforce Policies**: For IaC
2. **Address Recs**: For improvements
3. **Document Styles**: For consistency

$evidence
"@ `
                    -RemediationScript @"
# Quick IaC Design Setup

# Create Template Spec
New-AzTemplateSpec -Name 'iac-spec' -Version '1.0' -ResourceGroupName 'rg' -Location 'eastus' -TemplateFile 'template.json'

# Policy for IaC
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Require IaC' }
New-AzPolicyAssignment -Name 'iac-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Basic IaC setup - use declarative and modules"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE05' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
