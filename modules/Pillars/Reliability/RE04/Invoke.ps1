<#
.SYNOPSIS
    RE04 - Define reliability and recovery targets

.DESCRIPTION
    Validates that the workload has clearly defined reliability targets including
    availability targets (SLO), recovery time objectives (RTO), recovery point 
    objectives (RPO), and that monitoring is in place to measure against these targets.
    
    This check assesses:
    - Presence of availability monitoring and alerting
    - Azure Monitor alert rules configured for availability metrics
    - Service Health alerts for platform incidents
    - Backup policies and retention settings
    - Disaster recovery configurations
    - Application Insights availability tests
    - SLA monitoring and tracking

.NOTES
    Pillar: Reliability
    Recommendation: RE:04 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/metrics
    https://learn.microsoft.com/azure/well-architected/reliability/disaster-recovery
#>

Register-WafCheck -CheckId 'RE04' `
    -Pillar 'Reliability' `
    -Title 'Define reliability and recovery targets' `
    -Description 'Establish reliability targets including availability SLOs, RTO, RPO, and implement monitoring to track against these targets' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('Reliability', 'SLO', 'RTO', 'RPO', 'Monitoring', 'Availability', 'Recovery') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/metrics' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            $findings = @()
            $score = 0
            $maxScore = 0
            
            # 1. CHECK FOR METRIC ALERTS (Availability Monitoring)
            Write-Verbose "Checking for metric alert rules..."
            $metricAlerts = Get-AzMetricAlertRuleV2 -ErrorAction SilentlyContinue
            
            $availabilityAlerts = $metricAlerts | Where-Object { 
                $_.Criteria -and (
                    $_.Criteria.MetricName -match 'Availability|Health|Success|Failure|Error' -or
                    $_.Description -match 'SLO|SLA|uptime|availability'
                )
            }
            
            $maxScore += 20
            if ($availabilityAlerts.Count -gt 0) {
                $score += 20
                $findings += "✓ Found $($availabilityAlerts.Count) availability-related metric alerts"
            } else {
                $findings += "✗ No availability metric alerts configured"
            }
            
            # 2. CHECK FOR SERVICE HEALTH ALERTS
            Write-Verbose "Checking for Service Health alerts..."
            $serviceHealthAlerts = Get-AzActivityLogAlert -ErrorAction SilentlyContinue | Where-Object {
                $_.Condition.AllOf | Where-Object {
                    $_.Field -eq 'category' -and $_.Equals -eq 'ServiceHealth'
                }
            }
            
            $maxScore += 15
            if ($serviceHealthAlerts.Count -gt 0) {
                $score += 15
                $findings += "✓ Found $($serviceHealthAlerts.Count) Service Health alert(s) - monitors platform incidents"
            } else {
                $findings += "✗ No Service Health alerts configured - will miss Azure platform incidents"
            }
            
            # 3. CHECK FOR APPLICATION INSIGHTS AVAILABILITY TESTS
            Write-Verbose "Checking for Application Insights availability tests..."
            $appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue
            $totalAvailabilityTests = 0
            
            foreach ($ai in $appInsights) {
                try {
                    $tests = Get-AzApplicationInsightsWebTest -ResourceGroupName $ai.ResourceGroup -ErrorAction SilentlyContinue
                    if ($tests) {
                        $totalAvailabilityTests += $tests.Count
                    }
                } catch {
                    # Continue checking other App Insights
                }
            }
            
            $maxScore += 20
            if ($totalAvailabilityTests -gt 0) {
                $score += 20
                $findings += "✓ Found $totalAvailabilityTests availability test(s) across $($appInsights.Count) Application Insights instance(s)"
            } elseif ($appInsights.Count -gt 0) {
                $score += 5
                $findings += "⚠ Application Insights deployed but no availability tests configured"
            } else {
                $findings += "✗ No Application Insights or availability tests found"
            }
            
            # 4. CHECK FOR BACKUP CONFIGURATIONS (RPO Indicator)
            Write-Verbose "Checking backup policies for RPO definition..."
            $recoveryVaults = Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue
            $backupPolicies = @()
            $protectedItems = 0
            
            foreach ($vault in $recoveryVaults) {
                try {
                    Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $policies = Get-AzRecoveryServicesBackupProtectionPolicy -ErrorAction SilentlyContinue
                    if ($policies) {
                        $backupPolicies += $policies
                    }
                    
                    # Count protected items
                    $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction SilentlyContinue
                    foreach ($container in $containers) {
                        $items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -ErrorAction SilentlyContinue
                        $protectedItems += ($items | Measure-Object).Count
                    }
                } catch {
                    # Continue checking other vaults
                }
            }
            
            $maxScore += 20
            if ($backupPolicies.Count -gt 0 -and $protectedItems -gt 0) {
                $score += 20
                $findings += "✓ Found $($backupPolicies.Count) backup policies protecting $protectedItems item(s) - RPO defined"
            } elseif ($recoveryVaults.Count -gt 0) {
                $score += 5
                $findings += "⚠ Recovery Services Vaults exist but limited backup coverage"
            } else {
                $findings += "✗ No backup policies found - RPO not defined"
            }
            
            # 5. CHECK FOR DISASTER RECOVERY (RTO Indicator)
            Write-Verbose "Checking for disaster recovery configurations..."
            $asrProtectedItems = 0
            
            foreach ($vault in $recoveryVaults) {
                try {
                    Set-AzRecoveryServicesAsrVaultContext -Vault $vault -ErrorAction SilentlyContinue
                    $items = Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue
                    $asrProtectedItems += ($items | Measure-Object).Count
                } catch {
                    # Continue checking other vaults
                }
            }
            
            # Also check for SQL geo-replication
            $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
            $geoReplicatedDbs = 0
            
            foreach ($server in $sqlServers) {
                $databases = Get-AzSqlDatabase -ServerName $server.ServerName `
                    -ResourceGroupName $server.ResourceGroupName `
                    -ErrorAction SilentlyContinue | 
                    Where-Object { $_.DatabaseName -ne 'master' }
                
                foreach ($db in $databases) {
                    $links = Get-AzSqlDatabaseReplicationLink `
                        -ServerName $server.ServerName `
                        -DatabaseName $db.DatabaseName `
                        -ResourceGroupName $server.ResourceGroupName `
                        -ErrorAction SilentlyContinue
                    
                    if ($links) {
                        $geoReplicatedDbs++
                    }
                }
            }
            
            $maxScore += 15
            if ($asrProtectedItems -gt 0 -or $geoReplicatedDbs -gt 0) {
                $score += 15
                $findings += "✓ Disaster recovery configured: ASR protected items: $asrProtectedItems, Geo-replicated DBs: $geoReplicatedDbs"
            } else {
                $findings += "✗ No disaster recovery configuration found - RTO not achievable"
            }
            
            # 6. CHECK FOR ACTION GROUPS (Alerting Infrastructure)
            Write-Verbose "Checking for action groups..."
            $actionGroups = Get-AzActionGroup -ErrorAction SilentlyContinue
            
            $maxScore += 10
            if ($actionGroups.Count -gt 0) {
                $score += 10
                
                # Analyze action group configurations
                $hasEmail = ($actionGroups | Where-Object { $_.EmailReceivers.Count -gt 0 }).Count
                $hasSms = ($actionGroups | Where-Object { $_.SmsReceivers.Count -gt 0 }).Count
                $hasWebhook = ($actionGroups | Where-Object { $_.WebhookReceivers.Count -gt 0 }).Count
                $hasLogicApp = ($actionGroups | Where-Object { $_.AzureAppPushReceivers.Count -gt 0 -or $_.AutomationRunbookReceivers.Count -gt 0 }).Count
                
                $findings += "✓ Found $($actionGroups.Count) action group(s): Email($hasEmail) SMS($hasSms) Webhook($hasWebhook) Automation($hasLogicApp)"
            } else {
                $findings += "✗ No action groups configured - alerts will not be delivered"
            }
            
            # 7. CHECK FOR LOG ANALYTICS WORKSPACES (Monitoring Foundation)
            Write-Verbose "Checking for Log Analytics workspaces..."
            $logWorkspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
            
            # Check for diagnostic settings sending to Log Analytics
            $diagnosticSettingsQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/diagnosticsettings'
| extend workspaceId = tostring(properties.workspaceId)
| where isnotempty(workspaceId)
| summarize ResourcesWithDiagnostics = count()
"@
            $diagSettings = Invoke-AzResourceGraphQuery -Query $diagnosticSettingsQuery -SubscriptionId $SubscriptionId -UseCache
            
            $resourcesWithDiagnostics = if ($diagSettings.Count -gt 0) { $diagSettings[0].ResourcesWithDiagnostics } else { 0 }
            
            # Calculate overall score percentage
            $scorePercentage = if ($maxScore -gt 0) { [Math]::Round(($score / $maxScore) * 100) } else { 0 }
            
            # Build evidence
            $evidence = @"
Reliability Targets Assessment:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OVERALL SCORE: $score / $maxScore points ($scorePercentage%)

AVAILABILITY MONITORING (SLO Tracking):
- Metric Alert Rules: $($metricAlerts.Count) total, $($availabilityAlerts.Count) availability-focused
- Application Insights: $($appInsights.Count) instance(s), $totalAvailabilityTests availability test(s)
- Service Health Alerts: $($serviceHealthAlerts.Count)
- Action Groups: $($actionGroups.Count)

RECOVERY TARGETS (RTO/RPO):
- Recovery Services Vaults: $($recoveryVaults.Count)
- Backup Policies: $($backupPolicies.Count)
- Protected Items: $protectedItems
- ASR Protected Items: $asrProtectedItems
- Geo-Replicated Databases: $geoReplicatedDbs

MONITORING INFRASTRUCTURE:
- Log Analytics Workspaces: $($logWorkspaces.Count)
- Resources with Diagnostics: $resourcesWithDiagnostics

FINDINGS:
$($findings | ForEach-Object { "$_" } | Out-String)
"@
            
            # Determine status based on score
            if ($scorePercentage -ge 80) {
                return New-WafResult -CheckId 'RE04' `
                    -Status 'Pass' `
                    -Message "Strong reliability targets with comprehensive monitoring: $scorePercentage% coverage" `
                    -Metadata @{
                        Score = $score
                        MaxScore = $maxScore
                        ScorePercentage = $scorePercentage
                        MetricAlerts = $metricAlerts.Count
                        AvailabilityAlerts = $availabilityAlerts.Count
                        AvailabilityTests = $totalAvailabilityTests
                        BackupPolicies = $backupPolicies.Count
                        ProtectedItems = $protectedItems
                        ASRProtectedItems = $asrProtectedItems
                        ActionGroups = $actionGroups.Count
                    }
                    
            } elseif ($scorePercentage -ge 50) {
                
                return New-WafResult -CheckId 'RE04' `
                    -Status 'Warning' `
                    -Message "Partial reliability targets defined: $scorePercentage% coverage - gaps in monitoring or recovery" `
                    -Recommendation @"
Improve your reliability targets and monitoring:

## Current State Analysis:
$evidence

## Required Actions:

### 1. Define Clear Reliability Targets
Create documented targets for each critical workload:

**Availability Target (SLO)**:
- Define target uptime percentage (e.g., 99.9%, 99.95%, 99.99%)
- Document acceptable downtime per month
- Identify dependencies and their SLAs

**Recovery Time Objective (RTO)**:
- Maximum acceptable downtime duration
- Time to restore service after failure
- Include time for detection, response, and recovery

**Recovery Point Objective (RPO)**:
- Maximum acceptable data loss duration
- How much data can be lost (minutes, hours)?
- Determines backup frequency requirements

Example Target Definition:
```
Service: Customer Portal
- SLO: 99.9% (43.2 minutes downtime/month)
- RTO: 1 hour
- RPO: 15 minutes
- Monitoring: Availability tests every 5 minutes
```

### 2. Implement Availability Monitoring

#### Enable Application Insights Availability Tests:
```powershell
# Create availability test for critical endpoint
`$appInsights = Get-AzApplicationInsights -ResourceGroupName 'rg-monitoring' -Name 'app-insights'

New-AzApplicationInsightsWebTest ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'critical-endpoint-availability' ``
    -Location 'eastus' ``
    -Kind 'ping' ``
    -TestName 'Production API Health Check' ``
    -Enabled `$true ``
    -Frequency 300 ``
    -Timeout 120 ``
    -GeoLocation @('us-east-2-az-eus-edge', 'emea-nl-ams-azr', 'apac-sg-sin-azr') ``
    -RequestUrl 'https://api.contoso.com/health' ``
    -ExpectedHttpStatusCode 200
```

#### Create Metric Alerts for SLO Tracking:
```powershell
# Alert when availability drops below target
`$actionGroup = Get-AzActionGroup -ResourceGroupName 'rg-monitoring' -Name 'ops-team'

`$condition = New-AzMetricAlertRuleV2Criteria ``
    -MetricName 'Availability' ``
    -TimeAggregation Average ``
    -Operator LessThan ``
    -Threshold 99.9

New-AzMetricAlertRuleV2 ``
    -Name 'slo-availability-breach' ``
    -ResourceGroupName 'rg-monitoring' ``
    -WindowSize (New-TimeSpan -Minutes 15) ``
    -Frequency (New-TimeSpan -Minutes 5) ``
    -TargetResourceId `$appInsights.Id ``
    -Condition `$condition ``
    -ActionGroupId `$actionGroup.Id ``
    -Severity 1 ``
    -Description 'Availability below 99.9% SLO target'
```

### 3. Configure Service Health Alerts

```powershell
# Alert on Azure service incidents
`$condition = New-AzActivityLogAlertCondition ``
    -Field 'category' ``
    -Equal 'ServiceHealth'

New-AzActivityLogAlert ``
    -Name 'azure-service-health-incidents' ``
    -ResourceGroupName 'rg-monitoring' ``
    -Condition `$condition ``
    -Action `$actionGroup ``
    -Location 'global' ``
    -Description 'Alerts on Azure platform service health incidents'
```

### 4. Define and Implement RPO (Backup Strategy)

```powershell
# Create backup policy with defined RPO
`$vault = Get-AzRecoveryServicesVault -ResourceGroupName 'rg-backup' -Name 'vault-prod'
Set-AzRecoveryServicesVaultContext -Vault `$vault

# Daily backups for 15-minute RPO (with incremental backups)
`$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
`$schedulePolicy.ScheduleRunFrequency = 'Daily'
`$schedulePolicy.ScheduleRunTimes[0] = '2024-01-01T02:00:00Z'

`$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
`$retentionPolicy.DailySchedule.DurationCountInDays = 30
`$retentionPolicy.WeeklySchedule.DurationCountInWeeks = 12
`$retentionPolicy.MonthlySchedule.DurationCountInMonths = 12
`$retentionPolicy.YearlySchedule.DurationCountInYears = 5

New-AzRecoveryServicesBackupProtectionPolicy ``
    -Name 'DailyBackup-RPO15min' ``
    -WorkloadType AzureVM ``
    -RetentionPolicy `$retentionPolicy ``
    -SchedulePolicy `$schedulePolicy
```

### 5. Define and Implement RTO (Disaster Recovery)

#### Enable Azure Site Recovery:
```powershell
# Set up ASR for critical VMs
`$vault = Get-AzRecoveryServicesVault -ResourceGroupName 'rg-dr' -Name 'vault-asr'
Set-AzRecoveryServicesAsrVaultContext -Vault `$vault

# Configure replication for VM (enables RTO of ~15-30 minutes)
`$vm = Get-AzVM -ResourceGroupName 'rg-prod' -Name 'vm-critical'
`$fabric = Get-AzRecoveryServicesAsrFabric -Name 'asr-fabric-eastus'
`$protectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric `$fabric

# Enable replication to secondary region
New-AzRecoveryServicesAsrReplicationProtectedItem ``
    -ProtectionContainer `$protectionContainer ``
    -Name `$vm.Name ``
    -RecoveryAzureStorageAccountId '/subscriptions/.../storageAccounts/stdr' ``
    -RecoveryResourceGroupId '/subscriptions/.../resourceGroups/rg-dr'
```

#### Enable Database Geo-Replication:
```powershell
# Geo-replicate SQL databases for low RTO
`$primaryServer = Get-AzSqlServer -ResourceGroupName 'rg-prod' -ServerName 'sql-primary'
`$secondaryServer = Get-AzSqlServer -ResourceGroupName 'rg-dr' -ServerName 'sql-secondary'

Get-AzSqlDatabase -ServerName `$primaryServer.ServerName ``
    -ResourceGroupName `$primaryServer.ResourceGroupName ``
    -DatabaseName 'db-critical' |
    New-AzSqlDatabaseSecondary ``
        -PartnerResourceGroupName `$secondaryServer.ResourceGroupName ``
        -PartnerServerName `$secondaryServer.ServerName ``
        -AllowConnections All
```

### 6. Create SLO Dashboards

Build monitoring dashboards to track against targets:
```powershell
# Create Azure Dashboard for SLO tracking
`$dashboard = @{
    location = 'eastus'
    properties = @{
        lenses = @{
            '0' = @{
                order = 0
                parts = @{
                    '0' = @{
                        position = @{ x = 0; y = 0; rowSpan = 4; colSpan = 6 }
                        metadata = @{
                            type = 'Extension/HubsExtension/PartType/MonitorChartPart'
                            settings = @{
                                content = @{
                                    chartType = 'Line'
                                    metrics = @(
                                        @{
                                            resourceMetadata = @{ id = `$appInsights.Id }
                                            name = 'availabilityResults/availabilityPercentage'
                                            aggregationType = 'Average'
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

