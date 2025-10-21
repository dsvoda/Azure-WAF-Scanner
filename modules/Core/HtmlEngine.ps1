
function Get-Branding {
  $brand = Join-Path $PSScriptRoot '..\..\config\branding.json'
  if (Test-Path $brand) { return Get-Content $brand -Raw | ConvertFrom-Json } else { return @{ company=''; logo=''; color='#2b6cb0' } }
}
function Get-HtmlTemplate {
  $tpl = Join-Path $PSScriptRoot '..\..\report-assets\templates\default.html'
  Get-Content $tpl -Raw -Encoding utf8
}
