<#
.SYNOPSIS
    RE:02 - Identify and rate user and system flows

.DESCRIPTION
    Validates that critical user and system flows are identified, documented, 
    and have criticality ratings to prioritize reliability investments.

.NOTES
    Pillar: Reliability
    Recommendation: RE:02 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/reliability/identify-flows
#>

Register-WafCheck -CheckId 'RE02' `
    -Pillar 'Reliability' `
    -Title 'Identify and rate user and system flows' `
    -Description 'Identify and classify all user and system flows to understand dependencies and prioritize reliability efforts' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -Tags @('Reliability', 'Flows', 'Dependencies', 'Criticality', 'ApplicationMap') `
    -DocumentationUrl 'https://learn.microsoft.com/azure/well-architected/reliability/identify-flows' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Check for Application Insights (provides application map and dependency tracking)
            $appInsights = Get-AzApplicationInsights -ErrorAction SilentlyContinue
            
            # Check for criticality/priority tags on resources
            $criticalityTagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['criticality']) or 
        isnotempty(tags['Criticality']) or
        isnotempty(tags['priority']) or
        isnotempty(tags['Priority']) or
        isnotempty(tags['tier']) or
        isnotempty(tags['Tier'])
| extend criticalityTag = coalesce(
    tags['criticality'],
    tags['Criticality'],
    tags['priority'],
    tags['Priority'],
    tags['tier'],
    tags['Tier']
)
| summarize 
    TaggedResources = count(),
    CriticalityValues = make_set(criticalityTag)
"@
            $criticalityTagged = Invoke-AzResourceGraphQuery -Query $criticalityTagQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Check for flow/workload identification tags
            $flowTagQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where isnotempty(tags['flow']) or 
        isnotempty(tags['Flow']) or
        isnotempty(tags['workload']) or
        isnotempty(tags['Workload']) or
        isnotempty(tags['application']) or
        isnotempty(tags['Application'])
| extend flowTag = coalesce(
    tags['flow'],
    tags['Flow'],
    tags['workload'],
    tags['Workload'],
    tags['application'],
    tags['Application']
)
| summarize 
    FlowTaggedResources = count(),
    UniqueFlows = dcount(flowTag),
    FlowNames = make_set(flowTag)
