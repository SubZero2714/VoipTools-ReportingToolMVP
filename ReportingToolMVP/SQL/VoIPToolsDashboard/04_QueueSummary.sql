-- =====================================================
-- VoIPTools Dashboard: Queue Summary Query
-- Purpose: Per-queue breakdown with percentages
-- Used in: VoIPToolsDashboard.repx (optional - for queue detail reports)
-- =====================================================
-- This query is based on the user's original requirement

SELECT 
    qnumber,
    QueueName,
    TotalCalls,
    NotServicedCalls,
    ServicedCalls,
    AnsweredPercentage,
    AbandonedPercentage,
    AnsweredWithin20Percentage,
    TotalServicingSeconds,
    TotalServicingTime
FROM dbo.vw_QueueSummary
ORDER BY qnumber;
