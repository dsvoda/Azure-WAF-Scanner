
Register-WafCheck -Pillar 'Security' -Id 'SE09' -Name 'Protect secrets (Key Vault)' -Description 'KV soft delete & purge protection, RBAC' -InvokeScript {
  param([string]$SubscriptionId)

  $kv = Get-AzKeyVault -ErrorAction SilentlyContinue
  $ok = 0; $bad = 0
  foreach($v in $kv){
    if ($v.EnableSoftDelete -and $v.EnablePurgeProtection){ $ok++ } else { $bad++ }
  }
  $status = ($bad -eq 0 -and $kv.Count -gt 0) ? 'Pass' : ( $kv.Count -gt 0 ? 'Warn' : 'Fail' )
  New-WafResult -Pillar 'Security' -Id 'SE09' -Name 'Protect secrets (Key Vault)' -Description 'Soft delete & purge protection' `
    -SubscriptionId $SubscriptionId -TestMethod 'KeyVault props' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("KeyVaults={0}; Good={1}; NeedsFix={2}" -f $kv.Count,$ok,$bad) -Recommendation 'Enable soft delete and purge protection; restrict access via RBAC and logging'

}
