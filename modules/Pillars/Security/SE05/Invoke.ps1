
Register-WafCheck -Pillar 'Security' -Id 'SE05' -Name 'Strict IAM' -Description 'Owner assignments (user principals) and privileged roles' -InvokeScript {
  param([string]$SubscriptionId)

  $owners = Get-AzRoleAssignment -RoleDefinitionName 'Owner' -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue
  $userOwners = @($owners | Where-Object { $_.SignInName -and $_.ObjectType -eq 'User' })
  $status = ($userOwners.Count -gt 0) ? 'Warn' : 'Pass'
  New-WafResult -Pillar 'Security' -Id 'SE05' -Name 'Strict IAM' -Description 'User Owners at subscription scope' `
    -SubscriptionId $SubscriptionId -TestMethod 'RBAC' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("UserOwnerCount={0}" -f $userOwners.Count) -Recommendation 'Remove direct user Owner; use groups/PIM; enforce least privilege'

}
