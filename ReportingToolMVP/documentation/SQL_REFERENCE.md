# SQL Reference — Stored Procedures for the Queue Performance Dashboard

> **Database:** 3CX Exporter | **Server:** 3.132.72.134 (Production)  
> **Last Updated:** February 18, 2026

---

## Table of Contents

1. [Overview](#1-overview)
2. [Shared Concepts — Read This First](#2-shared-concepts)
3. [SP 1: sp_queue_stats_summary — KPI Cards](#3-sp-1-kpi-cards)
4. [SP 2: sp_queue_stats_daily_summary — Daily Chart Data](#4-sp-2-daily-chart-data)
5. [SP 3: qcall_cent_get_extensions_statistics_by_queues — Agent Table](#5-sp-3-agent-table)
6. [Database Schema Reference](#6-database-schema-reference)
7. [How the Application Uses These SPs](#7-application-usage)
8. [Testing Guide](#8-testing-guide)

---

## 1. Overview

The Queue Performance Dashboard report uses **three stored procedures**, each feeding a different section of the report:

```
┌─────────────────────────────────────────────────────────────┐
│                  QUEUE PERFORMANCE DASHBOARD                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  KPI CARDS (8 metrics)                               │   │
│  │  ← sp_queue_stats_summary (1 row)                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AREA CHART (Answered vs Abandoned over time)        │   │
│  │  ← sp_queue_stats_daily_summary (1 row/day)          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AGENT TABLE (per-agent performance)                 │   │
│  │  ← qcall_cent_get_extensions_statistics_by_queues   │   │
│  │     (1 row per agent per queue)                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

All three SPs share **identical parameters** and use the **same base CTE** (`queue_all_calls`), ensuring consistency across report sections.

---

## 2. Shared Concepts

### 2.1 Common Parameters

The KPI and Chart SPs (`sp_queue_stats_summary`, `sp_queue_stats_daily_summary`) share 5 parameters:

| Parameter | SQL Type | Example | Description |
|-----------|----------|---------|-------------|
| `@from` | `DATETIMEOFFSET` | `'2026-02-01 00:00:00 +00:00'` | Start of the reporting period (inclusive, UTC) |
| `@to` | `DATETIMEOFFSET` | `'2026-02-17 00:00:00 +00:00'` | End of the reporting period (exclusive, UTC) |
| `@queue_dns` | `VARCHAR(MAX)` | `'8000,8089'` | **REQUIRED:** Comma-separated queue DN numbers |
| `@sla_seconds` | `INT` | `20` | SLA threshold in seconds (default: 20) |
| `@report_timezone` | `VARCHAR(100)` | `'India Standard Time'` | Timezone for date display (NULL = UTC) |

The Agent SP (`qcall_cent_get_extensions_statistics_by_queues`) uses different parameter names:

| Parameter | SQL Type | Example | Description |
|-----------|----------|---------|-------------|
| `@period_from` | `DATETIMEOFFSET` | `'2026-02-01 00:00:00'` | Start of the reporting period (inclusive) |
| `@period_to` | `DATETIMEOFFSET` | `'2026-02-17 23:59:59'` | End of the reporting period (inclusive) |
| `@queue_dns` | `VARCHAR(MAX)` | `'8000,8089'` | Comma-separated queue DN numbers |
| `@wait_interval` | `TIME` | `'00:00:20'` | SLA threshold as TIME. Also filters out instant abandoned calls |

**Why `DATETIMEOFFSET`?** The 3CX database stores timestamps with timezone offsets. Using `DATETIMEOFFSET` ensures correct comparison without implicit conversion.

**Why `VARCHAR(MAX)` for queue DNs?** Allows passing any number of queues as a single comma-separated string. The SPs use `STRING_SPLIT()` to parse individual values. This approach avoids table-valued parameters which complicate the DevExpress Data Source Wizard.

**Key Differences:**
- KPI/Chart SPs use `@from`/`@to` (exclusive end); Agent SP uses `@period_from`/`@period_to` (inclusive end with BETWEEN)
- KPI/Chart SPs use `@sla_seconds` (INT); Agent SP uses `@wait_interval` (TIME)
- KPI/Chart SPs support `@report_timezone` for timezone-aware date display; Agent SP does not

### 2.2 Base Query Pattern

The KPI and Chart SPs (`sp_queue_stats_summary`, `sp_queue_stats_daily_summary`) use a direct JOIN between `queue_view` and `callcent_queuecalls_view`:

```sql
FROM dbo.queue_view qv
INNER JOIN dbo.callcent_queuecalls_view q
    ON q.q_num = qv.dn
   AND q.time_start >= @from
   AND q.time_start <  @to
WHERE qv.dn IN (SELECT TRIM(value) FROM STRING_SPLIT(@queue_dns, ','))
```

The Agent SP (`qcall_cent_get_extensions_statistics_by_queues`) uses a CTE called `queue_all_calls` that filters on date range, queue, and call quality:

```sql
;WITH queue_all_calls AS
(
    SELECT
        qcv.q_num AS queue_dn,
        qcv.to_dn AS extension_dn,
        qcv.ts_servicing,
        qcv.is_answered,
        qcv.call_history_id,
        DATEDIFF(SECOND, 0, qcv.ring_time) AS ring_seconds,
        DATEDIFF(SECOND, 0, qcv.ts_servicing) AS talk_seconds

    FROM CallCent_QueueCalls_View qcv WITH (NOLOCK)
    WHERE
        qcv.time_start BETWEEN @period_from AND @period_to
        AND (
            @queue_dns = '' OR @queue_dns IS NULL 
            OR qcv.q_num IN (SELECT LTRIM(value) FROM string_split(@queue_dns, ','))
        )
        AND (qcv.is_answered = 1 OR qcv.ring_time >= @wait_interval)
)
```

> **Note:** The KPI/Chart SPs use `queue_view` (an expanded queue metadata view) JOINed with `callcent_queuecalls_view` (call records). The Agent SP uses `CallCent_QueueCalls_View` directly with a call-quality filter via `@wait_interval`.

#### Why consistent filtering matters

Every metric in the dashboard must use the **exact same set of calls**. If SP1 counts 150 total calls and SP2 shows 160 total calls across dates, the dashboard would be inconsistent.

### 2.3 Understanding the Key Filters

#### Filter 1: Date Range

KPI/Chart SPs use exclusive end range:
```sql
q.time_start >= @from AND q.time_start < @to
```

Agent SP uses inclusive BETWEEN:
```sql
qcv.time_start BETWEEN @period_from AND @period_to
```

Selects calls that **started** within the specified period. `time_start` is the timestamp when the call entered the queue.

#### Filter 2: Queue Selection

KPI/Chart SPs (**@queue_dns is REQUIRED**):
```sql
qv.dn IN (SELECT TRIM(value) FROM STRING_SPLIT(@queue_dns, ','))
```

Agent SP (optional — empty/NULL = all queues):
```sql
@queue_dns = '' OR @queue_dns IS NULL 
OR qcv.q_num IN (SELECT LTRIM(value) FROM string_split(@queue_dns, ','))
```

#### Filter 3: Call Quality (Agent SP only)
```sql
qcv.is_answered = 1 OR qcv.ring_time >= @wait_interval
```

This filter is used by the Agent SP to exclude **"instant drops"** — calls that hung up almost immediately. The KPI/Chart SPs include all calls (answered + abandoned) without call-quality filtering, using `@sla_seconds` only for the SLA metric calculations.

| Call Status | Ring Time vs SLA | Included? | Reasoning |
|-------------|------------------|-----------|-----------|
| Answered (`is_answered = 1`) | Any | ✅ Yes | All answered calls count |
| Abandoned (`is_answered = 0`) | ≥ SLA threshold | ✅ Yes | Caller waited meaningfully |
| Abandoned (`is_answered = 0`) | < SLA threshold | ❌ No | Instant hang-up, not a real attempt |

**Why this matters:** If a robocall dials into the queue and drops after 1 second, you don't want that counted as an abandoned call. The `@wait_interval` threshold filters these out.

### 2.4 `WITH (NOLOCK)` — Performance Consideration

All queries use `WITH (NOLOCK)` (read uncommitted isolation). This means:
- **Faster reads:** No shared locks acquired
- **No blocking:** Read queries don't block write operations
- **Trade-off:** Slight chance of reading uncommitted (dirty) data

For a reporting/analytics application reading historical data, this trade-off is acceptable. The data being queried is finalized call history, not actively changing transactional data.

### 2.5 Database Views Used

| View | What It Contains | Used By |
|------|-----------------|---------|
| `CallCent_QueueCalls_View` | One row per call that entered a queue. Columns: `q_num` (queue DN), `to_dn` (agent extension), `time_start`, `ring_time`, `ts_servicing` (talk duration), `is_answered`, `call_history_id` | All 3 SPs |
| `extensions_by_queues_view` | Mapping of queue DNs to extension DNs with display names. Columns: `queue_dn`, `queue_display_name`, `extension_dn`, `extension_display_name` | SP1 + SP3 |

These are **pre-existing views** in the 3CX Exporter database (managed by 3CX). The SPs only **read** from them.

---

## 3. SP 1: `sp_queue_stats_summary` — KPI Cards

### Purpose

Returns a **single row** with aggregated metrics across all selected queues. This row feeds the 8 KPI cards in the report header.

### Output — Always Exactly 1 Row

| Column | Type | Example | KPI Card |
|--------|------|---------|----------|
| `queue_group` | varchar | `'SUMMARY'` | Fixed label |
| `description` | varchar | `'8000,8089'` | Filter info display (equals `@queue_dns` input) |
| `total_calls` | int | `487` | Card 1: Total Calls |
| `abandoned_calls` | int | `52` | Card 2: Abandoned |
| `answered_calls` | int | `435` | Card 3: Answered |
| `answered_percent` | decimal(5,2) | `89.32` | Card 4: Answer Rate |
| `answered_within_sla` | int | `380` | Within SLA count |
| `answered_within_sla_percent` | decimal(5,2) | `87.36` | Card 5: SLA % |
| `serviced_callbacks` | int | `0` | Card 8: Callbacks |
| `total_talking` | time | `12:45:30` | Card 6: Total Talk Time |
| `mean_talking_time` | time | `00:01:45` | Card 5: Avg Talk |
| `avg_wait_time` | time | `00:00:23` | Card 7: Avg Wait |
| `longest_wait_time` | time | `00:02:10` | Longest wait time |
| `period_from_utc` | datetimeoffset | `2026-02-01 00:00:00 +00:00` | Report period info |
| `period_to_utc` | datetimeoffset | `2026-02-17 00:00:00 +00:00` | Report period info |
| `period_from_local` | datetimeoffset | `2026-02-01 05:30:00 +05:30` | Timezone-adjusted period |
| `period_to_local` | datetimeoffset | `2026-02-17 05:30:00 +05:30` | Timezone-adjusted period |
| `report_timezone_used` | varchar | `'India Standard Time'` | Which timezone was applied |

### How It Works — Step by Step

```
Step 1: CTE queue_all_calls
        Selects all qualifying calls (date + queue + quality filters)
        Each row = one call

Step 2: CTE queue_names  
        Fetches display names for all queues from extensions_by_queues_view
        Each row = one queue (with display name)

Step 3: Final SELECT (NO GROUP BY)
        Aggregates ALL rows from queue_all_calls into 1 row
        JOINs with queue_names for display name logic
```

### Key Aggregation Details

**Queue Display Name Logic:**
```sql
CASE 
    WHEN COUNT(DISTINCT qn.queue_dn) = 1 THEN MIN(qn.queue_display_name)    -- "Support Queue"
    WHEN COUNT(DISTINCT qn.queue_dn) > 1 THEN 'Multiple Queues (' 
         + CAST(COUNT(DISTINCT qn.queue_dn) AS VARCHAR(10)) + ')'            -- "Multiple Queues (3)"
    ELSE '-'                                                                  -- No data
END
```
When a single queue is selected, show its name. When multiple, show a summary with count.

**Answer Rate:**
```sql
answered_calls * 100.0 / total_calls
-- Example: 435 * 100.0 / 487 = 89.32%
```

**SLA Percentage (calculated on answered calls only, NOT total):**
```sql
answered_within_sla * 100.0 / answered_calls  (not total_calls!)
-- Example: 380 * 100.0 / 435 = 87.36%
-- WHY: SLA measures how quickly answered calls were picked up.
--       Abandoned calls can't be "within SLA" — they were never answered.
```

**Total Talking Time:**
```sql
DATEADD(SECOND, SUM(talk_seconds WHERE is_answered = 1), 0) AS TIME
-- Adds up all talk seconds for answered calls, then converts to TIME format
-- Returns something like 12:45:30
```

**Mean Talking Time:**
```sql
SUM(talk_seconds for answered) / COUNT(answered calls)
-- Average talk duration per answered call
```

### Why No GROUP BY?

Version 1 of this SP had `GROUP BY queue_dn`, returning one row per queue. This broke the KPI cards because:
1. DevExpress XRLabel binds to the **first row** of the data source
2. With 3 queues, you get 3 rows — only the first queue's data appears in KPI cards
3. The other 2 queues' data is silently ignored

Version 2 removes `GROUP BY` entirely → always 1 aggregated row → KPI cards always work correctly.

---

## 4. SP 2: `sp_queue_stats_daily_summary` — Daily Chart Data

### Purpose

Returns **one row per calendar day** (in local timezone) with call volume metrics. This feeds the area chart showing "Answered vs Abandoned" trends over time. Uses a date-range CTE to ensure days with zero calls still appear.

### Output — 1 Row Per Day

| Column | Type | Example | Chart Usage |
|--------|------|---------|-------------|
| `report_date_local` | date | `2026-02-01` | **X-axis** (ArgumentDataMember) — date in local timezone |
| `total_calls` | int | `23` | Available for tooltips |
| `abandoned_calls` | int | `3` | **Series 2 value** (Area, red) |
| `answered_calls` | int | `20` | **Series 1 value** (Area, green) |
| `answered_percent` | decimal(5,2) | `86.96` | Available for tooltips |
| `answered_within_sla` | int | `18` | Available for tooltips |
| `answered_within_sla_percent` | decimal(5,2) | `90.00` | Available for tooltips |
| `serviced_callbacks` | int | `0` | Available for tooltips |
| `total_talking` | time | `02:15:30` | Daily total talk time |
| `mean_talking_time` | time | `00:06:47` | Daily avg talk time |
| `avg_wait_time` | time | `00:00:12` | Daily avg wait time |
| `longest_wait_time` | time | `00:01:45` | Daily max wait time |
| `period_from_utc` | datetimeoffset | `2026-02-01 00:00:00 +00:00` | Report period info |
| `period_to_utc` | datetimeoffset | `2026-02-17 00:00:00 +00:00` | Report period info |
| `period_from_local` | datetimeoffset | `2026-02-01 05:30:00 +05:30` | Timezone-adjusted period |
| `period_to_local` | datetimeoffset | `2026-02-17 05:30:00 +05:30` | Timezone-adjusted period |
| `report_timezone_used` | varchar | `'India Standard Time'` | Which timezone was applied |

### How It Works — Step by Step

```
Step 1: DateRange CTE — recursive date series
        Generates one row per day from @from to @to-1 day (in local timezone)
        using CAST(@from AT TIME ZONE 'UTC' AT TIME ZONE @report_timezone AS DATE)

Step 2: DailyStats CTE — aggregate call data per local date
        Joins queue_view + callcent_queuecalls_view
        Converts time_start to local timezone date for grouping
        GROUP BY local date

Step 3: Final SELECT — LEFT JOIN DateRange with DailyStats
        Ensures days with ZERO calls still appear (with 0 values)
        ORDER BY report_date_local (chronological)
```

### Why Date Range CTE?

Unlike the old SP which only returned days that had calls, the new SP generates a complete date sequence using a recursive CTE. Days with no calls get ISNULL-filled zeros. This prevents gaps in the area chart's X-axis.
```

With per-queue grouping, the chart shows overlapping/stacked data points for the same date, which is confusing and incorrect for a consolidated view.

### Chart Binding

In the .repx file, the XRChart uses these bindings:
```
ArgumentDataMember = "call_date"              → X-axis (Date)
Series 1 (Answered):    ValueDataMembers = "answered_calls"
Series 2 (Abandoned):   ValueDataMembers = "abandoned_calls"
```

---

## 5. SP 3: `qcall_cent_get_extensions_statistics_by_queues` — Agent Table

### Purpose

Returns **one row per agent per queue** with individual agent performance metrics. This feeds the agent detail table at the bottom of the report.

### Output — Multiple Rows

| Column | Type | Example | Table Column |
|--------|------|---------|--------------|
| `queue_dn` | varchar | `8000` | Queue DN |
| `queue_display_name` | varchar | `Support Queue` | Queue Name |
| `extension_dn` | varchar | `1001` | Agent Extension |
| `extension_display_name` | varchar | `John Smith` | Agent Name |
| `queue_received_count` | int | `487` | Calls Received (by queue total) |
| `extension_answered_count` | int | `45` | Calls Answered (by this agent) |
| `talk_time` | time | `01:23:45` | Total Talk Time |
| `avg_talk_time` | time | `00:01:51` | Avg Talk Per Call |
| `avg_answer_time` | time | `00:00:08` | Avg Answer Speed |

### How It Works — Step by Step

This SP is the most complex, using **three CTEs** that build on each other:

```
Step 1: CTE queue_all_calls
        All qualifying calls (same base filter as SP1/SP2)
        NO date extraction needed — we aggregate across the full period

Step 2: CTE queue_received_calls
        GROUP BY queue_dn → COUNT(*) per queue
        Result: How many total calls each queue received
        
        queue_dn | received_count
        8000     | 487
        8089     | 203

Step 3: CTE extension_answered
        GROUP BY queue_dn, extension_dn → per-agent answered statistics
        Only WHERE is_answered = 1 (only answered calls count for agents)
        
        queue_dn | extension_dn | answered_count | total_talk_seconds | avg_answer_seconds
        8000     | 1001         | 45             | 5025               | 8
        8000     | 1002         | 38             | 4180               | 6
        8089     | 1001         | 22             | 2640               | 12

Step 4: Final SELECT
        Base table: extensions_by_queues_view (ALL agents in ALL selected queues)
        LEFT JOIN queue_received_calls → adds queue total
        LEFT JOIN extension_answered → adds agent metrics
```

### Why LEFT JOINs Matter

```sql
FROM extensions_by_queues_view eqv          -- All agents (even those with 0 calls)
LEFT JOIN queue_received_calls qrc          -- Queue totals (may have no calls)
LEFT JOIN extension_answered ea             -- Agent metrics (may have answered nothing)
```

Using `LEFT JOIN` (not `INNER JOIN`) ensures:
- Agents who didn't answer any calls still appear in the table (with 0 counts)
- Queues that received no calls during the period still show their agents
- This matches the expected behavior: show all agents, even inactive ones

The `ISNULL(..., 0)` and `ISNULL(..., '00:00:00')` wrappers handle NULL values from unmatched LEFT JOINs.

### Time Conversion Pattern

All three SPs use the same pattern to convert seconds to `TIME` format:

```sql
-- Convert total_talk_seconds (integer) to TIME display
ISNULL(
    CAST(
        DATEADD(SECOND, ea.total_talk_seconds, 0)  -- Add seconds to midnight (1900-01-01 00:00:00)
    AS TIME),                                        -- Cast result to TIME (drops date portion)
    CAST('00:00:00' AS TIME)                         -- Default if NULL
)

-- Step by step:
-- total_talk_seconds = 5025
-- DATEADD(SECOND, 5025, 0) = '1900-01-01 01:23:45.000'
-- CAST(... AS TIME) = '01:23:45'
```

### Average Talk Time Calculation

```sql
CASE 
    WHEN ea.answered_count > 0 
    THEN ea.total_talk_seconds / ea.answered_count  -- Integer division
    ELSE 0 
END
-- 5025 / 45 = 111 seconds → 00:01:51
```

Note: This uses **integer division**, which truncates. For 45 calls with 5025 total seconds: 5025 / 45 = 111 (not 111.67). This is acceptable for HH:MM:SS display.

---

## 6. Database Schema Reference

### CallCent_QueueCalls_View

This is a 3CX-managed view (we don't control its schema). Key columns used:

| Column | Type | Description |
|--------|------|-------------|
| `q_num` | varchar | Queue DN number (e.g., `'8000'`) |
| `to_dn` | varchar | Extension DN of the agent who received the call |
| `time_start` | datetimeoffset | When the call entered the queue |
| `ring_time` | time | How long the call rang/waited before answer or abandon |
| `ts_servicing` | time | Duration of the conversation (talk time) |
| `is_answered` | bit | 1 = call was answered, 0 = abandoned |
| `call_history_id` | int | Unique identifier for the call |

### extensions_by_queues_view

Also 3CX-managed. Maps agents to queues with human-readable names:

| Column | Type | Description |
|--------|------|-------------|
| `queue_dn` | varchar | Queue DN number |
| `queue_display_name` | varchar | Human-readable queue name (e.g., `'Support Queue'`) |
| `extension_dn` | varchar | Agent extension number |
| `extension_display_name` | varchar | Agent full name (e.g., `'John Smith'`) |

### Relationship Between Views

```
CallCent_QueueCalls_View                extensions_by_queues_view
┌────────────────────────┐              ┌────────────────────────────┐
│ q_num (queue DN)       │◄────────────►│ queue_dn                   │
│ to_dn (extension DN)   │◄────────────►│ extension_dn               │
│ time_start             │              │ queue_display_name         │
│ ring_time              │              │ extension_display_name     │
│ ts_servicing           │              └────────────────────────────┘
│ is_answered            │
│ call_history_id        │
└────────────────────────┘

Join condition (in SP3):
  extensions_by_queues_view.queue_dn = queue_all_calls.queue_dn
  extensions_by_queues_view.extension_dn = queue_all_calls.extension_dn
```

---

## 7. How the Application Uses These SPs

### In the Report Generator (`QueuePerformanceDashboardGenerator.cs`)

The generator creates three `SqlDataSource` objects, one per SP:

```
SqlDataSource "dsKPIs"
  └── StoredProcQuery("KPIs")
      └── SP: sp_queue_stats_summary
      └── Params: @from → [Parameters.pPeriodFrom]
                  @to → [Parameters.pPeriodTo]
                  @queue_dns → [Parameters.pQueueDns]
                  @sla_seconds → [Parameters.pSlaSeconds]
                  @report_timezone → [Parameters.pReportTimezone]
      └── Used by: KPI card labels (XRLabel expressions)

SqlDataSource "dsChartData"
  └── StoredProcQuery("ChartData")
      └── SP: sp_queue_stats_daily_summary
      └── Params: (same 5 as above)
      └── Used by: XRChart with 2 Area series

SqlDataSource "dsAgents"
  └── StoredProcQuery("Agents")
      └── SP: qcall_cent_get_extensions_statistics_by_queues
      └── Params: @period_from → [Parameters.pPeriodFrom]
                  @period_to → [Parameters.pPeriodTo]
                  @queue_dns → [Parameters.pQueueDns]
                  @wait_interval → [Parameters.pWaitInterval]
      └── Used by: DetailReportBand with agent table
```

### Parameter Binding Chain

```
User types in Preview → Report Parameter → Expression → SP Parameter → SQL WHERE clause

Example (KPI/Chart SPs):
User enters: "2026-02-01" in Start Date field
  → pPeriodFrom report parameter = 2026-02-01T00:00:00
    → Expression: [Parameters.pPeriodFrom]
      → QueryParameter: @from = [Parameters.pPeriodFrom]
        → SQL: WHERE q.time_start >= '2026-02-01T00:00:00' AND q.time_start < @to

Example (Agent SP):
Same flow but parameter names differ:
  → QueryParameter: @period_from = [Parameters.pPeriodFrom]
    → SQL: WHERE qcv.time_start BETWEEN '2026-02-01T00:00:00' AND @period_to
```

### In the Report Designer (Manual Report Creation)

When creating a report manually in the Designer, the user:
1. Creates 6 Report Parameters (pPeriodFrom, pPeriodTo, pQueueDns, pWaitInterval, pSlaSeconds, pReportTimezone)
2. Opens Data Source Wizard
3. Selects connection "3CX_Exporter_Production"
4. Chooses "Stored Procedure" query type
5. Selects the SP name from dropdown
6. Uses `?paramName` syntax to bind SP parameters to Report Parameters directly

See `MANUAL_REPORT_CREATION_GUIDE.md` for the complete step-by-step process.

---

## 8. Testing Guide

### Running SPs Manually in SSMS

**SP 1 — KPI Summary:**
```sql
EXEC dbo.[sp_queue_stats_summary]
    @from            = '2026-02-01 00:00:00 +00:00',
    @to              = '2026-02-17 00:00:00 +00:00',
    @queue_dns       = '8000',
    @sla_seconds     = 20,
    @report_timezone = 'India Standard Time';
```

Expected: Exactly **1 row** with 18 columns.

**SP 2 — Daily Chart Data:**
```sql
EXEC dbo.[sp_queue_stats_daily_summary]
    @from            = '2026-02-01 00:00:00 +00:00',
    @to              = '2026-02-17 00:00:00 +00:00',
    @queue_dns       = '8000',
    @sla_seconds     = 20,
    @report_timezone = 'India Standard Time';
```

Expected: **One row per day** in the date range (including zero-call days), ordered by `report_date_local`.

**SP 3 — Agent Statistics:**
```sql
EXEC dbo.[qcall_cent_get_extensions_statistics_by_queues]
    @period_from = '2026-02-01 00:00:00',
    @period_to = '2026-02-09 23:59:59',
    @queue_dns = '8000,8089',
    @wait_interval = '00:00:05';
```

Expected: **One row per agent per queue**, ordered by queue_dn then extension_dn.

### Validation Checks

**Cross-SP Consistency (SP1 vs SP2):**
```sql
-- SP1's total_calls should equal sum of SP2's total_calls across all dates
-- Run both SPs with same parameters, then compare:
-- SP1: total_calls = 487
-- SP2: SUM(total_calls) across all dates = 487 ← Must match
```

**SP1 Arithmetic:**
```sql
-- total_calls = answered_calls + abandoned_calls
-- answered_percent = answered_calls * 100.0 / total_calls
-- answered_within_sla_percent = answered_within_sla * 100.0 / answered_calls (NOT total_calls)
```

**Multi-Queue Test:**
```sql
-- Run with single queue: @queue_dns = '8000'        → Note total_calls
-- Run with single queue: @queue_dns = '8089'        → Note total_calls  
-- Run with both:         @queue_dns = '8000,8089'   → total_calls should equal sum of above
```

**All-Queues Test:**
```sql
-- Run with @queue_dns = '' → Should return data across ALL queues in the database
```

### Automated Tests (xUnit)

The project includes integration tests in `ReportingToolMVP.Tests/`:

| Test File | Tests | SP Tested |
|-----------|-------|-----------|
| `KpiStoredProcTests.cs` | Row count, column presence, arithmetic consistency | SP1 |
| `ChartStoredProcTests.cs` | Date ordering, sum consistency with SP1 | SP2 |
| `AgentStoredProcTests.cs` | Agent presence, queue grouping, time calculations | SP3 |

Run with:
```powershell
cd ReportingToolMVP.Tests
dotnet test
```

---

*End of SQL Reference*
