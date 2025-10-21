
Register-WafCheck -Pillar 'Operational Excellence' -Id 'OE:03' -Name 'Ideation & planning formalized' -Description 'Manual: Boards/work tracking' -InvokeScript {
  param([string]$SubscriptionId)

  $status = 'Manual'
  New-WafResult -Pillar 'Operational Excellence' -Id 'OE:03' -Name 'Ideation & planning formalized' -Description 'Use Azure Boards/Jira; PRD and ADRs' `
    -SubscriptionId $SubscriptionId -TestMethod 'Manual' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence 'Work tracking tools not visible via subscription context' -Recommendation 'Enforce templates & gated reviews'

}
