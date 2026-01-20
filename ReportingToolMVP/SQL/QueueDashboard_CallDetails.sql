/*
 * Queue Dashboard - Call Details Query
 * Purpose: Get detailed call records for drill-down or detailed view
 * Used by: Call detail subreports or export functionality
 * 
 * Parameters:
 *   @StartDate - Start of date range (inclusive)
 *   @EndDate - End of date range (inclusive)
 *   @QueueNum - Optional: Filter by specific queue (NULL = all queues)
 * 
 * Call Outcomes:
 *   reason_noanswercode:
 *     0 = Call answered successfully
 *     2 = UserRequested (caller hung up)
 *     3 = MaxWaitTime (timeout in queue)
 *     4 = NoAgents
 *   
 *   reason_failcode:
 *     0 = Success
 *     1 = Agent timeout/no answer
 *     480 = Temporarily unavailable
 */

SELECT 
    -- Call Identification
    idcallcent_queuecalls AS CallId,
    call_history_id AS HistoryId,
    q_num AS QueueNumber,
    
    -- Timestamps
    time_start AS CallStartTime,
    time_end AS CallEndTime,
    DATEDIFF(SECOND, time_start, time_end) AS TotalDurationSeconds,
    
    -- Queue Metrics
    ts_waiting AS WaitTime,
    DATEDIFF(SECOND, '00:00:00', ts_waiting) AS WaitTimeSeconds,
    ts_servicing AS ServiceTime,
    DATEDIFF(SECOND, '00:00:00', ts_servicing) AS ServiceTimeSeconds,
    ts_polling AS PollingTime,
    ts_locating AS LocatingTime,
    
    -- Polling/Dialing Counts
    count_polls AS PollCount,
    count_dialed AS DialCount,
    count_rejected AS RejectedCount,
    count_dials_timed AS DialTimedOutCount,
    
    -- Caller Information
    from_userpart AS CallerNumber,
    from_displayname AS CallerName,
    to_dialednum AS DialedNumber,
    to_dn AS AgentExtension,
    to_dntype AS AgentType,
    cb_num AS CallbackNumber,
    
    -- Call Outcome
    reason_noanswercode AS NoAnswerCode,
    reason_noanswerdesc AS NoAnswerDescription,
    reason_failcode AS FailCode,
    reason_faildesc AS FailDescription,
    
    -- Calculated Status
    CASE 
        WHEN reason_noanswercode = 0 AND reason_failcode = 0 THEN 'Answered'
        WHEN reason_noanswercode = 2 THEN 'Abandoned (User Hung Up)'
        WHEN reason_noanswercode = 3 THEN 'Abandoned (Max Wait Time)'
        WHEN reason_noanswercode = 4 THEN 'No Agents Available'
        WHEN reason_failcode = 1 THEN 'Missed (Agent Timeout)'
        WHEN reason_failcode = 480 THEN 'Temporarily Unavailable'
        ELSE 'Other'
    END AS CallStatus,
    
    -- Additional Metadata
    call_result AS CallResult,
    deal_status AS DealStatus,
    is_visible AS IsVisible,
    is_agent AS IsAgentCall

FROM [dbo].[callcent_queuecalls]
WHERE 
    [time_start] >= @StartDate
    AND [time_start] < DATEADD(DAY, 1, @EndDate)
    AND (@QueueNum IS NULL OR [q_num] = @QueueNum)
ORDER BY 
    time_start DESC;
