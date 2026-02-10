-- =====================================================
-- VoIPTools Dashboard - Parameterized Stored Procedures
-- Database: Test_3CX_Exporter
-- Purpose: Dynamic filtering for reports by date, queue, agent
-- Created: February 4, 2026
-- 
-- USAGE:
--   sqlcmd -S "YOUR_SERVER" -d "YOUR_DATABASE" -i "05_FilterStoredProcedures.sql"
-- =====================================================

USE Test_3CX_Exporter;
GO

PRINT '============================================';
PRINT 'Creating Parameterized Stored Procedures';
PRINT '============================================';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 1: sp_GetQueueKPIs
-- Purpose: Get KPI metrics with optional filters
-- Parameters: Date range, Queue, Time period preset
-- =====================================================
PRINT 'Creating procedure: sp_GetQueueKPIs...';

IF OBJECT_ID('dbo.sp_GetQueueKPIs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetQueueKPIs;
GO

CREATE PROCEDURE dbo.sp_GetQueueKPIs
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @QueueNumber VARCHAR(20) = NULL,
    @TimePeriod VARCHAR(20) = NULL  -- 'Today', 'Yesterday', 'ThisWeek', 'ThisMonth', 'LastMonth'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Handle time period presets
    IF @TimePeriod IS NOT NULL
    BEGIN
        SET @EndDate = CAST(GETDATE() AS DATE);
        
        IF @TimePeriod = 'Today'
            SET @StartDate = CAST(GETDATE() AS DATE);
        ELSE IF @TimePeriod = 'Yesterday'
        BEGIN
            SET @StartDate = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));
            SET @EndDate = @StartDate;
        END
        ELSE IF @TimePeriod = 'ThisWeek'
            SET @StartDate = DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
        ELSE IF @TimePeriod = 'LastWeek'
        BEGIN
            SET @StartDate = DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()) - 7, CAST(GETDATE() AS DATE));
            SET @EndDate = DATEADD(DAY, 6, @StartDate);
        END
        ELSE IF @TimePeriod = 'ThisMonth'
            SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        ELSE IF @TimePeriod = 'LastMonth'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1);
            SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
        END
        ELSE IF @TimePeriod = 'Last7Days'
            SET @StartDate = DATEADD(DAY, -7, CAST(GETDATE() AS DATE));
        ELSE IF @TimePeriod = 'Last30Days'
            SET @StartDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    END
    
    -- Default to all data if no dates specified
    IF @StartDate IS NULL SET @StartDate = '2023-01-01';
    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    
    SELECT
        -- Filter Info
        @StartDate AS FilterStartDate,
        @EndDate AS FilterEndDate,
        @QueueNumber AS FilterQueue,
        
        -- Call Counts
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
        SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
        
        -- SLA Percentage
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                                       AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                                  THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
        END AS SLA1Percentage,
        
        -- Formatted Times
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS MaxTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS MaxWaitTime,
        
        GETDATE() AS ReportGeneratedAt
        
    FROM [dbo].[callcent_queuecalls]
    WHERE CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
      AND (@QueueNumber IS NULL OR q_num = @QueueNumber);
END
GO

PRINT '  ✓ sp_GetQueueKPIs created';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 2: sp_GetAgentPerformance
-- Purpose: Get agent metrics with optional filters
-- Parameters: Date range, Queue, Agent, TopN
-- =====================================================
PRINT 'Creating procedure: sp_GetAgentPerformance...';

