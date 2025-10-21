<#
.SYNOPSIS
    Azure WAF Scanner Core Module with enhanced functionality.
#>

#Requires -Version 7.0

# Module-level variables
$script:CheckRegistry = @()
$script:ModuleRoot = $PSScriptRoot
$script:CacheStore = @{}

#region Core Helper Functions

function Register-WafCheck {
    <#
    .SYNOPSIS
        Registers a WAF check to the scanner registry.
    
    .PARAMETER CheckId
        Unique identifier for the check (e.g., "REL-001").
    
    .PARAMETER Pillar
        WAF pillar (Reliability, Security, Cost, Performance, OperationalExcellence).
    
    .PARAMETER Title
        Human-readable title for the check.
    
    .PARAMETER Description
        Detailed description of what this check validates.
    
    .PARAMETER Severity
        Severity level: Critical, High, Medium, Low.
    
    .PARAMETER RemediationEffort
        Estimated effort to remediate: Low, Medium, High.
    
    .PARAMETER ScriptBlock
        The check logic. Must accept [string]$SubscriptionId parameter.
    
    .PARAMETER Tags
        Optional tags for categorization.
    
    .PARAMETER DocumentationUrl
        URL to relevant documentation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CheckId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Reliability', 'Security', 'CostOptimization', 'Performance', 'OperationalExcellence')]
        [string]$Pillar,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$Severity = 'Medium',
        
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$RemediationEffort = 'Medium',
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [string[]]$Tags = @(),
        
        [string]$DocumentationUrl = '',
        
        [string]$ComplianceFramework = ''
    )
    
    $check = [PSCustomObject]@{
        CheckId = $CheckId
        Pillar = $Pillar
        Title = $Title
        Description = $Description
        Severity = $Severity
        RemediationEffort = $RemediationEffort
        ScriptBlock = $ScriptBlock
        Tags = $Tags
        DocumentationUrl = $DocumentationUrl
        ComplianceFramework = $ComplianceFramework
        RegisteredAt = Get-Date
    }
    
    # Check for duplicates
    if ($script:CheckRegistry | Where-Object CheckId -eq $CheckId) {
        Write-Warning "Check $CheckId is already registered. Skipping duplicate."
        return
    }
    
    $script:CheckRegistry += $check
    Write-Verbose "Registered check: $CheckId - $Title"
}

function New-WafResult {
    <#
    .SYNOPSIS
        Creates a standardized WAF check result object.
    
    .PARAMETER CheckId
        The check identifier.
    
    .PARAMETER Status
        Result status: Pass, Fail, Warning, N/A, Error.
    
    .PARAMETER Message
        Result message describing the finding.
    
    .PARAMETER AffectedResources
        Array of affected resource IDs or names.
    
    .PARAMETER Recommendation
        Remediation recommendation.
    
    .PARAMETER RemediationScript
        Optional PowerShell/CLI script for remediation.
    
    .PARAMETER Metadata
        Additional metadata as hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CheckId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Fail', 'Warning', 'N/A', 'Error')]
        [string]$Status,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string[]]$AffectedResources = @(),
        
        [string]$Recommendation = '',
        
        [string]$RemediationScript = '',
        
        [hashtable]$Metadata = @{}
    )
    
    # Get check details from registry
    $checkInfo = $script:CheckRegistry | Where-Object CheckId -eq $CheckId | Select-Object -First 1
    
    if (!$checkInfo) {
        Write-Warning "Check $CheckId not found in registry"
        $checkInfo = @{
            Pillar = 'Unknown'
            Title = 'Unknown'
            Severity = 'Medium'
            RemediationEffort = 'Medium'
        }
    }
    
    return [PSCustomObject]@{
        CheckId = $CheckId
        Pillar = $checkInfo.Pillar
        Title = $checkInfo.Title
        Description = $checkInfo.Description
        Severity = $checkInfo.Severity
        RemediationEffort = $checkInfo.RemediationEffort
        Status = $Status
        Message = $Message
        AffectedResources = $AffectedResources
        Recommendation = $Recommendation
        RemediationScript = $RemediationScript
        DocumentationUrl = $checkInfo.DocumentationUrl
        Timestamp = Get-Date
        Metadata = $Metadata
    }
}

