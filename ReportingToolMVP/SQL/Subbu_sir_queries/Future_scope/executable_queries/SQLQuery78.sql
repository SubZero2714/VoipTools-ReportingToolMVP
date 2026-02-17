EXEC dbo.[sp_queue_stats_range] --it will all the queue wise information with the date range, specific queue can be added

    @from = '2026-02-01 00:00:00 +00:00',--from date

    @to   = '2026-02-09 00:00:00 +00:00',--to date

  @queue_dns = '', --(optional)If you want all extension info, leave it blank (‘’). If you want specific queue numbers, please enter them separated by commas, e.g., 8089,8000.

	@sla_seconds =20;--(optional)SLA Seconds
 