"@
            $flowTagged = Invoke-AzResourceGraphQuery -Query $flowTagQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Check for Application Insights availability tests (monitoring critical flows)
            $hasAvailabilityTests = $false
            $availabilityTestCount = 0
            
            foreach ($ai in $appInsights) {
                try {
                    $tests = Get-AzApplicationInsightsWebTest -ResourceGroupName $ai.ResourceGroup -ErrorAction SilentlyContinue
                    if ($tests) {
                        $availabilityTestCount += $tests.Count
                        $hasAvailabilityTests = $true
                    }
                } catch {
                    # Continue checking other App Insights
                }
            }
            
            # Check for Service Map / VM Insights (dependency mapping)
            $logAnalytics = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
            $hasServiceMap = $false
            $serviceMapSolutions = 0
            
            foreach ($workspace in $logAnalytics) {
                try {
                    $solutions = Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $workspace.ResourceGroupName `
                        -WorkspaceName $workspace.Name -ErrorAction SilentlyContinue
                    
                    $serviceMapSolution = $solutions | Where-Object { 
                        $_.Name -in @('ServiceMap', 'VMInsights', 'AzureNetworkAnalytics') 
                    }
                    
                    if ($serviceMapSolution) {
                        $hasServiceMap = $true
                        $serviceMapSolutions += $serviceMapSolution.Count
                    }
                } catch {
                    # Continue
                }
            }
            
            # Check for Azure Monitor workbooks (flow documentation)
            $workbooksQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type =~ 'microsoft.insights/workbooks'
| summarize WorkbookCount = count()
"@
            $workbooks = Invoke-AzResourceGraphQuery -Query $workbooksQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Get total resource count for percentage calculations
            $totalResourcesQuery = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize TotalResources = count()
"@
            $totalResources = Invoke-AzResourceGraphQuery -Query $totalResourcesQuery -SubscriptionId $SubscriptionId -UseCache
            
            # Calculate metrics
            $taggedResourceCount = if ($criticalityTagged.Count -gt 0) { $criticalityTagged[0].TaggedResources } else { 0 }
            $flowTaggedCount = if ($flowTagged.Count -gt 0) { $flowTagged[0].FlowTaggedResources } else { 0 }
            $uniqueFlows = if ($flowTagged.Count -gt 0) { $flowTagged[0].UniqueFlows } else { 0 }
            $totalResourceCount = if ($totalResources.Count -gt 0) { $totalResources[0].TotalResources } else { 1 }
            $workbookCount = if ($workbooks.Count -gt 0) { $workbooks[0].WorkbookCount } else { 0 }
            
            $criticalityTagPercent = [Math]::Round(($taggedResourceCount / $totalResourceCount) * 100, 1)
            $flowTagPercent = [Math]::Round(($flowTaggedCount / $totalResourceCount) * 100, 1)
            
            # Scoring indicators
            $indicators = @{
                HasAppInsights = $appInsights.Count -gt 0
                HasAvailabilityTests = $hasAvailabilityTests
                HasCriticalityTags = $taggedResourceCount -gt 0
                HasFlowTags = $flowTaggedCount -gt 0
                HasServiceMap = $hasServiceMap
                HasWorkbooks = $workbookCount -gt 0
            }
            
            $implementedCount = ($indicators.Values | Where-Object { $_ -eq $true }).Count
            
            $evidence = @"
Flow Identification Assessment:
- Application Insights: $($appInsights.Count) instances
- Availability Tests: $availabilityTestCount tests
- Resources with criticality tags: $taggedResourceCount ($criticalityTagPercent% of total)
- Resources with flow/workload tags: $flowTaggedCount ($flowTagPercent% of total)
- Unique flows identified: $uniqueFlows
- Service Map/VM Insights enabled: $hasServiceMap ($serviceMapSolutions solutions)
- Documentation workbooks: $workbookCount
- Total resources: $totalResourceCount
"@
            
            if ($implementedCount -ge 5 -and $criticalityTagPercent -ge 75) {
                return New-WafResult -CheckId 'RE02' `
                    -Status 'Pass' `
                    -Message "Strong flow identification and rating: $implementedCount/6 indicators present, $criticalityTagPercent% resources tagged" `
                    -Metadata @{
                        AppInsightsCount = $appInsights.Count
                        AvailabilityTests = $availabilityTestCount
                        CriticalityTaggedResources = $taggedResourceCount
                        CriticalityTagPercent = $criticalityTagPercent
                        FlowTaggedResources = $flowTaggedCount
                        UniqueFlows = $uniqueFlows
                        HasServiceMap = $hasServiceMap
                        WorkbooksCount = $workbookCount
                        Score = $implementedCount
                    }
                    
            } elseif ($implementedCount -ge 3 -or $criticalityTagPercent -ge 40) {
                
                $missingCapabilities = @()
                if (-not $indicators.HasAppInsights) { $missingCapabilities += "Application Insights for dependency tracking" }
                if (-not $indicators.HasAvailabilityTests) { $missingCapabilities += "Availability tests for critical flows" }
                if ($criticalityTagPercent -lt 75) { $missingCapabilities += "Complete criticality tagging (currently $criticalityTagPercent%)" }
                if (-not $indicators.HasFlowTags) { $missingCapabilities += "Flow/workload identification tags" }
                if (-not $indicators.HasServiceMap) { $missingCapabilities += "Service Map or VM Insights for dependency mapping" }
                if (-not $indicators.HasWorkbooks) { $missingCapabilities += "Documentation workbooks" }
                
                return New-WafResult -CheckId 'RE02' `
                    -Status 'Warning' `
                    -Message "Partial flow identification: $implementedCount/6 capabilities, $criticalityTagPercent% resources tagged" `
                    -Recommendation @"
Complete your flow identification and rating:

Missing capabilities:
$($missingCapabilities | ForEach-Object { "• $_" } | Out-String)

## Implementation Steps:

### 1. Identify All Flows (Week 1)
Document all user-facing and system flows:
- **User flows**: Authentication, data entry, reporting, etc.
- **System flows**: Data sync, batch processing, backups, etc.
- **Integration flows**: External API calls, partner integrations

Create a flow inventory spreadsheet:
| Flow Name | Type | Entry Point | Dependencies | Data Flows |
|-----------|------|-------------|--------------|------------|
| User Login | User | Web Portal | AAD, SQL DB | User credentials |
| Order Processing | User | API Gateway | SQL, Storage, Email | Order data |
| Nightly Batch | System | Function App | SQL, Data Lake | Analytics data |

### 2. Rate Flow Criticality (Week 1)
Assign criticality tiers based on business impact:

**Tier 1 (Critical)**: Direct revenue or compliance impact
- Availability target: 99.95%+
- Maximum downtime tolerance: Minutes
- Example: Payment processing, authentication

**Tier 2 (High)**: Significant user impact
- Availability target: 99.9%
- Maximum downtime tolerance: Hours
- Example: Main application features, reporting

**Tier 3 (Medium)**: Limited impact
- Availability target: 99.5%
- Maximum downtime tolerance: Days
- Example: Admin functions, background sync

**Tier 4 (Low)**: Minimal impact
- Availability target: 99%
- Maximum downtime tolerance: Weeks
- Example: Archive access, analytics

### 3. Implement Tagging (Week 2)
Tag all resources with criticality and flow association:

\`\`\`powershell
# Tag resources with criticality
Get-AzResource -ResourceGroupName 'production-rg' | ForEach-Object {
    Update-AzTag -ResourceId \$_.ResourceId -Tag @{
        'criticality' = 'tier1'
        'flow' = 'order-processing'
        'owner' = 'payments-team'
    } -Operation Merge
}
\`\`\`

### 4. Enable Dependency Tracking (Week 2)
- Deploy Application Insights to all applications
- Enable Application Map for visualizing dependencies
- Configure distributed tracing

### 5. Monitor Critical Flows (Week 3)
Create availability tests for each Tier 1 and Tier 2 flow:

\`\`\`powershell
# Create availability test for critical flow
New-AzApplicationInsightsWebTest -ResourceGroupName 'monitoring-rg' \`
    -Name 'login-flow-test' \`
    -Location 'eastus' \`
    -Kind 'multistep' \`
    -Enabled \$true \`
    -Frequency 300 \`
    -Timeout 120
\`\`\`

### 6. Document Dependencies (Week 3-4)
- Create architecture diagrams showing flow dependencies
- Document failure scenarios for each critical flow
- Build Azure Monitor workbooks for flow health dashboards

Current state:
$evidence
"@ `
                    -RemediationScript @"
# Flow Identification and Tagging Script

# Step 1: Define your flows and their criticality
`$flows = @(
    @{
        Name = 'UserAuthentication'
        Criticality = 'tier1'
        ResourceGroups = @('identity-rg', 'web-rg')
        Description = 'User login and authentication flow'
    },
    @{
        Name = 'OrderProcessing'
        Criticality = 'tier1'
        ResourceGroups = @('api-rg', 'database-rg', 'storage-rg')
        Description = 'Customer order creation and processing'
    },
    @{
        Name = 'Reporting'
        Criticality = 'tier2'
        ResourceGroups = @('analytics-rg')
        Description = 'Business intelligence and reporting'
    },
    @{
        Name = 'BackgroundSync'
        Criticality = 'tier3'
        ResourceGroups = @('integration-rg')
        Description = 'Nightly data synchronization'
    }
)

# Step 2: Apply tags to resources
Write-Host "Applying flow and criticality tags..." -ForegroundColor Cyan

foreach (`$flow in `$flows) {
    Write-Host "`nProcessing flow: `$(`$flow.Name) (Criticality: `$(`$flow.Criticality))" -ForegroundColor Yellow
    
    foreach (`$rgName in `$flow.ResourceGroups) {
        `$resources = Get-AzResource -ResourceGroupName `$rgName -ErrorAction SilentlyContinue
        
        if (`$resources) {
            Write-Host "  Tagging `$(`$resources.Count) resources in `$rgName"
            
            foreach (`$resource in `$resources) {
                `$tags = @{
                    'flow' = `$flow.Name
                    'criticality' = `$flow.Criticality
                    'flowDescription' = `$flow.Description
                }
                
                try {
                    Update-AzTag -ResourceId `$resource.ResourceId -Tag `$tags -Operation Merge -ErrorAction Stop
                    Write-Host "    ✓ Tagged: `$(`$resource.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "    ✗ Failed: `$(`$resource.Name) - `$_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Resource group not found: `$rgName" -ForegroundColor Yellow
        }
    }
}