function Invoke-AzResourceGraphQuery {
    <#
    .SYNOPSIS
        Executes Azure Resource Graph query with retry logic and pagination.
    
    .PARAMETER Query
        KQL query to execute.
    
    .PARAMETER SubscriptionId
        Target subscription ID.
    
    .PARAMETER MaxRetries
        Maximum retry attempts.
    
    .PARAMETER UseCache
        Whether to use cached results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [string]$SubscriptionId,
        
        [int]$MaxRetries = 3,
        
        [switch]$UseCache
    )
    
    $cacheKey = "$SubscriptionId-$($Query.GetHashCode())"
    
    # Check cache
    if ($UseCache -and $script:CacheStore.ContainsKey($cacheKey)) {
        $cached = $script:CacheStore[$cacheKey]
        $age = (Get-Date) - $cached.Timestamp
        
        if ($age.TotalMinutes -lt 30) {
            Write-Verbose "Using cached Resource Graph result (age: $($age.TotalMinutes.ToString('F1')) min)"
            return $cached.Data
        }
    }
    
    $attempt = 0
    $allResults = @()
    $skipToken = $null
    
    while ($attempt -lt $MaxRetries) {
        try {
            $params = @{
                Query = $Query
                First = 1000
            }
            
            if ($SubscriptionId) {
                $params.Subscription = $SubscriptionId
            }
            
            if ($skipToken) {
                $params.SkipToken = $skipToken
            }
            
            do {
                $result = Search-AzGraph @params
                
                if ($result.Data) {
                    $allResults += $result.Data
                }
                
                $skipToken = $result.SkipToken
                
                if ($skipToken) {
                    $params.SkipToken = $skipToken
                }
                
            } while ($skipToken)
            
            # Cache the result
            if ($UseCache) {
                $script:CacheStore[$cacheKey] = @{
                    Data = $allResults
                    Timestamp = Get-Date
                }
            }
            
            return $allResults
            
        } catch {
            $attempt++
            
            if ($_.Exception.Message -match "429|throttl" -and $attempt -lt $MaxRetries) {
                $delay = [Math]::Pow(2, $attempt)
                Write-Warning "Resource Graph throttled. Retrying in $delay seconds... (Attempt $attempt/$MaxRetries)"
                Start-Sleep -Seconds $delay
            } else {
                Write-Error "Resource Graph query failed: $_"
                throw
            }
        }
    }
}

function Get-WafAdvisorRecommendations {
    <#
    .SYNOPSIS
        Gets Azure Advisor recommendations for a subscription.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [string[]]$Categories = @('Cost', 'Security', 'Reliability', 'Performance', 'OperationalExcellence')
    )
    
    try {
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        $recommendations = Get-AzAdvisorRecommendation -ErrorAction Stop | 
            Where-Object { $Categories -contains $_.Category }
        
        return $recommendations
        
    } catch {
        Write-Warning "Failed to retrieve Advisor recommendations: $_"
        return @()
    }
}

function Get-WafDefenderFindings {
    <#
    .SYNOPSIS
        Gets Microsoft Defender for Cloud security findings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [string[]]$Severities = @('High', 'Medium', 'Low')
    )
    
    try {
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        # Get security assessments
        $assessments = Get-AzSecurityAssessment -ErrorAction SilentlyContinue
        
        if ($assessments) {
            return $assessments | Where-Object { 
                $_.Status.Code -ne 'Healthy' -and 
                $Severities -contains $_.Status.Severity 
            }
        }
        
        return @()
        
    } catch {
        Write-Warning "Failed to retrieve Defender findings: $_"
        return @()
    }
}

