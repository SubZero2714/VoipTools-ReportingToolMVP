CREATE OR ALTER PROCEDURE [dbo].[sp_queue_stats_range]
(
    @from DATETIMEOFFSET = NULL,
    @to   DATETIMEOFFSET = NULL,
    @sla_seconds INT = 20   -- SLA threshold (default 20 sec)
)
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Default to current day if not provided
    SET @from = ISNULL(@from, CAST(CAST(SYSDATETIMEOFFSET() AS DATE) AS DATETIMEOFFSET));
    SET @to   = ISNULL(@to, DATEADD(DAY, 1, @from));
 
    SELECT 
        qv.dn AS queue_dn,
        qv.display_name AS queue_display_name,
 
        -- Total Calls
        COUNT(q.q_num) AS total_calls,
 
        -- Abandoned Calls
        ISNULL(SUM(CASE WHEN q.is_answered = 0 THEN 1 ELSE 0 END), 0) AS abandoned_calls,
 
        -- Answered Calls
        ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 0) AS answered_calls,
 
        -- Answered %
        CASE 
            WHEN COUNT(q.q_num) > 0 
            THEN CAST(
                ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 0) 
                * 100.0 / COUNT(q.q_num) 
            AS DECIMAL(5,2))
            ELSE 0 
        END AS answered_percent,
 
        -- SLA Answered Calls
        ISNULL(SUM(
            CASE 
                WHEN q.is_answered = 1 
                 AND DATEDIFF(SECOND, '00:00:00', q.ring_time) <= @sla_seconds 
                THEN 1 ELSE 0 
            END
        ), 0) AS answered_within_sla,
 
        -- SLA Answered %
        CASE 
            WHEN ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 0) > 0
            THEN CAST(
                ISNULL(SUM(
                    CASE 
                        WHEN q.is_answered = 1 
                         AND DATEDIFF(SECOND, '00:00:00', q.ring_time) <= @sla_seconds 
                        THEN 1 ELSE 0 
                    END
                ), 0) * 100.0 
                / ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,2))
            ELSE 0 
        END AS answered_within_sla_percent,
 
        -- Serviced Callbacks
        ISNULL(SUM(CASE WHEN q.is_callback = 1 AND q.is_answered = 1 THEN 1 ELSE 0 END), 0) AS serviced_callbacks,
 
        -- Total Talking Time
        CAST(
            DATEADD(SECOND, 
                ISNULL(SUM(DATEDIFF(SECOND, '00:00:00', q.ts_servicing)), 0), 
            '00:00:00') AS TIME
        ) AS total_talking,
 
        -- Mean Talking Time
        CAST(
            DATEADD(SECOND, 
                CASE 
                    WHEN ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 0) > 0
                    THEN ISNULL(SUM(DATEDIFF(SECOND, '00:00:00', q.ts_servicing)), 0) 
                         / ISNULL(SUM(CASE WHEN q.is_answered = 1 THEN 1 ELSE 0 END), 1)
                    ELSE 0 
                END,
            '00:00:00') AS TIME
        ) AS mean_talking,
 
        -- Avg Wait Time
        CAST(
            DATEADD(SECOND,
                ISNULL(AVG(CASE 
                    WHEN q.q_num IS NOT NULL 
                    THEN DATEDIFF(SECOND, '00:00:00', q.ring_time)
                END), 0),
            '00:00:00') AS TIME
        ) AS avg_wait_time,
 
        -- Longest Wait Time
        CAST(
            DATEADD(SECOND,
                ISNULL(MAX(CASE 
                    WHEN q.q_num IS NOT NULL 
                    THEN DATEDIFF(SECOND, '00:00:00', q.ring_time)
                END), 0),
            '00:00:00') AS TIME
        ) AS longest_wait_time,
 
        -- Show period range in output
        @from AS period_from,
        @to   AS period_to
 
    FROM dbo.queue_view qv
    LEFT JOIN dbo.callcent_queuecalls_view q 
        ON q.q_num = qv.dn
        AND q.time_start >= @from 
        AND q.time_start < @to
 
    GROUP BY 
        qv.dn,
        qv.display_name
 
    ORDER BY 
        qv.dn;
END;