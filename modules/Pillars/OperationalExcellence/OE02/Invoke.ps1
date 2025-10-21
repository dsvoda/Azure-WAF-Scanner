
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE02' -Name 'Formalized ops tasks' -Description 'Standardize routine/emergency tasks as runbooks' -InvokeScript {
  param([string]$SubscriptionId)
  $aa = Get-AzAutomationAccount -ErrorAction SilentlyContinue
  $rb = 0
  foreach($a in $aa){ $rb += (Get-AzAutomationRunbook -AutomationAccountName $a.AutomationAccountName -ResourceGroupName $a.ResourceGroupName -ErrorAction SilentlyContinue).Count }
  $status = ($rb -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE02' -Name 'Formalized ops tasks' `
    -Description 'Automation runbooks present' -SubscriptionId $SubscriptionId -TestMethod 'Automation' `
    -Status $status -Score (Convert-StatusToScore $status) -Evidence ("Runbooks={0}" -f $rb) `
    -Recommendation 'Codify SOPs in runbooks; version control; schedule and alert on failures'
}
