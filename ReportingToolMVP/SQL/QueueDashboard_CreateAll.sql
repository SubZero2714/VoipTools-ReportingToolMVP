-- =====================================================
-- Queue Dashboard SQL Objects
-- Run this script to create all views/functions needed
-- for the Queue Dashboard report in Report Designer
-- =====================================================

USE [Test_3CX_Exporter]
GO

-- =====================================================
-- 1. VIEW: vw_QueueDashboard_KPIs
-- Returns summary KPIs for a date range
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueDashboard_KPIs', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueDashboard_KPIs
GO

CREATE VIEW dbo.vw_QueueDashboard_KPIs AS
SELECT 
    q_num AS QueueNumber,
    CAST(time_start AS DATE) AS CallDate,
    
    -- Call Counts
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN reason_noanswercode = 0 AND ts_servicing > '00:00:00' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN reason_noanswercode IN (3, 4) THEN 1 ELSE 0 END) AS AbandonedCalls,
    SUM(CASE WHEN reason_noanswercode = 2 THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- Today indicator
    CASE WHEN CAST(time_start AS DATE) = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS IsToday,
    
    -- Time Metrics (in seconds)
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitTimeSec,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitTimeSec,
    AVG(CASE WHEN ts_servicing > '00:00:00' THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) ELSE NULL END) AS AvgTalkTimeSec,
    MAX(CASE WHEN ts_servicing > '00:00:00' THEN DATEDIFF(SECOND, '00:00:00', ts_servicing) ELSE NULL END) AS MaxTalkTimeSec,
    
    -- SLA (answered within 20 seconds)
    SUM(CASE WHEN reason_noanswercode = 0 AND ts_servicing > '00:00:00' AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 THEN 1 ELSE 0 END) AS SLAMetCalls,
    
    -- Polls/Dialed
    SUM(count_polls) AS TotalPolls,
    SUM(count_dialed) AS TotalDialed,
    SUM(count_rejected) AS TotalRejected
FROM dbo.callcent_queuecalls
GROUP BY q_num, CAST(time_start AS DATE)
GO

-- =====================================================
-- 2. VIEW: vw_QueueDashboard_AgentPerformance
-- Returns agent-level metrics
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueDashboard_AgentPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueDashboard_AgentPerformance
GO

CREATE VIEW dbo.vw_QueueDashboard_AgentPerformance AS
SELECT 
    c.q_num AS QueueNumber,
    CAST(c.time_start AS DATE) AS CallDate,
    c.to_dn AS AgentExtension,
    COALESCE(u.firstname + ' ' + u.lastname, 'Ext ' + c.to_dn) AS AgentName,
    
    -- Call Counts
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN c.reason_noanswercode = 0 AND c.ts_servicing > '00:00:00' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN c.reason_noanswercode IN (2, 3, 4) THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- Time Metrics (in seconds)
    AVG(DATEDIFF(SECOND, '00:00:00', c.ts_waiting)) AS AvgAnswerTimeSec,
    AVG(CASE WHEN c.ts_servicing > '00:00:00' THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) ELSE NULL END) AS AvgTalkTimeSec,
    SUM(CASE WHEN c.ts_servicing > '00:00:00' THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) ELSE 0 END) AS TotalTalkTimeSec,
    
    -- Queue Time
    SUM(DATEDIFF(SECOND, '00:00:00', c.ts_waiting)) AS TotalQueueTimeSec,
    
    -- Percentage in Queue (will calculate in report)
    COUNT(*) AS CallsHandled
    
FROM dbo.callcent_queuecalls c
LEFT JOIN dbo.extension e ON c.to_dn = CAST(e.fkiddn AS VARCHAR)
LEFT JOIN dbo.users u ON e.fkiddn = u.fkidextension
WHERE c.to_dn IS NOT NULL AND c.to_dn != ''
GROUP BY c.q_num, CAST(c.time_start AS DATE), c.to_dn, u.firstname, u.lastname
GO

-- =====================================================
-- 3. VIEW: vw_QueueDashboard_CallTrends
-- Returns hourly call trends for charting
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueDashboard_CallTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueDashboard_CallTrends
GO

CREATE VIEW dbo.vw_QueueDashboard_CallTrends AS
SELECT 
    q_num AS QueueNumber,
    CAST(time_start AS DATE) AS CallDate,
    DATEPART(HOUR, time_start) AS CallHour,
    
    -- Call Counts by Status
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN reason_noanswercode = 0 AND ts_servicing > '00:00:00' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN reason_noanswercode IN (3, 4) THEN 1 ELSE 0 END) AS AbandonedCalls,
    SUM(CASE WHEN reason_noanswercode = 2 THEN 1 ELSE 0 END) AS MissedCalls
    
FROM dbo.callcent_queuecalls
GROUP BY q_num, CAST(time_start AS DATE), DATEPART(HOUR, time_start)
GO

-- =====================================================
-- 4. VIEW: vw_QueueList
-- Returns list of queues for dropdown
-- =====================================================
IF OBJECT_ID('dbo.vw_QueueList', 'V') IS NOT NULL
    DROP VIEW dbo.vw_QueueList
GO

CREATE VIEW dbo.vw_QueueList AS
SELECT DISTINCT
    c.q_num AS QueueNumber,
    COALESCE(q.name, 'Queue ' + c.q_num) AS QueueName
FROM dbo.callcent_queuecalls c
LEFT JOIN dbo.dn d ON c.q_num = d.iddn
LEFT JOIN dbo.queue q ON d.iddn = q.fkiddn
GO

-- =====================================================
-- Verify all views created
-- =====================================================
SELECT 'Views Created Successfully:' AS Status
UNION ALL
SELECT name FROM sys.views WHERE name LIKE 'vw_QueueDashboard%' OR name = 'vw_QueueList'
GO