New-AzPortalDashboard ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'SLO-Dashboard' ``
    -Dashboard `$dashboard
```

### 7. Establish Review Cadence

- **Daily**: Review availability test results
- **Weekly**: Check SLO compliance, review incidents
- **Monthly**: Analyze trends, update targets if needed
- **Quarterly**: Test DR procedures, validate RTO/RPO

### 8. Document Targets

Create a reliability targets document:
```markdown
# Reliability Targets - Customer Portal

## Service Level Objectives (SLO)
- **Target**: 99.9% availability
- **Error Budget**: 43.2 minutes/month
- **Measurement**: Application Insights availability tests (5-minute intervals)

## Recovery Time Objective (RTO)
- **Target**: 1 hour
- **Measurement**: Time from incident detection to service restoration
- **Strategy**: Active-passive failover to secondary region

## Recovery Point Objective (RPO)
- **Target**: 15 minutes
- **Measurement**: Maximum acceptable data loss
- **Strategy**: Continuous replication + hourly backups

## Dependencies
| Dependency | SLA | Impact if Down | Mitigation |
|------------|-----|----------------|------------|
| Azure SQL DB | 99.99% | Critical - no data access | Geo-replication to secondary |
| Storage Account | 99.9% | High - no file access | GRS replication |
| Azure AD | 99.99% | Critical - no auth | Cached tokens, 4hr validity |

## Monitoring
- Availability tests from 3 geographic locations
- Metric alerts on availability < 99.9%
- Service Health alerts for Azure incidents
- Weekly SLO compliance reports
```

