# VoIPTools Dashboard - SQL Queries

This folder contains all SQL queries used in the **VoIPToolsDashboard.repx** report.

## Query Files

| File | Data Source Name | Purpose | Report Section |
|------|------------------|---------|----------------|
| `01_KPIs.sql` | dsKPIs | Aggregated metrics (1 row) | Header KPI Cards |
| `02_AgentPerformance.sql` | dsAgentPerformance | Agent stats (multiple rows) | Agent Table |
| `03_CallTrends.sql` | dsCallTrends | Daily call counts (multiple rows) | Area Chart |
| `04_QueueSummary.sql` | dsQueueSummary | Per-queue breakdown | Optional Detail |

## Database Views Required

Before using the report, run `../VoIPToolsDashboard_Views.sql` to create these views:

- `dbo.vw_QueueKPIs`
- `dbo.vw_QueueAgentPerformance`
- `dbo.vw_QueueCallTrends`
- `dbo.vw_QueueSummary`

## Report Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    VoIPToolsDashboard.repx                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   dsKPIs     │  │dsAgentPerf   │  │dsCallTrends  │          │
│  │ (01_KPIs.sql)│  │(02_Agent.sql)│  │(03_Trends.sql)│         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         ▼                 ▼                 ▼                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  KPI Cards   │  │ Agent Table  │  │  Area Chart  │          │
│  │ (Header)     │  │ (Detail)     │  │ (Footer)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
               ┌──────────────────────────┐
               │     SQL Server Views     │
               │ (VoIPToolsDashboard_     │
               │  Views.sql)              │
               └──────────────────────────┘
                              │
                              ▼
               ┌──────────────────────────┐
               │ callcent_queuecalls      │
               │ (Source Table)           │
               └──────────────────────────┘
```

## Sample Data (from test database)

**KPIs:**
- Total Calls: 4,192
- Answered: 2,530
- Abandoned: 1,662
- SLA: 60%
- Avg Talk: 00:00:57

**Top Agents:**
- 1005 - Agent: 772 calls (18.42%)
- 2120 - Agent: 242 calls (5.77%)

**Date Range:**
- Dec 2023 - Oct 2025

---
*Created: February 4, 2026*