IF OBJECT_ID('dbo.sp_GetAgentPerformance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetAgentPerformance;
GO

CREATE PROCEDURE dbo.sp_GetAgentPerformance
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @QueueNumber VARCHAR(20) = NULL,
    @AgentExtension VARCHAR(20) = NULL,
    @TimePeriod VARCHAR(20) = NULL,
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Handle time period presets
    IF @TimePeriod IS NOT NULL
    BEGIN
        SET @EndDate = CAST(GETDATE() AS DATE);
        
        IF @TimePeriod = 'Today'
            SET @StartDate = CAST(GETDATE() AS DATE);
        ELSE IF @TimePeriod = 'Yesterday'
        BEGIN
            SET @StartDate = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));
            SET @EndDate = @StartDate;
        END
        ELSE IF @TimePeriod = 'ThisWeek'
            SET @StartDate = DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
        ELSE IF @TimePeriod = 'ThisMonth'
            SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        ELSE IF @TimePeriod = 'LastMonth'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1);
            SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
        END
        ELSE IF @TimePeriod = 'Last30Days'
            SET @StartDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    END
    
    IF @StartDate IS NULL SET @StartDate = '2023-01-01';
    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    
    -- Get total calls for percentage calculation (with same filters)
    DECLARE @TotalCalls INT;
    SELECT @TotalCalls = COUNT(*) 
    FROM [dbo].[callcent_queuecalls]
    WHERE CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
      AND (@QueueNumber IS NULL OR q_num = @QueueNumber);
    
    SELECT TOP (@TopN)
        COALESCE(to_dn, 'Unknown') AS AgentDN,
        CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
        COUNT(*) AS Calls,
        
        -- Answer Rate for this agent
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND(CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 1)
        END AS AnswerRatePercent,
        
        -- Time Metrics
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
                THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
                ELSE NULL END), 0), 108) AS AvgAnswer,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, 
            SUM(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS QTime,
        
        -- Percentage of filtered calls
        CAST(ROUND((CAST(COUNT(*) AS FLOAT) / NULLIF(@TotalCalls, 0)) * 100, 2) AS VARCHAR(10)) + '%' AS InQPercent,
        ROUND((CAST(COUNT(*) AS FLOAT) / NULLIF(@TotalCalls, 0)) * 100, 2) AS InQPercentValue
        
    FROM [dbo].[callcent_queuecalls]
    WHERE CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
      AND (@QueueNumber IS NULL OR q_num = @QueueNumber)
      AND (@AgentExtension IS NULL OR to_dn = @AgentExtension)
      AND to_dn IS NOT NULL
    GROUP BY to_dn
    ORDER BY COUNT(*) DESC;
END
GO

PRINT '  ✓ sp_GetAgentPerformance created';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 3: sp_GetCallTrends
-- Purpose: Get call trends with optional filters
-- Parameters: Date range, Queue, Granularity (Hour/Day/Week/Month)
-- =====================================================
PRINT 'Creating procedure: sp_GetCallTrends...';

IF OBJECT_ID('dbo.sp_GetCallTrends', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetCallTrends;
GO

CREATE PROCEDURE dbo.sp_GetCallTrends
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @QueueNumber VARCHAR(20) = NULL,
    @TimePeriod VARCHAR(20) = NULL,
    @Granularity VARCHAR(10) = 'Day',  -- 'Hour', 'Day', 'Week', 'Month'
    @TopN INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Handle time period presets
    IF @TimePeriod IS NOT NULL
    BEGIN
        SET @EndDate = CAST(GETDATE() AS DATE);
        
        IF @TimePeriod = 'Today'
        BEGIN
            SET @StartDate = CAST(GETDATE() AS DATE);
            SET @Granularity = 'Hour';  -- Force hourly for today
        END
        ELSE IF @TimePeriod = 'ThisWeek'
            SET @StartDate = DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
        ELSE IF @TimePeriod = 'ThisMonth'
            SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        ELSE IF @TimePeriod = 'LastMonth'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1);
            SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
        END
        ELSE IF @TimePeriod = 'Last30Days'
            SET @StartDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    END
    
    IF @StartDate IS NULL SET @StartDate = '2023-01-01';
    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    
    -- HOURLY granularity
    IF @Granularity = 'Hour'
    BEGIN
        SELECT TOP (@TopN)
            DATEPART(HOUR, time_start) AS PeriodKey,
            CONCAT(RIGHT('0' + CAST(DATEPART(HOUR, time_start) AS VARCHAR), 2), ':00') AS PeriodLabel,
            SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
            SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
            SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
            COUNT(*) AS TotalCalls
        FROM [dbo].[callcent_queuecalls]
        WHERE CAST(time_start AS DATE) >= @StartDate
          AND CAST(time_start AS DATE) <= @EndDate
          AND (@QueueNumber IS NULL OR q_num = @QueueNumber)
        GROUP BY DATEPART(HOUR, time_start)
        ORDER BY DATEPART(HOUR, time_start);
    END
    
    -- DAILY granularity (default)
    ELSE IF @Granularity = 'Day'
    BEGIN
        SELECT TOP (@TopN)
            CAST(time_start AS DATE) AS PeriodKey,
            FORMAT(time_start, 'MMM d') AS PeriodLabel,
            SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
            SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
            SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
            COUNT(*) AS TotalCalls
        FROM [dbo].[callcent_queuecalls]
        WHERE CAST(time_start AS DATE) >= @StartDate
          AND CAST(time_start AS DATE) <= @EndDate
          AND (@QueueNumber IS NULL OR q_num = @QueueNumber)
        GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'MMM d')
        ORDER BY CAST(time_start AS DATE);
    END
    
    -- WEEKLY granularity
    ELSE IF @Granularity = 'Week'
    BEGIN
        SELECT TOP (@TopN)
            DATEPART(WEEK, time_start) AS PeriodKey,
            CONCAT('Week ', DATEPART(WEEK, time_start)) AS PeriodLabel,
            SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
            SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
            SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
            COUNT(*) AS TotalCalls
        FROM [dbo].[callcent_queuecalls]
        WHERE CAST(time_start AS DATE) >= @StartDate
          AND CAST(time_start AS DATE) <= @EndDate
          AND (@QueueNumber IS NULL OR q_num = @QueueNumber)
        GROUP BY DATEPART(WEEK, time_start)
        ORDER BY DATEPART(WEEK, time_start);
    END
    
    -- MONTHLY granularity
    ELSE IF @Granularity = 'Month'
    BEGIN
        SELECT TOP (@TopN)
            FORMAT(time_start, 'yyyy-MM') AS PeriodKey,
            FORMAT(time_start, 'MMM yyyy') AS PeriodLabel,
            SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
            SUM(CASE WHEN reason_noanswercode IS NOT NULL AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
            SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
            COUNT(*) AS TotalCalls
        FROM [dbo].[callcent_queuecalls]
        WHERE CAST(time_start AS DATE) >= @StartDate
          AND CAST(time_start AS DATE) <= @EndDate
          AND (@QueueNumber IS NULL OR q_num = @QueueNumber)
        GROUP BY FORMAT(time_start, 'yyyy-MM'), FORMAT(time_start, 'MMM yyyy')
        ORDER BY FORMAT(time_start, 'yyyy-MM');
    END
END
GO

PRINT '  ✓ sp_GetCallTrends created';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 4: sp_GetQueueSummary
-- Purpose: Get per-queue summary with optional filters
-- Parameters: Date range, specific queues
-- =====================================================
PRINT 'Creating procedure: sp_GetQueueSummary...';

IF OBJECT_ID('dbo.sp_GetQueueSummary', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetQueueSummary;
GO

CREATE PROCEDURE dbo.sp_GetQueueSummary
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @QueueNumbers VARCHAR(500) = NULL,  -- Comma-separated list: '8000,8001,8002'
    @TimePeriod VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Handle time period presets
    IF @TimePeriod IS NOT NULL
    BEGIN
        SET @EndDate = CAST(GETDATE() AS DATE);
        
        IF @TimePeriod = 'Today'
            SET @StartDate = CAST(GETDATE() AS DATE);
        ELSE IF @TimePeriod = 'ThisWeek'
            SET @StartDate = DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
        ELSE IF @TimePeriod = 'ThisMonth'
            SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        ELSE IF @TimePeriod = 'LastMonth'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1);
            SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
        END
    END
    
    IF @StartDate IS NULL SET @StartDate = '2023-01-01';
    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    
    SELECT
        q_num AS QueueNumber,
        COALESCE(q_name, CONCAT('Queue ', q_num)) AS QueueName,
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
        
        -- Answer Rate
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND(CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 1)
        END AS AnswerRatePercent,
        
        -- SLA
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                                       AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                                  THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
        END AS SLAPercent,
        
        -- Times
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime
        
    FROM [dbo].[callcent_queuecalls]
    WHERE CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
      AND (@QueueNumbers IS NULL OR q_num IN (SELECT value FROM STRING_SPLIT(@QueueNumbers, ',')))
    GROUP BY q_num, q_name
    ORDER BY COUNT(*) DESC;
END
GO

PRINT '  ✓ sp_GetQueueSummary created';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 5: sp_GetAgentDetail
-- Purpose: Detailed metrics for a single agent
-- Parameters: Agent extension, Date range
-- =====================================================
PRINT 'Creating procedure: sp_GetAgentDetail...';

IF OBJECT_ID('dbo.sp_GetAgentDetail', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetAgentDetail;
GO

CREATE PROCEDURE dbo.sp_GetAgentDetail
    @AgentExtension VARCHAR(20),
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @TimePeriod VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Handle time period presets
    IF @TimePeriod IS NOT NULL
    BEGIN
        SET @EndDate = CAST(GETDATE() AS DATE);
        
        IF @TimePeriod = 'ThisMonth'
            SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        ELSE IF @TimePeriod = 'LastMonth'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1);
            SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
        END
        ELSE IF @TimePeriod = 'Last30Days'
            SET @StartDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    END
    
    IF @StartDate IS NULL SET @StartDate = '2023-01-01';
    IF @EndDate IS NULL SET @EndDate = CAST(GETDATE() AS DATE);
    
    -- Result Set 1: Agent Summary KPIs
    SELECT
        @AgentExtension AS AgentExtension,
        CONCAT(@AgentExtension, ' - Agent') AS AgentName,
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND(CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 1)
        END AS AnswerRatePercent,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TotalTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) ELSE NULL END), 0), 108) AS AvgAnswerTime
    FROM [dbo].[callcent_queuecalls]
    WHERE to_dn = @AgentExtension
      AND CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate;
    
    -- Result Set 2: Daily Breakdown
    SELECT
        CAST(time_start AS DATE) AS CallDate,
        FORMAT(time_start, 'ddd, MMM d') AS DateLabel,
        COUNT(*) AS Calls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS Answered,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk
    FROM [dbo].[callcent_queuecalls]
    WHERE to_dn = @AgentExtension
      AND CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
    GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'ddd, MMM d')
    ORDER BY CAST(time_start AS DATE);
    
    -- Result Set 3: Queue Breakdown (which queues this agent handles)
    SELECT
        q_num AS QueueNumber,
        COALESCE(q_name, CONCAT('Queue ', q_num)) AS QueueName,
        COUNT(*) AS Calls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS Answered
    FROM [dbo].[callcent_queuecalls]
    WHERE to_dn = @AgentExtension
      AND CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate
    GROUP BY q_num, q_name
    ORDER BY COUNT(*) DESC;
