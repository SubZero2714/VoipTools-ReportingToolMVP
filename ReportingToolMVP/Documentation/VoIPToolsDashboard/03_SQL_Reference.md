# SQL Query Reference

Complete documentation of all SQL queries used in VoIPTools Dashboard reports.

---

## Table of Contents

1. [Database Schema](#database-schema)
2. [Core Views](#core-views)
3. [Query Variations](#query-variations)
4. [Filter Templates](#filter-templates)

---

## Database Schema

### Source Table: `callcent_queuecalls`

This is the 3CX Call Center export table containing all queue call records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | int | Unique call ID |
| `time_start` | datetime | When the call entered the queue |
| `time_end` | datetime | When the call ended |
| `q_num` | varchar | Queue number (e.g., "8000", "8001") |
| `q_name` | varchar | Queue name |
| `from_no` | varchar | Caller phone number |
| `from_dn` | varchar | Caller display name |
| `to_no` | varchar | Destination number |
| `to_dn` | varchar | Agent extension who answered |
| `ts_waiting` | time(7) | Time spent waiting in queue |
| `ts_servicing` | time(7) | Time spent talking (00:00:00 = not answered) |
| `ts_polling` | time(7) | Time spent polling agents |
| `reason_noanswercode` | varchar | Why call wasn't answered (NULL if answered) |
| `reason_noanswer` | varchar | Human-readable no-answer reason |

### Key Logic

```sql
-- Call was ANSWERED if servicing time > 0
ts_servicing != '00:00:00.0000000'

-- Call was ABANDONED if servicing time = 0
ts_servicing = '00:00:00.0000000'

-- Call was MISSED if abandoned AND has a reason code
ts_servicing = '00:00:00.0000000' AND reason_noanswercode IS NOT NULL

-- SLA = Answered within 20 seconds
ts_servicing != '00:00:00.0000000' AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20
```

---

## Core Views

### VIEW 1: `vw_QueueKPIs`

**Purpose:** Aggregated metrics for the 8 KPI cards in the dashboard header.

**Returns:** 1 row with all metrics

```sql
CREATE VIEW dbo.vw_QueueKPIs AS
SELECT
    -- Raw Counts
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL 
             AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- SLA Percentage (answered within 20 seconds)
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(
            (CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                           AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                      THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS SLA1Percentage,
    
    -- Time Metrics (formatted as HH:MM:SS)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS MaxTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
    
    -- Metadata
    GETDATE() AS ReportGeneratedAt
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01';
```

**Fields Used in Report:**
| Field | KPI Card | Format |
|-------|----------|--------|
| `TotalCalls` | Total Calls | Number with comma |
| `AnsweredCalls` | Answered | Number, green |
| `AbandonedCalls` | Abandoned | Number, red |
| `MissedCalls` | Missed | Number, orange |
| `SLA1Percentage` | SLA % | Percentage, green |
| `AvgTalkTime` | Avg Talk | Time string |
| `MaxTalkTime` | Max Talk | Time string |
| `AvgWaitTime` | Avg Wait | Time string |

---

### VIEW 2: `vw_QueueAgentPerformance`

**Purpose:** Agent-level metrics for the performance table.

**Returns:** Multiple rows (1 per agent), ordered by calls handled

```sql
CREATE VIEW dbo.vw_QueueAgentPerformance AS
SELECT
    -- Agent Identifier
    COALESCE(to_dn, 'Unknown') AS AgentDN,
    CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
    
    -- Call Count
    COUNT(*) AS Calls,
    
    -- Average Answer Time (how fast agent picks up)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
            ELSE NULL END), 0), 108) AS AvgAnswer,
    
    -- Average Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk,
    
    -- Total Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TalkTime,
    
    -- Queue Time (total wait time)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS QTime,
    
    -- Percentage of total calls handled
    CAST(ROUND(
        (CAST(COUNT(*) AS FLOAT) / 
         NULLIF((SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
                 WHERE time_start >= '2023-01-01'), 0)) * 100, 2
    ) AS VARCHAR(10)) + '%' AS InQPercent

FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
  AND to_dn IS NOT NULL  -- Only agents who answered
GROUP BY to_dn;
```

**Fields Used in Report:**
| Field | Column | Description |
|-------|--------|-------------|
| `Agent` | Agent | Agent extension + name |
| `Calls` | Calls | Number of calls handled |
| `AvgAnswer` | Avg Answer | Average time to pick up |
| `AvgTalk` | Avg Talk | Average call duration |
| `TalkTime` | Talk Time | Total time on calls |
| `QTime` | Q Time | Total queue wait time |
| `InQPercent` | In Q% | % of all calls this agent handled |

---

### VIEW 3: `vw_QueueCallTrends`

**Purpose:** Daily call counts for the trend chart.

**Returns:** Multiple rows (1 per day), ordered by date

```sql
CREATE VIEW dbo.vw_QueueCallTrends AS
SELECT
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'MMM d') AS CallDateLabel,  -- "Jan 15" format
    
    -- Daily Counts
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL 
             AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    
    COUNT(*) AS TotalCalls
    
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'MMM d');
```

**Fields Used in Report:**
| Field | Chart Property | Description |
|-------|----------------|-------------|
| `CallDateLabel` | Argument (X-axis) | Date label like "Jan 15" |
| `AnsweredCalls` | Series 1 Value | Green area |
| `MissedCalls` | Series 2 Value | Yellow area |
| `AbandonedCalls` | Series 3 Value | Red area |

---

### VIEW 4: `vw_QueueSummary`

**Purpose:** Per-queue breakdown (optional, for detailed reports).

**Returns:** Multiple rows (1 per queue)

```sql
CREATE VIEW dbo.vw_QueueSummary AS
SELECT
    q_num AS QueueNumber,
    COALESCE(q_name, CONCAT('Queue ', q_num)) AS QueueName,
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    
    -- Answer Rate
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(
            CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS FLOAT) 
            / COUNT(*) * 100, 1)
    END AS AnswerRatePercent
    
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
GROUP BY q_num, q_name;
```

---

## Query Variations

### For Report Data Sources

These are the actual queries used in the .repx file data sources:

```sql
-- dsKPIs (returns 1 row)
SELECT TOP 1 * FROM dbo.vw_QueueKPIs

-- dsAgents (returns 10 rows)
SELECT TOP 10 Agent, Calls, AvgAnswer, AvgTalk, TalkTime, QTime, InQPercent
FROM dbo.vw_QueueAgentPerformance
ORDER BY Calls DESC

-- dsTrends (returns 15 rows for chart)
SELECT TOP 15 CallDate, CallDateLabel, AnsweredCalls, MissedCalls, AbandonedCalls
FROM dbo.vw_QueueCallTrends
ORDER BY CallDate ASC
```

---

## Filter Templates

Use these WHERE clauses to create filtered versions:

### Time Period Filters

```sql
-- TODAY ONLY
WHERE CAST(time_start AS DATE) = CAST(GETDATE() AS DATE)

-- YESTERDAY
WHERE CAST(time_start AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)

-- THIS WEEK (Monday to Sunday)
WHERE time_start >= DATEADD(DAY, 1 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE))
  AND time_start < DATEADD(DAY, 8 - DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE))

-- LAST 7 DAYS
WHERE time_start >= DATEADD(DAY, -7, GETDATE())

-- THIS MONTH
WHERE YEAR(time_start) = YEAR(GETDATE()) AND MONTH(time_start) = MONTH(GETDATE())

-- SPECIFIC MONTH (e.g., January 2026)
WHERE YEAR(time_start) = 2026 AND MONTH(time_start) = 1

-- LAST 30 DAYS
WHERE time_start >= DATEADD(DAY, -30, GETDATE())

-- DATE RANGE
WHERE time_start >= '2026-01-01' AND time_start < '2026-02-01'
```

### Hourly Breakdown

```sql
-- HOURLY TRENDS (instead of daily)
SELECT
    DATEPART(HOUR, time_start) AS HourOfDay,
    CONCAT(DATEPART(HOUR, time_start), ':00') AS HourLabel,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls
FROM [dbo].[callcent_queuecalls]
WHERE CAST(time_start AS DATE) = CAST(GETDATE() AS DATE)  -- Today only
GROUP BY DATEPART(HOUR, time_start)
ORDER BY HourOfDay;
```

### Queue Filters

```sql
-- SPECIFIC QUEUE
WHERE q_num = '8000'

-- MULTIPLE QUEUES
WHERE q_num IN ('8000', '8001', '8002')

-- QUEUES STARTING WITH 80xx
WHERE q_num LIKE '80%'
```

### Agent Filters

```sql
-- SPECIFIC AGENT
WHERE to_dn = '1006'

-- MULTIPLE AGENTS
WHERE to_dn IN ('1006', '1007', '1008')

-- TOP 5 AGENTS BY CALLS
SELECT TOP 5 ... ORDER BY Calls DESC
```

### Combined Filters

```sql
-- THIS MONTH, SPECIFIC QUEUE, TOP 10 AGENTS
SELECT TOP 10 
    Agent, Calls, AvgAnswer, AvgTalk
FROM dbo.vw_QueueAgentPerformance
WHERE QueueNumber = '8000'
  AND YEAR(CallDate) = 2026 AND MONTH(CallDate) = 1
ORDER BY Calls DESC;
```

---

## Creating Parameterized Views

For dynamic filtering, create stored procedures instead of views:

```sql
CREATE PROCEDURE sp_GetQueueKPIs
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @QueueNumber VARCHAR(20) = NULL
AS
BEGIN
    SET @StartDate = ISNULL(@StartDate, '2023-01-01');
    SET @EndDate = ISNULL(@EndDate, GETDATE());
    
    SELECT
        COUNT(*) AS TotalCalls,
        SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
        -- ... rest of KPI fields
    FROM [dbo].[callcent_queuecalls]
    WHERE time_start >= @StartDate 
      AND time_start < DATEADD(DAY, 1, @EndDate)
      AND (@QueueNumber IS NULL OR q_num = @QueueNumber);
END
```

---

## Performance Notes

1. **Index Recommendations:**
   ```sql
   CREATE INDEX IX_queuecalls_time_start ON callcent_queuecalls(time_start);
   CREATE INDEX IX_queuecalls_queue ON callcent_queuecalls(q_num);
   CREATE INDEX IX_queuecalls_agent ON callcent_queuecalls(to_dn);
   ```

2. **TOP Clause:** Always use `TOP` in report queries to limit data:
   - KPIs: `TOP 1` (only need aggregates)
   - Agents: `TOP 10` or `TOP 20`
   - Trends: `TOP 15` to `TOP 30` for charts

3. **Date Filtering:** Always filter by date to avoid scanning entire table