# Step 3: Create availability tests for critical flows
Write-Host "`n`nCreating availability tests for critical flows..." -ForegroundColor Cyan

`$appInsights = Get-AzApplicationInsights | Select-Object -First 1

if (-not `$appInsights) {
    Write-Host "Creating Application Insights..." -ForegroundColor Yellow
    `$appInsights = New-AzApplicationInsights `
        -ResourceGroupName 'monitoring-rg' `
        -Name 'flow-monitoring' `
        -Location 'eastus' `
        -Kind 'web'
}

`$criticalFlows = `$flows | Where-Object { `$_.Criticality -eq 'tier1' }

foreach (`$flow in `$criticalFlows) {
    `$testName = "`$(`$flow.Name)-availability-test".ToLower()
    
    # Example: Create a simple ping test (customize URL for your flows)
    `$webTest = @"
<WebTest Name="`$(`$flow.Name)" Enabled="True" Timeout="120">
  <Items>
    <Request Method="GET" Version="1.1" 
             Url="https://yourapp.azurewebsites.net/health/`$(`$flow.Name)" 
             ThinkTime="0" Timeout="120" ParseDependentRequests="False" 
             FollowRedirects="True" RecordResult="True" Cache="False" 
             ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
"@
    
    try {
        New-AzApplicationInsightsWebTest `
            -ResourceGroupName `$appInsights.ResourceGroup `
            -Name `$testName `
            -Location `$appInsights.Location `
            -Kind 'ping' `
            -WebTest `$webTest `
            -Frequency 300 `
            -Timeout 120 `
            -Enabled `$true `
            -Tag @{ "hidden-link:`$(`$appInsights.Id)" = "Resource" }
        
        Write-Host "  ✓ Created availability test: `$testName" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to create test: `$testName - `$_" -ForegroundColor Red
    }
}

# Step 4: Generate flow documentation
Write-Host "`n`nGenerating flow documentation..." -ForegroundColor Cyan

`$documentation = @"
# Flow Inventory - Generated $(Get-Date -Format 'yyyy-MM-dd')

## Critical Flows (Tier 1)
$((`$flows | Where-Object Criticality -eq 'tier1' | ForEach-Object { "- **`$(`$_.Name)**: `$(`$_.Description)" }) -join "`n")

