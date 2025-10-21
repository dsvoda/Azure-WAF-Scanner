
function Get-PolicySummary { param([string]$SubscriptionId)
  Get-AzPolicyStateSummary -SubscriptionId $SubscriptionId -Top 1 -ErrorAction SilentlyContinue
}
