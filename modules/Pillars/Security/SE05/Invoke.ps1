<#
.SYNOPSIS
    SE05 - Implement a secure identity and access management strategy

.DESCRIPTION
    Implement strict, conditional, and auditable identity and access management (IAM) across all workload users, team members, and system components. Limit access exclusively to as necessary. Use modern industry standards for all authentication and authorization implementations. Restrict and rigorously audit access that's not based on identity.

.NOTES
    Pillar: Security
    Recommendation: SE:05 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/identity-access
#>

Register-WafCheck -CheckId 'SE05' `
    -Pillar 'Security' `
    -Title 'Implement a secure identity and access management strategy' `
    -Description 'Implement strict, conditional, and auditable identity and access management (IAM) across all workload users, team members, and system components. Limit access exclusively to as necessary. Use modern industry standards for all authentication and authorization implementations. Restrict and rigorously audit access that''s not based on identity.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'IAM', 'RBAC', 'ManagedIdentities', 'ConditionalAccess') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/identity-access' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess IAM indicators
            
            # 1. RBAC Assignments: Check for over-privileged roles (e.g., Owner/Contributor at sub scope)
            $rbacQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roleassignments'
| extend roleName = tostring(properties.roleDefinitionId)
| join kind=inner (AuthorizationResources 
    | where type == 'microsoft.authorization/roledefinitions' 
    | project roleDefinitionId = id, roleDisplayName = properties.roleName) 
    on \$left.roleName == \$right.roleDefinitionId
| where roleDisplayName in ('Owner', 'Contributor')
| where properties.scope == '/subscriptions/$SubscriptionId'
| summarize OverPrivilegedAssignments = count()
"@
            $rbacResult = Invoke-AzResourceGraphQuery -Query $rbacQuery -SubscriptionId $SubscriptionId -UseCache
            $overPrivCount = if ($rbacResult.Count -gt 0) { $rbacResult[0].OverPrivilegedAssignments } else { 0 }
            
            # Custom vs Built-in Roles
            $customRoleQuery = @"
AuthorizationResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.authorization/roledefinitions'
| where properties.type == 'CustomRole'
| summarize CustomRoles = count()
"@
            $customResult = Invoke-AzResourceGraphQuery -Query $customRoleQuery -SubscriptionId $SubscriptionId -UseCache
            $customCount = if ($customResult.Count -gt 0) { $customResult[0].CustomRoles } else { 0 }
            
            # 2. Managed Identities: Check usage on resources
            $miQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.managedidentity/userassignedidentities' or identity.type contains 'SystemAssigned'
| summarize ManagedIdentities = count()
"@
            $miResult = Invoke-AzResourceGraphQuery -Query $miQuery -SubscriptionId $SubscriptionId -UseCache
            $miCount = if ($miResult.Count -gt 0) { $miResult[0].ManagedIdentities } else { 0 }
            
            # Total resources that could use MI (e.g., VMs, App Services)
            $potentialMIQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in~ ('microsoft.compute/virtualmachines', 'microsoft.web/sites', 'microsoft.containerservice/managedclusters')
| summarize PotentialMIResources = count()
"@
            $potentialResult = Invoke-AzResourceGraphQuery -Query $potentialMIQuery -SubscriptionId $SubscriptionId -UseCache
            $potentialCount = if ($potentialResult.Count -gt 0) { $potentialResult[0].PotentialMIResources } else { 0 }
            
            $miPercent = if ($potentialCount -gt 0) { [Math]::Round(($miCount / $potentialCount) * 100, 1) } else { 0 }
            
            # 3. Key Vault RBAC: Check if using RBAC over access policies
            $kvQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| extend enableRbacAuthorization = tobool(properties.enableRbacAuthorization)
| where enableRbacAuthorization == true
| summarize RBACKeyVaults = count()
"@
            $kvResult = Invoke-AzResourceGraphQuery -Query $kvQuery -SubscriptionId $SubscriptionId -UseCache
            $rbacKVCount = if ($kvResult.Count -gt 0) { $kvResult[0].RBACKeyVaults } else { 0 }
            
            $totalKVQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.keyvault/vaults'
| summarize TotalKeyVaults = count()
"@
            $totalKVResult = Invoke-AzResourceGraphQuery -Query $totalKVQuery -SubscriptionId $SubscriptionId -UseCache
            $totalKVCount = if ($totalKVResult.Count -gt 0) { $totalKVResult[0].TotalKeyVaults } else { 0 }
            
            # 4. Diagnostic Logging for Auditing
            $diagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| summarize DiagSettings = count()
"@
            $diagResult = Invoke-AzResourceGraphQuery -Query $diagQuery -SubscriptionId $SubscriptionId -UseCache
            $diagCount = if ($diagResult.Count -gt 0) { $diagResult[0].DiagSettings } else { 0 }
            
            # 5. Service Principals and Secrets
            $spQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.aad/applications'
| summarize ServicePrincipals = count()
"@
            $spResult = Invoke-AzResourceGraphQuery -Query $spQuery -SubscriptionId $SubscriptionId -UseCache
            $spCount = if ($spResult.Count -gt 0) { $spResult[0].ServicePrincipals } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($overPrivCount -gt 5) {
                $indicators += "High number of over-privileged assignments ($overPrivCount Owner/Contributor at sub scope)"
            }
            
            if ($miPercent -lt 50) {
                $indicators += "Low managed identity adoption ($miPercent% of potential resources)"
            }
            
            if ($rbacKVCount -lt $totalKVCount) {
                $indicators += "Not all Key Vaults using RBAC ($rbacKVCount/$totalKVCount)"
            }
            
            if ($diagCount -lt 10) {
                $indicators += "Limited diagnostic logging settings ($diagCount) for auditing"
            }
            
            if ($customCount -eq 0 -and $spCount -gt 10) {
                $indicators += "No custom roles but high service principals ($spCount) - potential for broad permissions"
            }
            
            $evidence = @"
IAM Assessment:
- Over-Privileged Assignments: $overPrivCount
- Custom Roles: $customCount
- Managed Identities: $miCount ($miPercent%)
- RBAC Key Vaults: $rbacKVCount / $totalKVCount
- Diagnostic Settings: $diagCount
- Service Principals: $spCount
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE05' `
                    -Status 'Pass' `
                    -Message 'Strong IAM strategy with least privilege and auditing' `
                    -Metadata @{
                        OverPriv = $overPrivCount
                        CustomRoles = $customCount
                        MIPercent = $miPercent
                        RBACKV = $rbacKVCount
                        DiagSettings = $diagCount
                        SPs = $spCount
                    }
            } else {
                return New-WafResult -CheckId 'SE05' `
                    -Status 'Fail' `
                    -Message "IAM gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Weak IAM increases unauthorized access risks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Core IAM Controls (Week 1)
1. **Refine RBAC**: Reduce broad roles, add custom
2. **Adopt Managed Identities**: For apps/VMs
3. **Enable KV RBAC**: Switch from access policies

### Phase 2: Auditing & Conditional Access (Weeks 2-3)
1. **Set Up Diagnostics**: Log all resources
2. **Implement Conditional Access**: Via Entra ID
3. **Review Secrets**: Rotate and use KV

$evidence
"@ `
                    -RemediationScript @"
# Quick IAM Setup

# Create Custom Role
$role = New-AzRoleDefinition -RoleName 'Custom Reader' -Description 'Custom read-only' -Actions @('Microsoft.Resources/subscriptions/resourceGroups/read')
Set-AzRoleDefinition -Role $role

# Assign Managed Identity to VM
Update-AzVM -ResourceGroupName 'rg' -Name 'vm' -IdentityType SystemAssigned

# Enable KV RBAC
Update-AzKeyVault -VaultName 'kv' -ResourceGroupName 'rg' -EnableRbacAuthorization $true

Write-Host "Basic IAM configured - expand with Conditional Access in Entra ID portal"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE05' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
