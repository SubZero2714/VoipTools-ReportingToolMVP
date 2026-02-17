# Similar to Samuel Sir's Report - SQL Scripts

This folder contains all stored procedures and SQL scripts used by the `Similar_to_samuel_sir's_report.repx` DevExpress report.

> **All NEW SPs are based on the same core logic from senior's `qcall_cent_get_extensions_statistics_by_queues`.**

---

## Report Parameters (Common to All SPs)
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `@period_from` | DATETIMEOFFSET | Start date/time with timezone | Required |
| `@period_to` | DATETIMEOFFSET | End date/time with timezone | Required |
| `@queue_dns` | VARCHAR(MAX) | Comma-separated queue DNs (empty = all) | '' |
| `@wait_interval` | TIME | SLA threshold / wait interval | '00:00:20' |

---

## Stored Procedures Used

### 1. Agent Performance Table - `qcall_cent_get_extensions_statistics_by_queues` (EXISTING)
**Purpose:** Returns agent-level performance data for the Agent Performance Table.

**Example Call:**
```sql
EXEC dbo.[qcall_cent_get_extensions_statistics_by_queues]
    @period_from = '2026-02-01 00:00:00',
    @period_to = '2026-02-09 23:59:59',
    @queue_dns = '8000',
    @wait_interval = '00:00:05';
```

**Returns:**
| Column | Type | Report Mapping |
|--------|------|----------------|
| queue_dn | VARCHAR | (Group by) |
| queue_display_name | VARCHAR | (Header) |
| extension_dn | VARCHAR | Agent column |
| extension_display_name | VARCHAR | Agent column |
| queue_received_count | INT | Calls to Queue |
| extension_answered_count | INT | Answered Calls |
| talk_time | TIME | Total Talk Time |
| avg_talk_time | TIME | Avg Talk Time |
| avg_answer_time | TIME | Avg Answer Time |

---

### 2. KPI Cards - `sp_queue_kpi_summary` ✅ NEW
**Purpose:** Returns queue-level aggregated KPI metrics for the KPI cards section.

**File:** `sp_queue_kpi_summary.sql`

**Example Call:**
```sql
EXEC dbo.[sp_queue_kpi_summary]
    @period_from = '2026-02-01 00:00:00',
    @period_to = '2026-02-09 23:59:59',
    @queue_dns = '8000',
    @wait_interval = '00:00:20';
```

**Returns:**
| Column | Type | Description |
|--------|------|-------------|
| queue_dn | VARCHAR | Queue extension number |
| queue_display_name | VARCHAR | Queue display name |
| total_calls | INT | Total calls received |
| abandoned_calls | INT | Abandoned calls count |
| answered_calls | INT | Answered calls count |
| answered_percent | DECIMAL(5,2) | Answer rate percentage |
| answered_within_sla | INT | Calls answered within SLA |
| answered_within_sla_percent | DECIMAL(5,2) | SLA compliance percentage |
| serviced_callbacks | INT | Callback count |
| total_talking | TIME | Total talk time |
| mean_talking | TIME | Average talk time |
| avg_waiting | TIME | Average wait time |

---

### 3. Call Trends Chart - `sp_queue_calls_by_date` ✅ NEW
**Purpose:** Returns daily call counts for the trend chart visualization.

**File:** `sp_queue_calls_by_date.sql`

**Example Call:**
```sql
EXEC dbo.[sp_queue_calls_by_date]
    @period_from = '2026-02-01 00:00:00',
    @period_to = '2026-02-09 23:59:59',
    @queue_dns = '8000',
    @wait_interval = '00:00:20';
```

**Returns:**
| Column | Type | Description |
|--------|------|-------------|
| call_date | DATE | Date of calls |
| total_calls | INT | Total calls on that date |
| answered_calls | INT | Answered calls |
| abandoned_calls | INT | Abandoned calls |
| answered_within_sla | INT | Calls answered within SLA |
| answer_rate | DECIMAL(5,2) | Answer rate percentage |
| sla_percent | DECIMAL(5,2) | SLA compliance percentage |

---

## Report Layout Mapping

| Report Section | Stored Procedure | Key Columns |
|----------------|------------------|-------------|
| KPI Cards | `sp_queue_kpi_summary` | total_calls, answered_calls, abandoned_calls, answered_within_sla_percent, mean_talking, total_talking, avg_waiting, serviced_callbacks |
| Call Trends Chart | `sp_queue_calls_by_date` | X-axis: call_date, Y-axis: total_calls/answered_calls/abandoned_calls |
| Agent Performance Table | `qcall_cent_get_extensions_statistics_by_queues` | All columns |

---

## Database Connection
- **Server:** 3.132.72.134
- **Database:** 3CX Exporter
- **Authentication:** SQL Server (sa)

---

## Installation - Run These Scripts

**On Production SQL Server:**
1. `sp_queue_kpi_summary.sql` - KPI cards data ✅ NEW
2. `sp_queue_calls_by_date.sql` - Chart data ✅ NEW

The existing SP `qcall_cent_get_extensions_statistics_by_queues` should already be present.

---

## Files in This Folder
| File | Status | Purpose |
|------|--------|---------|
| `README.md` | ✅ | This documentation |
| `sp_queue_kpi_summary.sql` | ✅ NEW | KPI cards stored procedure |
| `sp_queue_calls_by_date.sql` | ✅ NEW | Chart data stored procedure |

---

## Key Notes

1. **Same Base Logic:** Both new SPs use the same CTE pattern and `CallCent_QueueCalls_View` from the senior's original SP.

2. **SLA Threshold:** The `@wait_interval` parameter serves as the SLA threshold - calls answered within this time are counted as "within SLA".

3. **Empty Queue DNS:** Passing empty string `''` for `@queue_dns` returns data for ALL queues.

4. **View Dependency:** All SPs depend on `CallCent_QueueCalls_View` - ensure this view exists in the database.