function Get-WafPolicyCompliance {
    <#
    .SYNOPSIS
        Gets Azure Policy compliance state for a subscription.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
    try {
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        # Get policy states
        $policyStates = Get-AzPolicyState -SubscriptionId $SubscriptionId -Filter "ComplianceState eq 'NonCompliant'" -ErrorAction Stop
        
        return $policyStates
        
    } catch {
        Write-Warning "Failed to retrieve policy compliance: $_"
        return @()
    }
}

function Get-WafCostData {
    <#
    .SYNOPSIS
        Gets cost data for a subscription.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [int]$DaysBack = 30
    )
    
    try {
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        $startDate = (Get-Date).AddDays(-$DaysBack).ToString('yyyy-MM-dd')
        $endDate = (Get-Date).ToString('yyyy-MM-dd')
        
        # Get cost data using Cost Management
        $scope = "/subscriptions/$SubscriptionId"
        
        # Note: This requires Az.CostManagement module
        # Placeholder for cost query
        Write-Verbose "Retrieving cost data from $startDate to $endDate"
        
        # Actual implementation would use:
        # Invoke-AzCostManagementQuery or similar
        
        return @{
            TotalCost = 0
            StartDate = $startDate
            EndDate = $endDate
            CostByService = @()
        }
        
    } catch {
        Write-Warning "Failed to retrieve cost data: $_"
        return $null
    }
}

function Test-ResourceTag {
    <#
    .SYNOPSIS
        Tests if a resource has specific tags.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Resource,
        
        [Parameter(Mandatory)]
        [string[]]$RequiredTags
    )
    
    if (!$Resource.Tags) {
        return $false
    }
    
    foreach ($tag in $RequiredTags) {
        if (!$Resource.Tags.ContainsKey($tag)) {
            return $false
        }
    }
    
    return $true
}

function Get-ResourceGroupsByLocation {
    <#
    .SYNOPSIS
        Groups resources by location.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
    $query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| summarize count() by location
| order by count_ desc
"@
    
    return Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
}

function Test-HighAvailabilityConfiguration {
    <#
    .SYNOPSIS
        Tests if resources are configured for high availability.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Resource
    )
    
    # Check for availability zones
    $hasAvailabilityZones = $Resource.zones -and $Resource.zones.Count -ge 2
    
    # Check for redundancy in SKU
    $hasRedundancy = $Resource.sku.tier -match 'Premium|Standard' -and 
                     $Resource.sku.name -notmatch 'Basic'
    
    return $hasAvailabilityZones -or $hasRedundancy
}

function Get-UnusedResources {
    <#
    .SYNOPSIS
        Identifies potentially unused resources.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [int]$IdleDays = 30
    )
    
    $query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in ('microsoft.compute/disks', 'microsoft.network/publicipaddresses', 'microsoft.network/networkinterfaces')
| where properties.diskState == 'Unattached' 
    or (type == 'microsoft.network/publicipaddresses' and isnull(properties.ipConfiguration))
    or (type == 'microsoft.network/networkinterfaces' and isnull(properties.virtualMachine))
| project id, name, type, resourceGroup, location
"@
    
    return Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
}

function Get-ResourcesWithoutBackup {
    <#
    .SYNOPSIS
        Finds resources that should be backed up but aren't.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
    $query = @"
Resources
| where subscriptionId == '$SubscriptionId'
| where type in ('microsoft.compute/virtualmachines', 'microsoft.sql/servers/databases')
| project id, name, type, resourceGroup
| join kind=leftouter (
    RecoveryServicesResources
    | where type == 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
    | extend sourceResourceId = tolower(tostring(properties.sourceResourceId))
    | project sourceResourceId
) on `$left.id == `$right.sourceResourceId
| where isnull(sourceResourceId)
| project id, name, type, resourceGroup
"@
    
    return Invoke-AzResourceGraphQuery -Query $query -SubscriptionId $SubscriptionId -UseCache
}

