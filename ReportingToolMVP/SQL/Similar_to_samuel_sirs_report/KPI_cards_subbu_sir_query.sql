USE [3CX Exporter]
GO
 
/****** Object:  StoredProcedure [dbo].[sp_queue_stats_summary]    Script Date: 17-02-2026 08:27:34 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
 
CREATE OR ALTER   PROCEDURE [dbo].[sp_queue_stats_summary]
(
    @from            DATETIMEOFFSET = NULL,
    @to              DATETIMEOFFSET = NULL,
    @queue_dns       VARCHAR(MAX)    = NULL,     -- REQUIRED: comma-separated queue DNs (e.g. '800,801,802')
    @sla_seconds     INT             = 20,
    @report_timezone VARCHAR(100)    = NULL      -- e.g. 'India Standard Time', 'UTC', NULL = UTC
)
AS
BEGIN
    SET NOCOUNT ON;
 
    IF @queue_dns IS NULL OR TRIM(@queue_dns) = ''
    BEGIN
        RAISERROR('@queue_dns is required (comma-separated list of queue DNs).', 16, 1);
        RETURN;
    END
 
    -- Default to current UTC day (midnight → midnight UTC)
    SET @from = ISNULL(@from, 
        CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIMEOFFSET)
    );
 
    SET @to = ISNULL(@to, DATEADD(DAY, 1, @from));
 
    -- Optional timezone validation
    IF @report_timezone IS NOT NULL 
       AND @report_timezone NOT IN (SELECT name FROM sys.time_zone_info)
    BEGIN
        RAISERROR('Invalid @report_timezone. Use a valid name from sys.time_zone_info (e.g. ''India Standard Time'', ''UTC'').', 16, 1);
        RETURN;
    END
 
    SELECT
        'SUMMARY'                               AS queue_group,
       @queue_dns                      AS description,
 
        COUNT(q.q_num)                          AS total_calls,
        SUM(CASE WHEN q.is_answered = 0 THEN 1 ELSE 0 END) AS abandoned_calls,
        SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END) AS answered_calls,
 
        CASE WHEN COUNT(q.q_num) > 0 
             THEN CAST(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(q.q_num) AS DECIMAL(5,2))
             ELSE 0.00 END                      AS answered_percent,
 
        SUM(CASE WHEN q.is_answered = 1 
                 AND DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ring_time) <= @sla_seconds 
                 THEN 1 ELSE 0 END)             AS answered_within_sla,
 
        CASE WHEN SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END) > 0 
             THEN CAST(
                 SUM(CASE WHEN q.is_answered = 1 
                          AND DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ring_time) <= @sla_seconds 
                          THEN 1 ELSE 0 END) * 100.0 /
                 SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END) 
                 AS DECIMAL(5,2))
             ELSE 0.00 END                      AS answered_within_sla_percent,
 
        SUM(CASE WHEN q.is_callback = 1 AND q.is_answered = 1 THEN 1 ELSE 0 END) 
                                                AS serviced_callbacks,
 
        CAST(DATEADD(SECOND, 
                     ISNULL(SUM(DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ts_servicing)), 0),
                     CAST('00:00:00' AS TIME)) AS TIME)
                                                AS total_talking,
 
        CAST(DATEADD(SECOND, 
                     CASE WHEN SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END) > 0
                          THEN ISNULL(SUM(DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ts_servicing)), 0) /
                               SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END)
                          ELSE 0 END,
                     CAST('00:00:00' AS TIME)) AS TIME)
                                                AS mean_talking_time,
 
        CAST(DATEADD(SECOND, 
                     ISNULL(AVG(DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ring_time)), 0),
                     CAST('00:00:00' AS TIME)) AS TIME)
                                                AS avg_wait_time,
 
        CAST(DATEADD(SECOND, 
                     ISNULL(MAX(DATEDIFF(SECOND, CAST('00:00:00' AS TIME), q.ring_time)), 0),
                     CAST('00:00:00' AS TIME)) AS TIME)
                                                AS longest_wait_time,
 
        -- Period information
        @from                                   AS period_from_utc,
        @to                                     AS period_to_utc,
 
        CASE WHEN @report_timezone IS NULL 
             THEN @from 
             ELSE @from AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone 
        END                                    AS period_from_local,
 
        CASE WHEN @report_timezone IS NULL 
             THEN @to 
             ELSE @to   AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone 
        END                                    AS period_to_local,
 
        ISNULL(@report_timezone, 'UTC')        AS report_timezone_used
 
    FROM dbo.queue_view qv
    INNER JOIN dbo.callcent_queuecalls_view q
        ON q.q_num = qv.dn
       AND q.time_start >= @from
       AND q.time_start <  @to
    WHERE qv.dn IN (SELECT TRIM(value) FROM STRING_SPLIT(@queue_dns, ','))
    -- No GROUP BY → single aggregated row
 
END
GO


--EXEC [dbo].[sp_queue_stats_summary]
--    @from            = '2026-02-1 00:00:00 +00:00',
--    @to              = '2026-02-17 00:00:00 +00:00',
--    @queue_dns       = '8114,8001,8000',
--	 @sla_seconds    = 20,
--    @report_timezone = 'India Standard Time';