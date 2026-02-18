# VoIPTools Reporting Tool – Project Checklist
## Product Development Tracker

> **Purpose:** Master checklist tracking all completed work, pending tasks, and strategic items for the VoIPTools Reporting Tool product launch.  
> **Created:** February 18, 2026  
> **Last Updated:** February 19, 2026  
> **Owner:** Shushant  
> **Status:** Active Development (MVP Phase)

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Completed |
| 🔲 | Not Started |
| 🔄 | In Progress |
| ⚠️ | Blocked / Needs Input |

---

## Phase 1: Core Infrastructure & Architecture

### 1.1 Application Setup
| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.1.1 | .NET 8 Blazor Server project setup | ✅ | `ReportingToolMVP.csproj` |
| 1.1.2 | DevExpress XtraReports v25.2.3 integration | ✅ | All 5 DX packages same version |
| 1.1.3 | DevExpress Report Designer (DxReportDesigner) | ✅ | Route: `/reportdesigner` |
| 1.1.4 | DevExpress Report Viewer (DxReportViewer) | ✅ | Route: `/reportviewer` |
| 1.1.5 | SignalR optimization for large report payloads | ✅ | 1MB max message, 60s timeout |
| 1.1.6 | Response compression (Brotli + Gzip) | ✅ | Configured in `Program.cs` |
| 1.1.7 | Static file caching (7-day Cache-Control) | ✅ | CSS, JS, fonts |
| 1.1.8 | GitHub repository setup | ✅ | `SubZero2714/VoipTools-ReportingToolMVP` |

### 1.2 Report Storage & Data Source Services
| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.2.1 | File-based report storage (`FileReportStorageService`) | ✅ | `.repx` files in `Reports/Templates/` |
| 1.2.2 | In-memory cache with 10-min TTL + timestamp invalidation | ✅ | Prevents repeated disk reads |
| 1.2.3 | Template lookup (Templates/ first, Reports/ fallback) | ✅ | `FormatDisplayName()` for snake_case → readable |
| 1.2.4 | SQL Data Source wizard provider | ✅ | Production + Local connections |
| 1.2.5 | Custom connection provider service | ✅ | Resolves connection name → SqlDataConnection |
| 1.2.6 | Connection provider factory | ✅ | Factory wrapper for above |
| 1.2.7 | DB Schema provider factory | ✅ | Query Builder table/column discovery |
| 1.2.8 | Custom SQL queries enabled in Designer | ✅ | `EnableCustomSql()` in configurator |

### 1.3 Chart Persistence Fix
| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.3.1 | Root cause identified: `SaveLayoutToXml()` strips chart bindings | ✅ | DevExpress known limitation with SP-based data sources |
| 1.3.2 | Post-processing in `FileReportStorageService.SetData()` | ✅ | Extracts bindings pre-serialization, restores via regex |
| 1.3.3 | `ExtractChartSeriesBindings()` helper method | ✅ | Traverses report hierarchy for XRChart controls |
| 1.3.4 | `PostProcessChartXml()` helper method | ✅ | Restores ArgumentDataMember, ValueDataMembersSerializable |
| 1.3.5 | Sets `ValidateDataMembers="false"` on DataContainers | ✅ | Prevents runtime validation errors |
| 1.3.6 | Verified fix persists through multiple saves | ✅ | Tested with page footer additions |

---

## Phase 2: Database – Stored Procedures & Views

### 2.1 Stored Procedures
| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1.1 | `sp_queue_stats_summary` (KPI cards) | ✅ | 5 params: @from, @to, @queue_dns, @sla_seconds, @report_timezone |
| 2.1.2 | `sp_queue_stats_daily_summary` (Chart data) | ✅ | Same 5 params, returns 1 row/day |
| 2.1.3 | `qcall_cent_get_extensions_statistics_by_queues` (Agent table) | ✅ | 4 params: @period_from, @period_to, @queue_dns, @wait_interval |
| 2.1.4 | `@wait_interval` changed from TIME → VARCHAR(8) | ✅ | Fixed on production server |
| 2.1.5 | All 3 SPs deployed to production (3.132.72.134) | ✅ | Database: `3CX Exporter` |

