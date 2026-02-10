EXEC dbo.fn_rpt__extension_statistics_cdr_united
    @period_from = '2026-02-01 00:00:00',
    @period_to   = '2026-02-09 23:59:59',
    @call_area = 0,
    @include_queue_calls = 1,
    @wait_interval = '00:00:00',
    @members = '',
    @observers = '';