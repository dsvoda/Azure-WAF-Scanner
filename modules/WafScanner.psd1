@{
    # Script module or binary module file associated with this manifest
    RootModule = 'WafScanner.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'e8f4d2c1-9a3b-4f5e-8c7d-2a1b3c4d5e6f'
    
    # Author of this module
    Author = 'dsvoda'
    
    # Company or vendor of this module
    CompanyName = 'Community'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 dsvoda. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Azure Well-Architected Framework Scanner - Comprehensive assessment tool for Azure subscriptions with 60+ checks across all five WAF pillars (Reliability, Security, Cost Optimization, Operational Excellence, and Performance Efficiency). Generates interactive HTML reports, JSON/CSV exports, and provides actionable remediation recommendations.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' },
        @{ ModuleName = 'Az.ResourceGraph'; ModuleVersion = '0.13.0' },
        @{ ModuleName = 'Az.Advisor'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.Security'; ModuleVersion = '1.0.0' }
    )
    
    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()
    
    # Functions to export from this module
    FunctionsToExport = @(
        # Main Functions
        'Initialize-WafScanner',
        'Register-WafCheck',
        'Get-RegisteredChecks',
        'New-WafResult',
        'Invoke-WafCheck',
        'Invoke-WafSubscriptionScan',
        'Get-WafScanSummary',
        'Compare-WafBaseline',
        
        # Query Functions
        'Invoke-AzResourceGraphQuery',
        
        # Utility Functions
        'Convert-StatusToScore',
        'Estimate-ROI',
        'Get-WafWeights',
        'New-WafPortfolioSummary',
        'Get-AzurePortalLink',
        'Format-WafEvidence',
        'Test-WafConfigSchema',
        'Get-WafCheckById',
        'Export-WafResultsToCsv',
        'Export-WafResultsToJson'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @('Invoke-Arg')
    
    # DSC resources to export from this module
    DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    ModuleList = @()
    
    # List of all files packaged with this module
    FileList = @(
        'WafScanner.psm1',
        'WafScanner.psd1',
        'Core\Connect-Context.ps1',
        'Core\Get-Advisor.ps1',
        'Core\Get-CostData.ps1',
        'Core\Get-CostMonthly.ps1',
        'Core\Get-DefenderAssessments.ps1',
        'Core\Get-Orphans.ps1',
        'Core\Get-PolicyState.ps1',
        'Core\Get-Subscriptions.ps1',
        'Core\Invoke-Arg.ps1',
        'Core\Utils.ps1',
        'Core\HtmlEngine.ps1',
        'Core\Write-Result.ps1',
        'Report\New-EnhancedWafHtml.ps1',
        'Report\New-WafHtml.ps1',
        'Report\New-WafDocx.ps1',
        'Report\Build-WafNarrative.ps1'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'Azure',
                'WAF',
                'Well-Architected',
                'Assessment',
                'Security',
                'Compliance',
                'Best-Practices',
                'Cloud',
                'Governance',
                'Cost-Optimization',
                'Reliability',
                'Performance',
                'Operations',
                'DevOps',
                'Audit',
                'Report',
                'Analysis',
                'PSEdition_Core'
            )
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/dsvoda/Azure-WAF-Scanner/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/dsvoda/Azure-WAF-Scanner'
            
            # A URL to an icon representing this module
            IconUri = 'https://raw.githubusercontent.com/dsvoda/Azure-WAF-Scanner/main/docs/images/icon.png'
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
# Azure WAF Scanner v1.0.0

## Initial Release

### Features
- ✅ 60 comprehensive checks across all 5 WAF pillars
- ✅ Reliability (RE01-RE10): 10 checks
- ✅ Security (SE01-SE12): 12 checks
- ✅ Cost Optimization (CO01-CO14): 14 checks
- ✅ Operational Excellence (OE01-OE12): 12 checks
- ✅ Performance Efficiency (PE01-PE12): 12 checks

### Reporting
- Interactive HTML reports with charts and filtering
- JSON export for automation
- CSV export for analysis
- DOCX reports with executive summaries
- Baseline comparison for tracking improvements

### Performance
- Parallel subscription scanning
- Smart caching to reduce API calls
- Azure Resource Graph optimization
- Configurable timeouts and retry logic

### Documentation
- Complete API reference
- Troubleshooting guide
- Development guide for custom checks
- Examples and tutorials

### Links
- GitHub: https://github.com/dsvoda/Azure-WAF-Scanner
- Documentation: https://github.com/dsvoda/Azure-WAF-Scanner/tree/main/docs
- Issues: https://github.com/dsvoda/Azure-WAF-Scanner/issues
'@
            
            # Prerelease string of this module
            # Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance for install/update
            RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            ExternalModuleDependencies = @(
                'Az.Accounts',
                'Az.Resources',
                'Az.ResourceGraph',
                'Az.Advisor',
                'Az.Security'
            )
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/dsvoda/Azure-WAF-Scanner/blob/main/docs/'
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = ''
}
