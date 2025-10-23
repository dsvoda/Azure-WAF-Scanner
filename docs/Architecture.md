# Azure WAF Scanner - Architecture Documentation

**Version:** 1.0.0  
**Last Updated:** October 22, 2025  
**Status:** Production

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagrams](#architecture-diagrams)
3. [Component Design](#component-design)
4. [Data Flow](#data-flow)
5. [Module Dependencies](#module-dependencies)
6. [Check Execution Lifecycle](#check-execution-lifecycle)
7. [Caching Strategy](#caching-strategy)
8. [Error Handling](#error-handling)
9. [Scalability](#scalability)
10. [Security Architecture](#security-architecture)

---

## System Overview

The Azure WAF Scanner is a modular PowerShell-based assessment tool that evaluates Azure subscriptions against Microsoft's Well-Architected Framework. It uses Azure Resource Graph for efficient resource querying and generates comprehensive reports across multiple formats.

### Design Principles

1. **Modularity** - Each check is self-contained and independent
2. **Performance** - Parallel execution and intelligent caching
3. **Extensibility** - Easy to add custom checks
4. **Reliability** - Comprehensive error handling and retries
5. **Observability** - Detailed logging and telemetry

### Technology Stack

```
┌─────────────────────────────────────┐
│    PowerShell 7.0+ Runtime          │
├─────────────────────────────────────┤
│    Azure PowerShell Modules         │
│    • Az.Accounts                    │
│    • Az.Resources                   │
│    • Az.ResourceGraph               │
│    • Az.Advisor                     │
│    • Az.Security                    │
│    • Az.PolicyInsights              │
│    • Az.CostManagement              │
├─────────────────────────────────────┤
│    Azure Services                   │
│    • Azure Resource Graph           │
│    • Azure Advisor                  │
│    • Microsoft Defender for Cloud   │
│    • Azure Cost Management          │
│    • Azure Policy                   │
└─────────────────────────────────────┘
```

---

## Architecture Diagrams

### High-Level System Architecture

```
┌────────────────────────────────────────────────────────────┐
│                         User                               │
│                          │                                 │
│                          ▼                                 │
│              ┌──────────────────────┐                      │
│              │  Invoke-WafLocal.ps1 │                      │
│              │   (Entry Point)      │                      │
│              └──────────┬───────────┘                      │
│                         │                                  │
│         ┌───────────────┼───────────────┐                 │
│         ▼               ▼               ▼                  │
│  ┌──────────┐  ┌─────────────┐  ┌──────────┐             │
│  │  Config  │  │   Scanner    │  │  Report  │             │
│  │  Loader  │  │   Engine     │  │  Engine  │             │
│  └──────────┘  └──────┬──────┘  └──────────┘             │
│                       │                                    │
│         ┌────────────┼────────────┐                       │
│         ▼            ▼            ▼                        │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐                 │
│  │  Check   │ │   Query   │ │  Cache   │                 │
│  │  Loader  │ │  Engine   │ │  Manager │                 │
│  └────┬─────┘ └─────┬─────┘ └────┬─────┘                 │
│       │             │             │                        │
│       ▼             ▼             ▼                        │
│  ┌────────────────────────────────────────┐               │
│  │        Check Execution Layer           │               │
│  │  (60 Individual Check Modules)         │               │
│  └───────────────┬────────────────────────┘               │
│                  │                                         │
└──────────────────┼─────────────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │   Azure Services    │
         ├─────────────────────┤
         │ • Resource Graph    │
         │ • Azure Advisor     │
         │ • Defender for Cloud│
         │ • Cost Management   │
         │ • Azure Policy      │
         └─────────────────────┘
```

### Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Invoke-WafLocal.ps1                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 1. Initialize                                            │   │
│  │    • Parse parameters                                    │   │
│  │    • Load configuration                                  │   │
│  │    • Authenticate to Azure                               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 2. Discover Checks                                       │   │
│  │    • Scan modules/Pillars directory                      │   │
│  │    • Load check definitions                              │   │
│  │    • Apply filters (exclusions)                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 3. Execute Checks                                        │   │
│  │    ┌─────────────────────────────────────────────────┐   │   │
│  │    │ For each subscription:                          │   │   │
│  │    │   For each pillar:                              │   │   │
│  │    │     For each check:                             │   │   │
│  │    │       • Query Azure resources                   │   │   │
│  │    │       • Apply check logic                       │   │   │
│  │    │       • Cache results                           │   │   │
│  │    │       • Store findings                          │   │   │
│  │    └─────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 4. Generate Reports                                      │   │
│  │    • Aggregate results                                   │   │
│  │    • Calculate compliance scores                         │   │
│  │    • Generate HTML/CSV/JSON/DOCX                         │   │
│  │    • Compare to baseline (if provided)                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Parallel Execution Model

```
                    Main Thread
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    Sub-1           Sub-2           Sub-3
        │               │               │
    ┌───┴───┐       ┌───┴───┐       ┌───┴───┐
    │       │       │       │       │       │
  RE:*    SE:*    RE:*    SE:*    RE:*    SE:*
    │       │       │       │       │       │
  CO:*    OE:*    CO:*    OE:*    CO:*    OE:*
    │       │       │       │       │       │
  PE:*           PE:*           PE:*
    │               │               │
    └───────────────┼───────────────┘
                    │
              Aggregate Results
                    │
              Generate Reports
```

*Legend: Sub = Subscription, RE/SE/CO/OE/PE = Pillar checks*

---

## Component Design

### 1. Entry Point (`/run/Invoke-WafLocal.ps1`)

**Responsibilities:**
- Parse and validate command-line parameters
- Load configuration files
- Authenticate to Azure
- Orchestrate scan execution
- Handle output generation

**Key Functions:**
```powershell
function Initialize-WafScan {
    # Setup scan environment
}

function Invoke-SubscriptionScan {
    # Execute scan for single subscription
}

function Merge-ScanResults {
    # Combine results from multiple subscriptions
}
```

### 2. Check Loader (`/modules/Core/CheckLoader.ps1`)

**Responsibilities:**
- Discover check modules
- Load check definitions
- Validate check structure
- Apply check filters

**Check Discovery Process:**
```
1. Scan /modules/Pillars directory
2. Find all /*/Invoke.ps1 files
3. Load each check script
4. Validate Register-WafCheck call
5. Build check registry
6. Apply exclusion filters
7. Return executable check list
```

### 3. Query Engine (`/modules/Core/QueryEngine.ps1`)

**Responsibilities:**
- Execute Azure Resource Graph queries
- Manage query batching
- Handle API throttling
- Integrate caching

**Query Execution Flow:**
```
Input: KQL Query + Subscription ID
    │
    ▼
Check Cache
    │
    ├─ Hit ──> Return cached result
    │
    └─ Miss
        │
        ▼
    Execute Query
        │
        ├─ Success ──> Cache result ──> Return
        │
        └─ Throttled
            │
            ▼
        Wait + Retry
            │
            └─> Execute Query (max 3 attempts)
```

### 4. Cache Manager (`/modules/Core/CacheManager.ps1`)

**Responsibilities:**
- Store query results
- Manage cache expiration
- Implement cache eviction policies
- Provide cache statistics

**Cache Structure:**
```powershell
$CacheStore = @{
    Queries = @{
        '<QueryHash>' = @{
            Result = [object[]]
            Timestamp = [datetime]
            SubscriptionId = [string]
            TTL = [int] # minutes
        }
    }
    Statistics = @{
        Hits = [int]
        Misses = [int]
        SizeBytes = [long]
    }
}
```

### 5. Check Execution Engine

**Responsibilities:**
- Execute individual checks
- Handle check timeouts
- Capture check results
- Manage check state

**Check Execution Pattern:**
```powershell
function Invoke-CheckExecution {
    param(
        [object]$Check,
        [string]$SubscriptionId
    )
    
    $result = $null
    $timeout = New-TimeSpan -Seconds 300
    $job = Start-Job -ScriptBlock $Check.ScriptBlock -ArgumentList $SubscriptionId
    
    if (Wait-Job $job -Timeout $timeout) {
        $result = Receive-Job $job
    } else {
        Stop-Job $job
        $result = New-WafResult -CheckId $Check.Id -Status 'Timeout'
    }
    
    Remove-Job $job -Force
    return $result
}
```

### 6. Report Engine (`/modules/Core/ReportEngine.ps1`)

**Responsibilities:**
- Aggregate scan results
- Calculate compliance scores
- Generate multiple output formats
- Perform baseline comparison

**Report Generation Pipeline:**
```
Raw Results
    │
    ▼
Aggregate by Pillar/Subscription
    │
    ▼
Calculate Scores & Metrics
    │
    ▼
Apply Baseline Comparison (optional)
    │
    ├─> HTML ──> Interactive Dashboard
    ├─> JSON ──> Structured Data
    ├─> CSV  ──> Tabular Export
    └─> DOCX ──> Word Document
```

---

## Data Flow

### End-to-End Data Flow

```
┌──────────────┐
│ User Command │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────┐
│ 1. Authentication            │
│    Connect-AzAccount         │
└──────┬───────────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ 2. Configuration Loading     │
│    • config.json             │
│    • Parameters              │
└──────┬───────────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ 3. Check Discovery           │
│    Load 60 check modules     │
└──────┬───────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ 4. Subscription Loop                 │
│    For each subscription:            │
│    ┌──────────────────────────────┐  │
│    │ 4a. Query Resource Graph     │  │
│    │     (Resource inventory)     │  │
│    └────────┬─────────────────────┘  │
│             ▼                        │
│    ┌──────────────────────────────┐  │
│    │ 4b. Check Execution          │  │
│    │     • Per-pillar checks      │  │
│    │     • Parallel where possible│  │
│    └────────┬─────────────────────┘  │
│             ▼                        │
│    ┌──────────────────────────────┐  │
│    │ 4c. Result Collection        │  │
│    │     Store findings           │  │
│    └──────────────────────────────┘  │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────┐
│ 5. Result Aggregation        │
│    • Merge all findings      │
│    • Calculate scores        │
│    • Baseline comparison     │
└──────┬───────────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ 6. Report Generation         │
│    • HTML (interactive)      │
│    • JSON (automation)       │
│    • CSV (analysis)          │
│    • DOCX (documentation)    │
└──────┬───────────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ 7. Output to File System     │
│    ./waf-output/             │
└──────────────────────────────┘
```

### Data Structures

#### Check Result Object
```powershell
@{
    CheckId = 'SE-001'
    Pillar = 'Security'
    Title = 'Establish security baseline'
    Status = 'Pass|Fail|Warning|Error'
    Severity = 'Critical|High|Medium|Low'
    Message = 'Detailed status message'
    Timestamp = [datetime]::Now
    SubscriptionId = 'sub-guid'
    SubscriptionName = 'sub-name'
    AffectedResources = @(
        '/subscriptions/.../resourceGroups/.../providers/...'
    )
    Metadata = @{
        ExecutionTime = [timespan]
        CustomData = @{}
    }
    Recommendation = 'Detailed remediation guidance'
    RemediationScript = 'PowerShell/CLI script'
}
```

#### Aggregated Report Object
```powershell
@{
    ScanMetadata = @{
        ScanDate = [datetime]
        ScanDuration = [timespan]
        ScannedSubscriptions = @()
        TotalChecks = 60
    }
    Summary = @{
        OverallScore = 78.5
        PillarScores = @{
            Reliability = 85.0
            Security = 70.0
            CostOptimization = 65.0
            OperationalExcellence = 80.0
            PerformanceEfficiency = 90.0
        }
        StatusDistribution = @{
            Pass = 42
            Fail = 15
            Warning = 2
            Error = 1
        }
    }
    Findings = @(
        # Array of Check Result Objects
    )
    BaselineComparison = @{
        Improvements = @()
        Regressions = @()
        Unchanged = @()
    }
}
```

---

## Module Dependencies

### Module Hierarchy

```
Azure-WAF-Scanner/
│
├── run/
│   └── Invoke-WafLocal.ps1 ──────────┐
│                                      │
├── modules/                           │
│   ├── Core/                          ▼
│   │   ├── CheckLoader.ps1      ◄─────┤
│   │   ├── QueryEngine.ps1      ◄─────┤
│   │   ├── CacheManager.ps1     ◄─────┤
│   │   ├── ReportEngine.ps1     ◄─────┤
│   │   └── HelperFunctions.ps1  ◄─────┤
│   │                                   │
│   ├── Pillars/                        │
│   │   ├── Reliability/                │
│   │   │   ├── RE-001/Invoke.ps1      │
│   │   │   ├── RE-002/Invoke.ps1      │
│   │   │   └── ...                     │
│   │   ├── Security/                   │
│   │   ├── CostOptimization/           │
│   │   ├── OperationalExcellence/      │
│   │   └── PerformanceEfficiency/      │
│   │                                   │
│   └── Export/                         │
│       ├── HtmlExporter.ps1      ◄─────┤
│       ├── JsonExporter.ps1      ◄─────┤
│       ├── CsvExporter.ps1       ◄─────┤
│       └── DocxExporter.ps1      ◄─────┘
│
├── helpers/
│   └── New-WafItem.ps1
│
└── config.json
```

### Dependency Graph

```
Invoke-WafLocal.ps1
    │
    ├──> CheckLoader.ps1
    │       └──> modules/Pillars/**/Invoke.ps1
    │
    ├──> QueryEngine.ps1
    │       ├──> Azure Resource Graph API
    │       └──> CacheManager.ps1
    │
    ├──> ReportEngine.ps1
    │       ├──> HtmlExporter.ps1
    │       ├──> JsonExporter.ps1
    │       ├──> CsvExporter.ps1
    │       └──> DocxExporter.ps1
    │
    └──> HelperFunctions.ps1
            ├──> New-WafResult
            ├──> Invoke-AzResourceGraphQuery
            └──> Format-WafMessage
```

---

## Check Execution Lifecycle

### Detailed Check Lifecycle

```
┌────────────────────────────────────────┐
│ 1. Check Registration                  │
│    Register-WafCheck called            │
│    • CheckId, Pillar, Title assigned   │
│    • ScriptBlock stored                │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 2. Check Discovery                     │
│    Scanner loads all checks            │
│    • Validates structure               │
│    • Builds check registry             │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 3. Pre-Execution Filtering             │
│    Apply exclusions                    │
│    • Excluded pillars                  │
│    • Excluded check IDs                │
│    • Config-based filters              │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 4. Check Execution                     │
│    ┌────────────────────────────────┐  │
│    │ A. Setup                       │  │
│    │    • Prepare context           │  │
│    │    • Start timer               │  │
│    └──────────┬─────────────────────┘  │
│               ▼                        │
│    ┌────────────────────────────────┐  │
│    │ B. Query Phase                 │  │
│    │    • Build Resource Graph query│  │
│    │    • Check cache               │  │
│    │    • Execute if cache miss     │  │
│    └──────────┬─────────────────────┘  │
│               ▼                        │
│    ┌────────────────────────────────┐  │
│    │ C. Analysis Phase              │  │
│    │    • Apply check logic         │  │
│    │    • Evaluate conditions       │  │
│    │    • Determine status          │  │
│    └──────────┬─────────────────────┘  │
│               ▼                        │
│    ┌────────────────────────────────┐  │
│    │ D. Result Generation           │  │
│    │    • Create WafResult object   │  │
│    │    • Add recommendations       │  │
│    │    • Include remediation       │  │
│    └────────────────────────────────┘  │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 5. Error Handling                      │
│    Try-Catch wrapper                   │
│    • Timeout handling                  │
│    • Exception capture                 │
│    • Error result generation           │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 6. Result Collection                   │
│    Store in results array              │
│    • Group by pillar                   │
│    • Track metrics                     │
└────────────────────────────────────────┘
```

### State Transitions

```
[Registered] ──filter──> [Excluded]
     │
     └──pass filter──> [Queued]
                          │
                          ▼
                      [Executing]
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    [Success]        [Timeout]          [Error]
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                          ▼
                     [Completed]
```

---

## Caching Strategy

### Cache Architecture

```
┌─────────────────────────────────────────────────┐
│            Cache Manager                        │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │  L1 Cache (In-Memory)                   │   │
│  │  • Lifetime: Scan duration              │   │
│  │  │• Scope: Per-session                   │   │
│  │  • Store: Hashtable                     │   │
│  └───────────┬─────────────────────────────┘   │
│              │                                  │
│              ▼                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  L2 Cache (Optional Disk)               │   │
│  │  • Lifetime: Configurable (30 min)      │   │
│  │  • Scope: Cross-session                 │   │
│  │  • Store: JSON files                    │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Cache Key Generation

```powershell
function Get-CacheKey {
    param(
        [string]$Query,
        [string]$SubscriptionId
    )
    
    # Normalize query (remove whitespace, lowercase)
    $normalizedQuery = $Query -replace '\s+', ' ' `
                              -replace '^\s|\s$', '' `
                              -ToLower()
    
    # Create hash
    $bytes = [Text.Encoding]::UTF8.GetBytes(
        "$normalizedQuery|$SubscriptionId"
    )
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    
    return [BitConverter]::ToString($hash) -replace '-', ''
}
```

### Cache Hit/Miss Flow

```
Query Request
    │
    ▼
Generate Cache Key
    │
    ▼
Check L1 Cache
    │
    ├─ Hit ──> Validate TTL
    │             │
    │             ├─ Valid ──> Return Result
    │             │
    │             └─ Expired ──> Continue to L2
    │
    └─ Miss ──> Check L2 Cache (if enabled)
                   │
                   ├─ Hit ──> Load to L1 ──> Return Result
                   │
                   └─ Miss ──> Execute Query
                                  │
                                  ▼
                              Cache Result (L1 + L2)
                                  │
                                  ▼
                              Return Result
```

### Cache Eviction Policies

1. **Time-based (TTL):**
   - Default: 30 minutes
   - Configurable per-check
   - Automatic cleanup on expiration

2. **Size-based (LRU):**
   - Max cache size: 100 MB
   - Least Recently Used eviction
   - Triggered at 90% capacity

3. **Manual:**
   - Clear cache on config change
   - Forced refresh option
   - Subscription change detection

### Cache Performance Metrics

```powershell
@{
    Statistics = @{
        TotalRequests = 120
        CacheHits = 95
        CacheMisses = 25
        HitRate = 79.2  # percent
        AverageLookupTime = 2.5  # milliseconds
        CacheSizeBytes = 15728640  # ~15 MB
        EntriesCount = 48
    }
    Performance = @{
        TimeWithCache = '00:03:45'
        EstimatedTimeWithoutCache = '00:18:30'
        TimeSaved = '00:14:45'
        SpeedupFactor = 4.93
    }
}
```

---

## Error Handling

### Error Handling Strategy

```
                   Check Execution
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   Timeout           Exception         Success
        │                 │                 │
        │                 │                 │
   Log Warning       Try-Catch         Continue
        │            Hierarchy              │
        │                 │                 │
        ▼                 ▼                 ▼
  Return Timeout    Return Error      Return Result
     Status            Status            Object
```

### Exception Hierarchy

```powershell
try {
    # Check execution
    $result = Invoke-CheckLogic
}
catch [System.TimeoutException] {
    # Handle timeout
    Write-Warning "Check $CheckId timed out"
    return New-WafResult -Status 'Timeout'
}
catch [Microsoft.Rest.Azure.CloudException] {
    # Handle Azure API errors
    if ($_.Exception.Response.StatusCode -eq 429) {
        # Throttling - retry with backoff
        Start-Sleep -Seconds (Get-BackoffDelay $attemptNumber)
        # Retry logic
    } else {
        # Other Azure errors
        return New-WafResult -Status 'Error' `
            -Message $_.Exception.Message
    }
}
catch [System.UnauthorizedAccessException] {
    # Handle permission errors
    Write-Error "Insufficient permissions for check $CheckId"
    return New-WafResult -Status 'Error' `
        -Message "Access denied"
}
catch {
    # Generic error handler
    Write-Error "Check $CheckId failed: $_"
    return New-WafResult -Status 'Error' `
        -Message $_.Exception.Message `
        -Metadata @{
            ErrorType = $_.Exception.GetType().Name
            StackTrace = $_.ScriptStackTrace
        }
}
finally {
    # Cleanup
    Remove-Variable -Name tempVars -ErrorAction SilentlyContinue
}
```

### Retry Logic with Exponential Backoff

```powershell
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$InitialDelaySeconds = 2
    )
    
    $attempt = 0
    $lastException = $null
    
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        
        try {
            return & $ScriptBlock
        }
        catch {
            $lastException = $_
            
            if ($attempt -lt $MaxAttempts) {
                $delay = [Math]::Pow(2, $attempt) * $InitialDelaySeconds
                Write-Verbose "Attempt $attempt failed, retrying in $delay seconds..."
                Start-Sleep -Seconds $delay
            }
        }
    }
    
    throw "Failed after $MaxAttempts attempts. Last error: $lastException"
}
```

---

## Scalability

### Horizontal Scaling (Multiple Subscriptions)

```
Serial Execution (Default):
Sub-1 ──> Sub-2 ──> Sub-3 ──> Sub-4
Total Time = T1 + T2 + T3 + T4

Parallel Execution (-Parallel flag):
Sub-1 ──┐
Sub-2 ──┼──> Process ──> Complete
Sub-3 ──┤
Sub-4 ──┘
Total Time ≈ Max(T1, T2, T3, T4)
```

### Vertical Scaling (Per-Subscription Optimization)

1. **Query Batching:**
   ```powershell
   # Instead of:
   $vms = Query "...where type == 'vm'"
   $disks = Query "...where type == 'disk'"
   
   # Use:
   $resources = Query "...where type in ('vm', 'disk')"
   $vms = $resources | Where type -eq 'vm'
   $disks = $resources | Where type -eq 'disk'
   ```

2. **Resource Graph Pagination:**
   ```powershell
   $allResults = @()
   $skipToken = $null
   
   do {
       $batch = Invoke-AzResourceGraphQuery -Query $query `
           -First 1000 `
           -SkipToken $skipToken
       
       $allResults += $batch.Data
       $skipToken = $batch.SkipToken
   } while ($skipToken)
   ```

3. **Parallel Check Execution:**
   ```powershell
   $checks | ForEach-Object -Parallel {
       Invoke-Check -Check $_ -SubscriptionId $using:subId
   } -ThrottleLimit 10
   ```

### Performance Tuning Parameters

| Parameter | Default | Tuning Guide |
|-----------|---------|--------------|
| `MaxParallelism` | 5 | Increase for more concurrent subscriptions |
| `TimeoutSeconds` | 300 | Increase for large/complex subscriptions |
| `CacheDuration` | 30 min | Increase for stable environments |
| `RetryAttempts` | 3 | Decrease for faster failure detection |
| `ThrottleLimit` | 10 | Adjust based on API throttling |

---

## Security Architecture

### Authentication Flow

```
User
  │
  ▼
Connect-AzAccount
  │
  ├──> Interactive Login (Browser)
  ├──> Service Principal (ClientId + Secret)
  ├──> Managed Identity (Azure Resources)
  └──> Azure CLI (Cached Credentials)
  │
  ▼
Azure Active Directory
  │
  ▼
Token Acquisition
  │
  ▼
Azure PowerShell Session
  │
  ▼
Azure APIs
```

### Permission Requirements

**Minimum Required Permissions:**

```
Subscription Scope:
├── Reader
│   └── Read all resources and configurations
├── Security Reader
│   └── Read Defender for Cloud assessments
└── Cost Management Reader
    └── Read cost and usage data

Management Group Scope (optional):
└── Management Group Reader
    └── Read management group hierarchy
```

### Data Protection

1. **Sensitive Data Handling:**
   - No credentials stored
   - Resource IDs obfuscated when `-ObfuscateSensitiveData` flag used
   - Subscription IDs masked in shared reports

2. **Report Security:**
   ```powershell
   if ($ObfuscateSensitiveData) {
       $report.SubscriptionId = '***masked***'
       $report.TenantId = '***masked***'
       $report.AffectedResources = $report.AffectedResources | 
           ForEach-Object {
               $_ -replace '/subscriptions/[^/]+', '/subscriptions/***' `
                  -replace '/resourceGroups/[^/]+', '/resourceGroups/***'
           }
   }
   ```

3. **Audit Logging:**
   - All API calls logged
   - Scan history maintained
   - Access attempts tracked

---

## Deployment Models

### Local Execution
```
Developer Workstation
├── PowerShell 7+
├── Azure PowerShell modules
└── Manual execution
```

### Azure Automation
```
Automation Account
├── PowerShell Runbook
├── Schedule (weekly/monthly)
├── Managed Identity
└── Automatic report distribution
```

### Azure DevOps Pipeline
```
Pipeline Agent
├── PowerShell task
├── Azure Connection (Service Principal)
├── Artifact publishing
└── Work item creation for findings
```

### Azure Functions (Serverless)
```
Function App
├── PowerShell runtime
├── Timer trigger
├── Blob storage (reports)
└── Event Grid (notifications)
```

---

## Performance Optimization Checklist

- [ ] Enable caching (`config.json`)
- [ ] Use parallel execution (`-Parallel`)
- [ ] Batch Resource Graph queries
- [ ] Set appropriate timeouts
- [ ] Configure retry logic
- [ ] Monitor throttling
- [ ] Optimize check queries
- [ ] Use query projections
- [ ] Implement incremental scans
- [ ] Archive old reports

---

## Monitoring and Observability

### Telemetry Collection

```powershell
$telemetry = @{
    ScanId = New-Guid
    StartTime = Get-Date
    EndTime = $null
    Duration = $null
    ChecksExecuted = 0
    ChecksPassed = 0
    ChecksFailed = 0
    ChecksWarning = 0
    ChecksError = 0
    APICallsTotal = 0
    APICallsCached = 0
    APICallsThrottled = 0
    Subscriptions = @()
}
```

### Metrics Dashboard

```
┌─────────────────────────────────────────┐
│ Azure WAF Scanner - Performance Metrics  │
├─────────────────────────────────────────┤
│ Execution Time:      05:32 minutes      │
│ Checks Executed:     60/60              │
│ Cache Hit Rate:      78.5%              │
│ API Calls:           240 (52 cached)    │
│ Subscriptions:       3                  │
│ Compliance Score:    82.3%              │
└─────────────────────────────────────────┘
```

---

## Future Architecture Enhancements

### Roadmap Items

1. **Microservices Architecture (v2.0)**
   - API Gateway
   - Check execution service
   - Report generation service
   - Notification service

2. **Real-Time Monitoring (v2.1)**
   - Event-driven architecture
   - Azure Event Grid integration
   - Continuous compliance tracking

3. **Machine Learning Integration (v2.2)**
   - Anomaly detection
   - Predictive recommendations
   - Auto-tuning thresholds

4. **Multi-Cloud Support (v3.0)**
   - AWS checks
   - GCP checks
   - Unified reporting

---

**Document Version:** 1.0.0  
**Last Updated:** October 22, 2025  
**Next Review:** January 2026
