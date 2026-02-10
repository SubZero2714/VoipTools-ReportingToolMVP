# VoIPTools Customer Service Dashboard

## Overview

The **VoIPTools Customer Service Dashboard** is a DevExpress Report (.repx) that provides real-time insights into call center queue performance. It displays KPIs, agent performance metrics, and call trend visualizations on a single page.

![Dashboard Preview](./assets/dashboard-preview.png)

---

## Dashboard Components

| Section | Data Source | Description |
|---------|-------------|-------------|
| **KPI Cards** | `dsKPIs` → `vw_QueueKPIs` | 8 metric cards: Total Calls, Answered, Abandoned, Missed, SLA%, Avg Talk, Max Talk, Avg Wait |
| **Agent Performance Table** | `dsAgents` → `vw_QueueAgentPerformance` | Top 10 agents with calls handled, times, and percentages |
| **Call Trends Chart** | `dsTrends` → `vw_QueueCallTrends` | Spline area chart showing daily Answered/Missed/Abandoned trends |

---

## Files Structure

```
ReportingToolMVP/
├── Reports/
│   └── Templates/
│       └── VoIPToolsDashboard.repx      ← The report template
│
├── SQL/
│   └── VoIPToolsDashboard/
│       ├── 00_CreateAllViews.sql        ← Master script (run this first)
│       ├── 01_KPIs.sql                  ← KPI metrics query
│       ├── 02_AgentPerformance.sql      ← Agent table query
│       ├── 03_CallTrends.sql            ← Chart data query
│       └── 04_QueueSummary.sql          ← Optional: Per-queue breakdown
│
└── Documentation/
    └── VoIPToolsDashboard/
        ├── 00_Overview.md               ← This file
        ├── 01_Prerequisites.md          ← Setup requirements
        ├── 02_StepByStep_Guide.md       ← Manual creation guide
        ├── 03_SQL_Reference.md          ← Complete SQL documentation
        ├── 04_Customization.md          ← Styling and modifications
        └── 05_Future_Reports.md         ← Roadmap for additional reports
```

---

## Quick Start

### 1. Prerequisites
- SQL Server with 3CX call data (`callcent_queuecalls` table)
- DevExpress Blazor Reporting (v25.2.3+)
- .NET 8 runtime

### 2. Setup Database Views
```powershell
# Run the master SQL script
sqlcmd -S "YOUR_SERVER" -d "YOUR_DATABASE" -i "SQL/VoIPToolsDashboard/00_CreateAllViews.sql"
```

### 3. Open in Report Designer
1. Navigate to: `https://localhost:7209/reportdesigner`
2. Click **Open Report** → Select **VoIPToolsDashboard**
3. Click **Preview** to see live data

---

## Connection String

The report uses this connection format:
```
Server=LAPTOP-A5UI98NJ\SQLEXPRESS;
Database=Test_3CX_Exporter;
User Id=sa;
Password=YOUR_PASSWORD;
TrustServerCertificate=True;
```

---

## Next Steps

- [01_Prerequisites.md](./01_Prerequisites.md) - Detailed setup requirements
- [02_StepByStep_Guide.md](./02_StepByStep_Guide.md) - Create the report manually
- [03_SQL_Reference.md](./03_SQL_Reference.md) - Complete query documentation
- [05_Future_Reports.md](./05_Future_Reports.md) - Planned report types
