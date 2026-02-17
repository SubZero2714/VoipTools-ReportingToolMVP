EXEC dbo.[qcall_cent_get_extensions_statistics_by_queues]
    @period_from = '2026-02-01 00:00:00', --from date
    @period_to = '2026-02-09 23:59:59',--to date
    @queue_dns = '8000,8089', -- comma-separated queue DNs numbers
    @wait_interval = '00:00:05'; --Exclude calls dropped before