<#
.SYNOPSIS
    CO12 - Optimize scaling costs

.DESCRIPTION
    Evaluate alternative scaling configurations, and align with the cost model. Considerations should include utilization against the inherit limits of every instance, resource, and scale unit boundary. Use strategies for controlling demand and supply.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:12 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-scaling-costs
#>

Register-WafCheck -CheckId 'CO12' `
    -Pillar 'CostOptimization' `
    -Title 'Optimize scaling costs' `
    -Description 'Evaluate alternative scaling configurations, and align with the cost model. Considerations should include utilization against the inherit limits of every instance, resource, and scale unit boundary. Use strategies for controlling demand and supply.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'Scaling', 'Autoscaling', 'EventBased', 'DemandSupply') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/optimize-scaling-costs' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess scaling optimization indicators
            
            # 1. Autoscaling Settings with Rules
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize AutoscaleSettings = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].AutoscaleSettings } else { 0 }
            
            # 2. Event-Based Scaling (Queues, KEDA in AKS)
            $queueQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.servicebus/namespaces/queues' or type =~ 'microsoft.storage/storageaccounts/queueservices/queues'
| summarize Queues = count()
"@
            $queueResult = Invoke-AzResourceGraphQuery -Query $queueQuery -SubscriptionId $SubscriptionId -UseCache
            $queueCount = if ($queueResult.Count -gt 0) { $queueResult[0].Queues } else { 0 }
            
            $aksKEDAQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| extend addons = properties.addonProfiles
| where addons.keda.enabled == true
| summarize KEDAEnabledAKS = count()
"@
            $kedaResult = Invoke-AzResourceGraphQuery -Query $aksKEDAQuery -SubscriptionId $SubscriptionId -UseCache
            $kedaCount = if ($kedaResult.Count -gt 0) { $kedaResult[0].KEDAEnabledAKS } else { 0 }
            
            # 3. Demand Management (Caches, Load Balancers)
            $demandQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.cache/redis' or type =~ 'microsoft.network/loadbalancers' or type =~ 'microsoft.cdn/profiles'
| summarize DemandTools = count()
"@
            $demandResult = Invoke-AzResourceGraphQuery -Query $demandQuery -SubscriptionId $SubscriptionId -UseCache
            $demandCount = if ($demandResult.Count -gt 0) { $demandResult[0].DemandTools } else { 0 }
            
            # 4. Supply Caps (Autoscaling with Max Limits)
            # Note: Hard to query max limits directly; use presence of autoscaling as proxy
            
            # 5. Advisor Scaling Recs
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $scaleRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'scale|autoscaling|utilization' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling configurations"
            }
            
            if ($queueCount -eq 0 && $kedaCount -eq 0) {
                $indicators += "No event-based scaling indicators (queues/KEDA)"
            }
            
            if ($demandCount -eq 0) {
                $indicators += "No demand management tools (caches/load balancers)"
            }
            
            if ($scaleRecs -gt 0) {
                $indicators += "Unresolved scaling recommendations ($scaleRecs)"
            }
            
            $evidence = @"
Scaling Cost Assessment:
- Autoscaling Settings: $autoscaleCount
- Event-Based (Queues: $queueCount, KEDA: $kedaCount)
- Demand Tools: $demandCount
- Scaling Recommendations: $scaleRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO12' `
                    -Status 'Pass' `
                    -Message 'Optimized scaling costs with efficient strategies' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        Queues = $queueCount
                        KEDA = $kedaCount
                        DemandTools = $demandCount
                        ScaleRecs = $scaleRecs
                    }
            } else {
                return New-WafResult -CheckId 'CO12' `
                    -Status 'Fail' `
                    -Message "Scaling cost gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inefficient scaling increases costs.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Scaling Basics (Week 1)
1. **Enable Autoscaling**: With thresholds
2. **Use Event Scaling**: Queues/KEDA
3. **Implement Demand Control**: Caches/LBs

### Phase 2: Advanced (Weeks 2-3)
1. **Evaluate Scale Out/Up**: Vs cost model
2. **Control Supply**: Set caps
3. **Address Recommendations**: For savings

$evidence
"@ `
                    -RemediationScript @"
# Quick Scaling Optimization Setup

# Enable Autoscaling
New-AzAutoscaleSetting -Name 'scale-opt' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 1 -Rule (New-AzAutoscaleRule -MetricName 'CPUPercent' -MetricResourceId $id -Operator GreaterThan -Threshold 75 -ScaleActionDirection Increase -ScaleActionValue 1))

Write-Host "Basic scaling opt - expand with event-based"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO12' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
