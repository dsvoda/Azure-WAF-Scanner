
function Get-MonthlyCost {
  param([string]$SubscriptionId,[datetime]$From,[datetime]$To)
  $def = @{
    Type       = "Usage"
    Timeframe  = "Custom"
    TimePeriod = @{ From = $From; To = $To }
    Dataset    = @{
      Granularity = "Monthly"
      Aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } }
    }
  } | ConvertTo-Json -Depth 10
  Get-AzCostManagementQuery -Scope "/subscriptions/$SubscriptionId" -Definition $def -ErrorAction SilentlyContinue
}
function Get-CurrentMonthCost {
  param([string]$SubscriptionId)
  $start = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
  $end = Get-Date
  Get-MonthlyCost -SubscriptionId $SubscriptionId -From $start -To $end
}
function Get-LastFullMonthCost {
  param([string]$SubscriptionId)
  $now = Get-Date
  $start = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(-1)
  $end = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddSeconds(-1)
  Get-MonthlyCost -SubscriptionId $SubscriptionId -From $start -To $end
}
