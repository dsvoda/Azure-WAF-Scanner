
function Write-WafResult {
  param(
    [array]$InputObject,
    [ValidateSet('json','csv')]$Format,
    [string]$BaseName,
    [string]$OutputDir = (Join-Path (Get-Location) 'waf-output'),
    [string]$StorageAccount,
    [string]$Container
  )
  if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
  $path = Join-Path $OutputDir "$BaseName.$Format"
  if ($Format -eq 'json') { $InputObject | ConvertTo-Json -Depth 8 | Out-File -Encoding utf8 $path }
  else { $InputObject | Export-Csv -NoTypeInformation -Encoding utf8 $path }
}
