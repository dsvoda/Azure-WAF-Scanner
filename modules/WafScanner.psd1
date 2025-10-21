#
# Module manifest for module 'WafScanner'
#
# Generated on: 2024-10-21
#

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'WafScanner.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Core')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'Azure WAF Scanner Contributors'
    
    # Company or vendor of this module
    CompanyName = 'Community'
    
    # Copyright statement for this module
    Copyright = '(c) 2024. MIT License.'
    
    # Description of the functionality provided by this module
    Description = 'Azure Well-Architected Framework Scanner - Automated assessment tool for Azure subscriptions'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' }
        @{ ModuleName = 'Az.ResourceGraph'; ModuleVersion = '0.13.0' }
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
        'Register-WafCheck',
        'Get-RegisteredChecks',
        'New-WafResult',
        'Invoke-AzResourceGraphQuery',
        'Invoke-WafCheck',
        'Invoke-WafSubscriptionScan',
        'Get-WafScanSummary',
        'Compare-WafBaseline',
        'Initialize-WafScanner'
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
        'WafScanner.psd1'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @(
                'Azure',
                'WAF',
                'Well-Architected',
                'Assessment',
                'Compliance',
                'Security',
                'Reliability',
                'Cloud',
                'Governance'
            )
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/yourusername/Azure-WAF-Scanner/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/yourusername/Azure-WAF-Scanner'
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 1.0.0 (2024-10-21)
==========================

Initial Release Features:
-------------------------
- 60+ WAF checks across all 5 pillars
- Multiple output formats (JSON, CSV, HTML)
- Interactive HTML reports with charts
- Baseline comparison for tracking progress
- Parallel subscription scanning
- Configurable checks and filters
- Smart caching to reduce API calls
- Automatic retry logic for throttling
- Detailed remediation guidance

Supported Pillars:
-----------------
- Reliability (RE01-RE10)
- Security (SE01-SE12)
- Cost Optimization (CO01-CO14)
- Performance Efficiency (PE01-PE12)
- Operational Excellence (OE01-OE12)

Requirements:
------------
- PowerShell 7.0+
- Az.Accounts >= 2.0.0
- Az.Resources >= 6.0.0
- Az.ResourceGraph >= 0.13.0

Known Issues:
------------
- DOCX export requires PSWriteWord module (optional)
- Some checks require additional Az modules
- Parallel scanning may hit API rate limits on large tenants

For full documentation, see: https://github.com/yourusername/Azure-WAF-Scanner
'@
            
            # Prerelease string of this module
            Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance
            RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            ExternalModuleDependencies = @(
                'Az.Accounts',
                'Az.Resources',
                'Az.ResourceGraph'
            )
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/yourusername/Azure-WAF-Scanner/wiki'
    
    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''
}
