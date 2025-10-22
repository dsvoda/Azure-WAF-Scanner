<#
.SYNOPSIS
    OE03 - Formalize development practices

.DESCRIPTION
    Formalize development practices by standardizing processes, tools, and templates. Use Infrastructure as Code (IaC), CI/CD pipelines, and governance to ensure consistency, repeatability, and quality in development.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:03 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-development-practices
#>

Register-WafCheck -CheckId 'OE03' `
    -Pillar 'OperationalExcellence' `
    -Title 'Formalize development practices' `
    -Description 'Formalize development practices by standardizing processes, tools, and templates. Use Infrastructure as Code (IaC), CI/CD pipelines, and governance to ensure consistency, repeatability, and quality in development.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'DevelopmentPractices', 'IaC', 'CI/CD', 'Governance') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-development-practices' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess development formalization indicators
            
            # 1. IaC Deployments (ARM/Bicep)
            $iacQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/deployments' or type =~ 'microsoft.resources/templatespecs'
| summarize IaCDeployments = count()
"@
            $iacResult = Invoke-AzResourceGraphQuery -Query $iacQuery -SubscriptionId $SubscriptionId -UseCache
            $iacCount = if ($iacResult.Count -gt 0) { $iacResult[0].IaCDeployments } else { 0 }
            
            # 2. Azure DevOps Pipelines
            $pipelineQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/pipelines'
| summarize Pipelines = count()
"@
            $pipelineResult = Invoke-AzResourceGraphQuery -Query $pipelineQuery -SubscriptionId $SubscriptionId -UseCache
            $pipelineCount = if ($pipelineResult.Count -gt 0) { $pipelineResult[0].Pipelines } else { 0 }
            
            # 3. Policies for Development Standards
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'IaC' or properties.displayName contains 'deployment' or properties.displayName contains 'dev' or properties.displayName contains 'CI/CD'
| summarize DevPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].DevPolicies } else { 0 }
            
            # 4. Template Specs/Versions for Standardization
            $templateQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/templatespecs/versions'
| summarize TemplateVersions = count()
"@
            $templateResult = Invoke-AzResourceGraphQuery -Query $templateQuery -SubscriptionId $SubscriptionId -UseCache
            $templateCount = if ($templateResult.Count -gt 0) { $templateResult[0].TemplateVersions } else { 0 }
            
            # 5. Advisor OpEx Recs for Dev Practices
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $devRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'deployment|IaC|CI/CD|pipeline' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($iacCount -eq 0) {
                $indicators += "No IaC deployments detected"
            }
            
            if ($pipelineCount -eq 0) {
                $indicators += "No CI/CD pipelines"
            }
            
            if ($policyCount -eq 0) {
                $indicators += "No policies for development standards"
            }
            
            if ($templateCount -eq 0) {
                $indicators += "No template specs for standardization"
            }
            
            if ($devRecs -gt 0) {
                $indicators += "Unresolved dev practice recommendations ($devRecs)"
            }
            
            $evidence = @"
Development Practices Assessment:
- IaC Deployments: $iacCount
- CI/CD Pipelines: $pipelineCount
- Dev Policies: $policyCount
- Template Versions: $templateCount
- Dev Recommendations: $devRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE03' `
                    -Status 'Pass' `
                    -Message 'Formalized development practices with IaC and CI/CD' `
                    -Metadata @{
                        IaC = $iacCount
                        Pipelines = $pipelineCount
                        Policies = $policyCount
                        Templates = $templateCount
                        DevRecs = $devRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE03' `
                    -Status 'Fail' `
                    -Message "Development formalization gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Informal dev practices lead to inconsistencies.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: IaC & Pipelines (Week 1)
1. **Deploy IaC**: Bicep/ARM
2. **Set Pipelines**: For CI/CD
3. **Create Templates**: Specs

### Phase 2: Governance (Weeks 2-3)
1. **Assign Policies**: For standards
2. **Address Recs**: For improvements
3. **Standardize Processes**: With docs

$evidence
"@ `
                    -RemediationScript @"
# Quick Dev Formalization Setup

# Create Template Spec
New-AzTemplateSpec -Name 'std-template' -Version '1.0' -ResourceGroupName 'rg' -Location 'eastus' -TemplateFile 'template.bicep'

# Policy for IaC
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Deploy with IaC' }
New-AzPolicyAssignment -Name 'dev-iac' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Basic dev practices - integrate with DevOps"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE03' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
