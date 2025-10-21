
Register-WafCheck -Pillar 'Security' -Id 'SE:07' -Name 'Encrypt data' -Description 'Encryption at rest & in transit aligned to data classification' -InvokeScript {
  param([string]$SubscriptionId)
  $encKql = @"
resources
| where type in~ ('microsoft.compute/disks','microsoft.storage/storageaccounts')
| extend enc = tostring(properties.encryption.type)
| project id, type, enc
"@
  $enc = Invoke-Arg -Kql $encKql -Subscriptions $SubscriptionId
  $unencrypted = $enc | Where-Object { [string]::IsNullOrEmpty($_.enc) -or $_.enc -eq 'null' }
  $status = ($unencrypted.Count -gt 0) ? 'Fail' : 'Pass'
  New-WafResult -Pillar 'Security' -Id 'SE:07' -Name 'Encrypt data' `
    -Description 'Encryption at rest presence (disks/storage)' -SubscriptionId $SubscriptionId -TestMethod 'ARG KQL' `
    -Status $status -Score (Convert-StatusToScore $status) -Evidence ("UnencryptedCount={0}" -f $unencrypted.Count) `
    -Recommendation 'Enable platform encryption; use CMK (Key Vault) for high-sensitivity data' -EstimatedROI $null
}
