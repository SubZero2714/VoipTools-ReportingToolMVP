/*
 * Queue Dashboard - Parameterized SQL Functions
 * Purpose: Provide pre-calculated data for DevExpress Report Designer
 * 
 * These functions accept StartDate and EndDate parameters,
 * allowing users to filter the dashboard by date range.
 * 
 * Created: January 7, 2026
 * Database: Test_3CX_Exporter
 */

-- =====================================================
-- FUNCTION 1: KPI Summary (returns 1 row with all KPIs)
-- =====================================================
IF OBJECT_ID('fn_QueueDashboard_KPIs', 'IF') IS NOT NULL 
    DROP FUNCTION fn_QueueDashboard_KPIs;
GO

CREATE FUNCTION fn_QueueDashboard_KPIs
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Call Counts
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN reason_noanswercode IN (2, 3) THEN 1 ELSE 0 END) AS AbandonedCalls,
        SUM(CASE WHEN reason_failcode = 1 THEN 1 ELSE 0 END) AS MissedCalls,
        
        -- Time Metrics (in seconds for calculations)
        ISNULL(AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0) AS AvgWaitSeconds,
        ISNULL(MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0) AS MaxWaitSeconds,
        ISNULL(AVG(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
            THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) END), 0) AS AvgTalkSeconds,
        ISNULL(MAX(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
            THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) END), 0) AS MaxTalkSeconds,
        
        -- Time Metrics (formatted as HH:MM:SS strings for display)
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 0), 108) AS AvgWaitTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 0), 108) AS MaxWaitTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(AVG(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
                THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) END), 0), 0), 108) AS AvgTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(MAX(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
                THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) END), 0), 0), 108) AS MaxTalkTime,
        
        -- SLA Percentages (answered within 30/60 seconds)
        CAST(ISNULL(
            SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
                AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 30 THEN 1 ELSE 0 END) * 100.0 
            / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5,2)) AS SLA30Percent,
        CAST(ISNULL(
            SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 
                AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 60 THEN 1 ELSE 0 END) * 100.0 
            / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5,2)) AS SLA60Percent,
        
        -- Answer Rate Percentage
        CAST(ISNULL(
            SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 THEN 1 ELSE 0 END) * 100.0 
            / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5,2)) AS AnswerRatePercent
        
    FROM [dbo].[callcent_queuecalls]
    WHERE [time_start] >= @StartDate 
      AND [time_start] < DATEADD(DAY, 1, @EndDate)
);
GO

-- =====================================================
-- FUNCTION 2: Agent Performance (returns 1 row per agent)
-- =====================================================
IF OBJECT_ID('fn_QueueDashboard_Agents', 'IF') IS NOT NULL 
    DROP FUNCTION fn_QueueDashboard_Agents;
GO

CREATE FUNCTION fn_QueueDashboard_Agents
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Agent Identification
        c.to_dn AS AgentExtension,
        ISNULL(u.firstname + ' ' + u.lastname, 'Unknown') AS AgentName,
        CONCAT(c.to_dn, ' - ', ISNULL(u.firstname + ' ' + u.lastname, 'Unknown')) AS Agent,
        
        -- Call Counts
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 THEN 1 ELSE 0 END) AS AnsweredCalls,
        
        -- Time Metrics (formatted)
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(AVG(CASE WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
                THEN DATEDIFF(SECOND, '00:00:00', c.ts_waiting) END), 0), 0), 108) AS AvgAnswerTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(AVG(CASE WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
                THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) END), 0), 0), 108) AS AvgTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(SUM(CASE WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
                THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) ELSE 0 END), 0), 0), 108) AS TotalTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            ISNULL(SUM(DATEDIFF(SECOND, '00:00:00', c.ts_waiting)), 0), 0), 108) AS QueueTime,
        
        -- In Queue Percentage
        CAST(COUNT(*) * 100.0 / NULLIF(
            (SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
             WHERE [time_start] >= @StartDate 
               AND [time_start] < DATEADD(DAY, 1, @EndDate)
               AND to_dn IS NOT NULL), 0
        ) AS DECIMAL(5,2)) AS InQueuePercent

    FROM [dbo].[callcent_queuecalls] c
    LEFT JOIN [dbo].[dn] d ON c.to_dn = d.value
    LEFT JOIN [dbo].[users] u ON d.iddn = u.fkidextension
    WHERE c.[time_start] >= @StartDate 
      AND c.[time_start] < DATEADD(DAY, 1, @EndDate)
      AND c.to_dn IS NOT NULL
    GROUP BY 
        c.to_dn,
        u.firstname,
        u.lastname
);
GO

-- =====================================================
-- FUNCTION 3: Call Trends (returns 1 row per day for chart)
-- =====================================================
IF OBJECT_ID('fn_QueueDashboard_CallTrends', 'IF') IS NOT NULL 
    DROP FUNCTION fn_QueueDashboard_CallTrends;
GO

CREATE FUNCTION fn_QueueDashboard_CallTrends
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        CAST([time_start] AS DATE) AS CallDate,
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN reason_noanswercode IN (2, 3) THEN 1 ELSE 0 END) AS AbandonedCalls,
        SUM(CASE WHEN reason_failcode = 1 THEN 1 ELSE 0 END) AS MissedCalls
    FROM [dbo].[callcent_queuecalls]
    WHERE [time_start] >= @StartDate 
      AND [time_start] < DATEADD(DAY, 1, @EndDate)
    GROUP BY CAST([time_start] AS DATE)
);
GO

-- =====================================================
-- TEST QUERIES
-- =====================================================
-- Test KPIs for all data:
-- SELECT * FROM fn_QueueDashboard_KPIs('2023-01-01', '2025-12-31');

-- Test Agents for all data:
-- SELECT * FROM fn_QueueDashboard_Agents('2023-01-01', '2025-12-31') ORDER BY TotalCalls DESC;

-- Test Call Trends:
-- SELECT * FROM fn_QueueDashboard_CallTrends('2024-01-01', '2024-12-31') ORDER BY CallDate;

PRINT 'All Queue Dashboard functions created successfully!';
GO
