ALTER PROCEDURE [dbo].[sp_rpt__extension_statistics_cdr_united_today]
(
    @period_from DATETIME2(3),
    @period_to   DATETIME2(3),
    @call_area   INT = 0,
    @include_queue_calls BIT = 1,
    @wait_interval TIME(0) = '00:00:20',
    @members     VARCHAR(MAX) = '',
    @observers   VARCHAR(MAX) = ''
)
AS
BEGIN
    SET NOCOUNT ON;
 
    ------------------------------------------------------
    -- Temp Tables
    ------------------------------------------------------
    CREATE TABLE #cdr_stats
    (
        dn VARCHAR(50),
        display_name NVARCHAR(255),
        inbound_answered_count INT DEFAULT 0,
        inbound_unanswered_count INT DEFAULT 0,
        outbound_answered_count INT DEFAULT 0,
        outbound_unanswered_count INT DEFAULT 0,
        inbound_answered_talking_dur FLOAT DEFAULT 0,
        outbound_answered_talking_dur FLOAT DEFAULT 0
    );
 
    CREATE TABLE #cl_stats
    (
        dn VARCHAR(50),
        display_name NVARCHAR(255),
        inbound_answered_count INT DEFAULT 0,
        inbound_unanswered_count INT DEFAULT 0,
        outbound_answered_count INT DEFAULT 0,
        outbound_unanswered_count INT DEFAULT 0,
        inbound_answered_talking_dur FLOAT DEFAULT 0,
        outbound_answered_talking_dur FLOAT DEFAULT 0
    );
 
    ------------------------------------------------------
    -- Load Data
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
    -- Combine + Aggregate
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
 
            SUM(ISNULL(inbound_answered_count, 0)) AS inbound_answered,
            SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,
 
            SUM(ISNULL(outbound_answered_count, 0)) AS outbound_answered,
            SUM(ISNULL(outbound_unanswered_count, 0)) AS outbound_unanswered,
 
            SUM(ISNULL(inbound_answered_talking_dur, 0)) AS inbound_talk,
            SUM(ISNULL(outbound_answered_talking_dur, 0)) AS outbound_talk,
 
            SUM(ISNULL(inbound_answered_talking_dur, 0) 
              + ISNULL(outbound_answered_talking_dur, 0)) AS total_talk
        FROM combined
        GROUP BY dn, display_name
    )
 
    ------------------------------------------------------
    -- Final Output
    ------------------------------------------------------
    SELECT
        a.dn AS [Agent Extension],
        a.display_name AS [Name],
 
        ISNULL(a.inbound_answered, 0) AS [Inbound Answered],
        ISNULL(a.inbound_unanswered, 0) AS [Inbound Unanswered],
 
        CAST(
            CASE 
                WHEN (a.inbound_answered + a.inbound_unanswered) = 0 THEN 0
                ELSE 100.0 * a.inbound_answered 
                     / (a.inbound_answered + a.inbound_unanswered)
            END
        AS DECIMAL(5,2)) AS [Inbound Answered %],
 
        CAST(
            CASE 
                WHEN (a.inbound_answered + a.inbound_unanswered) = 0 THEN 0
                ELSE 100.0 * a.inbound_unanswered 
                     / (a.inbound_answered + a.inbound_unanswered)
            END
        AS DECIMAL(5,2)) AS [Inbound Abandoned %],
 
        ISNULL(a.outbound_answered, 0) AS [Outbound Answered],
        ISNULL(a.outbound_unanswered, 0) AS [Outbound Unanswered],
 
        CAST(
            CASE 
                WHEN (a.outbound_answered + a.outbound_unanswered) = 0 THEN 0
                ELSE 100.0 * a.outbound_answered 
                     / (a.outbound_answered + a.outbound_unanswered)
            END
        AS DECIMAL(5,2)) AS [Outbound Answered %],
 
        CAST(
            CASE 
                WHEN (a.outbound_answered + a.outbound_unanswered) = 0 THEN 0
                ELSE 100.0 * a.outbound_unanswered 
                     / (a.outbound_answered + a.outbound_unanswered)
            END
        AS DECIMAL(5,2)) AS [Outbound Abandoned %],
 
        (ISNULL(a.inbound_answered, 0) + ISNULL(a.outbound_answered, 0)) AS [Total Answered],
        (ISNULL(a.inbound_unanswered, 0) + ISNULL(a.outbound_unanswered, 0)) AS [Total Unanswered],
 
        CAST(
            CASE 
                WHEN ((a.inbound_answered + a.outbound_answered) + 
                      (a.inbound_unanswered + a.outbound_unanswered)) = 0 THEN 0
                ELSE 100.0 * (a.inbound_answered + a.outbound_answered)
                     / ((a.inbound_answered + a.outbound_answered) + 
                        (a.inbound_unanswered + a.outbound_unanswered))
            END
        AS DECIMAL(5,2)) AS [Total Answered %],
 
        CAST(
            CASE 
                WHEN ((a.inbound_answered + a.outbound_answered) + 
                      (a.inbound_unanswered + a.outbound_unanswered)) = 0 THEN 0
                ELSE 100.0 * (a.inbound_unanswered + a.outbound_unanswered)
                     / ((a.inbound_answered + a.outbound_answered) + 
                        (a.inbound_unanswered + a.outbound_unanswered))
            END
        AS DECIMAL(5,2)) AS [Total Abandoned %],
 
        RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, ISNULL(a.total_talk, 0), 0), 108), 8)
            AS [Total Talking]
 
    FROM agg a
    ORDER BY a.dn;
END;
GO