-- =====================================================
-- Agent Performance Table SP - Senior's Original Query
-- Returns agent-level statistics by queue for Agent Table
-- =====================================================
-- Server: 3.132.72.134 | Database: 3CX Exporter
-- =====================================================

CREATE OR ALTER PROCEDURE [dbo].[qcall_cent_get_extensions_statistics_by_queues]
(
    @period_from      DATETIMEOFFSET,
    @period_to        DATETIMEOFFSET,
    @queue_dns        VARCHAR(MAX),   -- comma-separated queue DNs
    @wait_interval    VARCHAR(8) = '00:00:20'  -- HH:MM:SS format string (VARCHAR so DevExpress Designer allows Expression binding)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Convert VARCHAR to TIME internally for comparison
    DECLARE @wait_time TIME = CAST(@wait_interval AS TIME);

    -- CTE 1: Get all qualifying calls from queue
    ;WITH queue_all_calls AS
    (
        SELECT
            qcv.q_num AS queue_dn,
            qcv.to_dn AS extension_dn,
            qcv.ts_servicing,
            qcv.is_answered,
            qcv.call_history_id,

            DATEDIFF(SECOND, 0, qcv.ring_time) AS ring_seconds,
            DATEDIFF(SECOND, 0, qcv.ts_servicing) AS talk_seconds

        FROM CallCent_QueueCalls_View qcv WITH (NOLOCK)
        WHERE
            qcv.time_start BETWEEN @period_from AND @period_to
            AND (@queue_dns = '' OR @queue_dns IS NULL OR qcv.q_num IN (
                SELECT LTRIM(value)
                FROM string_split(@queue_dns, ',')
            ))
            AND (qcv.is_answered = 1 OR qcv.ring_time >= @wait_time)
    ),

    -- CTE 2: Count total received calls per queue
    queue_received_calls AS
    (
        SELECT queue_dn, COUNT(*) AS received_count
        FROM queue_all_calls
        GROUP BY queue_dn
    ),

    -- CTE 3: Agent-level answered call statistics
    extension_answered AS
    (
        SELECT
            queue_dn,
            extension_dn,
            COUNT(*) AS answered_count,
            SUM(talk_seconds) AS total_talk_seconds,
            AVG(CASE WHEN is_answered = 1 THEN ring_seconds END) AS avg_answer_seconds
        FROM queue_all_calls
        WHERE is_answered = 1
        GROUP BY queue_dn, extension_dn
    )

    -- Final SELECT: Join with extensions_by_queues_view for display names
    SELECT
        eqv.queue_dn,
        eqv.queue_display_name,
        eqv.extension_dn,
        eqv.extension_display_name,

        -- Queue received count
        ISNULL(qrc.received_count, 0) AS queue_received_count,
        
        -- Agent answered count
        ISNULL(ea.answered_count, 0) AS extension_answered_count,

        -- Total talk time for agent
        ISNULL(
            CAST(DATEADD(SECOND, ea.total_talk_seconds, 0) AS TIME),
            CAST('00:00:00' AS TIME)
        ) AS talk_time,

        -- Average talk time per call
        ISNULL(
            CAST(
                DATEADD(
                    SECOND,
                    CASE 
                        WHEN ea.answered_count > 0 
                        THEN ea.total_talk_seconds / ea.answered_count 
                        ELSE 0 
                    END,
                0) AS TIME
            ),
            CAST('00:00:00' AS TIME)
        ) AS avg_talk_time,

        -- Average answer/ring time
        ISNULL(
            CAST(DATEADD(SECOND, ea.avg_answer_seconds, 0) AS TIME),
            CAST('00:00:00' AS TIME)
        ) AS avg_answer_time

    FROM extensions_by_queues_view eqv
    LEFT JOIN queue_received_calls qrc 
        ON eqv.queue_dn = qrc.queue_dn
    LEFT JOIN extension_answered ea 
        ON eqv.queue_dn = ea.queue_dn 
        AND eqv.extension_dn = ea.extension_dn

    WHERE (@queue_dns = '' OR @queue_dns IS NULL OR eqv.queue_dn IN (
        SELECT LTRIM(value)
        FROM string_split(@queue_dns, ',')
    ))

    ORDER BY eqv.queue_dn, eqv.extension_dn;

END;
GO

-- =====================================================
-- TEST QUERY
-- =====================================================
-- EXEC dbo.[qcall_cent_get_extensions_statistics_by_queues]
--     @period_from = '2026-02-01 00:00:00',
--     @period_to = '2026-02-09 23:59:59',
--     @queue_dns = '8000,8089',
--     @wait_interval = '00:00:05';