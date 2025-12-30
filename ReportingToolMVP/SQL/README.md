# SQL Queries Documentation

This folder contains documentation for all SQL queries used in the VoIPTools Reporting Tool MVP.

## Database Connection

**Server:** LAPTOP-A5UI98NJ\SQLEXPRESS (Development)  
**Database:** Test_3CX_Exporter  
**Authentication:** SQL Server Authentication

## Tables Used

| Table | Description |
|-------|-------------|
| `callcent_queuecalls` | Individual call records with queue metrics |
| `queue` | Queue definitions and names |
| `dn` | Phone numbers/extensions (links queue to calls) |

---

## Queries in CustomReportService.cs

### 1. GetQueuesAsync - Retrieve Available Queues

**Purpose:** Get list of all queues that have call data for dropdown population

**Location:** `Services/CustomReportService.cs` - Line 45

```sql
SELECT 
    c.q_num as QueueId,
    ISNULL(q.name, 'Queue ' + c.q_num) as QueueName
FROM (
    SELECT DISTINCT q_num FROM [dbo].[callcent_queuecalls]
) c
LEFT JOIN [dbo].[dn] d ON c.q_num = d.iddn
LEFT JOIN [dbo].[queue] q ON d.iddn = q.fkiddn
ORDER BY c.q_num
```

**Returns:** 31 unique queues (8000, 8001, 8002, etc.)

**Notes:**
- Uses DISTINCT on q_num to get unique queues
- LEFT JOIN to get queue names where available
- Falls back to "Queue " + number if no name found

---

### 2. GetCustomReportDataAsync - Dynamic Report Query

**Purpose:** Execute user-configured report with selected columns and filters

**Location:** `Services/CustomReportService.cs` - Line 75

**Dynamic SQL Structure:**
```sql
SELECT TOP {maxRows}
    {selectClause}          -- User-selected columns
FROM [dbo].[callcent_queuecalls]
WHERE 
    [time_start] >= @StartDate
    AND [time_start] < DATEADD(DAY, 1, @EndDate)
    AND [q_num] IN ({queueIdList})  -- Optional queue filter
{groupByClause}             -- If aggregate columns selected
{orderByClause}             -- Based on selected columns
```

**Available Columns (Whitelisted):**

| Column Name | SQL Expression | Description |
|-------------|---------------|-------------|
| QueueNumber | `[q_num]` | Queue identifier |
| TotalCalls | `COUNT(*)` | Total call count |
| PolledCount | `SUM([count_polls])` | Times call was offered |
| DialedCount | `SUM([count_dialed])` | Outbound dial attempts |
| RejectedCount | `SUM([count_rejected])` | Rejected/declined calls |
| AvgWaitTime | `AVG(DATEDIFF(SECOND, 0, [ts_waiting]))` | Average wait in seconds |
| AvgServiceTime | `AVG(DATEDIFF(SECOND, 0, [ts_servicing]))` | Average service in seconds |
| Date | `CAST([time_start] AS DATE)` | Date (for grouping) |

**Parameters:**
- `@StartDate` - Report start date
- `@EndDate` - Report end date  
- `maxRows` - Maximum rows (default 10000)

**Security:**
- Column whitelist prevents SQL injection
- Parameterized dates prevent injection
- Queue IDs validated before inclusion

---

## Table Schema Reference

### callcent_queuecalls

| Column | Type | Description |
|--------|------|-------------|
| q_num | varchar | Queue number (e.g., "8001") |
| time_start | datetime | Call start timestamp |
| ts_waiting | time | Time spent waiting |
| ts_servicing | time | Time spent in service |
| count_polls | int | Times call was offered to agents |
| count_dialed | int | Outbound dial attempts |
| count_rejected | int | Times call was rejected |

### queue

| Column | Type | Description |
|--------|------|-------------|
| fkiddn | int | Foreign key to dn table |
| name | varchar | Queue display name |

### dn

| Column | Type | Description |
|--------|------|-------------|
| iddn | int | Primary key (DN ID) |

---

## Performance Notes

- **Indexes:** Ensure index on `time_start` for date range queries
- **Row Limit:** Default 10,000 rows to prevent memory issues
- **Query Time:** Target < 5 seconds for typical queries
- **Data Volume:** ~4,192 records (Dec 2023 - Oct 2025)

---

## Adding New Queries

When adding new SQL queries:

1. Add SQL to whitelist in `AllowedColumns` dictionary
2. Document the query in this file
3. Use parameterized queries only (never string concatenation)
4. Add logging for query execution time
5. Test with date ranges spanning the full data set

---

*Last Updated: December 30, 2025*