END
GO

PRINT '  ✓ sp_GetAgentDetail created';
PRINT '';

-- =====================================================
-- STORED PROCEDURE 6: sp_GetMonthlyReport
-- Purpose: Monthly executive summary with comparisons
-- Parameters: Year, Month
-- =====================================================
PRINT 'Creating procedure: sp_GetMonthlyReport...';

IF OBJECT_ID('dbo.sp_GetMonthlyReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetMonthlyReport;
GO

CREATE PROCEDURE dbo.sp_GetMonthlyReport
    @Year INT = NULL,
    @Month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Year IS NULL SET @Year = YEAR(GETDATE());
    IF @Month IS NULL SET @Month = MONTH(GETDATE());
    
    DECLARE @StartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @EndDate DATE = EOMONTH(@StartDate);
    
    DECLARE @PrevStartDate DATE = DATEADD(MONTH, -1, @StartDate);
    DECLARE @PrevEndDate DATE = EOMONTH(@PrevStartDate);
    
    -- Current Month KPIs
    SELECT
        FORMAT(@StartDate, 'MMMM yyyy') AS ReportPeriod,
        @StartDate AS PeriodStart,
        @EndDate AS PeriodEnd,
        
        -- Current Month
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
        SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
        CASE WHEN COUNT(*) = 0 THEN 0
             ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                                       AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                                  THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
        END AS SLAPercent,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
        CONVERT(VARCHAR(8), DATEADD(SECOND, AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
        
        -- Previous Month (for comparison)
        (SELECT COUNT(*) FROM callcent_queuecalls 
         WHERE CAST(time_start AS DATE) >= @PrevStartDate AND CAST(time_start AS DATE) <= @PrevEndDate) AS PrevTotalCalls,
        (SELECT SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) FROM callcent_queuecalls 
         WHERE CAST(time_start AS DATE) >= @PrevStartDate AND CAST(time_start AS DATE) <= @PrevEndDate) AS PrevAnsweredCalls
        
    FROM [dbo].[callcent_queuecalls]
    WHERE CAST(time_start AS DATE) >= @StartDate
      AND CAST(time_start AS DATE) <= @EndDate;
END
GO

PRINT '  ✓ sp_GetMonthlyReport created';
PRINT '';

-- =====================================================
-- VERIFICATION & EXAMPLES
-- =====================================================
PRINT '============================================';
PRINT 'Testing Stored Procedures';
PRINT '============================================';
PRINT '';

-- Test sp_GetQueueKPIs
PRINT 'Test: sp_GetQueueKPIs @TimePeriod = ''Last30Days''';
EXEC sp_GetQueueKPIs @TimePeriod = 'Last30Days';
PRINT '';

-- Test sp_GetAgentPerformance
PRINT 'Test: sp_GetAgentPerformance @TopN = 5';
EXEC sp_GetAgentPerformance @TopN = 5;
PRINT '';

-- Test sp_GetCallTrends
PRINT 'Test: sp_GetCallTrends @Granularity = ''Month''';
EXEC sp_GetCallTrends @Granularity = 'Month', @TopN = 6;
PRINT '';

PRINT '============================================';
PRINT 'All Stored Procedures Created Successfully!';
PRINT '============================================';
PRINT '';
PRINT 'Available Procedures:';
PRINT '  - sp_GetQueueKPIs       : Get KPIs with date/queue filters';
PRINT '  - sp_GetAgentPerformance: Get agent metrics with filters';
PRINT '  - sp_GetCallTrends      : Get trends with granularity options';
PRINT '  - sp_GetQueueSummary    : Get per-queue breakdown';
PRINT '  - sp_GetAgentDetail     : Get detailed single-agent report';
PRINT '  - sp_GetMonthlyReport   : Get monthly executive summary';
PRINT '';
PRINT 'Time Period Options:';
PRINT '  Today, Yesterday, ThisWeek, LastWeek, ThisMonth, LastMonth, Last7Days, Last30Days';
PRINT '';
PRINT 'Granularity Options (for trends):';
PRINT '  Hour, Day, Week, Month';
GO
