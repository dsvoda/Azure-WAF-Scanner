
# Development Guide

## Philosophy
- **Read-only**: All checks use read scopes (Reader/Security Reader/etc). Running as your user, make sure you have read permissions.
- **Per-item modularity**: Each checklist item lives in its own folder under `modules/Pillars/...` and registers itself via `Register-WafCheck`.
- **Evidence-first**: Every result includes evidence and a concrete remediation.

## Coding Pattern
- Each `Invoke.ps1`:
  - Calls `Register-WafCheck -Pillar '<PillarName>' -Id 'XX:YY' -Name '...' -Description '...' -InvokeScript { param([string]$SubscriptionId) ... }`
  - Returns one or more `New-WafResult` objects.

- Status values: `Pass | Warn | Fail | Manual`
- Scoring: default mapping in `Utils.ps1` (Pass=100, Warn=60, Fail=0, Manual=50).

## Testing
- Run locally against a non-production test subscription.
- Use `tests/` Pester scaffolding (not included in this minimal package) or add as needed.
