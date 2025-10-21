
Register-WafCheck -Pillar 'Reliability' -Id 'RE07' -Name 'Self-healing measures' -Description 'LB health probes & VMSS automatic repairs' -InvokeScript {
  param([string]$SubscriptionId)

  $lbKql = "resources | where type =~ 'microsoft.network/loadBalancers/probes' | summarize c=count()"
  $lbp = Invoke-Arg -Kql $lbKql -Subscriptions $SubscriptionId
  $vmss = Get-AzVmss -ErrorAction SilentlyContinue
  $autoRepair = 0
  foreach($s in $vmss){ if($s.AutomaticRepairPolicy -and $s.AutomaticRepairPolicy.Enabled){ $autoRepair++ } }
  $status = (($lbp[0].c -gt 0) -and ($autoRepair -gt 0)) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Reliability' -Id 'RE07' -Name 'Self-healing measures' -Description 'LB probes and VMSS automatic repairs' `
    -SubscriptionId $SubscriptionId -TestMethod 'ARG+Compute' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("LBProbes={0}; VMSSAutoRepair={1}" -f $lbp[0].c,$autoRepair) -Recommendation 'Use health probes and enable VMSS automatic repairs'

}
