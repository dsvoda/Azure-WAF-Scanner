<#
.SYNOPSIS
    PE10 - Optimize operational tasks

.DESCRIPTION
    Optimize operational tasks by monitoring and minimizing the impact of software development lifecycle activities and routine operations (e.g., virus scans, secret rotations, backups, database reindexing, deployments) on workload performance. These tasks share compute resources with the workload, potentially causing performance degradation or missed targets. The goal is to ensure routine operations do not significantly affect workload efficiency.

.NOTES
    Pillar: Performance Efficiency
    Recommendation: PE:10 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-operational-tasks
#>

Register-WafCheck -CheckId 'PE10' `
    -Pillar 'PerformanceEfficiency' `
    -Title 'Optimize operational tasks' `
    -Description 'Optimize operational tasks by monitoring and minimizing the impact of software development lifecycle activities and routine operations (e.g., virus scans, secret rotations, backups, database reindexing, deployments) on workload performance.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('PerformanceEfficiency', 'OperationalTasks', 'Backups', 'Deployments', 'VirusScans') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/optimize-operational-tasks' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess operational tasks optimization indicators
            
            # 1. Deployment Slots for Optimized Deployments
            $slotQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites/slots'
| summarize DeploymentSlots = count()
"@
            $slotResult = Invoke-AzResourceGraphQuery -Query $slotQuery -SubscriptionId $SubscriptionId -UseCache
            $slotCount = if ($slotResult.Count -gt 0) { $slotResult[0].DeploymentSlots } else { 0 }
            
            # 2. Backup Configurations (Vaults)
            $backupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults'
| summarize BackupVaults = count()
"@
            $backupResult = Invoke-AzResourceGraphQuery -Query $backupQuery -SubscriptionId $SubscriptionId -UseCache
            $backupCount = if ($backupResult.Count -gt 0) { $backupResult[0].BackupVaults } else { 0 }
            
            # 3. Virus Scanning/Defender Enabled
            $defenderQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/pricings'
| where name == 'VirtualMachines' and properties.pricingTier == 'Standard'
| summarize DefenderVM = count()
"@
            $defenderResult = Invoke-AzResourceGraphQuery -Query $defenderQuery -SubscriptionId $SubscriptionId -UseCache
            $defenderCount = if ($defenderResult.Count -gt 0) { $defenderResult[0].DefenderVM } else { 0 }
            
            # 4. Database Optimization (Elastic Pools, Auto-Indexing)
            $dbOptQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/elasticpools' or (type =~ 'microsoft.sql/servers/databases' and properties.autoIndexing == true)
| summarize DbOpts = count()
"@
            $dbOptResult = Invoke-AzResourceGraphQuery -Query $dbOptQuery -SubscriptionId $SubscriptionId -UseCache
            $dbOptCount = if ($dbOptResult.Count -gt 0) { $dbOptResult[0].DbOpts } else { 0 }
            
            # 5. Advisor Performance Recs for Tasks
            $advisor = Get-AzAdvisorRecommendation -Category Performance -ErrorAction SilentlyContinue
            $taskRecs = $advisor | Where-Object { $_.ShortDescription.Problem -match 'task|operation|backup|deployment|scan' } | Measure-Object | Select-Object -ExpandProperty Count
            
            # Calculate indicators
            $indicators = @()
            
            if ($slotCount -eq 0) {
                $indicators += "No deployment slots for optimized deploys"
            }
            
            if ($backupCount -eq 0) {
                $indicators += "No backup vaults configured"
            }
            
            if ($defenderCount -eq 0) {
                $indicators += "Defender for VMs not enabled"
            }
            
            if ($dbOptCount -eq 0) {
                $indicators += "No optimized DB features"
            }
            
            if ($taskRecs -gt 0) {
                $indicators += "Unresolved task optimization recommendations ($taskRecs)"
            }
            
            $evidence = @"
Operational Tasks Assessment:
- Deployment Slots: $slotCount
- Backup Vaults: $backupCount
- Defender VM: $defenderCount
- DB Optimizations: $dbOptCount
- Task Recommendations: $taskRecs
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'PE10' `
                    -Status 'Pass' `
                    -Message 'Optimized operational tasks for performance' `
                    -Metadata @{
                        Slots = $slotCount
                        Backups = $backupCount
                        Defender = $defenderCount
                        DbOpts = $dbOptCount
                        TaskRecs = $taskRecs
                    }
            } else {
                return New-WafResult -CheckId 'PE10' `
                    -Status 'Fail' `
                    -Message "Operational tasks gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Unoptimized tasks degrade performance.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basics (Week 1)
1. **Use Deployment Slots**: For swaps
2. **Set Backups**: Incremental
3. **Enable Defender**: For scans

### Phase 2: Advanced (Weeks 2-3)
1. **Optimize DBs**: Indexes/pools
2. **Address Recs**: For improvements
3. **Schedule Tasks**: Off-peak

$evidence
"@ `
                    -RemediationScript @"
# Quick Tasks Optimization Setup

# Add Deployment Slot
New-AzWebAppSlot -Name 'app' -ResourceGroupName 'rg' -Slot 'staging'

# Enable Defender VM
Set-AzSecurityPricing -Name 'VirtualMachines' -PricingTier 'Standard'

Write-Host "Basic tasks opt - schedule and monitor"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'PE10' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
