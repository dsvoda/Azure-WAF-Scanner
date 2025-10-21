
function Get-DailyCosts {
  param([string]$SubscriptionId,[datetime]$From=(Get-Date).AddDays(-30),[datetime]$To=(Get-Date))
  $q = @{
    Type       = "Usage"
    Timeframe  = "Custom"
    TimePeriod = @{ From = $From; To = $To }
    Dataset    = @{ Granularity = "Daily"; Aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } } }
  } | ConvertTo-Json -Depth 10
  Get-AzCostManagementQuery -Scope "/subscriptions/$SubscriptionId" -Definition $q -ErrorAction SilentlyContinue
}
