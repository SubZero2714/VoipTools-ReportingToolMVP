# VoIPTools Reporting Suite - Report Catalog

> **Application:** https://localhost:7209  
> **Report Viewer:** /reportviewer  
> **Report Designer:** /reportdesigner  
> **Last Updated:** Auto-generated

---

## 📚 Documentation Quick Links

| Document | Description |
|----------|-------------|
| [COMPREHENSIVE_GUIDE.md](./VoIPToolsDashboard/COMPREHENSIVE_GUIDE.md) | ⭐ **Master reference** - Architecture, data flow, backend, SQL, flow diagrams |
| [00_Overview.md](./VoIPToolsDashboard/00_Overview.md) | Quick start guide |
| [02_StepByStep_Guide.md](./VoIPToolsDashboard/02_StepByStep_Guide.md) | Manual report creation walkthrough |
| [03_SQL_Reference.md](./VoIPToolsDashboard/03_SQL_Reference.md) | SQL views and query documentation |

---

## Phase 1 Reports (Complete) ✅

### 1. VoIPToolsDashboard
- **File:** `Reports/Templates/VoIPToolsDashboard.repx`
- **Type:** Multi-panel dashboard
- **Data Sources:** 4 SQL views (vw_QueueKPIs, vw_QueueAgentPerformance, vw_QueueCallTrends, vw_QueueSummary)
- **Features:**
  - KPI Summary Panel (Total Calls, Answered, Abandoned, SLA %)
  - Agent Performance Table (ranked by call volume)
  - Daily Call Trends Chart (line chart with answered/abandoned breakdown)
  - Queue Summary Table

### 2. Agent Summary Report
- **File:** `Reports/Templates/AgentSummaryReport.repx`
- **SQL Views:** `SQL/AgentSummaryReport/00_CreateViews.sql`
- **Views Created:**
  - `vw_AgentKPIs` - Per-agent KPI summary with rankings
  - `vw_AgentDailyPerformance` - Daily breakdown per agent
  - `vw_AgentQueueBreakdown` - Per-agent queue distribution
  - `vw_AgentHourlyActivity` - Hourly call patterns per agent
  - `vw_AgentList` - Agent dropdown values
- **Parameters:** Agent Extension (dropdown with top 15 agents)
- **Sections:**
  - KPI Cards (7 metrics: Total, Answered, Missed, Rate, Avg Talk, Max Talk, Total Talk)
  - Daily Performance Table (last 15 days)
  - Queue Distribution Table

### 3. Queue Summary Report
- **File:** `Reports/Templates/QueueSummaryReport.repx`
- **SQL Views:** `SQL/QueueSummaryReport/00_CreateViews.sql`
- **Views Created:**
  - `vw_QueueKPIsSummary` - Per-queue KPI summary with SLA
  - `vw_QueueDailyPerformance` - Daily breakdown per queue
  - `vw_QueueAgentBreakdown` - Per-queue agent distribution
  - `vw_QueueHourlyActivity` - Hourly call patterns per queue
  - `vw_QueueList` - Queue dropdown values
- **Parameters:** Queue Number (dropdown with 15 busiest queues)
- **Sections:**
  - KPI Cards (7 metrics: Total, Answered, Abandoned, Rate, SLA %, Avg Wait, Avg Talk)
  - Daily Performance Table with SLA tracking
  - Agent Performance in Queue Table

---

## Phase 2 Reports (Complete) ✅

### 4. Monthly Summary Report
- **File:** `Reports/Templates/MonthlySummaryReport.repx`
- **SQL Views:** `SQL/MonthlySummaryReport/00_CreateViews.sql`
- **Views Created:**
  - `vw_MonthlySummary` - Month-over-month aggregates
  - `vw_MonthlyQueueBreakdown` - Per-queue monthly stats
  - `vw_MonthlyAgentRankings` - Top agents per month
  - `vw_MonthlyWeekdayStats` - Day-of-week distribution
  - `vw_MonthList` - Month dropdown values
- **Parameters:** Month (dropdown with months having activity)
- **Sections:**
  - Month KPI Summary (calls, answered, abandoned, rates)
  - Queue Performance Table (with % of month share)
  - Top 10 Agents by Call Volume

---

## Phase 2 Reports (Planned) 📋

### 5. Agent Comparison Report
- **Purpose:** Compare multiple agents side-by-side
- **Features:** Multi-select agents, comparative bar charts, ranking tables

### 6. Queue Comparison Report
- **Purpose:** Compare multiple queues side-by-side
- **Features:** Multi-select queues, comparative metrics, SLA comparison

