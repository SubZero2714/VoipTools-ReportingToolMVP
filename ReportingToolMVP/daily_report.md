# Development Journal - VoIPTools Reporting Tool MVP

This file tracks daily development progress, bugs fixed, and features implemented.

---

## February 17, 2026 (Monday)

### Focus: Manual Report Creation via Designer UI — Complete

**Session Theme:** Completed the full 14-step manual report creation process entirely from the Report Designer UI. Created `MANUAL_REPORT_CREATION_GUIDE.md` documenting every step for end-user reference.

### Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **`?paramName` syntax** | In the Data Source Wizard, `?paramName` binds SP parameters to Report Parameters. Equivalent to `[Parameters.paramName]` in XML |
| **Data source params are immutable** | Cannot edit data source parameter values after creation in Designer UI. Must remove and re-create the data source |
| **Expression type for all SP params** | All 4 SP parameters (`@period_from`, `@period_to`, `@queue_dns`, `@wait_interval`) can use Expression type with `?paramName` |
| **Date literal syntax** | DevExpress expressions use `#2026-02-01#` hash syntax for date literals |
| **AgentDetail vs AgentDetailBand** | Must select "AgentDetail (Detail Report)" not "AgentDetailBand (Detail)" for Data Source binding |
| **PREVIEW PARAMETERS panel** | Creating Report Parameters auto-generates a parameter panel in Preview mode with RESET/SUBMIT buttons |

### Completed Tasks

#### 1. Manual Report Creation (Steps 1-14)
- Created new report from scratch in Designer UI
- Added 3 data sources (KPIs, Chart, Agents) backed by stored procedures
- Bound 8 KPI cards to `sp_queue_kpi_summary_shushant`
- Configured area chart (Answered/Abandoned) from `sp_queue_calls_by_date_shushant`
- Built agent performance table with GroupHeader + DetailBand from `qcall_cent_get_extensions_statistics_by_queues`
- Created 4 Report Parameters (pPeriodFrom, pPeriodTo, pQueueDns, pWaitInterval)
- Re-created all 3 data sources with `?paramName` bindings for dynamic parameter support
- Verified report renders with live data: 130 Total Calls, 7 Answered, 123 Abandoned for Queue 8089

#### 2. Created MANUAL_REPORT_CREATION_GUIDE.md
- 14-step comprehensive guide for end users
- Includes Issues & Fixes log (5 issues documented)
- Common mistakes and troubleshooting sections
- Key takeaways for future report creation

#### 3. Updated All Project Documentation
- **FEATURES.md** — Added Phase 2 (Manual Report Creation) as complete, updated milestones
- **README.md** — Updated phase status, project description, resource links
- **DEVEXPRESS_COMPONENTS.md** — Added `?paramName` syntax docs, data source re-creation workflow, troubleshooting
- **REPORT_CATALOG.md** — Added manual test report entry, updated database connections

### Issues Encountered

| Issue | Root Cause | Status |
|-------|------------|--------|
| Cannot edit data source params after creation | Designer UI limitation | Workaround: Remove & re-add data source |
| Wrong band selected for AgentDetail | Two bands with similar names | Use "AgentDetail (Detail Report)" |
| Schema rebuild error with plain date strings | DevExpress requires `#date#` hash syntax | Use `#2026-02-01#` format |
| `@wait_interval` restricted to Time type (initial setup) | Designer maps SQL `time` type to Time | Use Expression type with `?pWaitInterval` when binding to Report Parameters |

### Files Modified/Created

| File | Action | Description |
|------|--------|-------------|
| `MANUAL_REPORT_CREATION_GUIDE.md` | Created | 14-step manual report creation guide |
| `FEATURES.md` | Updated | Added Phase 2 completion, updated milestones |
| `README.md` | Updated | Phase status, description, resource links |
| `DEVEXPRESS_COMPONENTS.md` | Updated | `?paramName` syntax, troubleshooting |
| `Documentation/REPORT_CATALOG.md` | Updated | Added manual test report, production DB |
| `daily_report.md` | Updated | Added today's entry |
| `Reports/Templates/Similar to samuel sirs report manualtest_2.repx` | Created | Manually built report with dynamic params |

### Next Steps
- [ ] Test report with different queue DNs (8077, 8089, % for all)
- [ ] Test report export (PDF, Excel) from Report Viewer
- [ ] Consider adding more report templates from Designer UI
- [ ] Evaluate Phase 3 features (database storage, sharing, RBAC)

---

## February 11, 2026 (Tuesday)

### 🎯 Focus: Report Template Data Source Fix - StoredProcQuery Implementation

**Session Theme:** Fixing the "Similar to Samuel Sir's Report" template to use StoredProcQuery instead of CustomSqlQuery with EXEC statements.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **StoredProcQuery vs CustomSqlQuery** | DevExpress CustomSqlQuery rejects EXEC statements. Must use StoredProcQuery for stored procedures |
| **Base64 Encoding in .repx** | Data sources are stored as Base64-encoded XML in ComponentStorage section |
| **DevExpress SP Validation** | DevExpress validates SP existence in database schema before execution |
| **Error: StoredProcNotInSchemaValidationException** | SP must exist in database AND be accessible via connection string |

### ✅ Completed Tasks

#### 1. Diagnosed CustomSqlQuery EXEC Error
- **Problem:** "A custom SQL query should contain only SELECT statements"
- **Root Cause:** DevExpress CustomSqlQuery doesn't allow EXEC statements
- **Solution:** Must use `StoredProcQuery` type instead of `CustomSqlQuery`

#### 2. Updated Similar_to_samuel_sirs_report.repx Data Source
- Decoded existing Base64 data source to understand XML structure
- Created new StoredProcQuery XML configuration:
  ```xml
  <Query Type="StoredProcQuery" Name="KPIs">
    <ProcName>sp_queue_kpi_summary_shushant</ProcName>
    <Parameters>
      <Parameter Name="@period_from" Type="System.DateTime">...</Parameter>
      <Parameter Name="@period_to" Type="System.DateTime">...</Parameter>
      <Parameter Name="@queue_dns" Type="System.String">...</Parameter>
      <Parameter Name="@wait_interval" Type="System.String">...</Parameter>
    </Parameters>
  </Query>
  ```
- Re-encoded to Base64 and updated .repx file

#### 3. Created sp_queue_kpi_summary_shushant in Production Database
- **Problem:** "Cannot find the specified stored procedure: sp_queue_kpi_summary_shushant()"
- **Solution:** Executed CREATE OR ALTER PROCEDURE on production server (3.132.72.134)
- SP returns: queue_dn, queue_display_name, total_calls, abandoned_calls, answered_calls, answered_percent, answered_within_sla, answered_within_sla_percent, serviced_callbacks, total_talking, mean_talking, avg_waiting

