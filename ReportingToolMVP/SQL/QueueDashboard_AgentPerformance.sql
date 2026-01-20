/*
 * Queue Dashboard - Agent Performance Query
 * Purpose: Provides agent-level performance metrics for the data grid
 * Used by: QueueDashboard.repx report
 * 
 * Parameters:
 *   @StartDate - Start of date range (inclusive)
 *   @EndDate - End of date range (inclusive)
 *   @QueueNum - Optional: Filter by specific queue (NULL = all queues)
 * 
 * Joins:
 *   - callcent_queuecalls: Call records
 *   - dn: Directory numbers (extensions)
 *   - users: Agent first/last names
 * 
 * Notes:
 *   - Only includes calls where an agent answered (to_dn IS NOT NULL)
 *   - Groups by agent extension
 *   - Calculates avg times only for answered calls
 */

-- Agent Performance Query
SELECT 
    -- Agent Identification
    CONCAT(c.to_dn, ' - ', ISNULL(u.firstname + ' ' + u.lastname, 'Unknown Agent')) AS Agent,
    c.to_dn AS AgentExtension,
    u.firstname AS AgentFirstName,
    u.lastname AS AgentLastName,
    
    -- Call Counts
    COUNT(*) AS TotalCalls,
    
    SUM(CASE 
        WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
        THEN 1 ELSE 0 
    END) AS AnsweredCalls,
    
    -- Time Metrics (formatted as time)
    -- Average Answer Time (time from queue to agent pickup)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE 
            WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
            THEN DATEDIFF(SECOND, '00:00:00', c.ts_waiting) 
            ELSE NULL 
        END), 0), 108) AS AvgAnswerTime,
    
    -- Average Talk Time (service duration)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE 
            WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
            THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) 
            ELSE NULL 
        END), 0), 108) AS AvgTalkTime,
    
    -- Total Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(CASE 
            WHEN c.reason_noanswercode = 0 AND c.reason_failcode = 0 
            THEN DATEDIFF(SECOND, '00:00:00', c.ts_servicing) 
            ELSE 0 
        END), 0), 108) AS TotalTalkTime,
    
    -- Queue Time (total time calls waited)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', c.ts_waiting)), 0), 108) AS QueueTime,
    
    -- In Queue Percentage (agent's share of total calls)
    CAST(
        COUNT(*) * 100.0 / NULLIF(
            (SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
             WHERE [time_start] >= @StartDate 
               AND [time_start] < DATEADD(DAY, 1, @EndDate)
               AND (@QueueNum IS NULL OR [q_num] = @QueueNum)
               AND to_dn IS NOT NULL), 0
        ) AS DECIMAL(5,2)
    ) AS InQueuePercent

FROM [dbo].[callcent_queuecalls] c
LEFT JOIN [dbo].[dn] d ON c.to_dn = d.value
LEFT JOIN [dbo].[users] u ON d.iddn = u.fkidextension
WHERE 
    c.[time_start] >= @StartDate
    AND c.[time_start] < DATEADD(DAY, 1, @EndDate)
    AND (@QueueNum IS NULL OR c.[q_num] = @QueueNum)
    AND c.to_dn IS NOT NULL  -- Only include calls that reached an agent
GROUP BY 
    c.to_dn,
    u.firstname,
    u.lastname
ORDER BY 
    COUNT(*) DESC;  -- Most active agents first
