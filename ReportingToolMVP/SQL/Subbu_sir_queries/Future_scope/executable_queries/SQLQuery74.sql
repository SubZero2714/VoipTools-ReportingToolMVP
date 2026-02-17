EXEC dbo.sp_queue_stats_summary_rang_day_compare  --THIS QUERY WILL GIVE ME THE RANGE INFORMATION FOR THE SELECTED QUEUES AND FOR THE CURRENT DAY
@from = '2026-02-01 09:30:00',
@to = '2026-02-10 18:00:00',
 
	 @queue_list = '8089',
    @sla_seconds = 20;