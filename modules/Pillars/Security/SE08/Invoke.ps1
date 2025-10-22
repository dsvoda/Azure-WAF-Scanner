<#
.SYNOPSIS
    SE08 - Harden workload resources

.DESCRIPTION
    Harden all workload components by reducing extraneous surface area and tightening configurations. Increase the cost for attackers to exploit your workload without altering the workload functionality.

.NOTES
    Pillar: Security
    Recommendation: SE:08 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/en-us/azure/well-architected/security/harden-resources
#>

Register-WafCheck -CheckId 'SE08' `
    -Pillar 'Security' `
    -Title 'Harden workload resources' `
    -Description 'Harden all workload components by reducing extraneous surface area and tightening configurations. Increase the cost for attackers to exploit your workload without altering the workload functionality.' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -Tags @('Security', 'Hardening', 'VulnerabilityManagement', 'AccessControl', 'Configuration') `
    -DocumentationUrl 'https://learn.microsoft.com/en-us/azure/well-architected/security/harden-resources' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Assess hardening indicators
            
            # 1. Defender for Cloud Vulnerability Assessments
            $vulnQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/assessments'
| where properties.assessmentType == 'BuiltIn' and properties.displayName contains 'vulnerability'
| summarize VulnAssessments = count()
"@
            $vulnResult = Invoke-AzResourceGraphQuery -Query $vulnQuery -SubscriptionId $SubscriptionId -UseCache
            $vulnCount = if ($vulnResult.Count -gt 0) { $vulnResult[0].VulnAssessments } else { 0 }
            
            # Resolved vulnerabilities (healthy status)
            $resolvedVulnQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/assessments'
| where properties.assessmentType == 'BuiltIn' and properties.displayName contains 'vulnerability' and properties.status.code == 'Healthy'
| summarize ResolvedVulns = count()
"@
            $resolvedResult = Invoke-AzResourceGraphQuery -Query $resolvedVulnQuery -SubscriptionId $SubscriptionId -UseCache
            $resolvedCount = if ($resolvedResult.Count -gt 0) { $resolvedResult[0].ResolvedVulns } else { 0 }
            
            $vulnResolvePercent = if ($vulnCount -gt 0) { [Math]::Round(($resolvedCount / $vulnCount) * 100, 1) } else { 100 }
            
            # 2. VM Hardening: Check for Update Management and JIT Access
            $updateMgmtQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.automation/automationaccounts'
| summarize AutomationAccounts = count()
"@
            $updateResult = Invoke-AzResourceGraphQuery -Query $updateMgmtQuery -SubscriptionId $SubscriptionId -UseCache
            $automationCount = if ($updateResult.Count -gt 0) { $updateResult[0].AutomationAccounts } else { 0 }
            
            $jitQuery = @"
SecurityResources
| where subscriptionId == '$SubscriptionId'
| where type == 'microsoft.security/locations/jitnetworkaccesspolicies'
| summarize JITPolicies = count()
"@
            $jitResult = Invoke-AzResourceGraphQuery -Query $jitQuery -SubscriptionId $SubscriptionId -UseCache
            $jitCount = if ($jitResult.Count -gt 0) { $jitResult[0].JITPolicies } else { 0 }
            
            # 3. Container Hardening: AKS Security
            $aksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| extend 
    securityProfile = properties.securityProfile
| where securityProfile.azureDefender.enabled == true or securityProfile.defender.enabled == true
| summarize SecureAKS = count()
"@
            $aksResult = Invoke-AzResourceGraphQuery -Query $aksQuery -SubscriptionId $SubscriptionId -UseCache
            $secureAKS = if ($aksResult.Count -gt 0) { $aksResult[0].SecureAKS } else { 0 }
            
            $totalAKSQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.containerservice/managedclusters'
| summarize TotalAKS = count()
"@
            $totalAKSResult = Invoke-AzResourceGraphQuery -Query $totalAKSQuery -SubscriptionId $SubscriptionId -UseCache
            $totalAKS = if ($totalAKSResult.Count -gt 0) { $totalAKSResult[0].TotalAKS } else { 0 }
            
            # 4. Database Hardening: SQL Auditing/Firewall
            $sqlAuditQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers/auditingSettings'
| where properties.state == 'Enabled'
| summarize AuditedSQL = count()
"@
            $sqlAuditResult = Invoke-AzResourceGraphQuery -Query $sqlAuditQuery -SubscriptionId $SubscriptionId -UseCache
            $auditedSQL = if ($sqlAuditResult.Count -gt 0) { $sqlAuditResult[0].AuditedSQL } else { 0 }
            
            $totalSQLQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.sql/servers'
