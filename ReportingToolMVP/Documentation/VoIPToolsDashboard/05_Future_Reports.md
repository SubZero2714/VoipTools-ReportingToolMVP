# Future Reports Roadmap

This document outlines planned report types and their implementation approach.

---

## Current State

### ✅ Completed: VoIPTools Dashboard
- KPI cards, Agent table, Call Trends chart
- Uses SQL views for data
- Single-page layout

---

## Planned Report Types

### Report Category Matrix

| Report | Focus | Time Granularity | Key Metrics |
|--------|-------|------------------|-------------|
| **Agent Performance** | Individual agents | Daily/Weekly | Calls, Talk Time, Answer Rate |
| **Queue Performance** | Individual queues | Daily/Weekly | Volume, SLA, Wait Times |
| **Hourly Analysis** | Peak hours | Hourly | Call distribution |
| **Monthly Summary** | Management overview | Monthly | KPIs, Trends, Comparisons |
| **SLA Compliance** | Service levels | Daily/Weekly | SLA %, Breaches |
| **Caller Experience** | Wait/Abandon analysis | Daily | Wait times, Abandon rate |

---

## Phase 1: Agent Reports (Priority: High)

### 1.1 Agent Summary Report
**File:** `AgentPerformanceReport.repx`

**Purpose:** Detailed performance for a single agent or all agents

**Data Source Query:**
```sql
CREATE VIEW vw_AgentDetailedPerformance AS
SELECT
    to_dn AS AgentExtension,
    CONCAT(to_dn, ' - Agent') AS AgentName,
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'yyyy-MM') AS MonthKey,
    
    -- Daily Metrics
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS Answered,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS Missed,
    
    -- Time Metrics (seconds for calculations)
    AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS AvgTalkSeconds,
    SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)) AS TotalTalkSeconds,
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitSeconds,
    
    -- Answer Rate
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                                 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 1)
    END AS AnswerRatePercent
    
FROM callcent_queuecalls
WHERE to_dn IS NOT NULL
GROUP BY to_dn, CAST(time_start AS DATE), FORMAT(time_start, 'yyyy-MM');
```

**Report Sections:**
1. Agent Header (name, extension, photo placeholder)
2. KPI summary (Calls, Answer Rate, Avg Talk)
3. Daily performance table
4. Weekly trend chart
5. Comparison to team average

**Filters:**
- Agent selection (dropdown)
- Date range (start/end)
- Queue filter (optional)

---

### 1.2 Agent Comparison Report
**Purpose:** Compare multiple agents side-by-side

**Layout:**
```
┌────────────────────────────────────────────────┐
│ Agent Comparison: January 2026                 │
├───────┬───────┬───────┬───────┬───────┬───────┤
│ Agent │ Calls │ Ans % │ AvgTk │ SLA % │ Rank  │
├───────┼───────┼───────┼───────┼───────┼───────┤
│ 1006  │  772  │  92%  │ 01:28 │  85%  │   1   │
│ 2700  │  242  │  88%  │ 01:47 │  80%  │   2   │
│ ...   │  ...  │  ...  │  ...  │  ...  │  ...  │
└───────┴───────┴───────┴───────┴───────┴───────┘
         ╔═══════════════════════════════╗
         ║    Bar Chart: Calls by Agent  ║
         ╚═══════════════════════════════╝
```

---

## Phase 2: Queue Reports (Priority: High)

### 2.1 Queue Summary Report
**File:** `QueuePerformanceReport.repx`

**Purpose:** Performance analysis for specific queues