---

## Phase 3 Reports (Planned) 📋

### 7. Hourly Analysis Report
- **Purpose:** Hour-by-hour breakdown for a specific date or date range
- **Features:** Peak hour identification, call volume heatmap

### 8. Weekly Report
- **Purpose:** Week-over-week comparison and trends
- **Features:** Weekly KPIs, week comparison tables

### 9. SLA Compliance Report
- **Purpose:** Detailed SLA performance tracking
- **Features:** SLA breaches by queue, trend analysis, threshold configuration

---

## Database Objects Summary

| Object Type | Count | Location |
|-------------|-------|----------|
| VoIPToolsDashboard Views | 4 | `SQL/VoIPToolsDashboard/` |
| Agent Report Views | 5 | `SQL/AgentSummaryReport/` |
| Queue Report Views | 5 | `SQL/QueueSummaryReport/` |
| Monthly Report Views | 5 | `SQL/MonthlySummaryReport/` |
| Stored Procedures | 6 | `SQL/VoIPToolsDashboard/05_FilterStoredProcedures.sql` |
| **Total Views** | **19** | |

### Stored Procedures
1. `sp_GetQueueKPIs` - Queue KPIs with date/queue filters
2. `sp_GetAgentPerformance` - Agent stats with filters
3. `sp_GetCallTrends` - Call trends with granularity (Hour/Day/Week/Month)
4. `sp_GetQueueSummary` - Queue summary with filters
5. `sp_GetAgentDetail` - Single agent detailed stats
6. `sp_GetMonthlyReport` - Monthly aggregates

---

## Color Scheme

| Use | Color | Hex |
|-----|-------|-----|
| Primary (Blue) | ![#4361ee](https://via.placeholder.com/15/4361ee/4361ee.png) | `#4361ee` |
| Accent (Purple) | ![#9b59b6](https://via.placeholder.com/15/9b59b6/9b59b6.png) | `#9b59b6` |
| Success (Green) | ![#48bb78](https://via.placeholder.com/15/48bb78/48bb78.png) | `#48bb78` |
| Danger (Red) | ![#f56565](https://via.placeholder.com/15/f56565/f56565.png) | `#f56565` |
| Warning (Orange) | ![#e67e22](https://via.placeholder.com/15/e67e22/e67e22.png) | `#e67e22` |
| Text (Dark) | ![#2d3748](https://via.placeholder.com/15/2d3748/2d3748.png) | `#2d3748` |
| Text (Muted) | ![#718096](https://via.placeholder.com/15/718096/718096.png) | `#718096` |
| Border | ![#e2e8f0](https://via.placeholder.com/15/e2e8f0/e2e8f0.png) | `#e2e8f0` |

---

## Quick Start

1. **Start Application:**
   ```powershell
   cd d:\VoipTools-ReportingToolMVP\ReportingToolMVP
   dotnet run
   ```

2. **Access Reports:**
   - Open browser: https://localhost:7209/reportviewer
   - Select report from dropdown
   - Choose parameters (agent, queue, or month)
   - Click Submit/Preview

3. **Export Options:**
   - PDF, Excel, Word, CSV available in report viewer toolbar

---

## Database Connection

```
Server: LAPTOP-A5UI98NJ\SQLEXPRESS
Database: Test_3CX_Exporter
User: sa
Password: V01PT0y5
```

---

## Folder Structure

```
ReportingToolMVP/
├── Reports/
│   └── Templates/
│       ├── VoIPToolsDashboard.repx
│       ├── AgentSummaryReport.repx
│       ├── QueueSummaryReport.repx
│       └── MonthlySummaryReport.repx
├── SQL/
│   ├── VoIPToolsDashboard/
│   │   ├── 00_CreateAllViews.sql
│   │   └── 05_FilterStoredProcedures.sql
│   ├── AgentSummaryReport/
│   │   └── 00_CreateViews.sql
│   ├── QueueSummaryReport/
│   │   └── 00_CreateViews.sql
│   └── MonthlySummaryReport/
│       └── 00_CreateViews.sql
└── Documentation/
    ├── REPORT_CATALOG.md              ← This file
    └── VoIPToolsDashboard/
        ├── 00_Overview.md
        ├── 01_Prerequisites.md
        ├── 02_StepByStep_Guide.md
        ├── 03_SQL_Reference.md
        ├── 04_Customization.md
        ├── 05_Future_Reports.md
        └── COMPREHENSIVE_GUIDE.md     ← ⭐ Master technical reference
```
