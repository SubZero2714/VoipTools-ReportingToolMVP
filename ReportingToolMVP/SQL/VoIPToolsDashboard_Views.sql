-- =====================================================
-- VoIPTools Dashboard SQL Views
-- Database: Test_3CX_Exporter
-- Purpose: Data sources for VoIPToolsDashboard.repx report
-- Created: February 4, 2026
-- =====================================================

-- =====================================================
-- VIEW 1: vw_QueueKPIs
-- Purpose: Aggregated KPI metrics for dashboard header cards
-- Shows: Total Calls, Answered, Abandoned, SLA, Avg Times
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueKPIs', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueKPIs;
GO

CREATE VIEW dbo.vw_QueueKPIs AS
SELECT
    -- Call Counts
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- Today's calls
    SUM(CASE WHEN CAST(time_start AS DATE) = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) AS CallsToday,
    
    -- SLA Percentages (answered within 20 seconds)
    CASE 
        WHEN COUNT(*) = 0 THEN 0
        ELSE ROUND(
            (CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                           AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                      THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS SLA1Percentage,
    
    -- Answered Percentage
    CASE 
        WHEN COUNT(*) = 0 THEN 0
        ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS AnsweredPercentage,
    
    -- Abandoned Percentage
    CASE 
        WHEN COUNT(*) = 0 THEN 0
        ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS AbandonedPercentage,
    
    -- Average Times (in seconds for formatting)
    AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS AvgTalkTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS MaxTalkTimeSeconds,
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitTimeSeconds,
    
    -- Average Answer Time (wait time for answered calls only)
    AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
        THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
        ELSE NULL END) AS AvgAnswerTimeSeconds,
    
    -- Formatted Times (as strings for display)
    CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS MaxTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS MaxWaitTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
            ELSE NULL END), 0), 108) AS AvgAnswerTime,
    
    -- Date range info
    MIN(CAST(time_start AS DATE)) AS DataStartDate,
    MAX(CAST(time_start AS DATE)) AS DataEndDate,
    GETDATE() AS ReportGeneratedAt

FROM [dbo].[callcent_queuecalls]
-- Note: Using all available data for testing (actual range: Dec 2023 - Oct 2025)
WHERE time_start >= '2023-01-01';
GO

-- =====================================================
-- VIEW 2: vw_QueueAgentPerformance
-- Purpose: Agent-level performance metrics for the table
-- Shows: Agent name, calls handled, times, percentages
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueAgentPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueAgentPerformance;
GO

CREATE VIEW dbo.vw_QueueAgentPerformance AS
SELECT
    COALESCE(to_dn, 'Unknown') AS AgentDN,
    CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
    COUNT(*) AS Calls,
    
    -- Average Answer Time (wait time before pickup)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
            ELSE NULL END), 0), 108) AS AvgAnswer,
    
    -- Average Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk,
    
    -- Total Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TalkTime,
    
    -- Queue Time (total time in queue for this agent's calls)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS QTime,
    
    -- In Queue Percentage (percentage of total calls this agent handled)
    CAST(ROUND(
        (CAST(COUNT(*) AS FLOAT) / 
         NULLIF((SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
                 WHERE time_start >= '2023-01-01'), 0)) * 100, 2
    ) AS VARCHAR(10)) + '%' AS InQPercent,
    
    -- Numeric version for sorting
    ROUND(
        (CAST(COUNT(*) AS FLOAT) / 
         NULLIF((SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
                 WHERE time_start >= '2023-01-01'), 0)) * 100, 2
    ) AS InQPercentValue

FROM [dbo].[callcent_queuecalls]
-- Note: Using all available data for testing (actual range: Dec 2023 - Oct 2025)
WHERE time_start >= '2023-01-01'
  AND to_dn IS NOT NULL
GROUP BY to_dn
GO

-- =====================================================
-- VIEW 3: vw_QueueCallTrends
-- Purpose: Daily call counts for the area chart
-- Shows: Date, Answered, Missed, Abandoned counts
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueCallTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueCallTrends;
GO

CREATE VIEW dbo.vw_QueueCallTrends AS
SELECT
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'MMM d') AS CallDateLabel,
    
    -- Answered Calls (servicing time > 0)
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    
    -- Missed Calls (no answer code present and not serviced)
    SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- Abandoned Calls (not serviced, caller hung up)
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    
    -- Total for the day
    COUNT(*) AS TotalCalls

