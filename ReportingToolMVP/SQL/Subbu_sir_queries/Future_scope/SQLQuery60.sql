EXEC dbo.sp_rpt__extension_statistics_cdr_united
    @period_from = '2026-02-01 00:00:00',--strat date
    @period_to   = '2026-02-09 23:59:59',--end date
    @call_area = 0,--all calls 0,internal calls 1,external calls 2
    @include_queue_calls = 1, --@include_queue_calls=1,non queue calls 0
    @members = '';--If you want all extension info, leave it blank (‘’). If you want specific extension numbers, please enter them separated by commas, e.g., 6565,2142.