| summarize TotalSQL = count()
"@
            $totalSQLResult = Invoke-AzResourceGraphQuery -Query $totalSQLQuery -SubscriptionId $SubscriptionId -UseCache
            $totalSQL = if ($totalSQLResult.Count -gt 0) { $totalSQLResult[0].TotalSQL } else { 0 }
            
            # 5. App Service Hardening: Disable Unused Features
            $appQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites'
| extend 
    ftpState = tostring(properties.siteConfig.ftpsState)
| where ftpState == 'Disabled'
| summarize HardenedApps = count()
"@
            $appResult = Invoke-AzResourceGraphQuery -Query $appQuery -SubscriptionId $SubscriptionId -UseCache
            $hardenedApps = if ($appResult.Count -gt 0) { $appResult[0].HardenedApps } else { 0 }
            
            $totalAppQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.web/sites'
| summarize TotalApps = count()
"@
            $totalAppResult = Invoke-AzResourceGraphQuery -Query $totalAppQuery -SubscriptionId $SubscriptionId -UseCache
            $totalApps = if ($totalAppResult.Count -gt 0) { $totalAppResult[0].TotalApps } else { 0 }
            
            # Calculate indicators
            $indicators = @()
            
            if ($vulnResolvePercent -lt 80) {
                $indicators += "Low vulnerability resolution rate ($vulnResolvePercent%)"
            }
            
            if ($automationCount -eq 0) {
                $indicators += "No Automation Accounts for Update Management"
            }
            
            if ($jitCount -eq 0) {
                $indicators += "No JIT network access policies"
            }
            
            if ($secureAKS -lt $totalAKS) {
                $indicators += "Not all AKS clusters hardened with Defender ($secureAKS/$totalAKS)"
            }
            
            if ($auditedSQL -lt $totalSQL) {
                $indicators += "Not all SQL servers have auditing enabled ($auditedSQL/$totalSQL)"
            }
            
            if ($hardenedApps -lt $totalApps) {
                $indicators += "Not all App Services have FTP disabled ($hardenedApps/$totalApps)"
            }
            
            $evidence = @"
Hardening Assessment:
- Vulnerability Resolution: $resolvedCount / $vulnCount ($vulnResolvePercent%)
- Update Management Accounts: $automationCount
- JIT Policies: $jitCount
- Secure AKS: $secureAKS / $totalAKS
- Audited SQL Servers: $auditedSQL / $totalSQL
- Hardened App Services: $hardenedApps / $totalApps
"@
            
            if ($indicators.Count -eq 0) {
                return New-WafResult -CheckId 'SE08' `
                    -Status 'Pass' `
                    -Message 'Strong resource hardening across components' `
                    -Metadata @{
                        VulnPercent = $vulnResolvePercent
                        Automation = $automationCount
                        JIT = $jitCount
                        SecureAKS = $secureAKS
                        AuditedSQL = $auditedSQL
                        HardenedApps = $hardenedApps
                    }
            } else {
                return New-WafResult -CheckId 'SE08' `
                    -Status 'Fail' `
                    -Message "Hardening gaps identified: $($indicators.Count) issues requiring attention" `
                    -Recommendation @"
**CRITICAL**: Insufficient resource hardening increases exploit risks.

Issues identified:
$($indicators | ForEach-Object { "• $_" } | Out-String)

## Immediate Actions Required:

### Phase 1: Vulnerability Management (Week 1)
1. **Enable Assessments**: In Defender for Cloud
2. **Set Up Patching**: Use Update Management
3. **Configure JIT**: For VMs

### Phase 2: Component Hardening (Weeks 2-3)
1. **Secure AKS**: Enable Defender
2. **Audit Databases**: Enable SQL auditing
3. **Harden Apps**: Disable unused features

$evidence
"@ `
                    -RemediationScript @"
# Quick Hardening Setup

# Enable Defender Vulnerability Assessment
Set-AzSecurityPricing -Name 'VirtualMachines' -PricingTier 'Standard'

# Create JIT Policy
$jitPolicy = @{
    VirtualMachines = @(@{ id = '/subscriptions/$SubscriptionId/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm'; ports = @(@{ number = 22; allowedSourceAddressPrefix = @('*'); maxRequestAccessDuration = 'PT3H' }) })
}
New-AzSecurityJitNetworkAccessPolicy -ResourceGroupName 'rg' -Location 'eastus' -Name 'jit-policy' -Kind 'Basic' -VirtualMachine $jitPolicy.VirtualMachines

# Disable App FTP
Update-AzWebApp -ResourceGroupName 'rg' -Name 'app' -FtpsState 'Disabled'

Write-Host "Basic hardening configured - expand to containers and databases"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'SE08' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
