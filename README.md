
# Azure WAF Scanner (Local, On-Demand)

This tool scans Azure subscriptions against the Microsoft **Well-Architected Framework (WAF)** using **PowerShell** (Az modules, Resource Graph, Advisor, Policy Insights, Defender for Cloud, Cost Management, Monitor) and produces **JSON/CSV/HTML** reports.

- Runs **on-demand** using your **signed-in** Az context (no SPN, no Automation).
- Scans the **current subscription by default** or a list passed via `-Subscriptions`.
- Uses a **modular per-item** structure: each WAF checklist item has its own `Invoke.ps1` that registers a check.
- Outputs to a local folder (default `./waf-output`).

## Quick Start
```powershell
# PowerShell 7+
Connect-AzAccount       # or let the runner prompt you
pwsh ./run/Invoke-WafLocal.ps1 -EmitHtml -EmitCsv
# Optional: choose subscriptions by Id or Name
pwsh ./run/Invoke-WafLocal.ps1 -Subscriptions "00000000-0000-0000-0000-000000000000","My Sub Name" -EmitHtml
```

## Output
- `SUBID-YYYYMMDD-HHMMSS.json` (full results)
- `SUBID-YYYYMMDD-HHMMSS.csv`  (tabular export)
- `SUBID-YYYYMMDD-HHMMSS.html` (client-ready report)
- `SUBID-YYYYMMDD-HHMMSS-summary.json` (per-sub rollup)

## Project Layout
See `docs/Development.md`. The important bits:
```
run/Invoke-WafLocal.ps1            # main entry point
modules/WafScanner.psm1            # module (auto-loads per-item checks)
modules/Core/*.ps1                 # core helpers and registry
modules/Report/New-WafHtml.ps1     # HTML report rendering
modules/Pillars/<Pillar>/<ID>/Invoke.ps1  # one file per checklist item
report-assets/templates/default.html & styles.css
```

## Updating / Adding Items
- Use `helpers/New-WafItem.ps1` to scaffold a new control.
- Each file must call `Register-WafCheck` with a scriptblock `param([string]$SubscriptionId)` and return **one or more** `New-WafResult` objects.
- Prefer **Azure Resource Graph** for inventory, **Advisor** for recommendations, **Policy Insights** for compliance, **Defender** for posture, **CostManagement** for budgets/forecast.

## Requirements
PowerShell 7+, and Az modules. The runner auto-installs missing modules to the current user scope.

## License
MIT (sample content).

### Emit a Word document
Install-Module PSWriteWord -Scope CurrentUser -Force

Run with `-EmitDocx`.
