
Register-WafCheck -Pillar 'Performance Efficiency' -Id 'PE08' -Name 'Optimize data usage' -Description 'SQL automatic tuning presence' -InvokeScript {
  param([string]$SubscriptionId)

  $sql = Get-AzSqlServer -ErrorAction SilentlyContinue
  $auto = 0
  foreach($s in $sql){
    $dbs = Get-AzSqlDatabase -ServerName $s.ServerName -ResourceGroupName $s.ResourceGroupName -ErrorAction SilentlyContinue
    foreach($d in $dbs){
      try { $t = Get-AzSqlDatabaseAutomaticTuning -ServerName $s.ServerName -DatabaseName $d.DatabaseName -ResourceGroupName $s.ResourceGroupName -ErrorAction SilentlyContinue
            if($t -and $t.DesiredState -ne 'Off'){ $auto++ } } catch {}
    }
  }
  $status = ($auto -gt 0) ? 'Pass' : 'Warn'
  New-WafResult -Pillar 'Performance Efficiency' -Id 'PE08' -Name 'Optimize data usage' -Description 'SQL automatic tuning enabled' `
    -SubscriptionId $SubscriptionId -TestMethod 'SQL Automatic Tuning' -Status $status -Score (Convert-StatusToScore $status) `
    -Evidence ("AutoTunedDBs={0}" -f $auto) -Recommendation 'Enable automatic tuning; optimize partitions/indexes per workload telemetry'

}
