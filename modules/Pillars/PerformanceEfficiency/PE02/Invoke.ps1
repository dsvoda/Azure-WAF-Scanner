<#
.SYNOPSIS
    PE02 - Plan for capacity

.DESCRIPTION
    Plan for capacity by forecasting demand, defining capacity targets, and using autoscaling. Monitor utilization and adjust resources to meet performance requirements efficiently.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:02 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning
#>

Register-WafCheck -CheckId 'PE02' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Plan for capacity' `
    -Description 'Plan for capacity by forecasting demand, defining capacity targets, and using autoscaling. Monitor utilization and adjust resources to meet performance requirements efficiently.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'CapacityPlanning', 'Autoscaling', 'Forecasting', 'Utilization') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess capacity planning indicators
            
            # 1. Autoscaling Enabled
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize AutoscaleSettings = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].AutoscaleSettings } else { 0 }
            
            # 2. Load Testing Services
            $loadTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.loadtestservice/loadtests'
| summarize LoadTests = count()
"@
            $loadTestResult = Invoke-AzResourceGraphQuery -Query $loadTestQuery -SubscriptionId $SubscriptionId -UseCache
            $loadTestCount = if ($loadTestResult.Count -gt 0) { $loadTestResult[0].LoadTests } else { 0 }
            
            # 3. Utilization Monitoring (Alerts on CPU/Memory)
            $utilAlertQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/metricalerts'
| where properties.criteria.metricName contains 'CPU' or properties.criteria.metricName contains 'Memory' or properties.criteria.metricName contains 'Utilization'
| summarize UtilAlerts = count()
"@
            $utilAlertResult = Invoke-AzResourceGraphQuery -Query $utilAlertQuery -SubscriptionId $SubscriptionId -UseCache
            $utilAlertCount = if ($utilAlertResult.Count -gt 0) { $utilAlertResult[0].UtilAlerts } else { 0 }
            
            # 4. Reservations/Savings Plans (for capacity commitment)
            $reserveQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.capacity/reservationorders' or type =~ 'microsoft.billingbenefits/savingsplanorders'
| summarize Reserves = count()
"@
            $reserveResult = Invoke-AzResourceGraphQuery -Query $reserveQuery -SubscriptionId $SubscriptionId -UseCache
            $reserveCount = if ($reserveResult.Count -gt 0) { $reserveResult[0].Reserves } else { 0 }
            
            # 5. Advisor Capacity Recs
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $capRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'capacity|scale|utilization' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling configurations"
            }
            
            if ($loadTestCount -eq 0) {
                $indicators += "No load testing services"
            }
            
            if ($utilAlertCount -eq 0) {
                $indicators += "No utilization alerts"
            }
            
            if ($reserveCount -eq 0) {
                $indicators += "No reservations/savings plans for committed capacity"
            }
            
            if ($capRecs -gt 0) {
                $indicators += "Unresolved capacity recommendations ($capRecs)"
            }
            
            $evidence = @"
Capacity Planning Assessment:
- Autoscaling: $autoscaleCount
- Load Tests: $loadTestCount
- Utilization Alerts: $utilAlertCount
- Reservations/Plans: $reserveCount
- Capacity Recommendations: $capRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE02' `
                    -Status 'Pass' `
                    -Message 'Effective capacity planning in place' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        LoadTests = $loadTestCount
                        UtilAlerts = $utilAlertCount
                        Reserves = $reserveCount
                        CapRecs = $capRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE02' `
                    -Status 'Fail' `
                    -Message "Capacity planning gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Poor planning leads to inefficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Enable Autoscaling**: For resources
2. **Run Load Tests**: For forecasting
3. **Set Utilization Alerts**: For monitoring

### Phase 2: Advanced (Weeks 2-3)
1. **Commit Reservations**: For savings
2. **Address Recs**: For improvements
3. **Forecast Demand**: With tools

$evidence
"@ `
                    -RemediationScript @"
# Quick Capacity Planning Setup

# Enable Autoscaling
New-AzAutoscaleSetting -Name 'pe-scale' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1)

# Create Load Test
New-AzLoadTest -Name 'pe-load' -ResourceGroupName 'rg' -Location 'eastus'

Write-Host "Basic capacity planning - forecast and monitor"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE02' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