**Data Source Query:**
```sql
CREATE VIEW vw_QueueDetailedPerformance AS
SELECT
    q_num AS QueueNumber,
    COALESCE(q_name, CONCAT('Queue ', q_num)) AS QueueName,
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'yyyy-MM') AS MonthKey,
    
    -- Volume Metrics
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS Answered,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS Abandoned,
    
    -- SLA (20 second threshold)
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
              AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
         THEN 1 ELSE 0 END) AS WithinSLA,
    
    -- Wait Time Analysis
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitSeconds,
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitSeconds,
    
    -- Peak Hour (most common)
    DATEPART(HOUR, time_start) AS CallHour
    
FROM callcent_queuecalls
GROUP BY q_num, q_name, CAST(time_start AS DATE), 
         FORMAT(time_start, 'yyyy-MM'), DATEPART(HOUR, time_start);
```

**Report Sections:**
1. Queue header with name/number
2. KPI cards (Volume, SLA%, Wait Time)
3. Hourly distribution chart
4. Daily trend table
5. Top agents for this queue

---

### 2.2 Queue Comparison Report
**Purpose:** Compare all queues side-by-side

**Features:**
- Stacked bar chart showing relative volumes
- SLA comparison across queues
- Busiest queue identification

---

## Phase 3: Time-Based Reports (Priority: Medium)

### 3.1 Hourly Analysis Report
**Purpose:** Identify peak hours and staffing needs

**Data Source Query:**
```sql
CREATE VIEW vw_HourlyAnalysis AS
SELECT
    DATEPART(HOUR, time_start) AS HourOfDay,
    CONCAT(RIGHT('0' + CAST(DATEPART(HOUR, time_start) AS VARCHAR), 2), ':00') AS HourLabel,
    DATENAME(WEEKDAY, time_start) AS DayOfWeek,
    
    COUNT(*) AS Calls,
    AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS AvgWaitSeconds,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS Abandoned
    
FROM callcent_queuecalls
GROUP BY DATEPART(HOUR, time_start), DATENAME(WEEKDAY, time_start);
```

**Visualizations:**
- Heat map: Hours (Y) vs Days (X), color = call volume
- Line chart: Hourly call pattern
- Peak hours identification

---

### 3.2 Monthly Summary Report
**File:** `MonthlySummaryReport.repx`

**Purpose:** Executive summary for a specific month

**Structure:**
```
┌──────────────────────────────────────────────────────┐
│  MONTHLY PERFORMANCE SUMMARY - JANUARY 2026          │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ KPI Cards: Total | Answered | SLA | Wait Time  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  ┌────────────────────┐ ┌────────────────────┐      │
│  │ Daily Trend Chart  │ │ Queue Breakdown    │      │
│  │ (Line graph)       │ │ (Pie chart)        │      │
│  └────────────────────┘ └────────────────────┘      │
│                                                      │
│  ┌────────────────────┐ ┌────────────────────┐      │
│  │ Top 5 Agents       │ │ Hourly Distribution│      │
│  │ (Table)            │ │ (Bar chart)        │      │
│  └────────────────────┘ └────────────────────┘      │
│                                                      │
│  Month-over-Month Comparison: +15% calls, +5% SLA   │
└──────────────────────────────────────────────────────┘
```

**Filters:**
- Year dropdown
- Month dropdown
- Compare to previous month (toggle)

---

### 3.3 Weekly Report
**Purpose:** Week-by-week performance tracking

**Features:**
- Week number selection
- Day-by-day breakdown
- Weekend vs weekday comparison

---

## Phase 4: Specialized Reports (Priority: Low)

### 4.1 SLA Compliance Report
**Focus:** Service Level Agreement tracking

**Metrics:**
- SLA % by hour, day, week
- Breaches count and details
- Trend over time
- Threshold configuration (20s, 30s, 60s)

### 4.2 Abandoned Calls Analysis
**Focus:** Why callers hang up

**Metrics:**
- Abandon rate by time of day
- Average wait before abandon
- Repeat callers who abandoned
- Queue-specific abandon patterns

### 4.3 Caller Experience Report
**Focus:** Customer journey analysis

**Metrics:**
- First-call resolution indicators
- Repeat caller identification
- Long wait time analysis
- Transfer tracking (if available)

