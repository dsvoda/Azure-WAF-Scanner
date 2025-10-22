<#
.SYNOPSIS
    RE07 - Strengthen resiliency with self-preservation and self-healing

.DESCRIPTION
    Strengthen the resiliency of your workload by implementing self-preservation and self-healing measures. Use built-in features and well-established cloud patterns to help your workload remain functional during and recover from incidents.

.NOTES
    Pillar: Reliability
    Recommendation: RE:07 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/reliability/self-preservation
#>

Register-WafCheck -CheckId 'RE07' `
    -Pillar 'Reliability' `
    -Title 'Strengthen resiliency with self-preservation and self-healing' `
    -Description 'Strengthen the resiliency of your workload by implementing self-preservation and self-healing measures. Use built-in features and well-established cloud patterns to help your workload remain functional during and recover from incidents.' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('Reliability', 'SelfHealing', 'Resiliency', 'SelfPreservation') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/reliability/self-preservation' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Initialize assessment
            $issues = @()
            $totalResources = 0
            $resourcesWithHealing = 0
            
            # 1. App Services - Check for auto-heal configurations
            $appQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites'
| extend 
    autoHealEnabled = tobool(properties.siteConfig.autoHealEnabled),
    numberOfWorkers = toint(properties.siteConfig.numberOfWorkers)
| project 
    id, name, resourceGroup, autoHealEnabled, numberOfWorkers
"@
            $apps = Invoke-AzResourceGraphQuery -Query $appQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($apps.Count -gt 0) {
                $totalResources += $apps.Count
                foreach ($app in $apps) {
                    if ($app.autoHealEnabled -eq $true -and $app.numberOfWorkers -ge 2) {
                        $resourcesWithHealing++
                    } else {
                        $issues += "App Service '$($app.name)': Auto-heal not enabled or single instance"
                    }
                }
            }
            
            # 2. VM Scale Sets - Check for autoscaling (self-healing via scaling)
            $vmssQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| extend 
    capacity = toint(sku.capacity)
| project 
    id, name, resourceGroup, capacity
"@
            $vmss = Invoke-AzResourceGraphQuery -Query $vmssQuery -SubscriptionId $SubscriptionId -UseCache
            
            $vmssWithAutoscale = 0
            if ($vmss.Count -gt 0) {
                $totalResources += $vmss.Count
                foreach ($set in $vmss) {
                    $autoscale = Get-AzAutoscaleSetting -ErrorAction SilentlyContinue | Where-Object { $_.TargetResourceUri -eq $set.id }
                    if ($autoscale -and $set.capacity -ge 2) {
                        $vmssWithAutoscale++
                        $resourcesWithHealing++
                    } else {
                        $issues += "VMSS '$($set.name)': No autoscaling or low capacity"
                    }
                }
            }
            
            # 3. AKS Clusters - Check for node auto-repair and autoscaling
            $aksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| extend 
    nodePools = properties.agentPoolProfiles
| project 
    id, name, resourceGroup, nodePools
"@
            $aks = Invoke-AzResourceGraphQuery -Query $aksQuery -SubscriptionId $SubscriptionId -UseCache
            
            $aksWithHealing = 0
            if ($aks.Count -gt 0) {
                $totalResources += $aks.Count
                foreach ($cluster in $aks) {
                    $hasAutoscaling = $false
                    foreach ($pool in $cluster.nodePools) {
                        if ($pool.enableAutoScaling -eq $true) {
                            $hasAutoscaling = $true
                            break
                        }
                    }
                    if ($hasAutoscaling) {
                        $aksWithHealing++
                        $resourcesWithHealing++
                    } else {
                        $issues += "AKS '$($cluster.name)': No node pool autoscaling"
                    }
                }
            }
            
            # 4. Load Balancers - Check for health probes (self-preservation)
            $lbQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.network/loadbalancers'
| extend 
    probes = array_length(properties.probes)
| project 
    id, name, resourceGroup, probes
"@
            $lbs = Invoke-AzResourceGraphQuery -Query $lbQuery -SubscriptionId $SubscriptionId -UseCache
            
            if ($lbs.Count -gt 0) {
                $totalResources += $lbs.Count
                foreach ($lb in $lbs) {
                    if ($lb.probes -gt 0) {
                        $resourcesWithHealing++
                    } else {
                        $issues += "Load Balancer '$($lb.name)': No health probes configured"
                    }
                }
            }
            
            # Calculate overall
            $healingPercent = if ($totalResources -gt 0) { [Math]::Round(($resourcesWithHealing / $totalResources) * 100, 1) } else { 0 }
            
            $evidence = @"
Self-Healing Assessment:
- App Services with auto-heal: $($apps | Where-Object { $_.autoHealEnabled -eq $true } | Measure-Object).Count / $($apps.Count)
- VMSS with autoscaling: $vmssWithAutoscale / $($vmss.Count)
- AKS with node autoscaling: $aksWithHealing / $($aks.Count)
- Load Balancers with probes: $($lbs | Where-Object { $_.probes -gt 0 } | Measure-Object).Count / $($lbs.Count)
- Overall healing coverage: $healingPercent%
"@
            
            if ($healingPercent -ge 80) {
                return New-WafResult -CheckId 'RE07' `
                    -Status 'Pass' `
                    -Message "Strong self-healing implementation: $healingPercent% coverage across $totalResources resources" `
                    -Metadata @{
                        AppHealingCount = $($apps | Where-Object { $_.autoHealEnabled -eq $true } | Measure-Object).Count
                        VmssAutoscale = $vmssWithAutoscale
                        AksHealing = $aksWithHealing
                        LbProbes = $($lbs | Where-Object { $_.probes -gt 0 } | Measure-Object).Count
                        CoveragePercent = $healingPercent
                    }
            } else {
                return New-WafResult -CheckId 'RE07' `
                    -Status 'Fail' `
                    -Message "Insufficient self-healing: Only $healingPercent% coverage, $($issues.Count) issues identified" `
                    -Recommendation @"
**CRITICAL**: Workload lacks self-preservation and healing capabilities.

Issues identified:
$($issues | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Enable Basic Healing (Week 1)
1. **App Services**: Enable auto-heal rules
2. **Load Balancers**: Add health probes
3. **Autoscaling**: Configure basic rules

### Phase 2: Advanced Patterns (Weeks 2-3)
1. **Implement Retries**: Use Polly in code
2. **Circuit Breakers**: For external calls
3. **Chaos Testing**: Validate healing

$evidence
"@ `
                    -RemediationScript @"
# Quick Self-Healing Setup
`$WhatIf = `$true

# Enable App Service auto-heal
Get-AzWebApp | ForEach-Object {
    Set-AzWebApp -ResourceGroupName `$_.ResourceGroup -Name `$_.Name -AutoHealEnabled `$true -WhatIf:`$WhatIf
}

# Add LB health probe
Get-AzLoadBalancer | ForEach-Object {
    if (`$_.Probes.Count -eq 0) {
        Add-AzLoadBalancerProbeConfig -LoadBalancer `$_.Id -Name 'healthProbe' -Protocol Http -Port 80 -RequestPath '/' -IntervalInSeconds 15 -ProbeCount 2 -WhatIf:`$WhatIf
    }
}
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE07' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
