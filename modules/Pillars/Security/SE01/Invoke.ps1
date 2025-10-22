<#
.SYNOPSIS
    SE01 - Establish a security baseline

.DESCRIPTION
    Validates that a security baseline is established, aligned with compliance requirements, industry standards, and platform recommendations. Measures the workload architecture and operations against the baseline to sustain or improve security posture.

.NOTES
    Pillar: Security
    Recommendation: SE:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/establish-baseline
#>

Register-WafCheck -CheckId 'SE01' `
    -Pillar 'Security' `
    -Title 'Establish a security baseline' `
    -Description 'Establish a security baseline that''s aligned to compliance requirements, industry standards, and platform recommendations. Regularly measure your workload architecture and operations against the baseline to sustain or improve your security posture over time.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Baseline', 'Compliance', 'Standards') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/establish-baseline' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess security baseline indicators
            
            # 1. Check for Microsoft Defender for Cloud enablement
            $defenderPlansQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/pricings'
| where properties.pricingTier == 'Standard'
| summarize DefenderEnabledPlans = count()
"@
            $defenderResult = Invoke-AzResourceGraphQuery -Query $defenderPlansQuery -SubscriptionId $SubscriptionId -UseCache
            
            $defenderEnabled = if ($defenderResult.Count -gt 0) { $defenderResult[0].DefenderEnabledPlans } else { 0 }
            
            # 2. Check for policy assignments (indicating baseline enforcement)
            $policyAssignmentsQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| summarize PolicyAssignments = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyAssignmentsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].PolicyAssignments } else { 0 }
            
            # 3. Check for regulatory compliance standards in Defender for Cloud
            $complianceStandardsQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/regulatorycompliancestandards'
| summarize ComplianceStandards = dcount(name)
"@
            $complianceResult = Invoke-AzResourceGraphQuery -Query $complianceStandardsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $standardsCount = if ($complianceResult.Count -gt 0) { $complianceResult[0].ComplianceStandards } else { 0 }
            
            # 4. Check for Azure Policy initiatives (built-in baselines like Azure Security Benchmark)
            $initiativesQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policydefinitions'
| where properties.policyType == 'BuiltIn' and properties.displayName contains 'benchmark' or properties.displayName contains 'CIS' or properties.displayName contains 'NIST'
| summarize BuiltInInitiatives = count()
"@
            $initiativesResult = Invoke-AzResourceGraphQuery -Query $initiativesQuery -SubscriptionId $SubscriptionId -UseCache
            
            $initiativesCount = if ($initiativesResult.Count -gt 0) { $initiativesResult[0].BuiltInInitiatives } else { 0 }
            
            # 5. Check for security assessments from Defender
            $assessmentsQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/assessments'
| summarize Assessments = count()
"@
            $assessmentsResult = Invoke-AzResourceGraphQuery -Query $assessmentsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $assessmentsCount = if ($assessmentsResult.Count -gt 0) { $assessmentsResult[0].Assessments } else { 0 }
            
            # Calculate baseline score
            $baselineIndicators = @()
            
            if ($defenderEnabled -eq 0) {
                $baselineIndicators += "Microsoft Defender for Cloud not enabled on any plans"
            }
            
            if ($policyCount -lt 5) {
                $baselineIndicators += "Limited policy assignments ($policyCount) - insufficient enforcement"
            }
            
            if ($standardsCount -lt 3) {
                $baselineIndicators += "Few regulatory compliance standards enabled ($standardsCount)"
            }
            
            if ($initiativesCount -eq 0) {
                $baselineIndicators += "No built-in security benchmark initiatives assigned"
            }
            
            if ($assessmentsCount -lt 10) {
                $baselineIndicators += "Limited security assessments performed ($assessmentsCount)"
            }
            
            $evidence = @"
Security Baseline Assessment:
- Defender for Cloud Plans Enabled: $defenderEnabled
- Policy Assignments: $policyCount
- Compliance Standards: $standardsCount
- Built-in Initiatives: $initiativesCount
- Security Assessments: $assessmentsCount
"@
            
            # Determine status
            if ($baselineIndicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE01' `
                    -Status 'Pass' `
                    -Message 'Strong security baseline established with comprehensive coverage' `
                    -Metadata @{
                        DefenderPlans = $defenderEnabled
                        Policies = $policyCount
                        Standards = $standardsCount
                        Initiatives = $initiativesCount
                        Assessments = $assessmentsCount
                    }
            } else {
                return New-WafResult -CheckId 'SE01' `
                    -Status 'Fail' `
                    -Message "Security baseline gaps identified: $($baselineIndicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: No established security baseline increases risk exposure.

Issues identified:
$($baselineIndicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Enable Core Services (Week 1)
1. **Activate Defender for Cloud**: Enable standard tier plans
2. **Assign Policies**: Implement Azure Security Benchmark
3. **Enable Compliance Standards**: Add CIS, NIST, etc.

### Phase 2: Assessment & Improvement (Weeks 2-4)
1. **Run Assessments**: Use Defender dashboard
2. **Document Baseline**: Create policy document
3. **Monitor Compliance**: Set up regular reviews

$evidence
"@ `
                    -RemediationScript @"
# Quick Security Baseline Setup

# Enable Defender for Cloud
Set-AzSecurityPricing -Name 'VirtualMachines' -PricingTier 'Standard'
Set-AzSecurityPricing -Name 'SqlServers' -PricingTier 'Standard'
Set-AzSecurityPricing -Name 'AppServices' -PricingTier 'Standard'

# Assign Azure Security Benchmark policy
`$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Azure security baseline' }
New-AzPolicyAssignment -Name 'SecurityBaseline' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

Write-Host "Baseline policies assigned - review in Defender for Cloud dashboard"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE01' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
