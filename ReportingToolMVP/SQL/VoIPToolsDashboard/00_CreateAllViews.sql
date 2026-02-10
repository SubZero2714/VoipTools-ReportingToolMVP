-- =====================================================
-- VoIPTools Dashboard - Master SQL Setup Script
-- Database: Test_3CX_Exporter
-- Purpose: Creates all views required for VoIPToolsDashboard.repx
-- Created: February 4, 2026
-- 
-- USAGE:
--   sqlcmd -S "YOUR_SERVER" -d "YOUR_DATABASE" -i "00_CreateAllViews.sql"
-- =====================================================

USE Test_3CX_Exporter;
GO

PRINT '============================================';
PRINT 'VoIPTools Dashboard - Creating SQL Views';
PRINT '============================================';
PRINT '';

-- =====================================================
-- VIEW 1: vw_QueueKPIs
-- Purpose: Aggregated KPI metrics for dashboard header cards
-- Returns: 1 row with all metrics
-- Used by: dsKPIs data source → KPI Cards
-- =====================================================
PRINT 'Creating view: vw_QueueKPIs...';

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
    
    -- Today's calls (for comparison)
    SUM(CASE WHEN CAST(time_start AS DATE) = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) AS CallsToday,
    
    -- SLA Percentage (answered within 20 seconds)
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
    
    -- Average Times (in seconds for calculations)
    AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS AvgTalkTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS MaxTalkTimeSeconds,
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitTimeSeconds,
    
    -- Formatted Times (as HH:MM:SS strings for display)
    CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS MaxTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS MaxWaitTime,
    
    -- Metadata
    MIN(CAST(time_start AS DATE)) AS DataStartDate,
    MAX(CAST(time_start AS DATE)) AS DataEndDate,
    GETDATE() AS ReportGeneratedAt

FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01';  -- Adjust date range as needed
GO

PRINT '  ✓ vw_QueueKPIs created';
PRINT '';

-- =====================================================
-- VIEW 2: vw_QueueAgentPerformance
-- Purpose: Agent-level performance metrics
-- Returns: 1 row per agent, ordered by calls handled
-- Used by: dsAgents data source → Agent Performance Table
-- =====================================================
PRINT 'Creating view: vw_QueueAgentPerformance...';

IF OBJECT_ID('dbo.vw_QueueAgentPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueAgentPerformance;
GO

CREATE VIEW dbo.vw_QueueAgentPerformance AS
SELECT
    -- Agent Identifier
    COALESCE(to_dn, 'Unknown') AS AgentDN,
    CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
    
    -- Call Count
    COUNT(*) AS Calls,
    
    -- Average Answer Time (wait time for answered calls)
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
    
    -- Total Queue Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS QTime,
    
    -- Percentage of total calls handled by this agent
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
WHERE time_start >= '2023-01-01'
  AND to_dn IS NOT NULL  -- Only include agents who answered
GROUP BY to_dn;
GO

PRINT '  ✓ vw_QueueAgentPerformance created';
PRINT '';

-- =====================================================
-- VIEW 3: vw_QueueCallTrends
-- Purpose: Daily call counts for trend chart
-- Returns: 1 row per day, ordered by date
-- Used by: dsTrends data source → Call Trends Chart
-- =====================================================
PRINT 'Creating view: vw_QueueCallTrends...';

IF OBJECT_ID('dbo.vw_QueueCallTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueCallTrends;
GO

CREATE VIEW dbo.vw_QueueCallTrends AS
SELECT
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'MMM d') AS CallDateLabel,  -- "Jan 15" format for chart X-axis
    
    -- Daily Counts
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL 
             AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    COUNT(*) AS TotalCalls
    
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'MMM d');
GO

PRINT '  ✓ vw_QueueCallTrends created';
PRINT '';

-- =====================================================
-- VIEW 4: vw_QueueSummary
-- Purpose: Per-queue breakdown (optional, for detailed reports)
-- Returns: 1 row per queue
-- Used by: Queue-specific reports
-- =====================================================
PRINT 'Creating view: vw_QueueSummary...';

IF OBJECT_ID('dbo.vw_QueueSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueSummary;
GO

CREATE VIEW dbo.vw_QueueSummary AS
SELECT
    q_num AS QueueNumber,
    COALESCE(q_name, CONCAT('Queue ', q_num)) AS QueueName,
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    
    -- Answer Rate
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(
            CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) 
            / COUNT(*) * 100, 1)
    END AS AnswerRatePercent,
    
    -- Average Wait Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
    
    -- Average Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime
    
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
GROUP BY q_num, q_name;
GO

PRINT '  ✓ vw_QueueSummary created';
PRINT '';

-- =====================================================
-- VERIFICATION
-- =====================================================
PRINT '============================================';
PRINT 'Verifying views...';
PRINT '============================================';
PRINT '';

-- Test each view
SELECT 'vw_QueueKPIs' AS ViewName, 
       TotalCalls, AnsweredCalls, AbandonedCalls, SLA1Percentage 
FROM vw_QueueKPIs;

SELECT 'vw_QueueAgentPerformance' AS ViewName, 
       COUNT(*) AS AgentCount 
FROM vw_QueueAgentPerformance;

SELECT 'vw_QueueCallTrends' AS ViewName, 
       COUNT(*) AS DayCount,
       MIN(CallDate) AS FirstDate,
       MAX(CallDate) AS LastDate
FROM vw_QueueCallTrends;

SELECT 'vw_QueueSummary' AS ViewName, 
       COUNT(*) AS QueueCount 
FROM vw_QueueSummary;

PRINT '';
PRINT '============================================';
PRINT 'All views created successfully!';
PRINT '============================================';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Open https://localhost:7209/reportdesigner';
PRINT '2. Load VoIPToolsDashboard report';
PRINT '3. Click Preview to see live data';
PRINT '';
GO
