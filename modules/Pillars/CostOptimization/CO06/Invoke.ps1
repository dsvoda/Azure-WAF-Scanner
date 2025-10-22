<#
.SYNOPSIS
    CO06 - Align usage to billing increments

.DESCRIPTION
    Understand billing increments (meters) and align resource usage to those increments. Modify the service to align with billing increments, or modify resource usage to align with billing increments. Consider using a proof of concept to validate billing knowledge and design choices for major cost drivers and to reveal ways to align billing and resource usage.

.NOTES
    Pillar: Cost Optimization
    Recommendation: CO:06 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/align-usage-to-billing-increments
#>

Register-WafCheck -CheckId 'CO06' `
    -Pillar 'CostOptimization' `
    -Title 'Align usage to billing increments' `
    -Description 'Understand billing increments (meters) and align resource usage to those increments. Modify the service to align with billing increments, or modify resource usage to align with billing increments. Consider using a proof of concept to validate billing knowledge and design choices for major cost drivers and to reveal ways to align billing and resource usage.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('CostOptimization', 'BillingIncrements', 'UsageAlignment', 'Scheduling', 'Scaling') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/align-usage-to-billing-increments' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess alignment indicators
            
            # 1. Autoscaling Configurations (for aligning to usage patterns)
            $autoscaleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/autoscalesettings'
| summarize AutoscaleSettings = count()
"@
            $autoscaleResult = Invoke-AzResourceGraphQuery -Query $autoscaleQuery -SubscriptionId $SubscriptionId -UseCache
            $autoscaleCount = if ($autoscaleResult.Count -gt 0) { $autoscaleResult[0].AutoscaleSettings } else { 0 }
            
            # 2. Scheduled Shutdowns (tags or automation indicating scheduling)
            $scheduledQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where tags['shutdownSchedule'] != '' or tags['autoShutdown'] != '' or name contains 'schedule'
| summarize ScheduledResources = count()
"@
            $scheduledResult = Invoke-AzResourceGraphQuery -Query $scheduledQuery -SubscriptionId $SubscriptionId -UseCache
            $scheduledCount = if ($scheduledResult.Count -gt 0) { $scheduledResult[0].ScheduledResources } else { 0 }
            
            # Automation Runbooks for scheduling
            $runbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts/runbooks'
| where properties.description contains 'schedule' or properties.description contains 'shutdown' or name contains 'schedule'
| summarize Runbooks = count()
"@
            $runbookResult = Invoke-AzResourceGraphQuery -Query $runbookQuery -SubscriptionId $SubscriptionId -UseCache
            $runbookCount = if ($runbookResult.Count -gt 0) { $runbookResult[0].Runbooks } else { 0 }
            
            # 3. Low Utilization Resources (Advisor as proxy; count recommendations)
            $advisor = Get-AzAdvisorRecommendation -Category Cost -ErrorAction SilentlyContinue
            $lowUtilRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'underutilized|low utilization' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # 4. Dev/Test Environments (special pricing/alignment)
            $devTestQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where tags['environment'] == 'dev' or tags['environment'] == 'test' or name contains 'dev' or name contains 'test'
| summarize DevTestResources = count()
"@
            $devTestResult = Invoke-AzResourceGraphQuery -Query $devTestQuery -SubscriptionId $SubscriptionId -UseCache
            $devTestCount = if ($devTestResult.Count -gt 0) { $devTestResult[0].DevTestResources } else { 0 }
            
            # 5. Cost Anomaly Detection
            $anomalyQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.costmanagement/anomalies'
| summarize Anomalies = count()
"@
            $anomalyResult = Invoke-AzResourceGraphQuery -Query $anomalyQuery -SubscriptionId $SubscriptionId -UseCache
            $anomalyCount = if ($anomalyResult.Count -gt 0) { $anomalyResult[0].Anomalies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($autoscaleCount -eq 0) {
                $indicators += "No autoscaling for usage alignment"
            }
            
            if ($scheduledCount -eq 0 && $runbookCount -eq 0) {
                $indicators += "No scheduled shutdowns or automation for billing alignment"
            }
            
            if ($lowUtilRecs -gt 5) {
                $indicators += "High number of low utilization recommendations ($lowUtilRecs)"
            }
            
            if ($devTestCount -eq 0) {
                $indicators += "No identified dev/test resources for optimized billing"
            }
            
            if ($anomalyCount -eq 0) {
                $indicators += "No cost anomaly detection configured"
            }
            
            $evidence = @"
Billing Alignment Assessment:
- Autoscaling Settings: $autoscaleCount
- Scheduled Resources: $scheduledCount (Runbooks: $runbookCount)
- Low Util Recommendations: $lowUtilRecs
- Dev/Test Resources: $devTestCount
- Cost Anomalies: $anomalyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'CO06' `
                    -Status 'Pass' `
                    -Message 'Effective alignment of usage to billing increments' `
                    -Metadata @{
                        Autoscale = $autoscaleCount
                        Scheduled = $scheduledCount
                        Runbooks = $runbookCount
                        LowUtil = $lowUtilRecs
                        DevTest = $devTestCount
                        Anomalies = $anomalyCount
                    }
            } else {
                return New-WafResult -CheckId 'CO06' `
                    -Status 'Fail' `
                    -Message "Billing alignment gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Misaligned usage wastes costs on partial increments.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Alignment Basics (Week 1)
1. **Enable Autoscaling**: For variable loads
2. **Schedule Shutdowns**: For non-24/7 resources
3. **Tag Dev/Test**: For special rates

### Phase 2: Advanced (Weeks 2-3)
1. **Address Low Util**: Right-size resources
2. **Set Anomaly Detection**: For alerts
3. **Build POC**: Validate increments

$evidence
"@ `
                    -RemediationScript @"
# Quick Billing Alignment Setup

# Enable VM Autoscale
New-AzAutoscaleSetting -Name 'align-scale' -ResourceGroupName 'rg' -Location 'eastus' -TargetResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss' -Profile (New-AzAutoscaleProfile -Name 'default' -DefaultCapacity 2 -MaximumCapacity 10 -MinimumCapacity 2)

# Schedule Shutdown (Tag)
Update-AzTag -ResourceId '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm' -Tag @{'shutdownSchedule' = 'daily'} -Operation Merge

Write-Host "Basic alignment configured - implement full scheduling via Automation"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'CO06' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
