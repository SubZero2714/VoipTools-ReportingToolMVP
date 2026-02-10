USE [3CX Exporter]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_rpt__extension_statistics_cdr_united]    Script Date: 09-02-2026 03:27:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[fn_rpt__extension_statistics_cdr_united]
(
    @period_from         DATETIME2(3),
    @period_to           DATETIME2(3),
    @call_area           INT,
    @include_queue_calls BIT,
    @wait_interval       TIME(0),
    @members             VARCHAR(MAX) = '',
    @observers           VARCHAR(MAX) = ''
)
RETURNS TABLE
AS
RETURN
WITH cdr_stats AS
(
    SELECT *
    FROM dbo.fn_rpt__extension_statistics_cdr(
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval, @members, @observers
    )
),
cl_stats AS
(
    SELECT *
    FROM dbo.cl_get_extension_statistics(
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval, @members, @observers
    )
),
combined AS
(
    SELECT * FROM cdr_stats
    UNION ALL
    SELECT * FROM cl_stats
),
agg AS
(
    SELECT
        dn,
        display_name,
 
        SUM(ISNULL(inbound_answered_count, 0))   AS inbound_answered,
        SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,
 
        SUM(ISNULL(outbound_answered_count, 0))   AS outbound_answered,
        SUM(ISNULL(outbound_unanswered_count, 0)) AS outbound_unanswered,
		SUM(ISNULL(inbound_answered_talking_dur, 0)) AS inbound_answered_talking_dur,
		SUM(ISNULL(outbound_answered_talking_dur, 0)) AS outbound_answered_talking_dur,
        SUM(
            ISNULL(inbound_answered_talking_dur, 0)
          + ISNULL(outbound_answered_talking_dur, 0)
        ) AS total_talking_seconds
 
    FROM combined
    GROUP BY dn, display_name
)
 
--agg AS
--(
--    SELECT
--        dn,
--        display_name,
 
--        SUM(ISNULL(inbound_answered_count, 0))   AS inbound_answered,
--        SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,
 
--        SUM(ISNULL(outbound_answered_count, 0))   AS outbound_answered,
--        SUM(ISNULL(outbound_unanswered_count, 0)) AS outbound_unanswered,
 
--        SUM(ISNULL(inbound_answered_talking_dur, 0)
--          + ISNULL(outbound_answered_talking_dur, 0)) AS total_talking_seconds
--    FROM combined
--    GROUP BY dn, display_name
--)
SELECT
    a.dn            AS [Agent Extension],
    a.display_name  AS [Name],
 
    a.inbound_answered   AS [Inbound Answered],
    a.inbound_unanswered AS [Inbound Unanswered],
 
    a.outbound_answered   AS [Outbound Answered],
    a.outbound_unanswered AS [Outbound Unanswered],
 
    a.inbound_answered + a.outbound_answered
        AS [Total Answered],
 
    a.inbound_unanswered + a.outbound_unanswered
        AS [Total Unanswered],
 
		    RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.inbound_answered_talking_dur, 0), 108), 8)
        AS [Inbound Talking],
   RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.outbound_answered_talking_dur, 0), 108), 8)
        AS [Outbound Talking],
    -- Convert seconds → HH:mm:ss (correct & exact)
    RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.total_talking_seconds, 0), 108), 8)
        AS [Total Talking]
 
FROM agg a;