<#
.SYNOPSIS
    OE06 - Build a workload supply chain

.DESCRIPTION
    Build a workload supply chain that drives proposed changes through predictable, automated pipelines. The pipelines test and promote those changes across environments. Optimize a supply chain to make your workload reliable, secure, cost effective, and performant.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:06 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain
#>

Register-WafCheck -CheckId 'OE06' `
    -Pillar 'OperationalExcellence' `
    -Title 'Build a workload supply chain' `
    -Description 'Build a workload supply chain that drives proposed changes through predictable, automated pipelines. The pipelines test and promote those changes across environments. Optimize a supply chain to make your workload reliable, secure, cost effective, and performant.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'SupplyChain', 'CI/CD', 'Automation', 'Pipelines') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess supply chain indicators
            
            # 1. CI/CD Pipelines (Azure DevOps or GitHub)
            $pipelineQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.devops/pipelines' or type =~ 'microsoft.security/devopsconfigurations'
| summarize Pipelines = count()
"@
            $pipelineResult = Invoke-AzResourceGraphQuery -Query $pipelineQuery -SubscriptionId $SubscriptionId -UseCache
            $pipelineCount = if ($pipelineResult.Count -gt 0) { $pipelineResult[0].Pipelines } else { 0 }
            
            # 2. Automated Testing (Load Tests, Security Configurations)
            $testingQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests' or type =~ 'microsoft.security/devopsconfigurations'
| summarize TestingTools = count()
"@
            $testingResult = Invoke-AzResourceGraphQuery -Query $testingQuery -SubscriptionId $SubscriptionId -UseCache
            $testingCount = if ($testingResult.Count -gt 0) { $testingResult[0].TestingTools } else { 0 }
            
            # 3. Landing Zones/Management Groups
            $lzQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.management/managementgroups' or tags['landingZone'] == 'true'
| summarize LandingZones = count()
"@
            $lzResult = Invoke-AzResourceGraphQuery -Query $lzQuery -SubscriptionId $SubscriptionId -UseCache
            $lzCount = if ($lzResult.Count -gt 0) { $lzResult[0].LandingZones } else { 0 }
            
            # 4. IaC Deployments
            $iacQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/deployments'
| summarize IaCDeployments = count()
"@
            $iacResult = Invoke-AzResourceGraphQuery -Query $iacQuery -SubscriptionId $SubscriptionId -UseCache
            $iacCount = if ($iacResult.Count -gt 0) { $iacResult[0].IaCDeployments } else { 0 }
            
            # 5. Advisor Recs for Supply Chain
            $advisor = Get-AzAdvisorRecommendation -Category OperationalExcellence -ErrorAction SilentlyContinue
            $supplyRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'pipeline|deployment|supply|chain' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($pipelineCount -eq 0) {
                $indicators += "No CI/CD pipelines detected"
            }
            
            if ($testingCount -eq 0) {
                $indicators += "No automated testing tools"
            }
            
            if ($lzCount -eq 0) {
                $indicators += "No landing zones/management groups"
            }
            
            if ($iacCount -eq 0) {
                $indicators += "No IaC deployments"
            }
            
            if ($supplyRecs -gt 0) {
                $indicators += "Unresolved supply chain recommendations ($supplyRecs)"
            }
            
            $evidence = @"
Supply Chain Assessment:
- CI/CD Pipelines: $pipelineCount
- Testing Tools: $testingCount
- Landing Zones: $lzCount
- IaC Deployments: $iacCount
- Supply Recommendations: $supplyRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE06' `
                    -Status 'Pass' `
                    -Message 'Effective workload supply chain with automation' `
                    -Metadata @{
                        Pipelines = $pipelineCount
                        Testing = $testingCount
                        LandingZones = $lzCount
                        IaC = $iacCount
                        SupplyRecs = $supplyRecs
                    }
            } else {
                return New-WafResult -CheckId 'OE06' `
                    -Status 'Fail' `
                    -Message "Supply chain gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Weak supply chain impairs reliability.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Pipeline Basics (Week 1)
1. **Set Up CI/CD**: Azure DevOps/GitHub
2. **Enable Testing**: Integration/smoke
3. **Deploy IaC**: For stamps

### Phase 2: Advanced (Weeks 2-3)
1. **Create Landing Zones**: For envs
2. **Address Recs**: For improvements
3. **Optimize Pipelines**: For efficiency

$evidence
"@ `
                    -RemediationScript @"
# Quick Supply Chain Setup

# Create DevOps Pipeline (manual in portal)
# Enable Testing
New-AzLoadTest -Name 'oe-test' -ResourceGroupName 'rg' -Location 'eastus'

Write-Host "Basic supply chain - build full pipelines"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE06' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
