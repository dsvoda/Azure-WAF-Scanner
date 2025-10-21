
. $PSScriptRoot\..\Core\HtmlEngine.ps1
function New-WafHtml {
  param([array]$InputObject,[object]$Subscription)
  $brand = Get-Branding
  $tpl = Get-HtmlTemplate
  $summary = foreach($p in ($InputObject | Group-Object Pillar)){
    $avg = [math]::Round(($p.Group | Measure-Object -Property Score -Average).Average,0)
    "<div class='card'><b>$($p.Name)</b><br/>Avg Score: <span>$avg</span></div>"
  } -join ''
  $details = foreach($group in $InputObject | Group-Object Pillar){
@"
<h2>$($group.Name)</h2>
<table>
<tr><th>Control</th><th>Status</th><th>Score</th><th>Evidence</th><th>Recommendation</th><th>ROI</th></tr>
$(
  $group.Group | Sort-Object ControlId | ForEach-Object {
    $cls=$_.Status.ToLower()
    "<tr><td><b>$($_.ControlId)</b> $($_.ControlName)</td><td class='$cls'>$($_.Status)</td><td>$($_.Score)</td><td><details><summary>view</summary><pre>$([System.Web.HttpUtility]::HtmlEncode($_.Evidence))</pre></details></td><td>$($_.Recommendation)</td><td>$($_.EstimatedROI)</td></tr>"
  } -join ''
)
</table>
"@
  } -join ''
  $tpl.Replace('{{TITLE}}',"Azure WAF Report — $($Subscription.Name)") `
     .Replace('{{SUBTITLE}}',"$($Subscription.Id)") `
     .Replace('{{LOGO}}',$brand.logo) `
     .Replace('{{GENERATED}}',(Get-Date).ToString('u')) `
     .Replace('{{SUMMARY_HTML}}',$summary) `
     .Replace('{{DETAILS_HTML}}',$details)
}
