<#
.SYNOPSIS
    RE09 - Implement business continuity and disaster recovery (BCDR) plans

.DESCRIPTION
    Implement structured, tested, and documented business continuity and disaster recovery (BCDR) plans that align with the recovery targets. Plans must cover all components and the system as a whole.

.NOTES
    Pillar: Reliability
    Recommendation: RE:09 from Microsoft WAF
    Severity: Critical
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/reliability/disaster-recovery
#>

Register-WafCheck -CheckId 'RE09' `
    -Pillar 'Reliability' `
    -Title 'Implement business continuity and disaster recovery (BCDR) plans' `
    -Description 'Implement structured, tested, and documented business continuity and disaster recovery (BCDR) plans that align with the recovery targets. Plans must cover all components and the system as a whole.' `
    -Severity 'Critical' `
    -RemediationEffort 'High' `
    -Tags @('Reliability', 'BCDR', 'DisasterRecovery', 'BusinessContinuity') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/reliability/disaster-recovery' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Initialize assessment
            $issues = @()
            $totalBcdrResources = 0
            $coveredResources = 0
            
            # 1. Recovery Services Vaults - Check for BCDR setups
            $vaultQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults'
| project 
    id, name, resourceGroup
"@
            $vaults = Invoke-AzResourceGraphQuery -Query $vaultQuery -SubscriptionId $SubscriptionId -UseCache
            
            $protectedItems = 0
            foreach ($vault in $vaults) {
                Set-AzRecoveryServicesVaultContext -VaultId $vault.id -ErrorAction SilentlyContinue
                $items = Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -ErrorAction SilentlyContinue
                $protectedItems += $items.Count
            }
            $totalBcdrResources += $vaults.Count
            $coveredResources += $protectedItems
            
            if ($vaults.Count -eq 0) {
                $issues += "No Recovery Services Vaults configured"
            }
            
            # 2. Site Recovery - Check for protected items
            $asrItems = 0
            foreach ($vault in $vaults) {
                Set-AzRecoveryServicesAsrVaultContext -VaultId $vault.id -ErrorAction SilentlyContinue
                $asr = Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue
                $asrItems += $asr.Count
            }
            $coveredResources += $asrItems
            
            if ($asrItems -eq 0) {
                $issues += "No Site Recovery protected items"
            }
            
            # 3. SQL Geo-replication
            $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
            $geoDbs = 0
            foreach ($server in $sqlServers) {
                $dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName -ErrorAction SilentlyContinue
                foreach ($db in $dbs) {
                    $links = Get-AzSqlDatabaseReplicationLink -ServerName $server.ServerName -DatabaseName $db.DatabaseName -ResourceGroupName $server.ResourceGroupName -ErrorAction SilentlyContinue
                    if ($links.Count -gt 0) {
                        $geoDbs++
                    }
                }
            }
            $coveredResources += $geoDbs
            
            if ($geoDbs -eq 0 -and $sqlServers.Count -gt 0) {
                $issues += "No geo-replicated SQL databases"
            }
            
            $evidence = @"
BCDR Assessment:
- Recovery Vaults: $($vaults.Count)
- Protected Backup Items: $protectedItems
- ASR Protected Items: $asrItems
- Geo-Replicated DBs: $geoDbs
- Total Covered Resources: $coveredResources
"@
            
            if ($coveredResources -ge 10 -and $issues.Count -eq 0) {
                return New-WafResult -CheckId 'RE09' `
                    -Status 'Pass' `
                    -Message "Solid BCDR implementation covering $coveredResources resources" `
                    -Metadata @{
                        Vaults = $vaults.Count
                        Backups = $protectedItems
                        AsrItems = $asrItems
                        GeoDbs = $geoDbs
                    }
            } else {
                return New-WafResult -CheckId 'RE09' `
                    -Status 'Fail' `
                    -Message "Inadequate BCDR coverage: Only $coveredResources resources protected, $($issues.Count) issues" `
                    -Recommendation @"
**CRITICAL**: No BCDR plans implemented.

Issues identified:
$($issues | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Basic DR Setup (Week 1)
1. **Create Vaults**: Deploy Recovery Services
2. **Enable Backups**: For critical VMs/DBs
3. **Configure ASR**: For key workloads

### Phase 2: Testing & Documentation (Weeks 2-3)
1. **Test Failover**: Validate procedures
2. **Document Plans**: RTO/RPO alignment
3. **Automate Recovery**: Script runbooks

$evidence
"@ `
                    -RemediationScript @"
# Quick BCDR Setup
New-AzRecoveryServicesVault -ResourceGroupName 'rg-dr' -Name 'vault-dr' -Location 'eastus'

# Enable VM Backup
Get-AzVM | ForEach-Object {
    Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $_.ResourceGroupName -Name $_.Name -Policy (Get-AzRecoveryServicesBackupProtectionPolicy -Name 'DefaultPolicy')
}
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE09' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
