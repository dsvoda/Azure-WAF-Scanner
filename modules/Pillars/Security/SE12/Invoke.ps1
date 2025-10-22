<#
.SYNOPSIS
    SE12 - Develop and test an incident response plan

.DESCRIPTION
    Develop a robust incident response plan that aligns with your organization's security policies and compliance requirements. This plan should include preparation, identification, containment, eradication, recovery, and lessons learned phases to effectively manage security incidents.

.NOTES
    Pillar: Security
    Recommendation: SE:12 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/incident-response
#>

Register-WafCheck -CheckId 'SE12' `
    -Pillar 'Security' `
    -Title 'Develop and test an incident response plan' `
    -Description 'Develop a robust incident response plan that aligns with your organization''s security policies and compliance requirements. This plan should include preparation, identification, containment, eradication, recovery, and lessons learned phases to effectively manage security incidents.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'IncidentResponse', 'IRPlan', 'SecOps') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/incident-response' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess incident response indicators
            
            # 1. Microsoft Sentinel Incidents and Automation Rules
            $sentinelQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.operationsmanagement/solutions'
| where name contains 'SecurityInsights'
| summarize SentinelInstances = count()
"@
            $sentinelResult = Invoke-AzResourceGraphQuery -Query $sentinelQuery -SubscriptionId $SubscriptionId -UseCache
            $sentinelCount = if ($sentinelResult.Count -gt 0) { $sentinelResult[0].SentinelInstances } else { 0 }
            
            # Assuming Sentinel for IR; check automation rules (playbooks)
            $playbookQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.logic/workflows'
| where tags['Sentinel'] == 'true' or name contains 'playbook'
| summarize Playbooks = count()
"@
            $playbookResult = Invoke-AzResourceGraphQuery -Query $playbookQuery -SubscriptionId $SubscriptionId -UseCache
            $playbookCount = if ($playbookResult.Count -gt 0) { $playbookResult[0].Playbooks } else { 0 }
            
            # 2. Action Groups for Response
            $actionGroupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/actiongroups'
| summarize ActionGroups = count()
"@
            $actionGroupResult = Invoke-AzResourceGraphQuery -Query $actionGroupQuery -SubscriptionId $SubscriptionId -UseCache
            $actionGroupCount = if ($actionGroupResult.Count -gt 0) { $actionGroupResult[0].ActionGroups } else { 0 }
            
            # 3. Security Alerts and Workflows
            $alertRuleQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.securityinsights/alertRules'
| summarize AlertRules = count()
"@
            $alertRuleResult = Invoke-AzResourceGraphQuery -Query $alertRuleQuery -SubscriptionId $SubscriptionId -UseCache
            $alertRuleCount = if ($alertRuleResult.Count -gt 0) { $alertRuleResult[0].AlertRules } else { 0 }
            
            # 4. Backup and Recovery Services (for IR recovery)
            $backupQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.recoveryservices/vaults'
| summarize RecoveryVaults = count()
"@
            $backupResult = Invoke-AzResourceGraphQuery -Query $backupQuery -SubscriptionId $SubscriptionId -UseCache
            $backupCount = if ($backupResult.Count -gt 0) { $backupResult[0].RecoveryVaults } else { 0 }
            
            # 5. Policies for IR
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| where properties.displayName contains 'incident response' or properties.displayName contains 'backup' or properties.displayName contains 'recovery'
| summarize IRPolicies = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].IRPolicies } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($sentinelCount -eq 0) {
                $indicators += "No Microsoft Sentinel for centralized IR"
            }
            
            if ($playbookCount -eq 0) {
                $indicators += "No automation playbooks for response"
            }
            
            if ($actionGroupCount -lt 3) {
                $indicators += "Limited action groups for notifications ($actionGroupCount)"
            }
            
            if ($alertRuleCount -lt 10) {
                $indicators += "Few alert rules configured ($alertRuleCount)"
            }
            
            if ($backupCount -eq 0) {
                $indicators += "No Recovery Services Vaults for backup/recovery"
            }
            
            if ($policyCount -lt 2) {
                $indicators += "Limited IR-related policies ($policyCount)"
            }
            
            $evidence = @"
Incident Response Assessment:
- Sentinel Instances: $sentinelCount
- Automation Playbooks: $playbookCount
- Action Groups: $actionGroupCount
- Alert Rules: $alertRuleCount
- Recovery Vaults: $backupCount
- IR Policies: $policyCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE12' `
                    -Status 'Pass' `
                    -Message 'Robust incident response capabilities in place' `
                    -Metadata @{
                        Sentinel = $sentinelCount
                        Playbooks = $playbookCount
                        ActionGroups = $actionGroupCount
                        AlertRules = $alertRuleCount
                        Backups = $backupCount
                        Policies = $policyCount
                    }
            } else {
                return New-WafResult -CheckId 'SE12' `
                    -Status 'Fail' `
                    -Message "IR plan gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Inadequate incident response plan impairs recovery.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Core IR Tools (Week 1)
1. **Deploy Sentinel**: For incident management
2. **Create Playbooks**: For automation
3. **Set Up Action Groups**: For notifications

### Phase 2: Testing & Policies (Weeks 2-3)
1. **Configure Alerts**: For threats
2. **Enable Backups**: For recovery
3. **Assign Policies**: For IR enforcement

$evidence
"@ `
                    -RemediationScript @"
# Quick IR Plan Setup

# Deploy Sentinel
New-AzSentinelSolution -WorkspaceName 'ws' -ResourceGroupName 'rg' -Kind 'SecurityInsights'

# Create Action Group
New-AzActionGroup -Name 'ir-group' -ResourceGroupName 'rg' -ShortName 'IR' -Location 'global' -EmailReceiver @{Name='team';EmailAddress='secops@company.com'}

# Enable Backup Vault
New-AzRecoveryServicesVault -Name 'ir-vault' -ResourceGroupName 'rg' -Location 'eastus'

Write-Host "Basic IR configured - develop full plan and test"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE12' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