FROM [dbo].[callcent_queuecalls]
-- Note: Using all available data for testing (actual range: Dec 2023 - Oct 2025)
WHERE time_start >= '2023-01-01'
GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'MMM d')
GO

-- =====================================================
-- VIEW 4: vw_QueueSummary (from user's original query)
-- Purpose: Per-queue summary metrics
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueSummary;
GO

CREATE VIEW dbo.vw_QueueSummary AS
SELECT
    qdetails.qnumber,
    qdetails.name AS QueueName,
    ISNULL(calldetails.total_calls, 0) AS TotalCalls,
    ISNULL(calldetails.not_serviced_calls, 0) AS NotServicedCalls,
    ISNULL(calldetails.serviced_calls, 0) AS ServicedCalls,
    CASE
        WHEN ISNULL(calldetails.total_calls, 0) = 0 THEN 0
        ELSE ROUND((CAST(calldetails.serviced_calls AS FLOAT) / calldetails.total_calls) * 100, 2)
    END AS AnsweredPercentage,
    CASE
        WHEN ISNULL(calldetails.total_calls, 0) = 0 THEN 0
        ELSE ROUND((CAST(calldetails.not_serviced_calls AS FLOAT) / calldetails.total_calls) * 100, 2)
    END AS AbandonedPercentage,
    CASE
        WHEN ISNULL(calldetails.total_calls, 0) = 0 THEN 0
        ELSE ROUND((CAST(calldetails.answered_within_20_sec AS FLOAT) / calldetails.total_calls) * 100, 2)
    END AS AnsweredWithin20Percentage,
    ISNULL(calldetails.total_servicing_seconds, 0) AS TotalServicingSeconds,
    CONVERT(VARCHAR(8), DATEADD(SECOND, ISNULL(calldetails.total_servicing_seconds, 0), 0), 108) AS TotalServicingTime
FROM (
    SELECT  
        d.[iddn],
        d.[value] AS qnumber,
        q.name  
    FROM [dbo].[dn] d
        JOIN [queue] q ON d.[iddn] = q.fkiddn
) AS qdetails
LEFT JOIN (
    SELECT
        q_num AS queue_number,
        COUNT(*) AS total_calls,
        SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS not_serviced_calls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS serviced_calls,
        SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS total_servicing_seconds,
        SUM(
            CASE 
                WHEN ts_servicing != '00:00:00.0000000' 
                     AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                THEN 1 ELSE 0 
            END
        ) AS answered_within_20_sec
    FROM [dbo].[callcent_queuecalls]
    -- Note: Using all available data for testing
    WHERE time_start >= '2023-01-01'
    GROUP BY q_num
) AS calldetails ON qdetails.qnumber = calldetails.queue_number
GO

-- =====================================================
-- VERIFICATION QUERIES
-- Run these to verify views are working
-- =====================================================

-- Test KPIs
-- SELECT * FROM dbo.vw_QueueKPIs;

-- Test Agent Performance
-- SELECT * FROM dbo.vw_QueueAgentPerformance ORDER BY Calls DESC;

-- Test Call Trends
-- SELECT * FROM dbo.vw_QueueCallTrends ORDER BY CallDate;

-- Test Queue Summary
-- SELECT * FROM dbo.vw_QueueSummary ORDER BY qnumber;

PRINT 'All views created successfully!';
PRINT 'Views available:';
PRINT '  - dbo.vw_QueueKPIs (1 row with all KPI metrics)';
PRINT '  - dbo.vw_QueueAgentPerformance (agent-level stats)';
PRINT '  - dbo.vw_QueueCallTrends (daily call counts for chart)';
PRINT '  - dbo.vw_QueueSummary (per-queue summary)';
GO
