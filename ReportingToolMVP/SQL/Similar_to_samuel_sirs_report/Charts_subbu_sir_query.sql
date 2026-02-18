USE [3CX Exporter]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
CREATE OR ALTER PROCEDURE [dbo].[sp_queue_stats_daily_summary]
(
    @from            DATETIMEOFFSET = NULL,
    @to              DATETIMEOFFSET = NULL,
    @queue_dns       VARCHAR(MAX)    = NULL,
    @sla_seconds     INT             = 20,
    @report_timezone VARCHAR(100)    = 'India Standard Time'
)
AS
BEGIN
    SET NOCOUNT ON;
 
    ------------------------------------------------------------
    -- Validate queue
    ------------------------------------------------------------
    IF @queue_dns IS NULL OR TRIM(@queue_dns) = ''
    BEGIN
        RAISERROR('@queue_dns is required.', 16, 1);
        RETURN;
    END
 
    ------------------------------------------------------------
    -- Default date range (last 7 full days UTC)
    ------------------------------------------------------------
    SET @from = ISNULL(@from,
        DATEADD(DAY, -7, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIMEOFFSET))
    );
 
    SET @to = ISNULL(@to,
        DATEADD(DAY, 1, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIMEOFFSET))
    );
 
    ------------------------------------------------------------
    -- Validate timezone
    ------------------------------------------------------------
    IF @report_timezone NOT IN (SELECT name FROM sys.time_zone_info)
    BEGIN
        RAISERROR('Invalid timezone name.', 16, 1);
        RETURN;
    END
 
    ------------------------------------------------------------
    -- Generate LOCAL date range (one row per day)
    ------------------------------------------------------------
    ;WITH DateRange AS
    (
        SELECT
            CAST(@from AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone AS DATE) AS report_date_local
 
        UNION ALL
 
        SELECT DATEADD(DAY, 1, report_date_local)
        FROM DateRange
        WHERE report_date_local <
              CAST(DATEADD(DAY, -1, @to) AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone AS DATE)
    ),
 
    ------------------------------------------------------------
    -- Aggregate actual call data by LOCAL date
    ------------------------------------------------------------
    DailyStats AS
    (
        SELECT
            CAST(q.time_start AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone AS DATE)
                AS report_date_local,
 
            COUNT(q.q_num) AS total_calls,
 
            SUM(CASE WHEN q.is_answered = 0 THEN 1 ELSE 0 END)
                AS abandoned_calls,
 
            SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END)
                AS answered_calls,
 
            SUM(CASE WHEN q.is_answered = 1
                     AND DATEDIFF(SECOND, '00:00:00', q.ring_time) <= @sla_seconds
                     THEN 1 ELSE 0 END)
                AS answered_within_sla,
 
            SUM(CASE WHEN q.is_callback = 1 AND q.is_answered = 1 THEN 1 ELSE 0 END)
                AS serviced_callbacks,
 
            SUM(DATEDIFF(SECOND, '00:00:00', q.ts_servicing))
                AS total_talking_sec,
 
            AVG(DATEDIFF(SECOND, '00:00:00', q.ring_time))
                AS avg_wait_sec,
 
            MAX(DATEDIFF(SECOND, '00:00:00', q.ring_time))
                AS max_wait_sec
 
        FROM dbo.queue_view qv
        INNER JOIN dbo.callcent_queuecalls_view q
            ON q.q_num = qv.dn
           AND q.time_start >= @from
           AND q.time_start <  @to
 
        WHERE qv.dn IN (SELECT TRIM(value) FROM STRING_SPLIT(@queue_dns, ','))
 
        GROUP BY
            CAST(q.time_start AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone AS DATE)
    )
 
    ------------------------------------------------------------
    -- Final result (ALL days + data)
    ------------------------------------------------------------
    SELECT
        d.report_date_local,
 
        ISNULL(s.total_calls, 0)        AS total_calls,
        ISNULL(s.abandoned_calls, 0)    AS abandoned_calls,
        ISNULL(s.answered_calls, 0)     AS answered_calls,
 
        CASE WHEN ISNULL(s.total_calls, 0) > 0
             THEN CAST(s.answered_calls * 100.0 / s.total_calls AS DECIMAL(5,2))
             ELSE 0 END                  AS answered_percent,
 
        ISNULL(s.answered_within_sla, 0) AS answered_within_sla,
 
        CASE WHEN ISNULL(s.answered_calls, 0) > 0
             THEN CAST(s.answered_within_sla * 100.0 / s.answered_calls AS DECIMAL(5,2))
             ELSE 0 END                  AS answered_within_sla_percent,
 
        ISNULL(s.serviced_callbacks, 0)  AS serviced_callbacks,
 
        CAST(DATEADD(SECOND, ISNULL(s.total_talking_sec, 0), '00:00:00') AS TIME)
            AS total_talking,
 
        CAST(DATEADD(SECOND,
            CASE WHEN ISNULL(s.answered_calls,0) > 0
                 THEN s.total_talking_sec / s.answered_calls
                 ELSE 0 END,
            '00:00:00') AS TIME)
            AS mean_talking_time,
 
        CAST(DATEADD(SECOND, ISNULL(s.avg_wait_sec, 0), '00:00:00') AS TIME)
            AS avg_wait_time,
 
        CAST(DATEADD(SECOND, ISNULL(s.max_wait_sec, 0), '00:00:00') AS TIME)
            AS longest_wait_time,
 
        @from AS period_from_utc,
        @to   AS period_to_utc,
 
        @from AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone
            AS period_from_local,
 
        @to AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone
            AS period_to_local,
 
        @report_timezone AS report_timezone_used
 
    FROM DateRange d
    LEFT JOIN DailyStats s
        ON d.report_date_local = s.report_date_local
 
    ORDER BY d.report_date_local
    OPTION (MAXRECURSION 1000);
 
END
GO

--EXEC [dbo].[sp_queue_stats_daily_summary] 

--    @from            = '2026-02-02 00:00:00 +00:00',

--    @to              = '2026-02-18 00:00:00 +00:00',

--    @queue_dns       = '8114',

--    @report_timezone = 'India Standard Time';
 