Current Gaps:
$evidence
"@ `
                    -RemediationScript @"
# Reliability Targets Quick Setup Script

Write-Host "Setting up reliability targets and monitoring..." -ForegroundColor Cyan

# Configuration
`$resourceGroupName = 'rg-monitoring'
`$location = 'eastus'
`$appInsightsName = 'appinsights-slo'
`$actionGroupName = 'ag-reliability'

# 1. Ensure resource group exists
if (-not (Get-AzResourceGroup -Name `$resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name `$resourceGroupName -Location `$location
}

# 2. Create or get Application Insights
Write-Host "[1/6] Setting up Application Insights..." -ForegroundColor Yellow
`$appInsights = Get-AzApplicationInsights -ResourceGroupName `$resourceGroupName -Name `$appInsightsName -ErrorAction SilentlyContinue

if (-not `$appInsights) {
    `$appInsights = New-AzApplicationInsights ``
        -ResourceGroupName `$resourceGroupName ``
        -Name `$appInsightsName ``
        -Location `$location ``
        -Kind 'web'
    Write-Host "  ✓ Created Application Insights: `$appInsightsName" -ForegroundColor Green
} else {
    Write-Host "  ✓ Using existing Application Insights: `$appInsightsName" -ForegroundColor Green
}

# 3. Create action group for alerts
Write-Host "[2/6] Setting up action group..." -ForegroundColor Yellow
`$actionGroup = Get-AzActionGroup -ResourceGroupName `$resourceGroupName -Name `$actionGroupName -ErrorAction SilentlyContinue

if (-not `$actionGroup) {
    # Prompt for email
    `$email = Read-Host "Enter email address for alerts"
    
    `$emailReceiver = New-AzActionGroupReceiver ``
        -Name 'EmailOps' ``
        -EmailReceiver ``
        -EmailAddress `$email
    
    `$actionGroup = Set-AzActionGroup ``
        -ResourceGroupName `$resourceGroupName ``
        -Name `$actionGroupName ``
        -ShortName 'RelAlerts' ``
        -Receiver `$emailReceiver
    
    Write-Host "  ✓ Created action group with email: `$email" -ForegroundColor Green
} else {
    Write-Host "  ✓ Using existing action group: `$actionGroupName" -ForegroundColor Green
}

# 4. Create availability test
Write-Host "[3/6] Creating availability test..." -ForegroundColor Yellow
`$testUrl = Read-Host "Enter URL to monitor (e.g., https://api.contoso.com/health)"

`$webTestXml = @"
<WebTest Name="SLO Availability Test" Enabled="True" Timeout="30">
  <Items>
    <Request Method="GET" Version="1.1" Url="`$testUrl" 
             ThinkTime="0" Timeout="30" ParseDependentRequests="False" 
             FollowRedirects="True" RecordResult="True" Cache="False" 
             ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
"@

try {
    New-AzApplicationInsightsWebTest ``
        -ResourceGroupName `$resourceGroupName ``
        -Name 'webtest-slo-availability' ``
        -Location `$location ``
        -Kind 'ping' ``
        -WebTest `$webTestXml ``
        -GeoLocation @('us-east-2-az-eus-edge', 'emea-nl-ams-azr', 'apac-sg-sin-azr') ``
        -Frequency 300 ``
        -Timeout 30 ``
        -Enabled `$true ``
        -Tag @{ "hidden-link:`$(`$appInsights.Id)" = "Resource" } ``
        -ErrorAction Stop
    
    Write-Host "  ✓ Created availability test for: `$testUrl" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create availability test: `$_" -ForegroundColor Red
}

# 5. Create SLO availability alert (< 99.9%)
Write-Host "[4/6] Creating SLO breach alert..." -ForegroundColor Yellow

`$condition = New-AzMetricAlertRuleV2Criteria ``
    -MetricName 'availabilityResults/availabilityPercentage' ``
    -TimeAggregation Average ``
    -Operator LessThan ``
    -Threshold 99.9

try {
    New-AzMetricAlertRuleV2 ``
        -Name 'alert-slo-breach-99-9' ``
        -ResourceGroupName `$resourceGroupName ``
        -WindowSize (New-TimeSpan -Minutes 15) ``
        -Frequency (New-TimeSpan -Minutes 5) ``
        -TargetResourceId `$appInsights.Id ``
        -Condition `$condition ``
        -ActionGroupId `$actionGroup.Id ``
        -Severity 1 ``
        -Description 'Availability dropped below 99.9% SLO target' ``
        -ErrorAction Stop
    
    Write-Host "  ✓ Created SLO breach alert (threshold: 99.9%)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create alert: `$_" -ForegroundColor Red
}

# 6. Create Service Health alert
Write-Host "[5/6] Creating Service Health alert..." -ForegroundColor Yellow

`$condition = New-AzActivityLogAlertCondition ``
    -Field 'category' ``
    -Equal 'ServiceHealth'

try {
    New-AzActivityLogAlert ``
        -Name 'alert-service-health' ``
        -ResourceGroupName `$resourceGroupName ``
        -Condition `$condition ``
        -Action `$actionGroup ``
        -Location 'global' ``
        -Description 'Azure Service Health incidents' ``
        -ErrorAction Stop
    
    Write-Host "  ✓ Created Service Health alert" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create Service Health alert: `$_" -ForegroundColor Red
}

# 7. Generate reliability targets template
Write-Host "[6/6] Generating reliability targets document..." -ForegroundColor Yellow

`$template = @"
# Reliability Targets

## Service Level Objectives (SLO)

### Production Services
| Service | Availability Target | Error Budget | Measurement |
|---------|-------------------|--------------|-------------|
| API Endpoint | 99.9% | 43.2 min/month | Application Insights availability tests |
| Database | 99.95% | 21.6 min/month | Azure SQL built-in monitoring |
| Storage | 99.9% | 43.2 min/month | Storage metrics |

## Recovery Targets

### Recovery Time Objective (RTO)
- **Target**: 1 hour maximum downtime
- **Measurement**: Time from incident detection to service restoration
- **Validation**: Quarterly DR drills

### Recovery Point Objective (RPO)
- **Target**: 15 minutes maximum data loss
- **Measurement**: Backup frequency and replication lag
- **Validation**: Monthly restore tests

## Monitoring Configuration

### Application Insights
- Instance: `$appInsightsName
- Availability Tests: Multi-region (US, EU, APAC)
- Test Frequency: Every 5 minutes
- Alert Threshold: < 99.9% availability over 15 minutes

### Alert Configuration
- Action Group: `$actionGroupName
- Notification: Email to operations team
- Severity 1: SLO breach or Service Health incident
- Severity 2: Warning indicators (approaching thresholds)

## Next Steps

1. **Define targets for additional services**
   - Review all production workloads
   - Set appropriate SLO/RTO/RPO for each tier
   
2. **Implement backup strategy**
   - Configure Azure Backup with RPO-aligned schedules
   - Test restore procedures monthly
   
3. **Set up disaster recovery**
   - Enable Azure Site Recovery for critical VMs
   - Configure geo-replication for databases
   - Document failover procedures
   
4. **Establish review cadence**
   - Daily: Review availability test results
   - Weekly: SLO compliance check
   - Monthly: Incident retrospectives
   - Quarterly: Target review and DR drills

## Reference

- Application Insights: `$(`$appInsights.Id)
- Action Group: `$(`$actionGroup.Id)
- Monitoring: https://portal.azure.com/#@/resource`$(`$appInsights.Id)/overview

