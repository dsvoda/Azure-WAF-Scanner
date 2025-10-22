<#
.SYNOPSIS
    SE11 - Test security posture and operations

.DESCRIPTION
    Establish a comprehensive testing regimen that combines approaches to prevent security issues, validate threat prevention implementations, and test threat detection mechanisms. Rigorous testing validates controls, detects vulnerabilities proactively, and ensures resistance to attacks while maintaining confidentiality, integrity, and availability.

.NOTES
    Pillar: Security
    Recommendation: SE:11 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/test
#>

Register-WafCheck -CheckId 'SE11' `
    -Pillar 'Security' `
    -Title 'Test security posture and operations' `
    -Description 'Establish a comprehensive testing regimen that combines approaches to prevent security issues, validate threat prevention implementations, and test threat detection mechanisms. Rigorous testing validates controls, detects vulnerabilities proactively, and ensures resistance to attacks while maintaining confidentiality, integrity, and availability.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Testing', 'VulnerabilityAssessment', 'PenetrationTesting', 'ThreatSimulation') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/test' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess security testing indicators
            
            # 1. Defender Vulnerability Assessments
            $vulnQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/assessments'
| where properties.displayName contains 'vulnerability'
| summarize VulnAssessments = count()
"@
            $vulnResult = Invoke-AzResourceGraphQuery -Query $vulnQuery -SubscriptionId $SubscriptionId -UseCache
            $vulnCount = if ($vulnResult.Count -gt 0) { $vulnResult[0].VulnAssessments } else { 0 }
            
            # 2. Microsoft Sentinel for Hunting/Incident Simulation
            $sentinelQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationsmanagement/solutions'
| where name contains 'SecurityInsights'
| summarize SentinelInstances = count()
"@
            $sentinelResult = Invoke-AzResourceGraphQuery -Query $sentinelQuery -SubscriptionId $SubscriptionId -UseCache
            $sentinelCount = if ($sentinelResult.Count -gt 0) { $sentinelResult[0].SentinelInstances } else { 0 }
            
            # 3. DDoS Simulation (DDoS Plans as proxy for testing capability)
            $ddosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/ddosprotectionplans'
| summarize DDoSPlans = count()
"@
            $ddosResult = Invoke-AzResourceGraphQuery -Query $ddosQuery -SubscriptionId $SubscriptionId -UseCache
            $ddosCount = if ($ddosResult.Count -gt 0) { $ddosResult[0].DDoSPlans } else { 0 }
            
            # 4. DevOps Security Testing (AST via Defender for DevOps)
            $devopsPricing = Get-AzSecurityPricing -Name 'DevOps' -ErrorAction SilentlyContinue
            $isDevOpsEnabled = $devopsPricing -and $devopsPricing.PricingTier -eq 'Standard'
            
            $devopsConfigsQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/devopsconfigurations'
| summarize DevOpsConfigs = count()
"@
            $configsResult = Invoke-AzResourceGraphQuery -Query $devopsConfigsQuery -SubscriptionId $SubscriptionId -UseCache
            $configsCount = if ($configsResult.Count -gt 0) { $configsResult[0].DevOpsConfigs } else { 0 }
            
            # 5. Penetration Testing Indicators (Indirect: Security Assessments)
            $penTestQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/assessments'
| where properties.displayName contains 'penetration' or properties.displayName contains 'attack simulation'
| summarize PenTests = count()
"@
            $penResult = Invoke-AzResourceGraphQuery -Query $penTestQuery -SubscriptionId $SubscriptionId -UseCache
            $penCount = if ($penResult.Count -gt 0) { $penResult[0].PenTests } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($vulnCount -lt 10) {
                $indicators += "Limited vulnerability assessments performed ($vulnCount)"
            }
            
            if ($sentinelCount -eq 0) {
                $indicators += "No Microsoft Sentinel for threat hunting and simulation"
            }
            
            if ($ddosCount -eq 0) {
                $indicators += "No DDoS protection plans for simulation testing"
            }
            
            if (-not $isDevOpsEnabled) {
                $indicators += "Defender for DevOps not enabled for AST"
            } elseif ($configsCount -eq 0) {
                $indicators += "Defender for DevOps enabled but no configurations/repos connected"
            }
            
            if ($penCount -eq 0) {
                $indicators += "No penetration testing or attack simulations detected"
            }
            
            $evidence = @"
Security Testing Assessment:
- Vulnerability Assessments: $vulnCount
- Sentinel Instances: $sentinelCount
- DDoS Plans: $ddosCount
- Defender for DevOps: $isDevOpsEnabled (Configs: $configsCount)
- Pen Tests/Simulations: $penCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE11' `
                    -Status 'Pass' `
                    -Message 'Comprehensive security testing posture' `
                    -Metadata @{
                        VulnAssessments = $vulnCount
                        Sentinel = $sentinelCount
                        DDoS = $ddosCount
                        DevOpsEnabled = $isDevOpsEnabled
                        DevOpsConfigs = $configsCount
                        PenTests = $penCount
                    }
            } else {
                return New-WafResult -CheckId 'SE11' `
                    -Status 'Fail' `
                    -Message "Security testing gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Lack of security testing increases undetected vulnerabilities.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Enable Tools (Week 1)
1. **Activate Defender Scanning**: For vulnerabilities
2. **Deploy Sentinel**: For hunting
3. **Enable DevOps Security**: For AST

### Phase 2: Conduct Tests (Weeks 2-4)
1. **Run Simulations**: DDoS, attacks
2. **Perform Pen Tests**: Black/white box
3. **Integrate into SDLC**: Automate

$evidence
"@ `
                    -RemediationScript @"
# Quick Security Testing Setup

# Enable Defender Vulnerability Management
Set-AzSecurityPricing -Name 'VulnerabilityAssessment' -PricingTier 'Standard'

# Deploy Sentinel
New-AzSentinelSolution -WorkspaceName 'ws' -ResourceGroupName 'rg' -Kind 'SecurityInsights'

Write-Host "Testing tools configured - schedule simulations and pen tests"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE11' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
