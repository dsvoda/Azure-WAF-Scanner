<#
.SYNOPSIS
    OE10 - Enable automation for operations tasks

.DESCRIPTION
    Enable automation for operations tasks by identifying opportunities to automate repetitive tasks, such as provisioning, scaling, deployments, governance, and compliance. Use Azure-native tools like Azure Policy, virtual machine extensions, deployment scripts, and state configuration to streamline operations.

.NOTES
    Pillar: Operational Excellence
    Recommendation: OE:10 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/enable-automation
#>

Register-WafCheck -CheckId 'OE10' `
    -Pillar 'OperationalExcellence' `
    -Title 'Enable automation for operations tasks' `
    -Description 'Enable automation for operations tasks by identifying opportunities to automate repetitive tasks, such as provisioning, scaling, deployments, governance, and compliance. Use Azure-native tools like Azure Policy, virtual machine extensions, deployment scripts, and state configuration to streamline operations.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('OperationalExcellence', 'Automation', 'OperationsTasks', 'Provisioning', 'Scaling') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/enable-automation' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess automation enablement indicators
            
            # 1. Azure Policy Assignments
            $policyQuery = @"
PolicyResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/policyassignments'
| summarize PolicyAssignments = count()
"@
            $policyResult = Invoke-AzResourceGraphQuery -Query $policyQuery -SubscriptionId $SubscriptionId -UseCache
            $policyCount = if ($policyResult.Count -gt 0) { $policyResult[0].PolicyAssignments } else { 0 }
            
            # 2. Virtual Machine Extensions for Bootstrapping
            $vmExtQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.compute/virtualmachines/extensions'
| summarize VMExtensions = count()
"@
            $vmExtResult = Invoke-AzResourceGraphQuery -Query $vmExtQuery -SubscriptionId $SubscriptionId -UseCache
            $vmExtCount = if ($vmExtResult.Count -gt 0) { $vmExtResult[0].VMExtensions } else { 0 }
            
            # 3. Deployment Scripts
            $deployScriptQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.resources/deploymentscripts'
| summarize DeploymentScripts = count()
"@
            $deployScriptResult = Invoke-AzResourceGraphQuery -Query $deployScriptQuery -SubscriptionId $SubscriptionId -UseCache
            $deployScriptCount = if ($deployScriptResult.Count -gt 0) { $deployScriptResult[0].DeploymentScripts } else { 0 }
            
            # 4. State Configuration (DSC Nodes)
            # Note: DSC requires specific cmdlets; use Automation accounts as proxy
            $automationQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts'
| summarize AutomationAccounts = count()
"@
            $automationResult = Invoke-AzResourceGraphQuery -Query $automationQuery -SubscriptionId $SubscriptionId -UseCache
            $automationCount = if ($automationResult.Count -gt 0) { $automationResult[0].AutomationAccounts } else { 0 }
            
            # 5. Change Tracking Enabled
            $changeTrackingQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts' and properties.description contains 'change tracking'
| summarize ChangeTracking = count()
"@
            $changeTrackingResult = Invoke-AzResourceGraphQuery -Query $changeTrackingQuery -SubscriptionId $SubscriptionId -UseCache
            $changeTrackingCount = if ($changeTrackingResult.Count -gt 0) { $changeTrackingResult[0].ChangeTracking } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($policyCount -eq 0) {
                $indicators += "No Azure Policy assignments for governance automation"
            }
            
            if ($vmExtCount -eq 0) {
                $indicators += "No VM extensions for bootstrapping"
            }
            
            if ($deployScriptCount -eq 0) {
                $indicators += "No deployment scripts for automation"
            }
            
            if ($automationCount -eq 0) {
                $indicators += "No Automation accounts for state configuration"
            }
            
            if ($changeTrackingCount -eq 0) {
                $indicators += "No change tracking enabled"
            }
            
            $evidence = @"
Automation Enablement Assessment:
- Policy Assignments: $policyCount
- VM Extensions: $vmExtCount
- Deployment Scripts: $deployScriptCount
- Automation Accounts: $automationCount
- Change Tracking: $changeTrackingCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'OE10' `
                    -Status 'Pass' `
                    -Message 'Effective automation for operations tasks' `
                    -Metadata @{
                        Policies = $policyCount
                        VMExtensions = $vmExtCount
                        DeployScripts = $deployScriptCount
                        Automation = $automationCount
                        ChangeTracking = $changeTrackingCount
                    }
            } else {
                return New-WafResult -CheckId 'OE10' `
                    -Status 'Fail' `
                    -Message "Automation gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Manual operations hinder efficiency.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Governance & Bootstrapping (Week 1)
1. **Assign Policies**: For standards
2. **Add VM Extensions**: For configs
3. **Use Deployment Scripts**: For tasks

### Phase 2: Configuration & Tracking (Weeks 2-3)
1. **Set Automation Accounts**: For DSC
2. **Enable Change Tracking**: For monitoring
3. **Calculate ROI**: For automation

$evidence
"@ `
                    -RemediationScript @"
# Quick Automation Enablement Setup

# Assign Policy
$definition = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Audit VMs' }
New-AzPolicyAssignment -Name 'oe-policy' -PolicyDefinition $definition -Scope "/subscriptions/$SubscriptionId"

# Add VM Extension
New-AzVMExtension -ResourceGroupName 'rg' -VMName 'vm' -Name 'CustomScript' -Publisher 'Microsoft.Azure.Extensions' -ExtensionType 'CustomScript' -TypeHandlerVersion '2.0' -Settings @{'fileUris' = @('script.ps1'); 'commandToExecute' = 'powershell -file script.ps1'}

Write-Host "Basic automation - expand with DSC and tracking"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'OE10' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
