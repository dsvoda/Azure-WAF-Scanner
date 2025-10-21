# WAF Check Naming Convention

## Official Format

This project uses a **two-letter pillar abbreviation + two-digit number** format for all WAF checks, aligned with Microsoft's Azure Well-Architected Framework standards.

## Format Pattern
```
[PILLAR][NUMBER]
```

- **No hyphens, colons, or separators**
- **Two letters** for pillar (uppercase)
- **Two digits** for check number (zero-padded)

## Pillar Abbreviations

| Pillar | Abbreviation | Example |
|--------|--------------|---------|
| Reliability | `RE` | RE01, RE02, RE15 |
| Security | `SE` | SE01, SE02, SE15 |
| Cost Optimization | `CO` | CO01, CO02, CO15 |
| Performance Efficiency | `PE` | PE01, PE02, PE15 |
| Operational Excellence | `OE` | OE01, OE02, OE15 |

## Examples

✅ **CORRECT:**
- `RE01` - First reliability check
- `SE05` - Fifth security check
- `CO12` - Twelfth cost optimization check
- `PE01` - First performance check
- `OE03` - Third operational excellence check

❌ **INCORRECT:**
- `REL-001` (too verbose, has hyphen)
- `RE:01` (has colon)
- `R01` (abbreviation too short)
- `RE1` (number not zero-padded)
- `re01` (not uppercase)

## Directory Structure

Checks must be organized as:
```
modules/
└── [Pillar]/
    └── [CheckID]/
        └── Invoke.ps1
```

**Examples:**
```
modules/
├── Reliability/
│   ├── RE01/
│   │   └── Invoke.ps1
│   └── RE02/
│       └── Invoke.ps1
├── Security/
│   ├── SE01/
│   │   └── Invoke.ps1
│   └── SE02/
│       └── Invoke.ps1
└── CostOptimization/
    ├── CO01/
    │   └── Invoke.ps1
    └── CO02/
        └── Invoke.ps1
```

## Check ID Registration

When registering a check, use the exact format:
```powershell
Register-WafCheck -CheckId 'RE01' `
    -Pillar 'Reliability' `
    -Title 'Virtual Machines should use Availability Zones' `
    -Description '...' `
    -Severity 'High' `
    -RemediationEffort 'High' `
    -ScriptBlock { ... }
```

## Creating New Checks

Use the scaffolding tool with the correct format:
```powershell
# Correct usage
pwsh ./helpers/New-WafItem.ps1 -CheckId 'RE05' -Pillar 'Reliability' -Title 'Your Check Title'

# The tool will create:
# modules/Reliability/RE05/Invoke.ps1
```

## Numbering Guidelines

### Sequential Numbering
- Assign check IDs sequentially within each pillar
- Find the highest existing number and add 1
- Use zero-padding (01, 02, ... 09, 10, 11, etc.)

### Finding Next Available ID
```powershell
# List existing checks for a pillar
Get-ChildItem -Path .\modules\Reliability -Directory | Sort-Object Name

# Output might show: RE01, RE02, RE03, RE04
# Next available: RE05
```

### Maximum Check IDs
- Two digits support up to 99 checks per pillar (01-99)
- If you exceed 99 checks in a pillar, consider refactoring or splitting into subcategories

## Test Files

Test files should mirror the check ID format:
```
tests/Unit/[Pillar]/[CheckID].Tests.ps1
```

**Examples:**
```
tests/Unit/Reliability/RE01.Tests.ps1
tests/Unit/Security/SE05.Tests.ps1
tests/Unit/CostOptimization/CO03.Tests.ps1
```

## Configuration Files

When excluding checks in `config.json`:
```json
{
  "excludedChecks": ["RE01", "SE05", "CO03"],
  "excludedPillars": ["PerformanceEfficiency"]
}
```

## Why This Format?

1. **Microsoft Alignment**: Closely matches Microsoft's official WAF review format (RE:01, SE:05)
2. **Consistency**: Maintains consistency with existing 34+ checks in the repository
3. **Brevity**: Short and easy to type/remember
4. **Sortable**: Natural alphabetical sorting keeps checks organized
5. **File System Friendly**: No special characters that might cause issues on different platforms
6. **Visual Clarity**: Easy to parse at a glance

## References

- [Microsoft Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Azure Well-Architected Review Assessments](https://learn.microsoft.com/assessments/azure-architecture-review/)

## Change Log

- 2024-10-21: Initial naming convention documentation established
```
