# Contributing to Azure WAF Scanner

Thank you for your interest in contributing to the Azure Well-Architected Framework Scanner! This document provides guidelines and instructions for contributing to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Recognition](#recognition)

---

## 🤝 Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

---

## 💡 How Can I Contribute?

### Reporting Bugs

If you find a bug, please create an issue using our [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md). Include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Environment details** (PowerShell version, Az module versions, OS)
- **Error messages** and stack traces
- **Screenshots** if applicable

### Suggesting Enhancements

Feature requests are welcome! Use our [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md). Explain:

- **The problem** you're trying to solve
- **Your proposed solution**
- **Alternative solutions** you've considered
- **Use cases** and benefits
- **Implementation complexity** (if known)

### Adding New Checks

Want to add a new WAF check? Use our [Check Request template](.github/ISSUE_TEMPLATE/check_request.md). We especially welcome:

- Organization-specific checks
- Azure service-specific checks
- Compliance framework checks
- Cost optimization opportunities

### Improving Documentation

Documentation improvements are always appreciated:

- Fix typos and clarify explanations
- Add examples and use cases
- Create tutorials and how-to guides
- Translate documentation (future)
- Update screenshots and diagrams

---

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

1. **PowerShell 7.0+** ([Download](https://github.com/PowerShell/PowerShell/releases))
2. **Git** for version control
3. **Azure subscription** for testing (optional)
4. **VS Code** with PowerShell extension (recommended)

### Required PowerShell Modules

```powershell
# Install required modules
Install-Module Az.Accounts -Scope CurrentUser -Force
Install-Module Az.Resources -Scope CurrentUser -Force
Install-Module Az.ResourceGraph -Scope CurrentUser -Force
Install-Module Az.Advisor -Scope CurrentUser -Force

# Development tools
Install-Module Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0
Install-Module PSScriptAnalyzer -Force
```

### Fork and Clone

1. **Fork** the repository to your GitHub account
2. **Clone** your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/Azure-WAF-Scanner.git
cd Azure-WAF-Scanner
```

3. **Add upstream** remote:

```bash
git remote add upstream https://github.com/dsvoda/Azure-WAF-Scanner.git
```

---

## 🔄 Development Workflow

### 1. Create a Branch

Always create a new branch for your work:

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

### Branch Naming Convention

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `test/` - Test additions or improvements
- `refactor/` - Code refactoring
- `check/` - New WAF check additions

### 2. Make Changes

Follow our [Coding Standards](#coding-standards) while making changes.

### 3. Test Your Changes

```powershell
# Run all tests
Invoke-Pester -Path ./tests -Output Detailed

# Run specific test file
Invoke-Pester -Path ./tests/Unit/WafScanner.Module.Tests.ps1 -Output Detailed

# Check code coverage
Invoke-Pester -Path ./tests -CodeCoverage ./modules/**/*.ps1 -Output Detailed
```

### 4. Run Code Analysis

```powershell
# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path ./modules -Recurse -ReportSummary

# Auto-fix issues
Invoke-ScriptAnalyzer -Path ./modules -Recurse -Fix
```

### 5. Commit Changes

Write clear, descriptive commit messages:

```bash
# Good commit messages
git commit -m "Add SE13 check for Key Vault soft delete"
git commit -m "Fix RE01 empty resource group detection"
git commit -m "Update documentation for custom checks"

# Bad commit messages (avoid these)
git commit -m "Fixed stuff"
git commit -m "Updates"
git commit -m "WIP"
```

**Commit Message Format:**

```
<type>: <subject>

<body (optional)>

<footer (optional)>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes (formatting)
- `chore`: Maintenance tasks

### 6. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create pull request on GitHub
```

---

## 📝 Coding Standards

### PowerShell Style Guide

Follow these conventions for consistency:

#### General

- Use **4 spaces** for indentation (no tabs)
- **UTF-8** encoding for all files
- **LF** line endings (configure Git: `git config core.autocrlf input`)
- Maximum **120 characters** per line
- Remove trailing whitespace

#### Naming Conventions

```powershell
# Functions: PascalCase with approved verbs
function Get-WafCheckById { }
function Invoke-WafSubscriptionScan { }

# Variables: camelCase
$checkResults = @()
$subscriptionId = 'sub-123'

# Constants: UPPER_SNAKE_CASE
$MAX_RETRY_ATTEMPTS = 3

# Parameters: PascalCase
param(
    [string]$SubscriptionId,
    [int]$TimeoutSeconds
)
```

#### Code Structure

```powershell
<#
.SYNOPSIS
    Brief description of function.

.DESCRIPTION
    Detailed description of what the function does.

.PARAMETER ParameterName
    Description of parameter.

.EXAMPLE
    Example-Function -Parameter Value
    
.NOTES
    Additional notes.
#>
function Example-Function {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParameter,
        
        [Parameter()]
        [int]$OptionalParameter = 10
    )
    
    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }
    
    process {
        try {
            # Main logic here
            $result = "Processing: $RequiredParameter"
            
            return $result
            
        } catch {
            Write-Error "Failed to process: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
```

#### Error Handling

```powershell
# Always use try-catch for operations that might fail
try {
    $results = Invoke-SomeOperation
} catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    
    # Return error result instead of crashing
    return New-WafResult -CheckId 'XX01' `
        -Status 'Error' `
        -Message "Check failed: $($_.Exception.Message)"
}
```

#### Comments

```powershell
# Good comments explain WHY, not WHAT
# Calculate weighted score to prioritize critical issues
$weightedScore = $baseScore * $severityMultiplier

# Bad comments (avoid these)
# Set variable to 5
$count = 5
```

### PSScriptAnalyzer Rules

All code must pass PSScriptAnalyzer with zero errors:

```powershell
Invoke-ScriptAnalyzer -Path ./modules -Recurse -Settings ./.vscode/PSScriptAnalyzerSettings.psd1
```

---

## 🧪 Testing Requirements

### Test Coverage Requirements

- All new functions must have tests
- Minimum **70% code coverage** overall
- **100% coverage** for critical functions
- Tests must pass before PR is merged

### Writing Tests

Use Pester 5.x+ syntax:

```powershell
Describe 'My-NewFunction' {
    BeforeAll {
        Import-Module ./modules/WafScanner.psm1 -Force
    }
    
    Context 'Parameter Validation' {
        It 'Should accept valid parameters' {
            { My-NewFunction -Parameter 'Value' } | Should -Not -Throw
        }
        
        It 'Should throw on invalid parameters' {
            { My-NewFunction -Parameter $null } | Should -Throw
        }
    }
    
    Context 'Functionality' {
        It 'Should return expected result' {
            $result = My-NewFunction -Parameter 'Test'
            $result | Should -Not -BeNullOrEmpty
            $result.Property | Should -Be 'ExpectedValue'
        }
    }
    
    AfterAll {
        Remove-Module WafScanner -Force -ErrorAction SilentlyContinue
    }
}
```

### Test Organization

```
tests/
├── Unit/              # Unit tests for individual functions
├── Integration/       # Integration tests for workflows
├── Checks/           # Tests for WAF checks
└── Validation/       # Validation tests for standards
```

---

## 📚 Documentation

### Code Documentation

- All functions must have comment-based help
- Include at least one `.EXAMPLE` per function
- Document all parameters
- Add `.NOTES` for important information

### README Updates

Update README.md if you:
- Add new features
- Change installation process
- Modify usage examples
- Add new dependencies

### Check Documentation

New checks must include:

1. **Comment header** with synopsis, description, notes
2. **Documentation URL** to Microsoft Learn article
3. **Clear error messages** and recommendations
4. **Remediation script** when applicable

Example:

```powershell
<#
.SYNOPSIS
    XX01 - Check Title

.DESCRIPTION
    Detailed description of what this check validates.

.NOTES
    Pillar: Security
    Recommendation: XX:01 from Microsoft WAF
    Severity: High
    
.LINK
    https://learn.microsoft.com/azure/well-architected/...
#>

Register-WafCheck -CheckId 'XX01' `
    -Pillar 'Security' `
    -Title 'Check Title' `
    -Description 'What this checks' `
    -Severity 'High' `
    -RemediationEffort 'Medium' `
    -DocumentationUrl 'https://...' `
    -ScriptBlock {
        param([string]$SubscriptionId)
        
        try {
            # Check logic here
            
            return New-WafResult -CheckId 'XX01' `
                -Status 'Pass' `
                -Message 'Validation passed'
                
        } catch {
            return New-WafResult -CheckId 'XX01' `
                -Status 'Error' `
                -Message "Check failed: $($_.Exception.Message)"
        }
    }
```

---

## 🔀 Pull Request Process

### Before Submitting

Ensure your PR:

- [ ] Passes all tests locally
- [ ] Passes PSScriptAnalyzer with 0 errors
- [ ] Includes tests for new functionality
- [ ] Updates documentation
- [ ] Follows coding standards
- [ ] Has clear commit messages
- [ ] Is based on latest `main` branch

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manually tested

## Screenshots (if applicable)
Add screenshots to help explain your changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Commented complex code
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Tests pass
```

### Review Process

1. **Automated checks** run on PR (CI/CD)
2. **Maintainer review** (usually within 2-3 days)
3. **Address feedback** if requested
4. **Approval and merge** by maintainer

### After Merge

- Your contribution will be included in the next release
- You'll be added to CONTRIBUTORS.md
- Major contributors get mentioned in release notes

---

## 🏆 Recognition

We value all contributions! Contributors are recognized in:

### CONTRIBUTORS.md

All contributors are listed in our [CONTRIBUTORS.md](CONTRIBUTORS.md) file.

### Release Notes

Significant contributions are highlighted in release notes.

### All-Contributors Bot

We use the [All Contributors](https://allcontributors.org/) specification:

```bash
# Add yourself as a contributor
npm install -g all-contributors-cli
all-contributors add YOUR_USERNAME code,doc,test
```

**Contribution Types:**
- 💻 `code` - Code contributions
- 📖 `doc` - Documentation
- 🧪 `test` - Tests
- 🐛 `bug` - Bug reports
- 💡 `ideas` - Ideas and planning
- 📋 `projectManagement` - Project management
- 👀 `review` - Reviewed PRs
- 🎨 `design` - Design
- 🌍 `translation` - Translations

---

## ❓ Questions?

### Getting Help

- 📖 **Documentation:** Check [docs/](docs/) directory
- 💬 **Discussions:** Use [GitHub Discussions](https://github.com/dsvoda/Azure-WAF-Scanner/discussions)
- 🐛 **Issues:** [GitHub Issues](https://github.com/dsvoda/Azure-WAF-Scanner/issues)

### Maintainers

- [@dsvoda](https://github.com/dsvoda) - Project Creator

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).

---

## 🙏 Thank You!

Your contributions make this project better for everyone. Whether it's fixing a typo, adding a feature, or reporting a bug - thank you for being part of the Azure WAF Scanner community!

---

**Happy Contributing! 🎉**