### 2.2 Views Used
| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.2.1 | `CallCent_QueueCalls_View` – call records | ✅ | 3CX managed view |
| 2.2.2 | `extensions_by_queues_view` – queue-to-agent mappings | ✅ | 3CX managed view |

---

## Phase 3: Report Templates

### 3.1 Programmatic Report (Code-Generated)
| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1.1 | `QueuePerformanceDashboardGenerator.cs` | ✅ | Generates `.repx` on startup |
| 3.1.2 | XML post-processing for chart bindings | ✅ | Restores stripped DataMember properties |
| 3.1.3 | `Similar_to_samuel_sirs_report.repx` auto-generated | ✅ | Overwritten on each app restart |

### 3.2 Manual Report (Designer-Created)
| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.2.1 | Created report template in Designer UI | ✅ | `Similar to samuel sirs report manualtest_2.repx` |
| 3.2.2 | 6 Report Parameters configured | ✅ | pPeriodFrom, pPeriodTo, pQueueDns, pWaitInterval, pSlaSeconds, pReportTimezone |
| 3.2.3 | 3 Data Sources with Expression-bound params | ✅ | sqlDataSource1 (KPI), sqlDataSource2 (Chart), sqlDataSource3 (Agent) |
| 3.2.4 | 8 KPI cards bound to correct columns | ✅ | total_calls, answered_calls, abandoned_calls, sla_percentage, mean_talking_time, total_talking_time, avg_wait_time, callbacks |
| 3.2.5 | Area chart with 2 series (Answered + Abandoned) | ✅ | ArgumentDataMember: report_date_local |
| 3.2.6 | Filter Info panel (3 dynamic labels) | ✅ | Queue description, date range, SLA from params |
| 3.2.7 | Agent performance table bound to SP3 | ✅ | AgentDetail band → sqlDataSource3 |
| 3.2.8 | Page Footer (date/time + page numbers) | ✅ | XRPageInfo controls |

---

## Phase 4: UI & Navigation

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Sidebar navigation (Report Designer + Viewer) | ✅ | Collapsible, platform-style |
| 4.2 | Report selector dropdown in Viewer | ✅ | Lists all `.repx` templates |
| 4.3 | Removed Report Builder tab (cleanup) | ✅ | Was prototype, no longer needed |
| 4.4 | Removed Test Suite tab (cleanup) | ✅ | Moved to separate test project |
| 4.5 | Schedule Reports tab | ✅ | Route: `/schedulereports` |
| 4.6 | CSS theming (blazing-berry DevExpress theme) | ✅ | Custom site.css overrides |

---

## Phase 5: Documentation

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | `DEVELOPER_GUIDE.md` | ✅ | Architecture, data flow, file reference |
| 5.2 | `SQL_REFERENCE.md` | ✅ | SP documentation with CTE explanations |
| 5.3 | `MANUAL_REPORT_CREATION_GUIDE.md` | ✅ | 15-step end-user guide |
| 5.4 | `copilot-instructions.md` (AI context) | ✅ | Project context for AI agents |
| 5.5 | `PROJECT_CHECKLIST.md` (this document) | ✅ | Master task tracker |

---

## Phase 6: Testing

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | xUnit test project setup (`ReportingToolMVP.Tests/`) | ✅ | Integration tests |
| 6.2 | `KpiStoredProcTests.cs` – SP1 validation | ✅ | |
| 6.3 | `ChartStoredProcTests.cs` – SP2 validation | ✅ | |
| 6.4 | `AgentStoredProcTests.cs` – SP3 validation | ✅ | |

---

## Phase 7: Scheduled Reports (Email) — NEW

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Schedule Reports Blazor page + UI | ✅ | `ScheduleReports.razor` + CSS |
| 7.2 | ReportSchedule data model | ✅ | `Models/ReportSchedule.cs` with enums |
| 7.3 | SQL table for schedule persistence | ✅ | `report_schedules` deployed to production |
| 7.4 | Email service (SMTP) | ✅ | `EmailService.cs` via smtp.office365.com |
| 7.5 | Background scheduler service | ✅ | `ReportSchedulerBackgroundService.cs` (60s poll) |
| 7.6 | SMTP configuration in appsettings | ✅ | Placeholders in appsettings, real creds in User Secrets |
| 7.7 | Nav menu tab for Schedule Reports | ✅ | ⏰ Schedule Reports in sidebar |
| 7.8 | Secrets management (User Secrets + env vars) | ✅ | `dotnet user-secrets` for dev, env vars for prod |

