<#
.SYNOPSIS
    RE08 - Test for resiliency and availability

.DESCRIPTION
    Test for resiliency and availability scenarios by applying the principles of chaos engineering. Ensure that your graceful degradation implementation and scaling strategies are effective by performing active malfunction and simulated load testing.

.NOTES
    Pillar: Reliability
    Recommendation: RE:08 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/reliability/testing-strategy
#>

Register-WafCheck -CheckId 'RE08' `
    -Pillar 'Reliability' `
    -Title 'Test for resiliency and availability' `
    -Description 'Test for resiliency and availability scenarios by applying the principles of chaos engineering. Ensure that your graceful degradation implementation and scaling strategies are effective by performing active malfunction and simulated load testing.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'Testing', 'ChaosEngineering', 'ResiliencyTesting') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/reliability/testing-strategy' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Initialize assessment
            $issues = @()
            $totalTests = 0
            
            # 1. Chaos Studio - Check for experiments
            $chaosQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.chaos/experiments'
| extend 
    state = tostring(properties.state)
| project 
    id, name, resourceGroup, state
"@
            $experiments = Invoke-AzResourceGraphQuery -Query $chaosQuery -SubscriptionId $SubscriptionId -UseCache
            
            $activeExperiments = $($experiments | Where-Object { $_.state -eq 'Enabled' } | Measure-Object).Count
            $totalTests += $experiments.Count
            
            if ($experiments.Count -eq 0) {
                $issues += "No Chaos Studio experiments configured"
            }
            
            # 2. App Insights - Check for availability tests
            $appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue
            $availabilityTests = 0
            foreach ($ai in $appInsights) {
                $tests = Get-AzApplicationInsightsWebTest -ResourceGroupName $ai.ResourceGroup -ErrorAction SilentlyContinue
                $availabilityTests += $tests.Count
            }
            $totalTests += $availabilityTests
            
            if ($availabilityTests -eq 0) {
                $issues += "No availability tests in Application Insights"
            }
            
            # 3. Load Testing services
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| project 
    id, name
"@
            $loadTests = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $totalTests += $loadTests.Count
            
            if ($loadTests.Count -eq 0) {
                $issues += "No Azure Load Testing resources configured"
            }
            
            $evidence = @"
Resiliency Testing Assessment:
- Chaos Experiments: $($experiments.Count) total, $activeExperiments active
- Availability Tests: $availabilityTests
- Load Tests: $($loadTests.Count)
- Total Testing Resources: $totalTests
"@
            
            if ($totalTests -ge 5 -and $issues.Count -eq 0) {
                return New-WafResult -CheckId 'RE08' `
                    -Status 'Pass' `
                    -Message "Comprehensive resiliency testing in place with $totalTests testing resources" `
                    -Metadata @{
                        ChaosExperiments = $experiments.Count
                        ActiveChaos = $activeExperiments
                        AvailabilityTests = $availabilityTests
                        LoadTests = $loadTests.Count
                    }
            } else {
                return New-WafResult -CheckId 'RE08' `
                    -Status 'Fail' `
                    -Message "Inadequate resiliency testing: Only $totalTests testing resources, $($issues.Count) issues" `
                    -Recommendation @"
**CRITICAL**: No resiliency testing strategy implemented.

Issues identified:
$($issues | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basic Testing Setup (Week 1)
1. **Deploy Chaos Studio**: Create first experiment
2. **Add Availability Tests**: For critical endpoints
3. **Run Load Tests**: Simulate traffic

### Phase 2: Chaos Engineering (Weeks 2-4)
1. **Inject Faults**: Test failure scenarios
2. **Validate Recovery**: Measure RTO/RPO
3. **Automate Tests**: CI/CD integration

$evidence
"@ `
                    -RemediationScript @"
# Quick Chaos Experiment Setup
New-AzChaosExperiment -ResourceGroupName 'rg-test' -Name 'chaos-basic' -Location 'eastus' -DefinitionFile 'experiment.json'

# Availability Test
New-AzApplicationInsightsWebTest -ResourceGroupName 'rg-monitor' -Name 'avail-test' -Location 'eastus' -Kind 'ping' -Enabled
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE08' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
