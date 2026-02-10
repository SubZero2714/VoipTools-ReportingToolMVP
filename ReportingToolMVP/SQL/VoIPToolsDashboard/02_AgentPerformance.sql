-- =====================================================
-- VoIPTools Dashboard: Agent Performance Query
-- Purpose: Agent-level stats for the performance table
-- Used in: VoIPToolsDashboard.repx (dsAgentPerformance data source)
-- =====================================================
-- This query returns MULTIPLE ROWS - one per agent

SELECT TOP 10 
    Agent,       -- Agent name (e.g., "1005 - Agent")
    Calls,       -- Total calls handled
    AvgAnswer,   -- Average answer time (HH:MM:SS)
    AvgTalk,     -- Average talk time (HH:MM:SS)
    TalkTime,    -- Total talk time (HH:MM:SS)
    QTime,       -- Total queue time (HH:MM:SS)
    InQPercent   -- Percentage of total calls (e.g., "18.42%")
FROM dbo.vw_QueueAgentPerformance 
ORDER BY Calls DESC;