---

## Phase 8: Pre-Release — Strategic Items (from Management Review)

> *Items from management email (Feb 18, 2026). These are strategic requirements before production release.*

### 8.1 Data Accuracy & Performance
| # | Task | Status | Owner | Priority |
|---|------|--------|-------|----------|
| 8.1.1 | Verify accuracy of all report data | 🔲 | Team | **CRITICAL** |
| 8.1.2 | Ensure Exporter includes all needed SQL views, functions, etc. | 🔲 | Team | High |
| 8.1.3 | Run views/queries through SQL performance monitor tool | 🔲 | Team | High |
| 8.1.4 | Identify indexes needed for optimization | 🔲 | Team | High |
| 8.1.5 | Stress test with 10 million records | 🔲 | Team | **CRITICAL** |
| 8.1.6 | Run all queries/views/functions through AI for optimization | 🔲 | Team | Medium |

### 8.2 Code Quality & Architecture
| # | Task | Status | Owner | Priority |
|---|------|--------|-------|----------|
| 8.2.1 | Full code review — logical architecture | 🔲 | Team | High |
| 8.2.2 | Review views, functions, stored procedures architecture | 🔲 | Team | High |
| 8.2.3 | Agree on naming convention (views, functions, SPs) | 🔲 | Team | High |
| 8.2.4 | Ensure all components named appropriately for multi-report product | 🔲 | Team | High |

### 8.3 UX & DevExpress Integration
| # | Task | Status | Owner | Priority |
|---|------|--------|-------|----------|
| 8.3.1 | How DevExpress handles "Processing… please wait" | 🔲 | Team | Medium |
| 8.3.2 | Evaluate DevExpress stand-alone reporting server | 🔲 | Management | Medium |
| 8.3.3 | Stand-alone server features: security, report scheduling, etc. | 🔲 | Management | Medium |

### 8.4 Product Packaging & Distribution
| # | Task | Status | Owner | Priority |
|---|------|--------|-------|----------|
| 8.4.1 | Identify how to incorporate report + designer into Exporter | 🔲 | Team | High |
| 8.4.2 | Organize 100+ reports in a logical way for customer discovery | 🔲 | Team | High |
| 8.4.3 | Report Designer manual — check DevExpress white-label docs | 🔲 | Team | Medium |
| 8.4.4 | Handle scheduled reports (architecture decision) | ✅ | Team | High |

### 8.5 Go-to-Market & Support
| # | Task | Status | Owner | Priority |
|---|------|--------|-------|----------|
| 8.5.1 | Support team training plan before release | 🔲 | Management | Medium |
| 8.5.2 | Define support policy — what's supported vs billable | 🔲 | Management | Medium |
| 8.5.3 | Marketing plan — "how do we tell the world" | 🔲 | Management | Medium |

---

## Summary Statistics

| Category | Total | Completed | In Progress | Not Started |
|----------|-------|-----------|-------------|-------------|
| Infrastructure & Architecture | 8 | 8 | 0 | 0 |
| Report Storage & Services | 8 | 8 | 0 | 0 |
| Chart Persistence Fix | 6 | 6 | 0 | 0 |
| Database (SPs & Views) | 7 | 7 | 0 | 0 |
| Report Templates | 11 | 11 | 0 | 0 |
| UI & Navigation | 6 | 6 | 0 | 0 |
| Documentation | 5 | 5 | 0 | 0 |
| Testing | 4 | 4 | 0 | 0 |
| Scheduled Reports (Email) | 8 | 8 | 0 | 0 |
| Pre-Release Strategic | 16 | 1 | 0 | 15 |
| **TOTAL** | **79** | **63** | **1** | **15** |

---

## Notes

- This is a **new product**, not a bug fix. Quality and architecture standards should reflect a production release.
- All DevExpress packages must remain on the **same version** (currently 25.2.3).
- The production database server is at `3.132.72.134` (`3CX Exporter` database).
- Reports stored as `.repx` XML templates — portable and version-controllable.
- The programmatic report generator (`QueuePerformanceDashboardGenerator.cs`) overwrites `Similar_to_samuel_sirs_report.repx` on every app restart.

---

*End of Project Checklist*
