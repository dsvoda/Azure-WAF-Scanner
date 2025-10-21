
function Invoke-Arg {
  param([string]$Kql,[string[]]$Subscriptions)
  Search-AzGraph -Query $Kql -Subscription $Subscriptions -First 100000
}
function Invoke-ArgBatch {
  param([hashtable]$Queries,[string[]]$Subscriptions)
  $out = @{}; foreach($k in $Queries.Keys){ $out[$k] = Invoke-Arg -Kql $Queries[$k] -Subscriptions $Subscriptions }; $out
}
function Initialize-WafSubscriptionCache {
  param([string]$SubscriptionId)
  $global:Waf_SubCache = $global:Waf_SubCache ?? @{}
  if ($global:Waf_SubCache[$SubscriptionId]) { return }
  $queries = @{
    'nsgCount' = "resources | where type =~ 'microsoft.network/networksecuritygroups' | summarize c=count()"
    'fwCount'  = "resources | where type =~ 'microsoft.network/azurefirewalls' | summarize c=count()"
    'diagCount'= "resources | where type =~ 'microsoft.insights/diagnosticsettings' | summarize c=count()"
  }
  $batch = Invoke-ArgBatch -Queries $queries -Subscriptions $SubscriptionId
  $global:Waf_SubCache[$SubscriptionId] = @{ Arg=$batch }
}
function Get-WafCached {
  param([string]$SubscriptionId,[string]$Key)
  if ($global:Waf_SubCache.ContainsKey($SubscriptionId)) { return $global:Waf_SubCache[$SubscriptionId][$Key] }
  return $null
}
