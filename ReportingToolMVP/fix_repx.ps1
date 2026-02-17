# Fix the data sources in the repx file
# Problem: StoredProcQuery with embedded connection string fails
# Fix: Use CustomSqlQuery with connection-name-only format (proven to work in backup)

$dsKPIs = @'
<SqlDataSource Name="dsKPIs"><Connection Name="3CX_Exporter_Production"><Parameters /></Connection><Query Type="CustomSqlQuery" Name="KPIs"><Sql>EXEC dbo.[sp_queue_kpi_summary_shushant] @period_from, @period_to, @queue_dns, @wait_interval</Sql><Parameters><QueryParameter Name="@period_from" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodFrom]</QueryParameter><QueryParameter Name="@period_to" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodTo]</QueryParameter><QueryParameter Name="@queue_dns" Type="DevExpress.DataAccess.Expression">[Parameters.pQueueDns]</QueryParameter><QueryParameter Name="@wait_interval" Type="DevExpress.DataAccess.Expression">[Parameters.pWaitInterval]</QueryParameter></Parameters></Query><ResultSchema><DataSet Name="dsKPIs"><View Name="KPIs"><Field Name="queue_dn" Type="String" /><Field Name="queue_display_name" Type="String" /><Field Name="total_calls" Type="Int32" /><Field Name="abandoned_calls" Type="Int32" /><Field Name="answered_calls" Type="Int32" /><Field Name="answered_percent" Type="Double" /><Field Name="answered_within_sla" Type="Int32" /><Field Name="answered_within_sla_percent" Type="Double" /><Field Name="serviced_callbacks" Type="Int32" /><Field Name="total_talking" Type="String" /><Field Name="mean_talking" Type="String" /><Field Name="avg_waiting" Type="String" /></View></DataSet></ResultSchema><ConnectionOptions CloseConnection="true" /></SqlDataSource>
'@

$dsChartData = @'
<SqlDataSource Name="dsChartData"><Connection Name="3CX_Exporter_Production"><Parameters /></Connection><Query Type="CustomSqlQuery" Name="ChartData"><Sql>EXEC dbo.[sp_queue_calls_by_date_shushant] @period_from, @period_to, @queue_dns, @wait_interval</Sql><Parameters><QueryParameter Name="@period_from" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodFrom]</QueryParameter><QueryParameter Name="@period_to" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodTo]</QueryParameter><QueryParameter Name="@queue_dns" Type="DevExpress.DataAccess.Expression">[Parameters.pQueueDns]</QueryParameter><QueryParameter Name="@wait_interval" Type="DevExpress.DataAccess.Expression">[Parameters.pWaitInterval]</QueryParameter></Parameters></Query><ResultSchema><DataSet Name="dsChartData"><View Name="ChartData"><Field Name="queue_dn" Type="String" /><Field Name="queue_display_name" Type="String" /><Field Name="call_date" Type="DateTime" /><Field Name="total_calls" Type="Int32" /><Field Name="answered_calls" Type="Int32" /><Field Name="abandoned_calls" Type="Int32" /><Field Name="answered_within_sla" Type="Int32" /><Field Name="answer_rate" Type="Double" /><Field Name="sla_percent" Type="Double" /></View></DataSet></ResultSchema><ConnectionOptions CloseConnection="true" /></SqlDataSource>
'@

$dsAgents = @'
<SqlDataSource Name="dsAgents"><Connection Name="3CX_Exporter_Production"><Parameters /></Connection><Query Type="CustomSqlQuery" Name="Agents"><Sql>EXEC dbo.[qcall_cent_get_extensions_statistics_by_queues] @period_from, @period_to, @queue_dns, @wait_interval</Sql><Parameters><QueryParameter Name="@period_from" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodFrom]</QueryParameter><QueryParameter Name="@period_to" Type="DevExpress.DataAccess.Expression">[Parameters.pPeriodTo]</QueryParameter><QueryParameter Name="@queue_dns" Type="DevExpress.DataAccess.Expression">[Parameters.pQueueDns]</QueryParameter><QueryParameter Name="@wait_interval" Type="DevExpress.DataAccess.Expression">[Parameters.pWaitInterval]</QueryParameter></Parameters></Query><ResultSchema><DataSet Name="dsAgents"><View Name="Agents"><Field Name="queue_dn" Type="String" /><Field Name="queue_display_name" Type="String" /><Field Name="extension_dn" Type="String" /><Field Name="extension_display_name" Type="String" /><Field Name="queue_received_count" Type="Int32" /><Field Name="extension_answered_count" Type="Int32" /><Field Name="talk_time" Type="String" /><Field Name="avg_talk_time" Type="String" /><Field Name="avg_answer_time" Type="String" /></View></DataSet></ResultSchema><ConnectionOptions CloseConnection="true" /></SqlDataSource>
'@

$b64KPIs = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dsKPIs))
$b64Chart = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dsChartData))
$b64Agents = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dsAgents))

Write-Host "dsKPIs base64 length: $($b64KPIs.Length)"
Write-Host "dsChartData base64 length: $($b64Chart.Length)"
Write-Host "dsAgents base64 length: $($b64Agents.Length)"

# Read the repx file
$repxPath = "D:\VoipTools-ReportingToolMVP\ReportingToolMVP\Reports\Templates\Similar_to_samuel_sirs_report.repx"
$content = Get-Content $repxPath -Raw

# Replace the ComponentStorage section
$pattern = '(?s)<ComponentStorage>.*?</ComponentStorage>'
$replacement = @"
<ComponentStorage>
    <Item1 Ref="0" ObjectType="DevExpress.DataAccess.Sql.SqlDataSource,DevExpress.DataAccess.v25.2" Name="dsKPIs" Base64="$b64KPIs" />
    <Item2 Ref="100" ObjectType="DevExpress.DataAccess.Sql.SqlDataSource,DevExpress.DataAccess.v25.2" Name="dsChartData" Base64="$b64Chart" />
    <Item3 Ref="101" ObjectType="DevExpress.DataAccess.Sql.SqlDataSource,DevExpress.DataAccess.v25.2" Name="dsAgents" Base64="$b64Agents" />
  </ComponentStorage>
"@

$newContent = [regex]::Replace($content, $pattern, $replacement)
Set-Content $repxPath -Value $newContent -NoNewline
Write-Host "Repx file updated successfully!"
Write-Host "File size: $((Get-Item $repxPath).Length) bytes"
