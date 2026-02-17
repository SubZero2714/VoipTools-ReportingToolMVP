-- =====================================================
-- KPI Summary SP - Returns a SINGLE aggregated row across all selected queues
-- Based EXACTLY on qcall_cent_get_extensions_statistics_by_queues logic
-- =====================================================
-- Server: 3.132.72.134 | Database: 3CX Exporter
-- =====================================================
-- CHANGE LOG:
--   v1: One row per queue (GROUP BY queue_dn) — broke KPI cards for multi-queue input
--   v2: Single aggregated row — works for single AND multi-queue input
--       Added WITH (NOLOCK) for faster reads
-- =====================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_queue_kpi_summary_shushant]
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
    ),

    queue_names AS (
        SELECT DISTINCT 
            queue_dn,
            queue_display_name
        FROM extensions_by_queues_view WITH (NOLOCK)
        WHERE (
            @queue_dns = '' 
            OR @queue_dns IS NULL 
            OR queue_dn IN (SELECT LTRIM(value) FROM string_split(@queue_dns, ','))
        )
    )

    -- Aggregate across ALL selected queues into a SINGLE row
    -- v2: Removed GROUP BY queue_dn so KPI cards always get exactly 1 row
    SELECT
        @queue_dns AS queue_dn,
        
        CASE 
            WHEN COUNT(DISTINCT qn.queue_dn) = 1 THEN MIN(qn.queue_display_name)
            WHEN COUNT(DISTINCT qn.queue_dn) > 1 THEN 'Multiple Queues (' + CAST(COUNT(DISTINCT qn.queue_dn) AS VARCHAR(10)) + ')'
            ELSE '-'
        END AS queue_display_name,
        
        COUNT(*) AS total_calls,
        
        SUM(CASE WHEN qac.is_answered = 0 THEN 1 ELSE 0 END) AS abandoned_calls,
        
        SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END) AS answered_calls,
        
        CAST(
            CASE WHEN COUNT(*) > 0 
            THEN SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
            ELSE 0 END 
        AS DECIMAL(5,2)) AS answered_percent,
        
        SUM(qac.is_within_sla) AS answered_within_sla,
        
        CAST(
            CASE WHEN SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END) > 0 
            THEN SUM(qac.is_within_sla) * 100.0 / SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END)
            ELSE 0 END 
        AS DECIMAL(5,2)) AS answered_within_sla_percent,
        
        0 AS serviced_callbacks,
        
        ISNULL(
            CAST(DATEADD(SECOND, SUM(CASE WHEN qac.is_answered = 1 THEN qac.talk_seconds ELSE 0 END), 0) AS TIME),
            CAST('00:00:00' AS TIME)
        ) AS total_talking,
        
        ISNULL(
            CAST(DATEADD(SECOND, 
                CASE WHEN SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END) > 0 
                THEN SUM(CASE WHEN qac.is_answered = 1 THEN qac.talk_seconds ELSE 0 END) / SUM(CASE WHEN qac.is_answered = 1 THEN 1 ELSE 0 END)
                ELSE 0 END, 0) AS TIME),
            CAST('00:00:00' AS TIME)
        ) AS mean_talking,
        
        ISNULL(
            CAST(DATEADD(SECOND, 
                AVG(CASE WHEN qac.is_answered = 1 THEN qac.ring_seconds END), 0) AS TIME),
            CAST('00:00:00' AS TIME)
        ) AS avg_waiting

    FROM queue_all_calls qac
    INNER JOIN queue_names qn ON qac.queue_dn = qn.queue_dn;
    -- NO GROUP BY → always returns exactly 1 aggregated row

END;
GO

-- =====================================================
-- TEST QUERIES
-- =====================================================
-- Single queue:
-- EXEC dbo.[sp_queue_kpi_summary_shushant]
--     @period_from = '2025-06-01 00:00:00',
--     @period_to = '2026-02-12 23:59:59',
--     @queue_dns = '8000',
--     @wait_interval = '00:00:20';
--
-- Multiple queues:
-- EXEC dbo.[sp_queue_kpi_summary_shushant]
--     @period_from = '2025-06-01 00:00:00',
--     @period_to = '2026-02-12 23:59:59',
--     @queue_dns = '8000,8089',
--     @wait_interval = '00:00:20';
