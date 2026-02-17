-- =====================================================
-- Chart Data SP - Returns daily breakdown aggregated across ALL selected queues
-- Based EXACTLY on qcall_cent_get_extensions_statistics_by_queues logic
-- =====================================================
-- Server: 3.132.72.134 | Database: 3CX Exporter
-- =====================================================
-- CHANGE LOG:
--   v1: One row per queue per date (GROUP BY queue_dn, call_date) — duplicated dates for multi-queue
--   v2: One row per date (GROUP BY call_date only) — correct chart for single AND multi-queue
--       Added WITH (NOLOCK) for faster reads
-- =====================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_queue_calls_by_date_shushant]
(
    @period_from      DATETIMEOFFSET,
    @period_to        DATETIMEOFFSET,
    @queue_dns        VARCHAR(MAX),   -- comma-separated queue DNs (empty = all queues)
    @wait_interval    TIME = '00:00:05'  -- SLA threshold
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH queue_all_calls AS
    (
        SELECT
            qcv.q_num AS queue_dn,
            qcv.to_dn AS extension_dn,
            CAST(qcv.time_start AS DATE) AS call_date,
            qcv.ts_servicing,
            qcv.is_answered,
            qcv.call_history_id,

            DATEDIFF(SECOND, 0, qcv.ring_time) AS ring_seconds,
            DATEDIFF(SECOND, 0, qcv.ts_servicing) AS talk_seconds,
            
            CASE WHEN qcv.is_answered = 1 AND qcv.ring_time <= @wait_interval THEN 1 ELSE 0 END AS is_within_sla

        FROM CallCent_QueueCalls_View qcv WITH (NOLOCK)
        WHERE
            qcv.time_start BETWEEN @period_from AND @period_to
            AND (
                @queue_dns = '' 
                OR @queue_dns IS NULL 
                OR qcv.q_num IN (SELECT LTRIM(value) FROM string_split(@queue_dns, ','))
            )
            AND (qcv.is_answered = 1 OR qcv.ring_time >= @wait_interval)
    )

    -- v2: Aggregate by DATE only (not per-queue) so chart gets one data point per date
    SELECT
        @queue_dns AS queue_dn,
        call_date,
        
        COUNT(*) AS total_calls,
        
        SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END) AS answered_calls,
        
        SUM(CASE WHEN is_answered = 0 THEN 1 ELSE 0 END) AS abandoned_calls,
        
        SUM(is_within_sla) AS answered_within_sla,
        
        CAST(
            CASE WHEN COUNT(*) > 0 
            THEN SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
            ELSE 0 END 
        AS DECIMAL(5,2)) AS answer_rate,
        
        CAST(
            CASE WHEN SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END) > 0 
            THEN SUM(is_within_sla) * 100.0 / SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END)
            ELSE 0 END 
        AS DECIMAL(5,2)) AS sla_percent

    FROM queue_all_calls qac
    GROUP BY call_date
    ORDER BY call_date;

END;
GO

-- =====================================================
-- TEST QUERIES
-- =====================================================
-- Single queue:
-- EXEC dbo.[sp_queue_calls_by_date_shushant]
--     @period_from = '2025-06-01 00:00:00',
--     @period_to = '2026-02-12 23:59:59',
--     @queue_dns = '8000',
--     @wait_interval = '00:00:20';
--
-- Multiple queues:
-- EXEC dbo.[sp_queue_calls_by_date_shushant]
--     @period_from = '2025-06-01 00:00:00',
--     @period_to = '2026-02-12 23:59:59',
--     @queue_dns = '8000,8089',
--     @wait_interval = '00:00:20';
