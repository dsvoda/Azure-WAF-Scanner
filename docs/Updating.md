
# Updating & Extending

## Add a new control
```powershell
# Examples:
pwsh ./helpers/New-WafItem.ps1 -PillarFolder Security -ControlId 'SE:07' -ControlName 'Encrypt data' -Description 'Encryption at rest/in transit'
```

Then edit the generated `Invoke.ps1` and implement logic using Az cmdlets/Resource Graph/Advisor/Policy/Defender.

## Tips
- Use `Invoke-Arg` (KQL) for inventory.
- Use `Get-WafCached` to access cached subscription data warmed by the runner.
- Keep queries efficient and set `-ErrorAction SilentlyContinue` for optional providers.