Generated: $(Get-Date)
"@

`$template | Out-File 'reliability-targets.md' -Encoding UTF8
Write-Host "  ✓ Saved reliability targets template to: reliability-targets.md" -ForegroundColor Green

Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Review and customize reliability-targets.md" -ForegroundColor Gray
Write-Host "2. Configure backup policies for critical resources" -ForegroundColor Gray
Write-Host "3. Enable disaster recovery (ASR/geo-replication)" -ForegroundColor Gray
Write-Host "4. Schedule quarterly DR drills" -ForegroundColor Gray
Write-Host "`nMonitoring dashboard: https://portal.azure.com/#@/resource`$(`$appInsights.Id)/overview" -ForegroundColor Gray
"@
                    
            } else {
                
                return New-WafResult -CheckId 'RE04' `
                    -Status 'Fail' `
                    -Message "CRITICAL: Reliability targets not defined - insufficient monitoring and recovery capabilities ($scorePercentage%)" `
                    -Recommendation @"
**IMMEDIATE ACTION REQUIRED**: Reliability targets are fundamental to operating production workloads.

## Why This Matters:

Without defined reliability targets, you cannot:
- Know if your service is meeting expectations
- Prioritize which incidents require immediate response
- Make informed architectural decisions
- Allocate resources effectively
- Meet customer commitments

Current Score: $scorePercentage% (CRITICAL)

## Critical Gaps:
$evidence

## Immediate Actions (This Week):

### 1. Define Basic Reliability Targets

For EACH production service, document:

**Availability Target (SLO)**: Target uptime percentage
- Tier 1 (Critical): 99.95% = 21.6 min downtime/month
- Tier 2 (Important): 99.9% = 43.2 min downtime/month  
- Tier 3 (Standard): 99.5% = 3.6 hours downtime/month

**Recovery Time Objective (RTO)**: How quickly must service be restored?
- Critical: < 15 minutes
- Important: < 1 hour
- Standard: < 4 hours

**Recovery Point Objective (RPO)**: How much data loss is acceptable?
- Zero data loss: Synchronous replication
- Minimal loss: < 5 minutes (continuous backup)
- Acceptable loss: < 1 hour (hourly backups)

### 2. Set Up Basic Monitoring (Day 1-2)

#### Deploy Application Insights:
```powershell
# Quick start - deploy Application Insights
New-AzApplicationInsights ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'app-insights-prod' ``
    -Location 'eastus' ``
    -Kind 'web'
```

#### Create First Availability Test:
```powershell
# Monitor your most critical endpoint
New-AzApplicationInsightsWebTest ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'critical-endpoint-test' ``
    -Location 'eastus' ``
    -Kind 'ping' ``
    -Enabled `$true ``
    -Frequency 300 ``
    -Timeout 30 ``
    -RequestUrl 'https://your-critical-endpoint.com/health'
```

### 3. Create Action Group (Day 2)

Don't have alerts go nowhere:
```powershell
# Create notification channel
`$email = New-AzActionGroupReceiver ``
    -Name 'OpsTeam' ``
    -EmailReceiver ``
    -EmailAddress 'ops@company.com'

Set-AzActionGroup ``
    -ResourceGroupName 'rg-monitoring' ``
    -Name 'ag-production-alerts' ``
    -ShortName 'ProdAlert' ``
    -Receiver `$email
```

### 4. Set Up Service Health Alerts (Day 2)

Know when Azure has problems:
```powershell
`$condition = New-AzActivityLogAlertCondition ``
    -Field 'category' ``
    -Equal 'ServiceHealth'

New-AzActivityLogAlert ``
    -Name 'alert-azure-service-health' ``
    -ResourceGroupName 'rg-monitoring' ``
    -Condition `$condition ``
    -Action (Get-AzActionGroup -Name 'ag-production-alerts') ``
    -Location 'global'
```

### 5. Implement Basic Backup (Week 1)

Meet your RPO:
```powershell
# Create Recovery Services Vault
New-AzRecoveryServicesVault ``
    -ResourceGroupName 'rg-backup' ``
    -Name 'vault-prod' ``
    -Location 'eastus'

# Enable backup for VMs
`$vault = Get-AzRecoveryServicesVault -Name 'vault-prod'
Set-AzRecoveryServicesVaultContext -Vault `$vault

# Create daily backup policy
`$policy = Get-AzRecoveryServicesBackupProtectionPolicy ``
    -WorkloadType AzureVM ``
    -Name 'DefaultPolicy'

# Enable backup on critical VMs
Get-AzVM -ResourceGroupName 'rg-prod' | ForEach-Object {
    Enable-AzRecoveryServicesBackupProtection ``
        -ResourceGroupName `$_.ResourceGroupName ``
        -Name `$_.Name ``
        -Policy `$policy
}
```

### 6. Document Everything (Week 1)

Create a simple reliability targets document:

```markdown
# Reliability Targets - [Service Name]

## Current State
- Monitoring: [Yes/No]
- Backup: [Yes/No]
- DR: [Yes/No]

## Targets
- Availability: 99.9%
- RTO: 1 hour
- RPO: 15 minutes

## How We Measure
- Availability tests every 5 minutes
- Alert if < 99.9% over 15 min window
- Weekly SLO compliance review

## Recovery Procedures
1. Detection: Automated alerts via action group
2. Assessment: Check Application Insights dashboard
3. Response: Follow runbook [link]
4. Recovery: Restore from backup or failover to DR

## Next Review: [Date]
```

## Week 2-4: Enhance Coverage

After basics are in place:

1. **Add more availability tests** for all critical endpoints
2. **Enable geo-replication** for databases (low RTO)
3. **Configure Azure Site Recovery** for VMs (automated DR)
4. **Create SLO dashboards** in Azure Portal
5. **Test recovery procedures** - validate RTO/RPO are achievable
6. **Establish review cadence** - weekly SLO checks

## Success Metrics:

After 4 weeks, you should have:
- ✓ Documented SLO/RTO/RPO for all Tier 1 services
- ✓ Availability tests running on all critical endpoints
- ✓ Action groups configured and tested
- ✓ Service Health alerts active
- ✓ Daily backups with validated restores
- ✓ SLO dashboard visible to team
- ✓ First reliability review meeting completed

## Cost Impact:

Minimal additional cost:
- Application Insights: ~`$2-5/month for basic monitoring
- Availability tests: ~`$1 per test location per month
- Backup storage: ~`$10-50/month depending on data volume
- Log Analytics: ~`$2-10/month for log retention

**Return**: Avoiding a single 1-hour outage typically justifies years of monitoring costs.

## Resources:

- [Azure Monitor SLA tracking](https://learn.microsoft.com/azure/azure-monitor/sla)
- [Backup and disaster recovery](https://learn.microsoft.com/azure/architecture/framework/resiliency/backup-and-recovery)
- [Define reliability targets](https://learn.microsoft.com/azure/well-architected/reliability/metrics)

Current State Summary:
$evidence

**START TODAY**: Every day without monitoring is a day you're flying blind.
"@ `
                    -RemediationScript @"
# EMERGENCY: Quick Reliability Targets Setup
# Run this script to establish basic monitoring IMMEDIATELY

Write-Host "═" * 70 -ForegroundColor Red
Write-Host "EMERGENCY RELIABILITY SETUP" -ForegroundColor Red
Write-Host "═" * 70 -ForegroundColor Red
Write-Host ""

# Prompt for essential info
Write-Host "This script will set up BASIC reliability monitoring." -ForegroundColor Yellow
Write-Host "You'll need to provide a few pieces of information.`n" -ForegroundColor Yellow

`$subscriptionId = (Get-AzContext).Subscription.Id
`$resourceGroupName = Read-Host "Enter resource group name (will create if doesn't exist)"
`$location = Read-Host "Enter location (e.g., eastus, westus2)"
`$criticalUrl = Read-Host "Enter your MOST CRITICAL URL to monitor (e.g., https://api.example.com/health)"
`$email = Read-Host "Enter email address for alerts"

Write-Host "`nStarting setup..." -ForegroundColor Cyan

# 1. Create resource group if needed
Write-Host "[1/5] Creating resource group..." -ForegroundColor Yellow
if (-not (Get-AzResourceGroup -Name `$resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name `$resourceGroupName -Location `$location | Out-Null
    Write-Host "  ✓ Created resource group: `$resourceGroupName" -ForegroundColor Green
} else {
    Write-Host "  ✓ Using existing resource group: `$resourceGroupName" -ForegroundColor Green
}

# 2. Create Application Insights
Write-Host "[2/5] Creating Application Insights..." -ForegroundColor Yellow
`$appInsights = New-AzApplicationInsights ``
    -ResourceGroupName `$resourceGroupName ``
    -Name "appinsights-emergency-`$(Get-Random -Maximum 9999)" ``
    -Location `$location ``
    -Kind 'web'

Write-Host "  ✓ Created Application Insights: `$(`$appInsights.Name)" -ForegroundColor Green

# 3. Create action group
Write-Host "[3/5] Creating action group..." -ForegroundColor Yellow
`$receiver = New-AzActionGroupReceiver ``
    -Name 'EmergencyContact' ``
    -EmailReceiver ``
    -EmailAddress `$email

`$actionGroup = Set-AzActionGroup ``
    -ResourceGroupName `$resourceGroupName ``
    -Name "ag-emergency-`$(Get-Random -Maximum 9999)" ``
    -ShortName 'Emergency' ``
    -Receiver `$receiver

Write-Host "  ✓ Created action group - alerts will go to: `$email" -ForegroundColor Green
Write-Host "  ⚠ CHECK YOUR EMAIL - confirm the alert subscription!" -ForegroundColor Yellow

# 4. Create availability test
Write-Host "[4/5] Creating availability test..." -ForegroundColor Yellow

`$webTest = @"
<WebTest Name="Emergency Monitoring" Enabled="True" Timeout="30">
  <Items>
    <Request Method="GET" Version="1.1" Url="`$criticalUrl" 
             ThinkTime="0" Timeout="30" ParseDependentRequests="False" 
             FollowRedirects="True" RecordResult="True" Cache="False" 
             ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
"@

New-AzApplicationInsightsWebTest ``
    -ResourceGroupName `$resourceGroupName ``
    -Name "webtest-emergency-`$(Get-Random -Maximum 9999)" ``
    -Location `$location ``
    -Kind 'ping' ``
    -WebTest `$webTest ``
    -GeoLocation @('us-east-2-az-eus-edge') ``
    -Frequency 300 ``
    -Timeout 30 ``
    -Enabled `$true ``
    -Tag @{ "hidden-link:`$(`$appInsights.Id)" = "Resource" } | Out-Null

Write-Host "  ✓ Created availability test for: `$criticalUrl" -ForegroundColor Green

# 5. Create availability alert
Write-Host "[5/5] Creating availability alert..." -ForegroundColor Yellow

`$condition = New-AzMetricAlertRuleV2Criteria ``
    -MetricName 'availabilityResults/availabilityPercentage' ``
    -TimeAggregation Average ``
    -Operator LessThan ``
    -Threshold 95

New-AzMetricAlertRuleV2 ``
    -Name "alert-emergency-availability" ``
    -ResourceGroupName `$resourceGroupName ``
    -WindowSize (New-TimeSpan -Minutes 15) ``
    -Frequency (New-TimeSpan -Minutes 5) ``
    -TargetResourceId `$appInsights.Id ``
    -Condition `$condition ``
    -ActionGroupId `$actionGroup.Id ``
    -Severity 1 ``
    -Description 'EMERGENCY: Availability below 95%' | Out-Null

Write-Host "  ✓ Created availability alert (threshold: 95%)" -ForegroundColor Green

# Summary
Write-Host "`n" -NoNewline
Write-Host "═" * 70 -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "═" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "What was created:" -ForegroundColor White
Write-Host "  • Application Insights: `$(`$appInsights.Name)" -ForegroundColor Gray
Write-Host "  • Availability test: checking `$criticalUrl every 5 minutes" -ForegroundColor Gray
Write-Host "  • Alert: emails `$email if availability < 95%" -ForegroundColor Gray
Write-Host ""
Write-Host "CRITICAL NEXT STEPS:" -ForegroundColor Red
Write-Host "  1. CHECK YOUR EMAIL - confirm alert subscription" -ForegroundColor Yellow
Write-Host "  2. View monitoring dashboard:" -ForegroundColor Yellow
Write-Host "     https://portal.azure.com/#@/resource`$(`$appInsights.Id)/overview" -ForegroundColor Cyan
Write-Host "  3. Define full reliability targets (SLO/RTO/RPO) this week" -ForegroundColor Yellow
Write-Host "  4. Add more availability tests for other critical endpoints" -ForegroundColor Yellow
Write-Host "  5. Set up backups for data recovery (RPO)" -ForegroundColor Yellow
Write-Host ""
Write-Host "This is a BASIC setup. You need to:" -ForegroundColor Red
Write-Host "  - Add more comprehensive monitoring" -ForegroundColor Red
Write-Host "  - Configure disaster recovery" -ForegroundColor Red
Write-Host "  - Document procedures" -ForegroundColor Red
Write-Host "  - Test recovery capabilities" -ForegroundColor Red
Write-Host ""
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE04' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
