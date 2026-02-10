-- =====================================================
-- VoIPTools Dashboard: KPIs Query
-- Purpose: Aggregated KPI metrics for dashboard header
-- Used in: VoIPToolsDashboard.repx (dsKPIs data source)
-- =====================================================
-- This query returns a SINGLE ROW with all KPI metrics

SELECT * FROM dbo.vw_QueueKPIs;

-- Fields returned:
-- TotalCalls, AnsweredCalls, AbandonedCalls, MissedCalls,
-- CallsToday, SLA1Percentage, AnsweredPercentage, AbandonedPercentage,
-- AvgTalkTimeSeconds, MaxTalkTimeSeconds, AvgWaitTimeSeconds, MaxWaitTimeSeconds,
-- AvgAnswerTimeSeconds, AvgTalkTime, MaxTalkTime, AvgWaitTime, MaxWaitTime, AvgAnswerTime,
-- DataStartDate, DataEndDate, ReportGeneratedAt
