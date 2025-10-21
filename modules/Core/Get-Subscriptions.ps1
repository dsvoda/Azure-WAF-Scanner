
function Get-WafSubscriptions {
  [CmdletBinding()]
  param([string[]] $Include,[string[]] $Exclude)
  $subs = Get-AzSubscription -ErrorAction SilentlyContinue
  if ($Include) { $subs = $subs | Where-Object { $_.Id -in $Include -or $_.Name -in $Include } }
  if ($Exclude) { $subs = $subs | Where-Object { ($_.Id -notin $Exclude) -and ($_.Name -notin $Exclude) } }
  return $subs
}
