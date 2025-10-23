# PSScriptAnalyzer Settings for Azure WAF Scanner
# Save this file as: .vscode/PSScriptAnalyzerSettings.psd1

@{
    # Include specific rules
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingWriteHost',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseApprovedVerbs',
        'PSAvoidUsingPositionalParameters',
        'PSUseSingularNouns',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUsePSCredentialType',
        'PSAvoidGlobalVars',
        'PSUseCmdletCorrectly',
        'PSAvoidUsingEmptyCatchBlock',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSShouldProcess',
        'PSMissingModuleManifestField',
        'PSAvoidDefaultValueSwitchParameter',
        'PSUseBOMForUnicodeEncodedFile'
    )
    
    # Exclude specific rules if needed
    ExcludeRules = @(
        # Uncomment rules below if you need to exclude them
        # 'PSAvoidUsingWriteHost'  # Enable if you need Write-Host for formatting
    )
    
    # Rule-specific configurations
    Rules = @{
        # Cmdlet alias checking
        PSAvoidUsingCmdletAliases = @{
            # Allow specific aliases if needed
            Whitelist = @()
        }
        
        # Compatible syntax checking for different PowerShell versions
        PSUseCompatibleSyntax = @{
            Enable = $true
            # Target PowerShell versions your code should be compatible with
            TargetVersions = @(
                '7.0',
                '7.1', 
                '7.2',
                '7.3',
                '7.4'
            )
        }
        
        # Compatible commands checking
        PSUseCompatibleCommands = @{
            Enable = $true
            # Ignore commands that might not be available in all environments
            IgnoreCommands = @(
                # Add any commands to ignore here
            )
        }
        
        # Compatible types checking
        PSUseCompatibleTypes = @{
            Enable = $true
            # Ignore types that might not be available in all environments
            IgnoreTypes = @(
                # Add any types to ignore here
            )
        }
        
        # Avoid using deprecated commands
        PSAvoidUsingDeprecatedManifestFields = @{
            Enable = $true
        }
        
        # Function parameter checking
        PSProvideCommentHelp = @{
            Enable = $false  # Set to $true if you want to enforce comment-based help
            ExportedOnly = $true
            BlockComment = $true
            VSCodeSnippetCorrection = $false
            Placement = 'before'
        }
        
        # Variable naming conventions
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $false  # Disabled by default as it can be too strict
        }
        
        # Use consistent indentation
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }
        
        # Use consistent whitespace
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
            CheckParameter = $false
            IgnoreAssignmentOperatorInsideHashTable = $false
        }
        
        # Align assignment statements
        PSAlignAssignmentStatement = @{
            Enable = $false  # Disabled by default as it can conflict with personal style
            CheckHashtable = $false
        }
        
        # Use correct casing for built-in cmdlets
        PSUseCorrectCasing = @{
            Enable = $false  # Disabled by default to avoid too many warnings
        }
        
        # Place open brace on same line
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        
        # Place close brace properly  
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
    }
    
    # Include specific paths only
    IncludeDefaultRules = $true
    
    # Severity levels to include (Error, Warning, Information)
    Severity = @(
        'Error',
        'Warning'
        # 'Information'  # Uncomment to include informational messages
    )
}
