
function Get-Advisor { param([string]$SubscriptionId,[string[]]$Category)
  Get-AzAdvisorRecommendation -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue | Where-Object {
    if ($Category) { $_.Category -in $Category } else { $true }
  }
}
