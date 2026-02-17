USE [3CX Exporter]
GO
 
/****** Object:  StoredProcedure [dbo].[sp_rpt__extension_statistics_cdr_united_today]    Script Date: 09-02-2026 03:21:02 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE   PROCEDURE [dbo].[sp_rpt__extension_statistics_cdr_united_today]
(
    @period_from DATETIME2(3),
    @period_to   DATETIME2(3),
    @call_area   INT,
    @include_queue_calls BIT,
    @wait_interval TIME(0),
    @members     VARCHAR(MAX) = '',
    @observers   VARCHAR(MAX) = ''
)
AS
BEGIN
    SET NOCOUNT ON;
 
    ------------------------------------------------------
    -- Temp Tables to store SP Results
    ------------------------------------------------------
    CREATE TABLE #cdr_stats
    (
        dn VARCHAR(50),
        display_name NVARCHAR(255),
        inbound_answered_count INT,
        inbound_unanswered_count INT,
        outbound_answered_count INT,
        outbound_unanswered_count INT,
        inbound_answered_talking_dur FLOAT,
        outbound_answered_talking_dur FLOAT
    );
 
    CREATE TABLE #cl_stats
    (
        dn VARCHAR(50),
        display_name NVARCHAR(255),
        inbound_answered_count INT,
        inbound_unanswered_count INT,
        outbound_answered_count INT,
        outbound_unanswered_count INT,
        inbound_answered_talking_dur FLOAT,
        outbound_answered_talking_dur FLOAT
    );
 
    ------------------------------------------------------
    -- Call Converted Stored Procedures
    ------------------------------------------------------
    INSERT INTO #cdr_stats
    EXEC dbo.sp_rpt_extension_statistics_cdr
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval,
        @members, @observers;
 
    INSERT INTO #cl_stats
    EXEC dbo.sp_cl_get_extension_statistics
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval,
        @members, @observers;
 
    ------------------------------------------------------
    -- Combine Both Result Sets
    ------------------------------------------------------
    WITH combined AS
    (
        SELECT * FROM #cdr_stats
        UNION ALL
        SELECT * FROM #cl_stats
    ),
    agg AS
    (
        SELECT
            dn,
            display_name,
 
            SUM(ISNULL(inbound_answered_count,   0)) AS inbound_answered,
            SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,
 
            SUM(ISNULL(outbound_answered_count,  0)) AS outbound_answered,
            SUM(ISNULL(outbound_unanswered_count,0)) AS outbound_unanswered,
 
            SUM(
                ISNULL(inbound_answered_talking_dur, 0)
              + ISNULL(outbound_answered_talking_dur, 0)
            ) AS total_talking_seconds
 
        FROM combined
        GROUP BY dn, display_name
    )
 
    ------------------------------------------------------
    -- Final Output (Same as TVF)
    ------------------------------------------------------
    SELECT
        a.dn AS [Agent Extension],
        a.display_name AS [Name],
 
        a.inbound_answered   AS [Inbound Answered],
        a.inbound_unanswered AS [Inbound Unanswered],
 
        CAST(
            100.0 * a.inbound_answered 
            / NULLIF(a.inbound_answered + a.inbound_unanswered, 0)
        AS DECIMAL(5,2)) AS [Inbound Answered %],
 
        CAST(
            100.0 * a.inbound_unanswered 
            / NULLIF(a.inbound_answered + a.inbound_unanswered, 0)
        AS DECIMAL(5,2)) AS [Inbound Abandoned %],
 
        a.outbound_answered   AS [Outbound Answered],
        a.outbound_unanswered AS [Outbound Unanswered],
 
        CAST(
            100.0 * a.outbound_answered 
            / NULLIF(a.outbound_answered + a.outbound_unanswered, 0)
        AS DECIMAL(5,2)) AS [Outbound Answered %],
 
        CAST(
            100.0 * a.outbound_unanswered 
            / NULLIF(a.outbound_answered + a.outbound_unanswered, 0)
        AS DECIMAL(5,2)) AS [Outbound Abandoned %],
 
        (a.inbound_answered + a.outbound_answered) AS [Total Answered],
 
        (a.inbound_unanswered + a.outbound_unanswered) AS [Total Unanswered],
 
        CAST(
            100.0 * (a.inbound_answered + a.outbound_answered)
            / NULLIF(
                (a.inbound_answered + a.outbound_answered) +
                (a.inbound_unanswered + a.outbound_unanswered), 0
            )
        AS DECIMAL(5,2)) AS [Total Answered %],
 
        CAST(
            100.0 * (a.inbound_unanswered + a.outbound_unanswered)
            / NULLIF(
                (a.inbound_answered + a.outbound_answered) +
                (a.inbound_unanswered + a.outbound_unanswered), 0
            )
        AS DECIMAL(5,2)) AS [Total Abandoned %],
 
        RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.total_talking_seconds, 0), 108), 8)
            AS [Total Talking]
 
    FROM agg a
    ORDER BY a.dn;
 
END;
GO