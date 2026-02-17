EXEC dbo.sp_rpt__extension_statistics_cdr_united_today
    @period_from = '2026-02-09 00:00:00',
    @period_to   = '2026-02-09 23:59:59',
    @call_area   = 0,
    @include_queue_calls = 1,
    @wait_interval = '00:00:20',
    @members = '',
    @observers = '';