-- =====================================================
-- VoIPTools Dashboard: Call Trends Query
-- Purpose: Daily call counts for the area chart
-- Used in: VoIPToolsDashboard.repx (dsCallTrends data source)
-- =====================================================
-- This query returns MULTIPLE ROWS - one per day

SELECT 
    CallDate,          -- Date (for X-axis)
    CallDateLabel,     -- Formatted date label (e.g., "Mar 5")
    AnsweredCalls,     -- Green series
    MissedCalls,       -- Yellow series
    AbandonedCalls     -- Red series
FROM dbo.vw_QueueCallTrends
ORDER BY CallDate;