---

## Implementation Priority

### Phase 1 (Weeks 1-2)
1. ✅ VoIPTools Dashboard (DONE)
2. 🔲 Agent Summary Report
3. 🔲 Queue Summary Report

### Phase 2 (Weeks 3-4)
4. 🔲 Monthly Summary Report
5. 🔲 Agent Comparison Report
6. 🔲 Queue Comparison Report

### Phase 3 (Weeks 5-6)
7. 🔲 Hourly Analysis Report
8. 🔲 Weekly Report
9. 🔲 SLA Compliance Report

### Phase 4 (Future)
10. 🔲 Abandoned Calls Analysis
11. 🔲 Caller Experience Report
12. 🔲 Custom Report Builder integration

---

## Filter Implementation Strategy

### Report Parameters

Each report should support these common parameters:

```csharp
public class ReportParameters
{
    // Time Filters
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string TimePeriod { get; set; }  // "Today", "ThisWeek", "ThisMonth", "Custom"
    
    // Granularity
    public string GroupBy { get; set; }  // "Hour", "Day", "Week", "Month"
    
    // Entity Filters
    public string[] QueueNumbers { get; set; }
    public string[] AgentExtensions { get; set; }
    
    // Display Options
    public int TopN { get; set; } = 10;  // For "Top 10" type queries
    public bool IncludeChart { get; set; } = true;
}
```

### Time Period Presets

| Preset | Description | SQL Filter |
|--------|-------------|------------|
| Today | Current date | `CAST(time_start AS DATE) = CAST(GETDATE() AS DATE)` |
| Yesterday | Previous date | `CAST(time_start AS DATE) = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))` |
| This Week | Mon-Sun current | `DATEPART(WEEK, time_start) = DATEPART(WEEK, GETDATE())` |
| Last Week | Mon-Sun previous | `DATEPART(WEEK, time_start) = DATEPART(WEEK, GETDATE()) - 1` |
| This Month | Current month | `MONTH(time_start) = MONTH(GETDATE()) AND YEAR...` |
| Last Month | Previous month | `MONTH(time_start) = MONTH(DATEADD(MONTH, -1, GETDATE()))...` |
| Jan 2026 | Specific month | `time_start >= '2026-01-01' AND time_start < '2026-02-01'` |
| Custom | User-defined | Uses @StartDate, @EndDate parameters |

---

## File Naming Convention

```
Reports/Templates/
├── VoIPToolsDashboard.repx          # Main dashboard
├── AgentPerformance/
│   ├── AgentSummary.repx            # Single agent detail
│   ├── AgentComparison.repx         # Multi-agent comparison
│   └── AgentDaily.repx              # Daily breakdown
├── QueuePerformance/
│   ├── QueueSummary.repx            # Single queue detail
│   ├── QueueComparison.repx         # Multi-queue comparison
│   └── QueueHourly.repx             # Hourly breakdown
├── TimeBased/
│   ├── HourlyAnalysis.repx          # Peak hours
│   ├── WeeklySummary.repx           # Week view
│   └── MonthlySummary.repx          # Month view
└── Specialized/
    ├── SLACompliance.repx           # SLA tracking
    └── AbandonedCalls.repx          # Abandon analysis
```

---

## Next Steps

1. **Choose Next Report:** Agent Summary or Queue Summary
2. **Create SQL Views:** Add filtered views with parameters
3. **Design Layout:** Follow dashboard pattern
4. **Test with Data:** Verify accuracy against raw SQL
5. **Document:** Add to this guide

---

## Questions to Decide

1. **Default Time Range:** What should be the default? Last 30 days? This month?
2. **Export Formats:** PDF only, or also Excel/CSV?
3. **Scheduling:** Should reports auto-generate on schedule?
4. **Email Delivery:** Send reports via email?
5. **Dashboard Integration:** Show reports in main dashboard or separate page?
