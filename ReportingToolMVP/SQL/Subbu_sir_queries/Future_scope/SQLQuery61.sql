USE [3CX Exporter]
GO
/****** Object:  StoredProcedure [dbo].[call_cent_get_extensions_statistics_by_queues]    Script Date: 09-02-2026 07:55:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROCEDURE [dbo].[call_cent_get_extensions_statistics_by_queues]
(
    @period_from      DATETIMEOFFSET,
    @period_to        DATETIMEOFFSET,
    @queue_dns        VARCHAR(MAX),   -- space-separated queue DNs
    @wait_interval    TIME
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
            qcv.call_history_id
        FROM CallCent_QueueCalls_View qcv
        WHERE
            qcv.time_start BETWEEN @period_from AND @period_to
            AND qcv.q_num IN (SELECT value FROM string_split(@queue_dns, ' '))
            AND (qcv.is_answered = 1 OR qcv.ring_time >= @wait_interval)
    ),
 
    queue_received_calls AS
    (
        SELECT
            queue_dn,
            COUNT(*) AS received_count
        FROM queue_all_calls
        GROUP BY queue_dn
    ),
 
    extension_answered AS
    (
        SELECT
            queue_dn,
            extension_dn,
            COUNT(*) AS answered_count,
            CAST(DATEADD(SECOND, SUM(DATEDIFF(SECOND, 0, ts_servicing)), 0) AS TIME) AS talking_time
        FROM queue_all_calls
        WHERE is_answered = 1
        GROUP BY queue_dn, extension_dn
    )
 
    SELECT
        eqv.queue_dn,
        eqv.queue_display_name,
        eqv.extension_dn,
        eqv.extension_display_name,
        ISNULL(qrc.received_count, 0) AS queue_received_count,
        ISNULL(ea.answered_count, 0) AS extension_answered_count,
       -- ISNULL(ed.dropped_count, 0) AS extension_dropped_count,
      --  ea.talking_time AS talk_time
		 ISNULL(ea.talking_time, CAST('00:00:00' AS TIME)) AS talk_time
    FROM extensions_by_queues_view eqv
    LEFT JOIN queue_received_calls qrc 
        ON eqv.queue_dn = qrc.queue_dn
    LEFT JOIN extension_answered ea 
        ON eqv.queue_dn = ea.queue_dn 
        AND eqv.extension_dn = ea.extension_dn
		WHERE eqv.queue_dn IN (SELECT value FROM string_split(@queue_dns, ' '))
    ORDER BY eqv.queue_dn, eqv.extension_dn;
END;