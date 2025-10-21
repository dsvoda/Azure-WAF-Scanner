
Register-WafCheck -Pillar 'Reliability' -Id 'RE09' -Name 'BCDR plans implemented' -Description 'ASR/Backup coverage & tested plans' -InvokeScript {
  param([string]$SubscriptionId)

  $vaults = Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue
  $replicas = 0
  foreach($v in $vaults){
    try {
      Set-AzRecoveryServicesAsrVaultContext -VaultId $v.Id -ErrorAction SilentlyContinue
      $replicas += (Get-AzRecoveryServicesAsrReplicationProtectedItem -ErrorAction SilentlyContinue).Count
    } catch {}
  }
  $status = ($replicas -gt 0) ? 'Warn' : 'Fail'
  New-WafResult -Pillar 'Reliability' -Id 'RE09' -Name 'BCDR plans implemented' -Description 'ASR protected items present' `
    -SubscriptionId $SubscriptionId -TestMethod 'ASR (read-only)' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("Vaults={0}; ReplicatedItems={1}" -f $vaults.Count,$replicas) -Recommendation 'Protect critical workloads with ASR/Geo-restore; test DR drills quarterly'

}
