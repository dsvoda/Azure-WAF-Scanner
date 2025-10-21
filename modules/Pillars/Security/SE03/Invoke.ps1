
Register-WafCheck -Pillar 'Security' -Id 'SE03' -Name 'Data classification & labeling' -Description 'Purview/AIP presence (approx)' -InvokeScript {
  param([string]$SubscriptionId)

  try { $pv = Get-AzPurviewAccount -ErrorAction Stop; $status = ($pv.Count -gt 0) ? 'Warn' : 'Manual' } catch { $status = 'Manual' }
  New-WafResult -Pillar 'Security' -Id 'SE03' -Name 'Data classification & labeling' -Description 'Purview account presence' `
    -SubscriptionId $SubscriptionId -TestMethod 'Purview presence' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("PurviewAccounts={0}" -f (if($pv){$pv.Count}else{0})) -Recommendation 'Deploy Microsoft Purview and enable auto-classification; enforce labels via Policy where possible'

}