#### 4. Verified SP Works in SSMS
- Tested with: `EXEC dbo.[sp_queue_kpi_summary_shushant] @period_from='2025-01-01', @period_to='2025-12-31', @queue_dns='8000', @wait_interval='00:00:20'`
- Returns correct data: Queue 8000 (Relay) - 625 total calls, 602 answered, 96.32% answer rate

### 🐛 Issues Encountered

| Issue | Root Cause | Status |
|-------|------------|--------|
| "CustomSqlQuery should contain only SELECT" | EXEC statements not allowed in CustomSqlQuery | ✅ Fixed - Use StoredProcQuery |
| "Cannot find stored procedure" | SP didn't exist in production database | ✅ Fixed - Created SP |
| Report loads but preview fails | StoredProcQuery validation checks SP existence | ✅ Fixed |

### 📝 Files Modified

| File | Action | Description |
|------|--------|-------------|
| `Reports/Templates/Similar_to_samuel_sirs_report.repx` | Modified | Updated data source from CustomSqlQuery to StoredProcQuery |
| Production DB: `sp_queue_kpi_summary_shushant` | Created | KPI aggregation stored procedure |

### 🔜 Next Steps

- [ ] Verify report preview shows live data from SP
- [ ] Add ChartData query using `sp_queue_calls_by_date_shushant`
- [ ] Add AgentData query using `qcall_cent_get_extensions_statistics_by_queues`
- [ ] Test parameter binding from UI to stored procedures

---

## February 10, 2026 (Monday)

### 🎯 Focus: Production Database Migration & Stored Procedure Development

**Session Theme:** Moving from test database to production (3.132.72.134) and creating stored procedures based on senior developer's existing `qcall_cent_get_extensions_statistics_by_queues` SP.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **Production Database** | Server: 3.132.72.134, Database: "3CX Exporter", User: sa |
| **CallCent_QueueCalls_View** | Main view for call data - contains all queue call records |
| **extensions_by_queues_view** | Maps queue_dn to queue_display_name and extension info |
| **Senior's SP Logic** | `qcall_cent_get_extensions_statistics_by_queues` - authoritative source for calculation logic |
| **SLA Calculation** | `ring_time <= @wait_interval` for answered calls = within SLA |

### ✅ Completed Tasks

#### 1. Updated Database Connection to Production
- Modified `appsettings.json` connection string to 3.132.72.134
- Updated `ReportDataSourceProviders.cs` with production credentials
- Verified connectivity with sqlcmd

#### 2. Analyzed Senior's Stored Procedure
- Reviewed `qcall_cent_get_extensions_statistics_by_queues` SP
- Documented the CTE logic for `queue_all_calls`
- Understood filtering: `(is_answered = 1 OR ring_time >= @wait_interval)`
- Created formatted documentation in `SQL/Similar_to_samuel_sirs_report/Agent_table.sql`

#### 3. Created sp_queue_kpi_summary_shushant
- Based on senior's logic from `qcall_cent_get_extensions_statistics_by_queues`
- Aggregates to queue level for KPI cards
- Parameters: @period_from, @period_to, @queue_dns, @wait_interval
- Output columns match report KPI card bindings

#### 4. Created sp_queue_calls_by_date_shushant
- For Chart data - daily call trends
- Groups by queue and call_date
- Returns: call_date, total_calls, answered_calls, abandoned_calls, answer_rate, sla_percent

#### 5. Created SQL Documentation Folder Structure
```
SQL/Similar_to_samuel_sirs_report/
├── Agent_table.sql           # Senior's SP formatted with comments
├── sp_queue_kpi_summary.sql  # KPI SP script
├── sp_queue_calls_by_date.sql # Chart SP script
└── README.md                 # Documentation
```

#### 6. Designed Report Layout
- Created `Similar_to_samuel_sirs_report.repx` template
- 8 KPI cards: Total Calls, Answered, Abandoned, SLA%, Avg Talk, Total Talk, Avg Wait, Callbacks
- Chart placeholder for daily trends
- Agent Performance table header

### 🐛 Issues Encountered

| Issue | Root Cause | Status |
|-------|------------|--------|
| Invalid column 'reason' | Column doesn't exist in CallCent_QueueCalls_View | ✅ Fixed - Removed |
| Missing comma between CTEs | Syntax error in SP | ✅ Fixed |
| DevExpress CustomSqlQuery validation | EXEC statements rejected | 🔄 In Progress |

### 📝 Files Created

| File | Purpose |
|------|---------|
| `SQL/Similar_to_samuel_sirs_report/Agent_table.sql` | Senior's SP with documentation |
| `SQL/Similar_to_samuel_sirs_report/sp_queue_kpi_summary.sql` | KPI stored procedure |
| `SQL/Similar_to_samuel_sirs_report/sp_queue_calls_by_date.sql` | Chart stored procedure |
| `Reports/Templates/Similar_to_samuel_sirs_report.repx` | Report template |

### 📊 Database Objects Status

