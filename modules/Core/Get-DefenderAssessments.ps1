
function Get-DefenderAssessments { param([string]$SubscriptionId) Get-AzSecurityAssessment -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue }
function Get-SecureScore { param([string]$SubscriptionId) Get-AzSecuritySecureScore -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue }
