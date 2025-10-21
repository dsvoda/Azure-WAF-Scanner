
$req = 'Az.Accounts','Az.Resources','Az.ResourceGraph','Az.Advisor','Az.PolicyInsights','Az.Security','Az.Monitor','Az.CostManagement','Az.Consumption'
$missing = $req | Where-Object { -not (Get-Module $_ -ListAvailable) }
if ($missing){ Write-Host "Installing: $($missing -join ', ')" -ForegroundColor Yellow; $missing | ForEach-Object { Install-Module $_ -Scope CurrentUser -Force } }
try { $ctx = Get-AzContext -ErrorAction Stop; Write-Host "Az context found: $($ctx.Subscription.Name)" -ForegroundColor Green }
catch { Write-Host "No Az login. Run Connect-AzAccount." -ForegroundColor Yellow }