function Format-RemediationScript {
    <#
    .SYNOPSIS
        Generates remediation scripts for common issues.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IssueType,
        
        [Parameter(Mandatory)]
        [hashtable]$Context
    )
    
    switch ($IssueType) {
        'MissingTags' {
            return @"
# Add required tags to resource
`$resourceId = '$($Context.ResourceId)'
`$tags = @{
    'Environment' = 'Production'
    'Owner' = 'TeamName'
    'CostCenter' = 'CC-001'
}

Update-AzTag -ResourceId `$resourceId -Tag `$tags -Operation Merge
"@
        }
        
        'UnattachedDisk' {
            return @"
# Review and delete unattached disk if no longer needed
`$diskId = '$($Context.ResourceId)'

# First, verify it's truly unused
Get-AzDisk -ResourceId `$diskId

# If confirmed unused, remove it
# Remove-AzDisk -ResourceId `$diskId -Force
"@
        }
        
        'NoBackup' {
            return @"
# Enable Azure Backup for resource
`$resourceId = '$($Context.ResourceId)'
`$vaultName = 'YourRecoveryServicesVault'
`$policyName = 'DefaultPolicy'

# Get vault and policy
`$vault = Get-AzRecoveryServicesVault -Name `$vaultName
`$policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name `$policyName -VaultId `$vault.ID

# Enable backup
Enable-AzRecoveryServicesBackupProtection -ResourceId `$resourceId -Policy `$policy -VaultId `$vault.ID
"@
        }
        
        default {
            return "# No automated remediation available. Please review manually."
        }
    }
}

#endregion

#region Module Initialization

function Initialize-WafScanner {
    <#
    .SYNOPSIS
        Initializes the WAF Scanner module.
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing Azure WAF Scanner..."
    
    # Check required modules
    $requiredModules = @(
        @{ Name = 'Az.Accounts'; MinVersion = '2.0.0' }
        @{ Name = 'Az.Resources'; MinVersion = '6.0.0' }
        @{ Name = 'Az.ResourceGraph'; MinVersion = '0.13.0' }
        @{ Name = 'Az.Advisor'; MinVersion = '2.0.0' }
        @{ Name = 'Az.Security'; MinVersion = '1.0.0' }
        @{ Name = 'Az.PolicyInsights'; MinVersion = '1.6.0' }
    )
    
    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | 
            Where-Object { $_.Version -ge [version]$module.MinVersion } |
            Select-Object -First 1
        
        if (!$installed) {
            Write-Warning "Module $($module.Name) (>= $($module.MinVersion)) not found. Installing..."
            try {
                Install-Module -Name $module.Name -MinimumVersion $module.MinVersion -Scope CurrentUser -Force -AllowClobber
                Write-Verbose "Installed $($module.Name)"
            } catch {
                Write-Error "Failed to install $($module.Name): $_"
            }
        }
    }
    
    # Load check modules
    $checkPaths = Get-ChildItem -Path (Join-Path $script:ModuleRoot "Pillars") -Filter "Invoke.ps1" -Recurse -ErrorAction SilentlyContinue
    
    Write-Verbose "Found $($checkPaths.Count) check files"
    
    foreach ($checkPath in $checkPaths) {
        try {
            . $checkPath.FullName
            Write-Verbose "Loaded check: $($checkPath.FullName)"
        } catch {
            Write-Warning "Failed to load check from $($checkPath.FullName): $_"
        }
    }
    
    Write-Verbose "WAF Scanner initialized with $($script:CheckRegistry.Count) checks"
}

# Auto-initialize on module import
Initialize-WafScanner

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Register-WafCheck',
    'New-WafResult',
    'Invoke-AzResourceGraphQuery',
    'Get-WafAdvisorRecommendations',
    'Get-WafDefenderFindings',
    'Get-WafPolicyCompliance',
    'Get-WafCostData',
    'Test-ResourceTag',
    'Get-ResourceGroupsByLocation',
    'Test-HighAvailabilityConfiguration',
    'Get-UnusedResources',
    'Get-ResourcesWithoutBackup',
    'Format-RemediationScript',
    'Initialize-WafScanner'
)
```