## High Priority Flows (Tier 2)
$((`$flows | Where-Object Criticality -eq 'tier2' | ForEach-Object { "- **`$(`$_.Name)**: `$(`$_.Description)" }) -join "`n")

## Medium Priority Flows (Tier 3)
$((`$flows | Where-Object Criticality -eq 'tier3' | ForEach-Object { "- **`$(`$_.Name)**: `$(`$_.Description)" }) -join "`n")

## Reliability Targets by Tier

| Tier | Availability | Max Downtime/Month | Recovery Time |
|------|--------------|-------------------|---------------|
| Tier 1 | 99.95% | 21.6 minutes | < 15 minutes |
| Tier 2 | 99.9% | 43.2 minutes | < 1 hour |
| Tier 3 | 99.5% | 3.6 hours | < 4 hours |
| Tier 4 | 99.0% | 7.2 hours | < 24 hours |

## Next Steps
1. Review and validate flow criticality assignments
2. Document detailed dependencies for each flow
3. Create failure mode analysis for Tier 1 flows
4. Establish monitoring dashboards
5. Define incident response procedures per tier
"@

`$documentation | Out-File 'flow-inventory.md' -Encoding UTF8

Write-Host "`nFlow documentation saved to: flow-inventory.md" -ForegroundColor Green

# Step 5: Generate summary report
`$summary = @{
    GeneratedDate = Get-Date
    TotalFlows = `$flows.Count
    FlowsByCriticality = @{
        Tier1 = (`$flows | Where-Object Criticality -eq 'tier1').Count
        Tier2 = (`$flows | Where-Object Criticality -eq 'tier2').Count
        Tier3 = (`$flows | Where-Object Criticality -eq 'tier3').Count
        Tier4 = (`$flows | Where-Object Criticality -eq 'tier4').Count
    }
    AvailabilityTestsCreated = `$criticalFlows.Count
    ResourcesTagged = (Get-AzResource -Tag @{ flow = '*' }).Count
}

`$summary | ConvertTo-Json -Depth 5 | Out-File 'flow-tagging-summary.json'

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total flows defined: `$(`$summary.TotalFlows)" -ForegroundColor White
Write-Host "Tier 1 (Critical): `$(`$summary.FlowsByCriticality.Tier1)" -ForegroundColor Red
Write-Host "Tier 2 (High): `$(`$summary.FlowsByCriticality.Tier2)" -ForegroundColor Yellow
Write-Host "Tier 3 (Medium): `$(`$summary.FlowsByCriticality.Tier3)" -ForegroundColor Gray
Write-Host "Resources tagged: `$(`$summary.ResourcesTagged)" -ForegroundColor Green
Write-Host "`nSummary saved to: flow-tagging-summary.json" -ForegroundColor Gray
"@
                    
            } else {
                return New-WafResult -CheckId 'RE02' `
                    -Status 'Fail' `
                    -Message "Flow identification not implemented: Only $implementedCount/6 capabilities present, $criticalityTagPercent% resources tagged" `
                    -Recommendation @"
**CRITICAL**: Flow identification is essential for prioritizing reliability investments.

Without identified and rated flows, you cannot:
- Prioritize which components need highest reliability
- Set appropriate availability targets per flow
- Allocate resources effectively
- Make informed architectural decisions
- Respond to incidents with proper context

## Immediate Actions Required:

### Week 1: Flow Discovery Workshop
Conduct workshops with stakeholders to identify:

1. **All User Flows**:
   - Primary customer journeys
   - Secondary features
   - Administrative functions
   - Support/maintenance activities

2. **All System Flows**:
   - Scheduled batch jobs
   - Data synchronization
   - Integration with external systems
   - Backup and maintenance processes

3. **Flow Dependencies**:
   - Which services does each flow use?
   - What data stores are accessed?
   - What external dependencies exist?
   - What are the failure modes?

### Week 2: Criticality Rating
Rate each flow using business impact:

**Tier 1 - Mission Critical**:
- Direct revenue generation
- Regulatory compliance required
- Customer-facing, no alternative
- Example: Payment processing, core authentication

**Tier 2 - Business Critical**:
- Significant customer impact
- No immediate workaround
- Revenue impact within hours
- Example: Product search, order management

**Tier 3 - Important**:
- Moderate customer impact
- Workaround available
- Revenue impact within days
- Example: Reporting, analytics

**Tier 4 - Low Priority**:
- Minimal customer impact
- Can be deferred
- No immediate revenue impact
- Example: Archive access, audit logs

### Week 3: Infrastructure Implementation

1. **Deploy Application Insights**:
\`\`\`powershell
New-AzApplicationInsights -ResourceGroupName 'monitoring-rg' \`
    -Name 'app-insights' -Location 'eastus' -Kind 'web'
\`\`\`

2. **Tag All Resources**:
\`\`\`powershell
# Apply flow and criticality tags
Update-AzTag -ResourceId '/subscriptions/.../resourceId' \`
    -Tag @{
        'flow' = 'order-processing'
        'criticality' = 'tier1'
        'owner' = 'team-name'
    } -Operation Merge
\`\`\`

3. **Create Availability Tests**:
\`\`\`powershell
# Monitor each critical flow
New-AzApplicationInsightsWebTest -ResourceGroupName 'monitoring-rg' \`
    -Name 'critical-flow-test' -Location 'eastus' -Kind 'ping' \`
    -Enabled \$true -Frequency 300
\`\`\`

4. **Enable VM Insights / Service Map**:
\`\`\`powershell
# For dependency mapping
Set-AzVMExtension -ResourceGroupName 'rg' -VMName 'vm' \`
    -Name 'DependencyAgent' -Publisher 'Microsoft.Azure.Monitoring.DependencyAgent' \`
    -Type 'DependencyAgentWindows' -TypeHandlerVersion '9.10'
\`\`\`

### Week 4: Documentation and Governance

1. Create flow catalog with:
   - Flow name and description
   - Criticality tier
   - Dependencies (upstream/downstream)
   - Availability targets
   - Recovery procedures

2. Establish review process:
   - Quarterly flow criticality reviews
   - Architecture review for new flows
   - Incident retrospective updates

3. Build monitoring dashboards:
   - Flow health overview
   - Availability by tier
   - Dependency health

Current state:
$evidence

**START THIS WEEK**: Without flow identification, you're operating blind.
"@ `
                    -RemediationScript @"
# Quick Start: Flow Identification in 1 Hour

# This script helps you quickly identify and document flows

Write-Host "=== Azure Flow Identification Quick Start ===" -ForegroundColor Cyan

# Step 1: Discover existing applications
Write-Host "`n[1/4] Discovering applications..." -ForegroundColor Cyan

`$apps = @{
    WebApps = Get-AzWebApp
    FunctionApps = Get-AzFunctionApp  
    VMs = Get-AzVM
    ContainerApps = Get-AzResource -ResourceType 'Microsoft.App/containerApps'
    LogicApps = Get-AzResource -ResourceType 'Microsoft.Logic/workflows'
}

Write-Host "Found applications:"
Write-Host "  - Web Apps: `$(`$apps.WebApps.Count)"
Write-Host "  - Function Apps: `$(`$apps.FunctionApps.Count)"
Write-Host "  - Virtual Machines: `$(`$apps.VMs.Count)"
Write-Host "  - Container Apps: `$(`$apps.ContainerApps.Count)"
Write-Host "  - Logic Apps: `$(`$apps.LogicApps.Count)"

# Step 2: Create flow template
Write-Host "`n[2/4] Creating flow template..." -ForegroundColor Cyan

`$flowTemplate = @"
# Flow Inventory Template

## Instructions
1. List all user-facing and system flows below
2. Assign criticality tier (1-4) based on business impact
3. Document dependencies for each flow
4. Review with stakeholders

## Flow Template
| Flow Name | Type | Criticality | Entry Point | Dependencies | Max Downtime |
|-----------|------|-------------|-------------|--------------|--------------|
| User Login | User | Tier 1 | Web Portal | AAD, SQL DB | 5 minutes |
| Order Entry | User | Tier 1 | API Gateway | SQL, Storage | 15 minutes |
| Reporting | User | Tier 2 | Web Portal | SQL, Analytics | 4 hours |
| Nightly Batch | System | Tier 3 | Function App | SQL, Data Lake | 24 hours |

## Discovered Applications to Review:
$(
    (`$apps.WebApps | ForEach-Object { "- Web App: `$(`$_.Name) (Resource Group: `$(`$_.ResourceGroup))" }) -join "`n"
    (`$apps.FunctionApps | ForEach-Object { "- Function App: `$(`$_.Name) (Resource Group: `$(`$_.ResourceGroup))" }) -join "`n"
    (`$apps.VMs | ForEach-Object { "- VM: `$(`$_.Name) (Resource Group: `$(`$_.ResourceGroup))" }) -join "`n"
)

## Criticality Tier Definitions

**Tier 1 - Mission Critical**
- Availability Target: 99.95%
- Max Downtime/Month: 21.6 minutes
- Recovery Time: < 15 minutes
- Business Impact: Direct revenue loss, compliance violation

**Tier 2 - Business Critical**
- Availability Target: 99.9%
- Max Downtime/Month: 43.2 minutes
- Recovery Time: < 1 hour
- Business Impact: Significant customer impact

**Tier 3 - Important**
- Availability Target: 99.5%
- Max Downtime/Month: 3.6 hours
- Recovery Time: < 4 hours
- Business Impact: Moderate impact, workarounds available

**Tier 4 - Low Priority**
- Availability Target: 99.0%
- Max Downtime/Month: 7.2 hours
- Recovery Time: < 24 hours
- Business Impact: Minimal, can be deferred

## Next Steps
1. Fill out the flow inventory table above
2. Review with business stakeholders
3. Run the tagging script to apply criticality tags
4. Set up monitoring for critical flows
"@

`$flowTemplate | Out-File 'flow-inventory-template.md' -Encoding UTF8

# Step 3: Create simple tagging script template
Write-Host "`n[3/4] Creating tagging script template..." -ForegroundColor Cyan

`$taggingScript = @'
# Flow Tagging Script
# Edit the flows array below with your actual flows

`$flows = @(
    @{
        Name = 'UserAuthentication'
        Criticality = 'tier1'
        ResourceGroups = @('identity-rg')  # Edit these
    },
    @{
        Name = 'OrderProcessing'
        Criticality = 'tier1'
        ResourceGroups = @('api-rg', 'database-rg')  # Edit these
    }
    # Add more flows here
)

# Apply tags
foreach (`$flow in `$flows) {
    foreach (`$rgName in `$flow.ResourceGroups) {
        Get-AzResource -ResourceGroupName `$rgName | ForEach-Object {
            Update-AzTag -ResourceId `$_.ResourceId -Tag @{
                'flow' = `$flow.Name
                'criticality' = `$flow.Criticality
            } -Operation Merge
        }
    }
}
'@

`$taggingScript | Out-File 'apply-flow-tags.ps1' -Encoding UTF8

# Step 4: Generate summary
Write-Host "`n[4/4] Generating summary..." -ForegroundColor Cyan

Write-Host "`n=== Quick Start Complete ===" -ForegroundColor Green
Write-Host "`nFiles created:"
Write-Host "  1. flow-inventory-template.md - Fill this out with your flows"
Write-Host "  2. apply-flow-tags.ps1 - Run this after filling out the template"
Write-Host "`nNext steps:"
Write-Host "  1. Open flow-inventory-template.md"
Write-Host "  2. Document your flows and assign criticality"
Write-Host "  3. Edit apply-flow-tags.ps1 with your resource groups"
Write-Host "  4. Run apply-flow-tags.ps1 to tag resources"
Write-Host "  5. Deploy Application Insights for dependency tracking"
Write-Host "`nEstimated time to complete: 2-4 hours with stakeholder input"
"@
            }
            
        } catch {
            return New-WafResult -CheckId 'RE02' `
                -Status 'Error' `
                -Message "Check execution failed: $($_.Exception.Message)" `
                -Metadata @{
                    ErrorType = $_.Exception.GetType().Name
                    StackTrace = $_.ScriptStackTrace
                }
        }
    }
