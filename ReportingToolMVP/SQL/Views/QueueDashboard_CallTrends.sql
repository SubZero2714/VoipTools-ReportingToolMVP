/*
 * Queue Dashboard - Call Trends Query (for Chart)
 * Purpose: Provides time-series data for the area/line chart
 * Used by: QueueDashboard.repx report - XRChart component
 * 
 * Parameters:
 *   @StartDate - Start of date range (inclusive)
 *   @EndDate - End of date range (inclusive)
 *   @QueueNum - Optional: Filter by specific queue (NULL = all queues)
 *   @GroupBy - 'HOUR', 'DAY', 'WEEK', 'MONTH'
 * 
 * Series:
 *   - Answered Calls (green area)
 *   - Missed Calls (orange area)
 *   - Abandoned Calls (red area)
 */

-- Call Trends by Day (use this for date range > 7 days)
SELECT 
    CAST([time_start] AS DATE) AS CallDate,
    
    SUM(CASE 
        WHEN reason_noanswercode = 0 AND reason_failcode = 0 
        THEN 1 ELSE 0 
    END) AS AnsweredCalls,
    
    SUM(CASE 
        WHEN reason_failcode = 1 
        THEN 1 ELSE 0 
    END) AS MissedCalls,
    
    SUM(CASE 
        WHEN reason_noanswercode IN (2, 3) 
        THEN 1 ELSE 0 
    END) AS AbandonedCalls,
    
    COUNT(*) AS TotalCalls
    
FROM [dbo].[callcent_queuecalls]
WHERE 
    [time_start] >= @StartDate
    AND [time_start] < DATEADD(DAY, 1, @EndDate)
    AND (@QueueNum IS NULL OR [q_num] = @QueueNum)
GROUP BY 
    CAST([time_start] AS DATE)
ORDER BY 
    CallDate;

/*
 * Alternative: Call Trends by Hour (use for single day reports)
 */
-- SELECT 
--     CAST([time_start] AS DATE) AS CallDate,
--     DATEPART(HOUR, [time_start]) AS CallHour,
--     
--     SUM(CASE 
--         WHEN reason_noanswercode = 0 AND reason_failcode = 0 
--         THEN 1 ELSE 0 
--     END) AS AnsweredCalls,
--     
--     SUM(CASE 
--         WHEN reason_failcode = 1 
--         THEN 1 ELSE 0 
--     END) AS MissedCalls,
--     
--     SUM(CASE 
--         WHEN reason_noanswercode IN (2, 3) 
--         THEN 1 ELSE 0 
--     END) AS AbandonedCalls,
--     
--     COUNT(*) AS TotalCalls
--     
-- FROM [dbo].[callcent_queuecalls]
-- WHERE 
--     [time_start] >= @StartDate
--     AND [time_start] < DATEADD(DAY, 1, @EndDate)
--     AND (@QueueNum IS NULL OR [q_num] = @QueueNum)
-- GROUP BY 
--     CAST([time_start] AS DATE),
--     DATEPART(HOUR, [time_start])
-- ORDER BY 
--     CallDate, CallHour;
