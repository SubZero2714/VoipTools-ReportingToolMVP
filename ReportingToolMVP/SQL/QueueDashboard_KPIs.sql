/*
 * Queue Dashboard - KPI Summary Query
 * Purpose: Provides all Key Performance Indicators for the dashboard header
 * Used by: QueueDashboard.repx report
 * 
 * Parameters:
 *   @StartDate - Start of date range (inclusive)
 *   @EndDate - End of date range (inclusive)
 *   @QueueNum - Optional: Filter by specific queue (NULL = all queues)
 * 
 * Metrics Calculated:
 *   - Total Calls: All calls in the period
 *   - Answered Calls: reason_noanswercode = 0 AND reason_failcode = 0
 *   - Abandoned Calls: reason_noanswercode IN (2, 3) - UserRequested or MaxWaitTime
 *   - Missed Calls: reason_failcode = 1 - No agent answered
 *   - Average Wait Time: Time caller waited in queue
 *   - Max Wait Time: Longest wait time
 *   - Average Service Time: Duration of answered calls
 *   - Max Service Time: Longest call duration
 *   - SLA % (30 sec): Percentage answered within 30 seconds
 */

-- KPI Summary Query
SELECT 
    -- Call Counts
    COUNT(*) AS TotalCalls,
    
    SUM(CASE 
        WHEN reason_noanswercode = 0 AND reason_failcode = 0 
        THEN 1 ELSE 0 
    END) AS AnsweredCalls,
    
    SUM(CASE 
        WHEN reason_noanswercode IN (2, 3)  -- UserRequested, MaxWaitTime
        THEN 1 ELSE 0 
    END) AS AbandonedCalls,
    
    SUM(CASE 
        WHEN reason_failcode = 1  -- No answer/Timeout
        THEN 1 ELSE 0 
    END) AS MissedCalls,
    
    -- Time Metrics (in seconds)
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitTimeSeconds,
    AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS AvgServiceTimeSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS MaxServiceTimeSeconds,
    
    -- SLA Metrics (percentage answered within threshold)
    CAST(
        SUM(CASE 
            WHEN reason_noanswercode = 0 
             AND reason_failcode = 0 
             AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 30 
            THEN 1 ELSE 0 
        END) * 100.0 / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS SLA30SecPercent,
    
    CAST(
        SUM(CASE 
            WHEN reason_noanswercode = 0 
             AND reason_failcode = 0 
             AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 60 
            THEN 1 ELSE 0 
        END) * 100.0 / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS SLA60SecPercent,
    
    -- Calculated Percentages
    CAST(
        SUM(CASE WHEN reason_noanswercode = 0 AND reason_failcode = 0 THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS AnswerRatePercent
    
FROM [dbo].[callcent_queuecalls]
WHERE 
    [time_start] >= @StartDate
    AND [time_start] < DATEADD(DAY, 1, @EndDate)
    AND (@QueueNum IS NULL OR [q_num] = @QueueNum);