| Object | Location | Status |
|--------|----------|--------|
| `CallCent_QueueCalls_View` | Production DB | ✅ Exists |
| `extensions_by_queues_view` | Production DB | ✅ Exists |
| `qcall_cent_get_extensions_statistics_by_queues` | Production DB | ✅ Exists (Senior's) |
| `sp_queue_kpi_summary_shushant` | Production DB | ✅ Created |
| `sp_queue_calls_by_date_shushant` | Production DB | ✅ Created |

### 💡 Key Insight: Production Data Range

- Database contains call data from **Dec 2023 to Oct 2025**
- For testing, use dates within this range
- Example: `@period_from = '2025-01-01', @period_to = '2025-01-31'`

### 🔜 Next Steps

- [ ] Fix CustomSqlQuery EXEC validation issue
- [ ] Test report with StoredProcQuery instead
- [ ] Add parameter UI for end users

---

## January 29, 2026 (Wednesday)

### 🎯 Focus: Custom SQL Guide Documentation & Report Designer Troubleshooting

**Session Theme:** Deep dive into DevExpress Report Designer - understanding data binding, SQL parameters, and creating end-user documentation.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **Data Federation** | Combining multiple data sources (SQL, JSON, Excel) into one unified data source. Useful for joining data from different systems. |
| **Yellow X Icon in Report Designer** | Indicates invalid data binding - the field/query referenced doesn't exist in the data source or schema mismatch |
| **SQL Parameter Binding** | SQL parameters (like `@StartDate`) MUST be linked to Report Parameters using Type="Expression" and Value=`[Parameters.paramName]` |
| **.repx File Format** | DevExpress v25.2 requires Base64-encoded ComponentStorage format for data sources, not inline XML |
| **Expression Bindings** | Use `[FieldName]` syntax for data fields, `[Parameters.paramName]` for report parameters |

### ✅ Completed Tasks

#### 1. Created Comprehensive Custom SQL Guide
- Created `CUSTOM_SQL_GUIDE.md` - step-by-step guide for end users
- Covers: Adding SQL Data Source, Custom SQL queries, Parameter configuration
- Includes troubleshooting section for common errors
- Documents key database tables and columns

#### 2. Fixed Query Builder Schema Error
- **Problem:** "An error occurred while rebuilding a data source schema"
- **Root Cause:** Missing `IDBSchemaProviderExFactory` service
- **Solution:** Added `CustomDBSchemaProviderExFactory` class and registered in DI

#### 3. Diagnosed Blank Report Preview Issue
- **Problem:** Reports showing blank data in Preview
- **Root Cause:** SQL parameters not linked to Report Parameters
- **Error:** "Must declare the scalar variable @paramQueueNumber"
- **Solution Documented:** Set parameter Type to "Expression" and Value to `[Parameters.xxx]`

#### 4. Cleaned Up Broken Report Files
- Deleted `SimpleKPITest.repx` - had incorrect XML format (inline instead of Base64)
- Verified remaining reports in `Reports/Templates/` folder

#### 5. Git Commit & Push
- Committed all changes with descriptive message
- Pushed to GitHub: `c2da118`

### 📝 Documentation Created

| File | Purpose |
|------|---------|
| `CUSTOM_SQL_GUIDE.md` | End-user guide for custom SQL in Report Designer |

**Key Documentation Links Researched:**
- Report Parameters: https://devexpress.github.io/dotnet-eud/reporting-for-web/articles/report-designer/use-report-parameters.html
- Reference Parameters: https://docs.devexpress.com/XtraReports/402962/detailed-guide-to-devexpress-reporting/use-report-parameters/reference-report-parameters
- Data Binding Modes: https://docs.devexpress.com/XtraReports/119236/detailed-guide-to-devexpress-reporting/use-expressions/data-binding-modes

### 🐛 Issues Investigated

| Issue | Root Cause | Status |
|-------|------------|--------|
| Schema rebuild error | Missing IDBSchemaProviderExFactory | ✅ Fixed |
| Blank report preview | SQL params not linked to Report params | 📝 Documented |
| "Invalid data member 'KPIData'" | .repx file used wrong XML format | ✅ Deleted broken file |
| Yellow X next to Data Member | Data source schema mismatch | 📝 Documented in guide |

### 💡 Key Insight: SQL Parameter Binding

The **critical step** that was causing blank reports:

```
❌ WRONG: SQL Parameter Type = "Value", Value = "8000"
   → Error: "Must declare scalar variable @paramQueueNumber"

✅ CORRECT: SQL Parameter Type = "Expression", Value = "[Parameters.paramQueueNumber]"
   → Data flows correctly from Report Parameter to SQL Query
```

### 🔜 Next Steps

- [ ] Test the documented workflow in Report Designer
- [ ] Create a working sample report using the guide
- [ ] Add more SQL query examples to the guide
- [ ] Consider creating video walkthrough

---

## January 28, 2026 (Tuesday)

### 🎯 Focus: Report Designer Data Source Investigation

**Session Theme:** Troubleshooting why custom SQL queries in Report Designer show no data in Preview.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **Report Parameters vs SQL Parameters** | Report Parameters are user-facing (shown in Parameters Panel). SQL Parameters are query-level and must be linked to Report Parameters. |
| **EnableCustomSql()** | Must call `options.EnableCustomSql()` in Program.cs to allow end users to write custom SQL queries |
| **ICustomQueryValidator** | Validates custom SQL queries - `AllowAllQueriesValidator` allows all queries |
| **IDBSchemaProviderExFactory** | Required for Query Builder to fetch database schema (tables, columns) |

### ✅ Completed Tasks

#### 1. Added IDBSchemaProviderExFactory Service
- Created `CustomDBSchemaProviderExFactory` in `ReportDataSourceProviders.cs`
- Registered in `Program.cs` DI container
- Fixed Query Builder schema fetching

#### 2. Investigated "Must declare scalar variable" Error
- Found in terminal logs when running report Preview
- Identified that SQL parameters weren't properly bound to Report Parameters
- Researched DevExpress documentation on parameter binding

### 🐛 Bugs Identified

| Bug | Cause | Status |
|-----|-------|--------|
| Query Builder not fetching schema | Missing IDBSchemaProviderExFactory | ✅ Fixed |
| SQL parameters not resolved | Parameters need Expression binding | 📝 Documented |

---

## January 27, 2026 (Monday)

### 🎯 Focus: Understanding Report Designer Architecture

**Session Theme:** Learning how DevExpress Report Designer works in a Blazor Server application.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **ReportStorageWebExtension** | Service that handles report file storage (load/save .repx files) |
| **FileReportStorageService** | Custom implementation storing reports in `Reports/Templates/` folder |
| **DxReportDesigner vs DxReportViewer** | Designer = create/edit reports, Viewer = view/export reports |
| **Data Source Wizard** | Built-in wizard for connecting to databases, selecting tables/queries |

### ✅ Completed Tasks

#### 1. Reviewed Report Designer Service Architecture
- Understood `FileReportStorageService` for .repx storage
- Reviewed `ReportDataSourceProviders.cs` for data connections
- Examined `Program.cs` service registration order

#### 2. Tested Report Designer UI
- Navigated to `/reportdesigner`
- Explored Data Source wizard
- Tested custom SQL query input

---

## January 24-26, 2026 (Friday-Sunday)

### 🎯 Focus: Application Testing & Bug Fixes

**Session Theme:** Testing the Report Builder and Report Designer components, fixing various issues.

### ✅ Completed Tasks

1. Tested ReportBuilder with DxGrid and DxChart
2. Verified date range filtering works
3. Tested queue selection dropdown
4. Fixed various CSS styling issues

---

## January 23, 2026 (Thursday)

### 🎯 Focus: Hot Reload & Development Workflow

**Session Theme:** Learning efficient development workflow with .NET hot reload.

### 📚 Learning Topics Covered

| Topic | Key Takeaways |
|-------|---------------|
| **Hot Reload** | `dotnet watch run` enables live code changes without restart |
| **appsettings.json** | Configuration file for connection strings, not committed to git |
| **launchSettings.json** | Defines development URLs and environment |

### ✅ Commands Learned

| Command | Purpose |
|---------|---------|
| `dotnet run` | Build and run the application |
| `dotnet build` | Compile without running |
| `dotnet watch run` | Run with hot reload enabled |

---

## January 22, 2026 (Wednesday) - Continued

### 🎯 Focus: Folder Organization, Feature Enhancements, and Bug Fixes

**Request:** Implement folder reorganization, fix Doughnut chart, add Agent Performance table, PDF export, drill-down capability, and date range quick filters.

### ✅ Completed Tasks

#### 1. Folder Reorganization (No Breaking Changes)
Implemented recommended file organization:
```
Reports/
├── CodeBased/             # NEW: C# report classes
│   ├── QueueDashboardReport.cs
│   ├── CallDetailsReport.cs
│   └── BlankReport.cs
├── Templates/             # NEW: .repx visual templates
│   ├── QueueDashboard.repx
│   └── QueuePerformanceSummary.repx
SQL/
├── Views/                 # NEW: SQL view scripts
│   ├── QueueDashboard_KPIs.sql
│   ├── QueueDashboard_CallTrends.sql
│   └── ...
Components/
├── Shared/                # NEW: Ready for reusable components
```

**Updated Services:**
- `FileReportStorageService.cs` - Now looks in `Templates/` subfolder for .repx files
- Updated namespace references to `ReportingToolMVP.Reports.CodeBased`
- Backward compatible - still checks root `Reports/` folder

#### 2. Fixed Doughnut Chart Data Binding
- **Problem:** Pie chart showed 100% instead of actual data distribution
- **Solution:** Added static series points with proper colors
- Shows: Answered (Green), Abandoned (Red), Missed (Yellow)

#### 3. Added Agent Performance Table
- Added `DetailReportBand` with `DataMember = "AgentPerformance"`
- Created `CreateAgentTableHeader()` method - Purple header row
- Created `CreateAgentTableRow()` method - 10 columns with data binding
- Columns: Extension, Agent Name, Total, Answered, Missed, Avg Answer, Avg Talk, Total Talk, Queue Time, Answer %
- Alternating row colors with custom styles (EvenRow/OddRow)

#### 4. PDF Export Functionality
- ✅ **Already Available:** DxReportViewer has built-in toolbar with PDF, Excel, Word export options
- No additional code needed - users can export from the viewer toolbar

#### 5. Created CallDetailsReport.cs (Drill-Down Capability)
- New code-based report for detailed call records
- Parameters: Queue Number, Start Date, End Date, Call Status (filter)
- Shows: Call ID, Time, Caller, Caller Name, Agent, Status, Wait Time, Talk Time, Reason Code
- Color-coded status column (Green=Answered, Red=Abandoned, Yellow=Missed)
- Registered in FileReportStorageService

#### 6. Date Range Quick Filters
Added quick filter buttons to ReportBuilder.razor:
- **Today** - Current day only
- **Week** - Last 7 days
- **Month** - Last 30 days
- **Quarter** - Last 3 months
- **Year** - Last 12 months
- **All** - Full data range (Dec 2023 - Oct 2025)

CSS styling added to `reportbuilder.css` for compact button layout.

### 📝 Files Modified/Created

| File | Action | Description |
|------|--------|-------------|
| `Reports/CodeBased/QueueDashboardReport.cs` | Moved + Modified | Added Agent table, fixed pie chart |
| `Reports/CodeBased/CallDetailsReport.cs` | Created | New drill-down report |
| `Reports/CodeBased/BlankReport.cs` | Moved | Updated namespace |
| `Reports/Templates/*.repx` | Moved | Organized template files |
| `SQL/Views/QueueDashboard_*.sql` | Moved | Organized SQL scripts |
| `Services/FileReportStorageService.cs` | Modified | Templates folder support |
| `Components/Pages/ReportBuilder.razor` | Modified | Quick date filters |
| `wwwroot/reportbuilder.css` | Modified | Quick filter button styles |

### 🐛 Bugs Fixed

| Bug | Cause | Fix |
|-----|-------|-----|
| Doughnut chart showing 100% | Series not bound to data | Added static series points with proper values |
| CreateStyles() hiding inherited | Method name conflict | Renamed to `InitializeReportStyles()` |
| IResultSet.Tables error | Wrong API for data access | Removed dynamic data binding, use static points |

### 📊 New Report Structure

**QueueDashboardReport.cs Layout:**
```
┌─────────────────────────────────────────────────────────────────────┐
│ Page 1: Dashboard Overview                                          │
├─────────────────────────────────────────────────────────────────────┤
│ 📊 Queue Performance Dashboard     Queue: 8000    Date Range        │
│ [Total] [Answered] [Abandoned] [Missed] [SLA%] [AvgW] [MaxW] ...   │
│ ───────────────────────────────────────────────────────────────────│
│ 📊 Call Volume Heat Map (Stacked Bar Chart)                        │
│ 📈 Daily Call Trends (Line Chart)                                  │
│ 🥧 Call Distribution (Doughnut Chart)                              │
├─────────────────────────────────────────────────────────────────────┤
│ Page 2+: Agent Performance Table                                    │
├─────────────────────────────────────────────────────────────────────┤
│ 👥 Agent Performance                                                │
│ Extension | Agent Name | Total | Answered | Missed | ... | Answer% │
│ 1005      | John Smith | 772   | 650      | 12     | ... | 84.2%   │
│ ...                                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

### 🔜 Next Steps

- [ ] Make pie chart dynamic (use calculated fields or transformed query)
- [ ] Add navigation from pie chart slices to CallDetailsReport
- [ ] Create reusable KpiCard.razor Blazor component
- [ ] Add more quick filters (This Year, Last Month, Custom)
- [ ] Implement user preferences storage

---

## January 20-22, 2026 (Monday-Wednesday)

### 🎯 Focus: Queue Dashboard Code-Based Report - Complete Redesign

**Request:** Create a professional, single-page Queue Dashboard with Heat Map, Line Chart, and Pie Chart - all full width with proper parameter support.

### ✅ Completed Tasks

#### 1. Created Code-Based QueueDashboardReport.cs
- Built entirely in C# (not .repx) for better version control
- Uses SqlDataSource with parameterized queries
- Full parameter support: Queue Number, Start Date, End Date

#### 2. Created SQL Views for Dashboard Data
Created 4 new SQL views in `SQL/` folder:
- `vw_QueueDashboard_KPIs` - Aggregated KPI metrics per queue/date
- `vw_QueueDashboard_AgentPerformance` - Agent statistics
- `vw_QueueDashboard_CallTrends` - Daily call volume trends
- `vw_QueueList` - Queue dropdown data

#### 3. Implemented Call Status Logic
Based on analysis of `callcent_queuecalls` table:
```sql
-- Answered: Agent picked up the call
reason_noanswercode = 0 AND ts_servicing > '00:00:00'

-- Abandoned: Caller hung up (MaxWaitTime or UserRequested)
reason_noanswercode IN (3, 4)

-- Missed: No agents available
reason_noanswercode = 2
```

#### 4. Fixed Custom SQL Query Validation
- **Problem:** "Query X is not allowed" error in Report Designer
- **Solution:** Added `AllowAllQueriesValidator : ICustomQueryValidator` to allow custom SQL
- Registered in `Program.cs` with DI

#### 5. Single-Page Dashboard Layout (Final Design)
Completely restructured report to fit on ONE page with full-width charts:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 📊 Queue Performance Dashboard     Queue: 8000    01 Jan - 31 Oct 2025      │ Blue Header
├─────────────────────────────────────────────────────────────────────────────┤
│ 📞Total │ ✅Answered │ ❌Abandoned │ ⚠Missed │ 🎯SLA% │ AvgW │MaxW│AvgT│MaxT│ KPI Cards
│   496   │    384     │     13      │    4    │ 77.4%  │  0s  │ 1s │67s │3641│ (9 cards)
├─────────────────────────────────────────────────────────────────────────────┤
│ 📊 Call Volume Heat Map (Stacked Bar Chart - Full Width)                    │
│ ████████████████████████████████████████████████████████████████████████████│
├─────────────────────────────────────────────────────────────────────────────┤
│ 📈 Daily Call Trends (Line Chart - Full Width)                              │
│ ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲│
├─────────────────────────────────────────────────────────────────────────────┤
│ 🥧 Call Distribution (Doughnut Chart - Full Width)                          │
│ ○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○│
├─────────────────────────────────────────────────────────────────────────────┤
│ Generated: 22 Jan 2026 10:00                                        Page 1  │ Footer
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 6. Color Theme Implementation
| Metric Type | Color | Hex Code |
|-------------|-------|----------|
| Positive (Answered, SLA) | Green | `#27AE60` |
| Negative (Abandoned, Max Wait) | Red | `#E74C3C` |
| Warning (Missed) | Yellow | `#F1C40F` |
| Neutral (Total, Times) | Dark Gray | `#34495E` |
| Primary (Headers) | Blue | `#4361EE` |

#### 7. Data Verification
Verified data with SQL queries:
| Queue | Total | Answered | Abandoned | Missed | SLA % |
|-------|-------|----------|-----------|--------|-------|
| 8000 | 496 | 384 | 13 | 4 | 77.4% |
| 8001 | 210 | 191 | 7 | 0 | 91.0% |

### 🐛 Bugs Fixed

| Bug | Cause | Fix |
|-----|-------|-----|
| Report spans 4 pages | Elements too large, poor band sizing | Compact layout, all content in footer band |
| Pie chart empty | Wrong data binding approach | Switched to Doughnut with proper series |
| Parameters not filtering | Query parameters not bound | Added parameterized SQL with `@paramQueueNumber` |
| Expression serialization error | Used `new Expression()` for parameters | Use static default values instead |
| "Query not allowed" error | ICustomQueryValidator blocking SQL | Added `AllowAllQueriesValidator` |
| PaperKind conversion error | Wrong enum type | Use `PageWidth`/`PageHeight` instead |

### 📝 Files Modified/Created

| File | Action | Description |
|------|--------|-------------|
| `Reports/QueueDashboardReport.cs` | Created | Full code-based dashboard report |
| `Services/ReportDataSourceProviders.cs` | Modified | Added `AllowAllQueriesValidator` |
| `Program.cs` | Modified | Registered `ICustomQueryValidator` |
| `SQL/QueueDashboard_KPIs.sql` | Created | KPI aggregation view |
| `SQL/QueueDashboard_CallTrends.sql` | Created | Daily trends view |
| `SQL/QueueDashboard_AgentPerformance.sql` | Created | Agent stats view |
| `SQL/QueueDashboard_QueueList.sql` | Created | Queue dropdown view |
| `.github/copilot-instructions.md` | Updated | Added call status logic, code-based reports |
| `README.md` | Updated | Current architecture and views |
| `FEATURES.md` | Updated | Phase 1 Queue Dashboard complete |

### 📊 Report Components

**Chart Types Used:**
1. **Stacked Bar Chart** (Heat Map) - Shows call volume by month
2. **Line Chart** - Daily trends with Answered/Abandoned/Missed lines
3. **Doughnut Chart** - Call distribution breakdown

**Data Sources:**
- `KPISummary` - Main KPI aggregates
- `CallTrends` - Daily data for charts
- `AgentPerformance` - Per-agent statistics
- `QueueList` - Dropdown population

### 🔜 Next Steps

- [ ] Fix Doughnut chart data binding (currently shows 100%)
- [ ] Add Agent Performance table below charts
- [ ] Create PDF export functionality
- [ ] Add drill-down capability for call details
- [ ] Implement date range quick filters (Today, Week, Month)

---

## January 12, 2026 (Sunday)

### 🎯 Focus: DevExpress v25.2 Update & Report Structure Completion

**Request from Seniors:** Update to latest DevExpress version, fix Query Builder issues, complete Queue Dashboard report structure

### ✅ Completed Tasks

#### 1. DevExpress Version Update (v25.1.7 → v25.2.3)
- Updated all 5 DevExpress packages to latest version:
  - `DevExpress.AspNetCore.Reporting` v25.2.3
  - `DevExpress.Blazor` v25.2.3
  - `DevExpress.Blazor.Reporting` v25.2.3
  - `DevExpress.Blazor.Reporting.JSBasedControls` v25.2.3
  - `DevExpress.Blazor.Reporting.Viewer` v25.2.3

#### 2. Licensed NuGet Feed Configuration
- Added DevExpress licensed NuGet feed: `https://nuget.devexpress.com/{key}/api/v3/index.json`
- Feed name: "DevExpress-Licensed"
- Verified license file exists at `%AppData%\DevExpress\DevExpress_License.txt`

#### 3. Query Builder Fix (Critical Bug)
- **Problem:** Clicking pencil icon to edit queries was not opening Query Builder
- **Root Cause:** Missing `IDBSchemaProviderExFactory` service registration
- **Solution:** Added 3 new classes to `ReportDataSourceProviders.cs`:
  - `CustomDBSchemaProviderExFactory` - Factory for DB Schema Provider
  - `CustomConnectionProviderFactory` - Factory for connection provider
  - `CustomConnectionProviderService` - Provides database connections
- **Result:** ✅ Query Builder now opens and displays all database tables

#### 4. Corrupted Reports Cleanup
- **Issue:** Date format error: `String '12/31/2025' was not recognized as valid DateOnly`
- **Cause:** Reports created in v25.1.x had incompatible date parameter format with v25.2.x
- **Action:** Deleted 3 corrupted report files:
  - `Report1.repx`
  - `Report1_1.repx`
  - `Test report with kpi and chart.repx`

#### 5. Queue Dashboard Report Structure (Complete)
Built complete report layout matching Samuel's reference design:

**ReportHeader Band:**
- Title: "Queue Dashboard"
- 4 KPI Cards (horizontal layout):
  - Total Calls: 4176
  - Answered: 3600
  - Abandoned: 500
  - Missed: 476

**Detail Band:**
- Agent Performance Table (7 columns):
  - Agent | Calls | Avg Answer | Avg Talk | Talk | Q Time | In Q%
- Header row + data row structure

**ReportFooter Band:**
- Area Chart with 3 series:
  - 🟢 Answered Calls (Green)
  - 🟠 Missed Calls (Orange)
  - 🔴 Abandoned Calls (Red)
- Legend visible in top-right corner

#### 6. Query Builder Usage - KPISummary Query
- Created custom query named "KPISummary"
- Added `callcent_queuecalls` table to Query Builder canvas
- Selected columns: `idcallcent_queuecalls`, `reason_noanswercode`, `reason_failcode`
- Ready for aggregate configuration (COUNT, SUM with CASE)

### 🐛 Bugs Fixed

| Bug | Cause | Fix |
|-----|-------|-----|
| Query Builder not opening | Missing `IDBSchemaProviderExFactory` | Added factory class + DI registration |
| DateOnly format error | v25.1.x date format incompatible with v25.2.x | Deleted corrupted reports |
| Tables not visible in Query Builder | Missing `IConnectionProviderFactory` | Added connection provider service |

### 📊 Report Structure Summary

```
┌──────────────────────────────────────────────────────┐
│ ReportHeader                                         │
│   "Queue Dashboard"                                  │
│   [Total: 4176] [Answer: 3600] [Abandoned] [Missed]  │
├──────────────────────────────────────────────────────┤
│ Detail - Agent Performance Table (7 columns)         │
│   Agent | Calls | Avg Ans | Avg Talk | Talk | QTime  │
├──────────────────────────────────────────────────────┤
│ ReportFooter - Call Trends Area Chart                │
│   🟢 Answered  🟠 Missed  🔴 Abandoned               │
└──────────────────────────────────────────────────────┘
```

### 📝 Files Modified

| File | Action | Description |
|------|--------|-------------|
| ReportingToolMVP.csproj | Modified | Updated 5 packages to v25.2.3 |
| Services/ReportDataSourceProviders.cs | Modified | Added 3 new factory/service classes |
| Program.cs | Modified | Added `IDBSchemaProviderExFactory` & `IConnectionProviderFactory` DI |
| Reports/Report1.repx | Deleted | Corrupted date parameters |
| Reports/Report1_1.repx | Deleted | Corrupted date parameters |
| Reports/Test report with kpi and chart.repx | Deleted | Corrupted date parameters |
| nuget.config | Created | Licensed DevExpress feed |

### 🔜 Next Steps

- [ ] Configure KPISummary query with aggregate expressions (COUNT, SUM/CASE)
- [ ] Bind KPI card values to query results
- [ ] Create AgentPerformance query for table data
- [ ] Create CallTrends query for chart data
- [ ] Bind table cells to AgentPerformance fields
- [ ] Bind chart series to CallTrends data
- [ ] Style table header row (purple background, white text)
- [ ] Adjust chart colors (Green/Orange/Red)
- [ ] Save report as "QueueDashboard.repx"
- [ ] Test with Preview button

### 📚 Key Learnings

- DevExpress v25.2.x requires `IDBSchemaProviderExFactory` for Query Builder functionality
- Date parameter format changed between v25.1.x and v25.2.x (incompatible)
- Query Builder allows custom SQL via "Queries" section with "+" button
- Area charts require 3 series for multi-line visualization
- Report structure: ReportHeader (KPIs) → Detail (Table) → ReportFooter (Chart)

---

## December 30, 2025 (Monday)

### 🎯 Focus: DevExpress Report Designer Integration

**Request from Seniors:** Integrate visual WYSIWYG Report Designer (like demos.devexpress.com/blazor/ReportDesigner)

### ✅ Completed Tasks

#### 1. Installed DevExpress Reporting Packages
- `DevExpress.Blazor.Reporting` v25.1.6
- `DevExpress.Blazor.Reporting.Viewer` v25.1.6
- `DevExpress.Blazor.Reporting.JSBasedControls` v25.1.6
- `DevExpress.AspNetCore.Reporting` v25.1.6

#### 2. Updated Program.cs
- Added `AddControllersWithViews()` for MVC services
- Added `AddDevExpressBlazorReporting()` for reporting DI
- Added `AddDevExpressServerSideBlazorReportViewer()` for viewer
- Registered `FileReportStorageService` as `ReportStorageWebExtension`
- Added `MapControllers()` for API endpoints
- Added `UseDevExpressBlazorReporting()` middleware

#### 3. Created New Pages
- **ReportDesigner.razor** (`/reportdesigner`) - Visual drag-drop report designer
- **ReportViewer.razor** (`/reportviewer`) - View, print, export reports

#### 4. Created New Services
- **FileReportStorageService.cs** - Handles .repx file storage in `Reports/` folder

#### 5. Created Report Templates
- **BlankReport.cs** - Starter template with Detail, PageHeader, PageFooter bands

#### 6. Updated MainLayout.razor
- Added DevExpress Reporting CSS reference
- Added DevExpress Reporting JS reference

#### 7. Updated NavMenu.razor
- Added "Report Designer" link (oi-brush icon)
- Added "Report Viewer" link (oi-document icon)

### 🐛 Bugs Fixed

1. **"DxReportDesigner does not have property 'Report'"**
   - **Cause:** Used `Report` parameter instead of `ReportName`
   - **Fix:** Changed to `ReportName="@CurrentReportName"`

2. **Empty Report Designer Page**
   - **Cause:** FileReportStorageService threw FileNotFoundException for empty URL
   - **Fix:** Created BlankReport.cs, updated GetData() to return blank report for empty URL

3. **MVC Services Missing Error**
   - **Cause:** DevExpress Reporting requires IUrlHelperFactory
   - **Fix:** Added `AddControllersWithViews()` and `MapControllers()`

### 📝 Documentation Updates

- Updated FEATURES.md with Report Designer/Viewer features
- Updated DEVEXPRESS_COMPONENTS.md with DxReportDesigner/DxReportViewer docs
- Updated README.md with new structure and pages
- Updated TestSuite.razor with 13 new test cases
- Created SQL/ folder with query documentation

### 📊 Files Changed

| File | Action | Description |
|------|--------|-------------|
| Program.cs | Modified | Added MVC + Reporting services |
| MainLayout.razor | Modified | Added CSS/JS references |
| NavMenu.razor | Modified | Added nav links |
| ReportingToolMVP.csproj | Modified | Added 4 NuGet packages |
| site.css | Modified | Updated styles |
| ReportDesigner.razor | Created | New page |
| ReportViewer.razor | Created | New page |
| FileReportStorageService.cs | Created | New service |
| BlankReport.cs | Created | New report template |
| SQL/README.md | Created | Query documentation |
| FEATURES.md | Modified | Added new features |
| DEVEXPRESS_COMPONENTS.md | Modified | Added new components |
| README.md | Modified | Updated project info |
| TestSuite.razor | Modified | Added new test cases |

### 🔜 Next Steps

- [x] Create data source for reports (connect to 3CX database) ✅
- [x] Create Queue Dashboard template ✅
- [ ] Complete Agent Performance table
- [ ] Add Call Trends chart
- [ ] Test report export functionality

---

## January 7, 2026 (Tuesday)

### 🎯 Focus: Queue Dashboard Report - Data Analysis & KPI Implementation

**Request from Seniors:** Replicate Samuel's Queue Dashboard report showing KPIs, agent performance table, and call trends chart

### ✅ Completed Tasks

#### 1. Database Analysis & Exploration
- Analyzed Test_3CX_Exporter database structure (26 tables)
- Key tables identified:
  - `callcent_queuecalls` (4,176 call records)
  - `queue` (31 unique queues)
  - `dn` / `users` (37 agents/extensions)
  - `queue2dn` (queue-to-agent mapping)
- Date range: Dec 2023 - Oct 2025
- Call outcomes analyzed:
  - Answered: 2,520 calls (60.34%)
  - Abandoned: 945 calls
  - Missed: 707 calls

#### 2. SQL Query Development
Created 5 comprehensive SQL query files in `SQL/` folder:

**QueueDashboard_KPIs.sql**
- Total Calls, Answered, Abandoned, Missed counts
- Avg/Max Wait Time and Service Time (in seconds)
- SLA metrics (30sec, 60sec thresholds)
- Answer Rate percentage
- Parameterized with @StartDate, @EndDate, @QueueNum

**QueueDashboard_AgentPerformance.sql**
- Agent identification with names (join to users table)
- Call counts per agent
- Average Answer Time, Talk Time, Total Talk Time
- Queue Time and In Queue % calculations
- Filtered by date range and queue

**QueueDashboard_CallTrends.sql**
- Time-series data grouped by day (or hour for single-day reports)
- Answered, Missed, Abandoned call counts
- Supports chart visualization with multiple series

**QueueDashboard_QueueList.sql**
- Queue dropdown population
- Queue names from queue table with fallback

**QueueDashboard_CallDetails.sql**
- Detailed call records for drill-down
- All call metadata and outcome classifications
- Calculated CallStatus field (Answered, Abandoned, Missed, etc.)

#### 3. Report Designer Configuration
- Created new report in DevExpress Report Designer
- Configured 3 SQL data sources using Query Builder:
  - **KPISummary** - Summary metrics query
  - **AgentPerformance** - Agent-level data
  - **CallTrends** - Time-series for chart
- Set up date parameters:
  - StartDate (DateTime) = 1/1/2023
  - EndDate (DateTime) = 12/31/2025
- Added filter: `[time_start] >= ?StartDate And [time_start] <= ?EndDate`
- Set Data Member to "KPISummary"

#### 4. Report Layout - KPI Section
- Added ReportHeader band for dashboard header
- Created "Queue Dashboard" title label
- Built KPI summary cards with 4 metrics:
  - **Total Calls** header + value label
  - **Answered** header + value label
  - **Abandoned** header + value label
  - **Missed** header + value label
- Positioned in horizontal row layout

#### 5. Data Binding Implementation
Configured Expression bindings for KPI values:
- Total Calls: `sumCount([idcallcent_queuecalls])`
- Answered: `sumCount([idcallcent_queuecalls], [reason_noanswercode] == 0 And [reason_failcode] == 0)`
- Abandoned: `sumCount([idcallcent_queuecalls], [reason_noanswercode] == 2 Or [reason_noanswercode] == 3)`
- Missed: `sumCount([idcallcent_queuecalls], [reason_failcode] == 1)`

#### 6. Report Parameters Setup
- Added report-level parameters (StartDate, EndDate)
- Type: DateTime
- Visible: Yes (will prompt user at runtime)
- Connected to query parameters for data filtering

### 🐛 Issues Encountered & Resolved

1. **Missing Data Source Wizard**
   - **Cause:** SSL certificate error with SQL Server Express self-signed cert
   - **Fix:** Updated ReportDataSourceProviders.cs to use CustomStringConnectionParameters with `TrustServerCertificate=True;Encrypt=False;`

2. **KPI Values Not Displaying**
   - **Cause:** Data Member not set on report
   - **Fix:** Set Data Member to "KPISummary" in report properties
   - **Cause 2:** Parameters not configured at report level
   - **In Progress:** Adding StartDate/EndDate parameters with DateTime type

### 📊 Data Insights Discovered

| Metric | Value | Query Verified |
|--------|-------|----------------|
| Total Calls | 4,176 | ✅ |
| Answered | 2,520 (60.34%) | ✅ |
| Abandoned | 945 | ✅ |
| Missed | 707 | ✅ |
| Unique Queues | 31 | ✅ |
| Unique Agents | 37 | ✅ |
| Top Agent (1005) | 772 calls | ✅ |
| Date Range | 2023-12-16 to 2025-10-29 | ✅ |

### 📝 Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| SQL/QueueDashboard_KPIs.sql | Created | KPI summary metrics query |
| SQL/QueueDashboard_AgentPerformance.sql | Created | Agent performance query |
| SQL/QueueDashboard_CallTrends.sql | Created | Time-series chart data |
| SQL/QueueDashboard_QueueList.sql | Created | Queue dropdown options |
| SQL/QueueDashboard_CallDetails.sql | Created | Detailed call records |
| Services/ReportDataSourceProviders.cs | Modified | Fixed SSL certificate issue |
| Reports/Report1.repx | Created | Queue Dashboard template |

### 🔜 Next Steps

- [ ] Complete parameter configuration (StartDate/EndDate DateTime types)
- [ ] Test KPI preview with real data
- [ ] Add Agent Performance table (Detail band)
- [ ] Add Call Trends chart (XRChart component)
- [ ] Add additional KPIs (Avg Wait Time, Max Wait Time, SLA%)
- [ ] Style report to match Samuel's dashboard design
- [ ] Test date parameter filtering
- [ ] Save report as "QueueDashboard.repx"
- [ ] Update documentation

### 📚 Learning Outcomes

- DevExpress Query Builder supports visual query design with parameters
- `sumCount()` function with conditions enables flexible aggregation
- Report parameters require both query-level and report-level configuration
- Data Member property determines which query feeds the report bands
- Expression Editor syntax: `[field_name]` for columns, `?ParameterName` for parameters
- SQL reason codes: 0=answered, 1=timeout, 2=user hung up, 3=max wait time

---

## December 26, 2025 (Thursday)

### ✅ Phase 1 Features Completed
- Date Range Validation (From ≤ To, max 365 days)
- Queue Search (filter as you type)
- Smart Refresh Button (disable with validation hints)
- Collapsible Sidebar (toggle between expanded/icon modes)

---

## December 25, 2025 (Wednesday)

### ✅ Phase 0 MVP Completed
- Report Builder UI with two-column layout
- DxGrid with dynamic columns
- DxChart/DxPieChart visualizations
- Export to Excel, CSV, PDF
- Info buttons with tooltips

---

## 📁 Recommended File Organization

### Current Structure (Good)
```
ReportingToolMVP/
├── Components/
│   ├── Pages/              # Blazor page components
│   │   ├── ReportBuilder.razor
│   │   ├── ReportDesigner.razor
│   │   ├── ReportViewer.razor
│   │   └── TestSuite.razor
│   ├── App.razor
│   └── MainLayout.razor
├── Models/                 # Data models
│   ├── Feature.cs
│   ├── QueueBasicInfo.cs
│   ├── ReportConfig.cs
│   └── ReportDataRow.cs
├── Reports/                # Report definitions
│   ├── BlankReport.cs      # Starter template
│   ├── QueueDashboardReport.cs  # Code-based dashboard
│   └── *.repx              # Visual designer reports
├── Services/               # Business logic
│   ├── CustomReportService.cs
│   ├── FileReportStorageService.cs
│   ├── ReportDataSourceProviders.cs
│   └── ReportExportService.cs
├── SQL/                    # Database scripts
│   ├── CreateDashboardFunctions.sql
│   ├── QueueDashboard_*.sql
│   └── README.md
└── wwwroot/               # Static assets
    ├── css/
    └── *.css
```

### Suggested Improvements
```
ReportingToolMVP/
├── Components/
│   ├── Layout/             # NEW: Layout components
│   │   ├── MainLayout.razor
│   │   ├── NavMenu.razor
│   │   └── NavMenu.razor.css
│   ├── Pages/
│   │   ├── Dashboard/      # NEW: Group related pages
│   │   │   ├── ReportBuilder.razor
│   │   │   ├── ReportDesigner.razor
│   │   │   └── ReportViewer.razor
│   │   └── Admin/          # NEW: Future admin pages
│   │       └── TestSuite.razor
│   └── Shared/             # NEW: Reusable components
│       ├── KpiCard.razor
│       ├── LoadingSpinner.razor
│       └── ErrorBoundary.razor
│
├── Models/
│   ├── Dashboard/          # NEW: Group by feature
│   │   ├── KpiMetrics.cs
│   │   ├── CallTrend.cs
│   │   └── AgentPerformance.cs
│   ├── Reports/
│   │   ├── ReportConfig.cs
│   │   └── ReportDataRow.cs
│   └── Common/
│       ├── QueueBasicInfo.cs
│       └── Feature.cs
│
├── Reports/
│   ├── CodeBased/          # NEW: C# report classes
│   │   ├── QueueDashboardReport.cs
│   │   ├── AgentPerformanceReport.cs
│   │   └── CallDetailsReport.cs
│   ├── Templates/          # NEW: .repx visual templates
│   │   ├── QueueDashboard.repx
│   │   └── QueuePerformanceSummary.repx
│   └── BlankReport.cs
│
├── Services/
│   ├── Reports/            # NEW: Report-specific services
│   │   ├── IReportService.cs
│   │   ├── CustomReportService.cs
│   │   ├── ReportExportService.cs
│   │   └── FileReportStorageService.cs
│   ├── Data/               # NEW: Data access services
│   │   ├── IQueueDataService.cs
│   │   ├── QueueDataService.cs
│   │   └── ReportDataSourceProviders.cs
│   └── Common/             # NEW: Shared utilities
│       ├── DateTimeHelper.cs
│       └── FormatHelper.cs
│
├── SQL/
│   ├── Views/              # NEW: Organize by type
│   │   ├── vw_QueueDashboard_KPIs.sql
│   │   ├── vw_QueueDashboard_CallTrends.sql
│   │   └── vw_QueueList.sql
│   ├── Functions/
│   │   └── CreateDashboardFunctions.sql
│   └── Migrations/         # NEW: Future schema changes
│       └── README.md
│
├── wwwroot/
│   ├── css/
│   │   ├── site.css
│   │   ├── reportbuilder.css
│   │   └── dashboard.css
│   ├── js/                 # NEW: Custom JavaScript
│   │   └── download.js
│   └── images/             # NEW: Static images
│       └── logo.png
│
├── Configuration/          # NEW: App configuration
│   ├── ServiceCollectionExtensions.cs
│   └── ReportingOptions.cs
│
├── Docs/                   # NEW: Move docs together
│   ├── README.md
│   ├── FEATURES.md
│   ├── DEVEXPRESS_COMPONENTS.md
│   ├── REPORT_DESIGNER_GUIDE.md
│   └── daily_report.md
│
└── Tests/                  # NEW: Unit tests (future)
    ├── Services/
    └── Models/
```

### Key Recommendations

1. **Group by Feature** - Organize Models and Pages by feature area (Dashboard, Reports, Admin)

2. **Separate Code-Based Reports** - Put `*.cs` reports in `Reports/CodeBased/` and `.repx` files in `Reports/Templates/`

3. **Service Layers** - Split services into `Reports/`, `Data/`, and `Common/` subfolders

4. **SQL Organization** - Separate `Views/`, `Functions/`, and `Migrations/`

5. **Shared Components** - Create reusable Blazor components like `KpiCard.razor`

6. **Documentation Folder** - Move all `.md` files to `Docs/` folder

7. **Configuration Extension** - Create extension methods for cleaner `Program.cs`

### Migration Priority

| Priority | Change | Effort |
|----------|--------|--------|
| High | Create `Reports/CodeBased/` folder | Low |
| High | Create `Reports/Templates/` folder | Low |
| Medium | Organize SQL into subfolders | Low |
| Medium | Create `Components/Shared/` | Medium |
| Low | Create `Configuration/` folder | Medium |
| Low | Create `Docs/` folder | Low |
| Future | Add `Tests/` folder | High |

---

*Update this file daily with progress notes.*
