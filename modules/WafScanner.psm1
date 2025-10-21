
# Core
. $PSScriptRoot\Core\Connect-Context.ps1
. $PSScriptRoot\Core\Get-Subscriptions.ps1
. $PSScriptRoot\Core\Invoke-Arg.ps1
. $PSScriptRoot\Core\Get-Advisor.ps1
. $PSScriptRoot\Core\Get-PolicyState.ps1
. $PSScriptRoot\Core\Get-DefenderAssessments.ps1
. $PSScriptRoot\Core\Get-CostData.ps1
. $PSScriptRoot\Core\Write-Result.ps1
. $PSScriptRoot\Core\Get-CostMonthly.ps1
. $PSScriptRoot\Core\Get-Orphans.ps1
. $PSScriptRoot\Core\Utils.ps1
. $PSScriptRoot\Core\Registry.ps1
. $PSScriptRoot\Report\New-WafHtml.ps1
. $PSScriptRoot\Report\Build-WafNarrative.ps1
. $PSScriptRoot\Report\New-WafDocx.ps1

# Auto-load all per-item checks
Load-WafChecks

Export-ModuleMember -Function `
  Ensure-AzLogin, Get-WafSubscriptions, Invoke-Arg, Get-Advisor, Get-PolicySummary, `
  Get-DefenderAssessments, Get-SecureScore, Get-DailyCosts, Write-WafResult, `
  New-WafResult, Convert-StatusToScore, Estimate-ROI, `
  Register-WafCheck, Load-WafChecks, Invoke-WafChecksForSubscription, `
  New-WafHtml, Initialize-WafSubscriptionCache, Get-WafCached, New-WafPortfolioSummary
