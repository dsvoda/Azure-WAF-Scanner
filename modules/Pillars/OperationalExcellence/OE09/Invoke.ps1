
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:09' -Name 'Automate repetitive tasks' -Description 'Automation jobs/schedules' -InvokeScript {
  param([string]$SubscriptionId)

  $aa = Get-AzAutomationAccount -ErrorAction SilentlyContinue
  $schedules = 0
  foreach($a in $aa){ $schedules += (Get-AzAutomationScheduledRunbook -AutomationAccountName $a.AutomationAccountName -ResourceGroupName $a.ResourceGroupName -ErrorAction SilentlyContinue).Count }
  $status = ($schedules -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:09' -Name 'Automate repetitive tasks' -Description 'Scheduled runbooks present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Automation schedules' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("ScheduledRunbooks={0}" -f $schedules) -Recommendation 'Automate toil with runbooks/Functions; prefer native automation'

}
