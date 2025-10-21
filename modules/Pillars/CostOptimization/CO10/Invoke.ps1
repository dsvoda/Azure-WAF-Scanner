
Register-WafCheck -Pillar 'Cost Optimization' -Id 'CO10' -Name 'Optimize data costs' -Description 'Storage tiering & lifecycle policies' -InvokeScript {
  param([string]$SubscriptionId)

  $stor = Get-AzStorageAccount -ErrorAction SilentlyContinue
  $lc = 0
  foreach($s in $stor){
    try { $pol = Get-AzStorageAccountManagementPolicy -ResourceGroupName $s.ResourceGroupName -StorageAccountName $s.StorageAccountName -ErrorAction SilentlyContinue; if($pol){$lc++} } catch{}
  }
  $status = ($lc -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Cost Optimization' -Id 'CO10' -Name 'Optimize data costs' -Description 'Storage lifecycle policies present' `
    -SubscriptionId $SubscriptionId -TestMethod 'Storage Mgmt Policy' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("StorageAccounts={0}; WithLifecyclePolicy={1}" -f $stor.Count,$lc) -Recommendation 'Enable lifecycle mgmt and appropriate access tiers (Cool/Archive); optimize backup/replication retention'

}
