
function Ensure-AzLogin {
  try { $null = Get-AzContext -ErrorAction Stop }
  catch {
    Write-Host "You're not signed in. Opening device login..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
  }
}
