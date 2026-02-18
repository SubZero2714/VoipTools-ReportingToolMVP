# VoIPTools Reporting Tool — Comprehensive Developer Guide

> **Version:** 3.0 | **Last Updated:** February 18, 2026  
> **Framework:** .NET 8.0 | **UI:** Blazor Server | **Reporting:** DevExpress XtraReports v25.2.3  
> **Application URL:** `https://localhost:7209`

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Architecture Diagram](#3-architecture-diagram)
4. [Solution Structure — Every File Explained](#4-solution-structure)
5. [Data Flow — Request to Rendered Report](#5-data-flow)
6. [Program.cs — Application Startup In Detail](#6-programcs)
7. [Services Layer — Deep Dive](#7-services-layer)
8. [Report Generator — QueuePerformanceDashboardGenerator.cs](#8-report-generator)
9. [Blazor Pages — Designer, Viewer & Schedule Reports](#9-blazor-pages)
10. [Layout & Navigation](#10-layout-and-navigation)
11. [DevExpress Component Integration](#11-devexpress-integration)
12. [Database Configuration](#12-database-configuration)
13. [NuGet Packages](#13-nuget-packages)
14. [Build & Run](#14-build-and-run)
15. [Report Template (.repx) System](#15-repx-system)
16. [SignalR & Performance Tuning](#16-signalr-and-performance)
17. [Scheduled Reports (Email Delivery)](#17-scheduled-reports)
18. [Secrets & Configuration Management](#18-secrets-and-configuration)
19. [Troubleshooting](#19-troubleshooting)
20. [Glossary](#20-glossary)

---

## 1. Project Overview

This is a **standalone .NET 8 Blazor Server application** for creating, editing, and viewing custom reports against the **3CX Exporter** call center database. It uses the **DevExpress Report Designer** (WYSIWYG) to let users build reports visually — no code required after initial setup.

### What This Application Does

```
┌─────────────────────────────────────────────────────────────────┐
│                     END USER WORKFLOW                            │
│                                                                 │
│  1. Open /reportdesigner → Design report visually               │
│  2. Add data sources (stored procedures from 3CX Exporter DB)   │
│  3. Drag fields onto report bands (KPI cards, charts, tables)   │
│  4. Save → .repx file stored on server disk                     │
│  5. Open /reportviewer → Select report → View/Export (PDF/Excel)│
└─────────────────────────────────────────────────────────────────┘
```

### Three Application Pages

| Page | Route | Purpose |
|------|-------|---------|
| **Report Designer** | `/reportdesigner` | WYSIWYG drag-and-drop report editor. Users create/edit reports with stored procedure data sources, KPI panels, charts, tables. |
| **Report Viewer** | `/reportviewer` | View saved reports with parameter filtering. Export to PDF, Excel, CSV, HTML, and more. |
| **Schedule Reports** | `/schedulereports` | Configure automated report generation and email delivery on daily/weekly/monthly schedules. |

---

## 2. Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Runtime** | .NET | 8.0 | Application framework |
| **UI Framework** | Blazor Server | (built-in) | Server-side rendered components via SignalR WebSocket |
| **Reporting Engine** | DevExpress XtraReports | 25.2.3 | Report designer, viewer, PDF/Excel export |
| **UI Components** | DevExpress Blazor | 25.2.3 | `DxReportDesigner`, `DxReportViewer` |
| **Theme** | DevExpress Blazing Berry | 25.2.3 | CSS theme for all DevExpress components |
| **Database** | SQL Server | (remote) | 3CX Exporter call center database |
| **DB Client** | Microsoft.Data.SqlClient | 6.1.2 | ADO.NET driver for SQL Server |
| **Real-time** | SignalR | (built-in) | Blazor Server's communication channel |
| **Compression** | Brotli + Gzip | (built-in) | Response compression for SignalR frames |
| **Caching** | IMemoryCache | (built-in) | In-memory cache for report file reads |

### Why These Technologies?

- **Blazor Server** (not WebAssembly): Reports are large, data-heavy, and require server-side SQL connections. Blazor Server keeps all logic on the server and streams UI diffs to the browser.
- **DevExpress XtraReports**: Industry-standard .NET reporting library with visual designer, stored procedure binding, expression engine, and multi-format export.
- **SignalR**: Blazor Server's backbone. Every UI interaction travels over a persistent WebSocket connection. The app tunes SignalR buffers for large report payloads.

---

## 3. Architecture Diagram

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            BROWSER (Client)                              │
│                                                                          │
│   /reportdesigner                          /reportviewer                 │
│   ┌─────────────────────┐                  ┌─────────────────────┐      │
│   │  DxReportDesigner   │                  │  DxReportViewer     │      │
│   │  (JS-based WYSIWYG) │                  │  (JS-based viewer)  │      │
│   └────────┬────────────┘                  └────────┬────────────┘      │
│            │ SignalR WebSocket                       │ SignalR WebSocket │
└────────────┼────────────────────────────────────────┼───────────────────┘
             │                                        │
┌────────────┼────────────────────────────────────────┼───────────────────┐
│            ▼            SERVER (.NET 8)              ▼                   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────┐       │
│   │                    Program.cs (DI Container)                 │       │
│   │                                                             │       │
│   │  Services registered:                                        │       │
│   │  ├── FileReportStorageService → ReportStorageWebExtension   │       │
│   │  ├── CustomDataSourceWizardConnectionStringsProvider         │       │
│   │  ├── CustomConnectionProviderService                         │       │
│   │  ├── CustomConnectionProviderFactory                         │       │
│   │  ├── CustomDBSchemaProviderExFactory                         │       │
│   │  ├── ReportScheduleRepository (Scoped)                       │       │
│   │  ├── EmailService (Singleton)                                │       │
│   │  ├── ReportGeneratorService (Singleton)                      │       │
│   │  └── ReportSchedulerBackgroundService (Hosted)               │       │
│   └───────────────────────────┬─────────────────────────────────┘       │
│                               │                                          │
│   ┌───────────────────────────┼─────────────────────────────────┐       │
│   │              Report Storage (File System)                    │       │
│   │                                                             │       │
│   │  Reports/Templates/*.repx  ◄────── Save/Load ──────►       │       │
│   │                                                             │       │
│   │  On startup: QueuePerformanceDashboardGenerator.cs          │       │
│   │  generates Similar_to_samuel_sirs_report.repx               │       │
│   └───────────────────────────┬─────────────────────────────────┘       │
│                               │                                          │
│   ┌───────────────────────────▼─────────────────────────────────┐       │
│   │                    SQL Server (Remote)                        │       │
│   │                                                             │       │
│   │  Server: 3.132.72.134                                        │       │
│   │  Database: 3CX Exporter                                      │       │
│   │                                                             │       │
│   │  Stored Procedures:                                          │       │
│   │  ├── sp_queue_stats_summary               → KPI cards       │       │
│   │  ├── sp_queue_stats_daily_summary         → Area chart      │       │
│   │  └── qcall_cent_get_extensions_statistics  → Agent table    │       │
│   │         _by_queues                                           │       │
│   └─────────────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────────┘
```

### Request Flow Diagram

```
User clicks PREVIEW in Designer (or opens Viewer)
       │
       ▼
Browser ──SignalR──► Blazor Server
       │
       ▼
DxReportDesigner / DxReportViewer component
       │
       ▼
ReportStorageWebExtension.GetData(reportName)
       │
       ▼
FileReportStorageService reads .repx from disk
(with IMemoryCache — skips disk if file unchanged)
       │
       ▼
DevExpress Report Engine parses .repx XML
       │
       ▼
For each SqlDataSource in the report:
  │
  ├── IConnectionProviderFactory.Create()
  │     └── CustomConnectionProviderService.LoadConnection(connectionName)
  │           └── Returns SqlDataConnection with connection string
  │
  ├── Executes stored procedure with bound parameters
  │     (e.g., EXEC sp_queue_stats_summary @from, @to, @queue_dns, @sla_seconds, @report_timezone)
  │
  └── Result set feeds into report bands (KPI cards, chart, table)
       │
       ▼
Rendered report (HTML/PDF) sent back to browser via SignalR
```

### Data Source Binding Flow

```
Report Parameter (user input)          Data Source Parameter          SQL SP Parameter
┌──────────────────────┐       ┌─────────────────────────┐       ┌──────────────────┐
│ pPeriodFrom          │──────►│ ?pPeriodFrom             │──────►│ @period_from     │
│ (DateTime: 2026-02-01│       │ Expression type          │       │ DATETIMEOFFSET   │
│  from PREVIEW panel) │       │ in .repx XML             │       │ in SQL Server    │
└──────────────────────┘       └─────────────────────────┘       └──────────────────┘

Chain: [Parameters.pPeriodFrom] → ?pPeriodFrom → @period_from → SQL WHERE clause
```

---

## 4. Solution Structure

### Complete File Tree with Explanations

```
VoipTools-ReportingToolMVP/                    ← Git repository root
│
├── VoipTools-ReportingToolMVP.sln             ← Visual Studio solution file
├── .gitignore                                 ← Git ignore rules
├── .github/
│   └── copilot-instructions.md                ← AI agent context for GitHub Copilot
│
├── image005.png                               ← Reference screenshot
├── unnamed.jpg                                ← Reference screenshot
├── logo_base64.txt                            ← Base64-encoded logo for reports
│
├── backup/                                    ← Historical .repx backups (Phase 1 experiments)
│   ├── AgentTableSubreport.repx
│   ├── VoIPToolsDashboard.repx
│   ├── VoIPToolsDashboard_01.repx
│   ├── VoIPToolsDashboard_02.repx
│   └── Backup/                                ← Deeper backup folder
│
├── ReportingToolMVP.Tests/                    ← xUnit integration test project
│   ├── ReportingToolMVP.Tests.csproj          ← Test project file (Dapper, xUnit)
│   ├── appsettings.Test.json                  ← Test DB connection config
│   ├── DatabaseTestBase.cs                    ← Shared test base class
│   ├── KpiStoredProcTests.cs                  ← Tests for sp_queue_stats_summary
│   ├── ChartStoredProcTests.cs                ← Tests for sp_queue_stats_daily_summary
│   └── AgentStoredProcTests.cs                ← Tests for qcall_cent_get_extensions_statistics_by_queues
│
└── ReportingToolMVP/                          ← ★ MAIN APPLICATION PROJECT
    │
    ├── ReportingToolMVP.csproj                ← Project file with NuGet package references
    ├── Program.cs                             ← ★ Application entry point & DI configuration
    ├── _Imports.razor                         ← Root-level Razor using statements
    ├── appsettings.json                       ← Configuration (connection strings, SMTP placeholders)
    ├── appsettings.Development.json           ← Development overrides
    ├── appsettings.json.sample                ← Template for new developers
    │   NOTE: SMTP credentials stored in User Secrets (dev) or env vars (prod)
    │
    ├── DEVELOPER_GUIDE.md                     ← ★ THIS FILE — comprehensive developer manual
    ├── SQL_REFERENCE.md                       ← Complete SQL stored procedure documentation
    ├── MANUAL_REPORT_CREATION_GUIDE.md        ← End-user step-by-step report creation guide
    ├── daily_report.md                        ← Development journal / progress log
    ├── RELEASE_VERIFICATION_CHECKLIST.md      ← Pre-release testing checklist
    ├── fix_repx.ps1                           ← One-time PowerShell script for .repx XML fixes
    │
    ├── Components/                            ← Blazor component layer
    │   ├── App.razor                          ← Root Blazor component (Router)
    │   ├── MainLayout.razor                   ← HTML document layout (head, body, scripts)
    │   ├── _Imports.razor                     ← Component-level using statements
    │   └── Pages/
    │       ├── ReportDesigner.razor           ← ★ /reportdesigner — WYSIWYG editor page
    │       ├── ReportViewer.razor             ← ★ /reportviewer — Report viewing/export page
    │       ├── ScheduleReports.razor          ← ★ /schedulereports — Automated email scheduling
    │       └── ScheduleReports.razor.css      ← Scoped CSS for schedule page
    │
    ├── Shared/                                ← Shared layout components
    │   ├── MainLayout.razor                   ← Page layout with sidebar + content area
    │   ├── MainLayout.razor.css               ← Scoped CSS for layout
    │   ├── NavMenu.razor                      ← ★ Sidebar navigation (Designer + Viewer + Schedule links)
    │   └── NavMenu.razor.css                  ← Scoped CSS for navigation sidebar
    │
    ├── Pages/                                 ← Non-interactive pages
    │   ├── Index.razor                        ← "/" route — redirects to /reportdesigner
    │   ├── Error.cshtml                       ← Server error page (500)
    │   └── Error.cshtml.cs                    ← Error page code-behind
    │
    ├── Models/                                ← Data models
    │   └── ReportSchedule.cs                  ← Schedule entity + enums (Frequency, Format, RunStatus)
    │
    ├── Services/                              ← ★ Backend service layer
    │   ├── FileReportStorageService.cs        ← ★ .repx file storage (save/load/list)
    │   ├── ReportDataSourceProviders.cs       ← ★ 5 classes for DB connections in Designer
    │   ├── ReportScheduleRepository.cs        ← ADO.NET CRUD for report_schedules table
    │   ├── EmailService.cs                    ← SMTP email sender with attachments
    │   ├── ReportGeneratorService.cs          ← Server-side PDF/XLSX/CSV export from .repx
    │   └── ReportSchedulerBackgroundService.cs ← Background service polling (60s) for due schedules
    │
    ├── Reports/                               ← Report generation & templates
    │   ├── QueuePerformanceDashboardGenerator.cs  ← ★ Code-based .repx generator
    │   ├── logo_base64.txt                    ← Logo data for embedding in reports
    │   └── Templates/                         ← ★ .repx report template storage
    │       ├── Similar_to_samuel_sirs_report.repx     ← Production report (auto-generated)
    │       ├── VoIPToolsDashboard.repx                ← Phase 1 views-based dashboard
    │       ├── AgentTableSubreport.repx               ← Agent sub-report fragment
    │       └── Similar to samuel sirs report*.repx    ← Manual test iterations
    │
    ├── SQL/                                   ← SQL scripts & stored procedures
    │   ├── CreateReportSchedulesTable.sql     ← ★ DDL for report_schedules table
    │   ├── Similar_to_samuel_sirs_report/     ← ★ Active SP definitions
    │   │   ├── README.md                      ← SP documentation
    │   │   ├── sp_queue_kpi_summary.sql       ← SP 1: KPI aggregation
    │   │   ├── sp_queue_calls_by_date.sql     ← SP 2: Daily call trends
    │   │   ├── Agent_table.sql                ← SP 3: Agent performance
    │   │   ├── Charts_subbu_sir_query.sql     ← Senior's chart SP (reference)
    │   │   └── KPI_cards_subbu_sir_query.sql  ← Senior's KPI SP (reference)
    │   ├── VoIPToolsDashboard/                ← Phase 1 SQL views (legacy)
    │   ├── VoIPToolsDashboard_Views.sql       ← Phase 1 view creation script
    │   └── Tests/
    │       └── data_integrity_tests.sql       ← SQL test suite (15 tests)
    │
    ├── Properties/
    │   └── launchSettings.json                ← Dev server URLs & environment
    │
    └── wwwroot/                               ← Static web assets
        ├── favicon.ico                        ← Browser tab icon
        ├── logo.jpg                           ← Logo image file
        └── css/
            ├── site.css                       ← Global custom styles
            ├── bootstrap/                     ← Bootstrap CSS framework
            └── open-iconic/                   ← Icon library (oi-* classes)
```

---

## 5. Data Flow

### Flow 1: User Opens Report Designer

```
1. Browser navigates to /reportdesigner
2. Blazor Server routes to ReportDesigner.razor
3. Component renders <DxReportDesigner ReportName="">
4. DevExpress JS loads in the browser (dx-blazor.js)
5. Designer calls FileReportStorageService.GetUrls() to populate "Open" menu
6. If ReportName is empty → GetData("") → returns blank XtraReport
7. If ReportName has value → GetData(name) → reads .repx from Templates/ folder
8. Designer renders the WYSIWYG editing surface
```

### Flow 2: User Saves a Report

```
1. User clicks Save in the Designer toolbar
2. DxReportDesigner serializes the report to XML (.repx format)
3. Calls FileReportStorageService.SetData(report, url)
4. Service writes .repx file to Reports/Templates/{url}.repx
5. Cache is invalidated (UrlsCacheKey removed)
```

### Flow 3: User Previews a Report (with Parameters)

```
1. User clicks PREVIEW in Designer → Parameters panel appears
2. User enters: Start Date, End Date, Queue DN, SLA Threshold
3. Clicks SUBMIT
4. DevExpress engine resolves expressions: ?pPeriodFrom → [Parameters.pPeriodFrom]
5. For each SqlDataSource:
   a. CustomConnectionProviderFactory.Create() → returns CustomConnectionProviderService
   b. Service.LoadConnection("3CX_Exporter_Production") → returns SqlDataConnection
   c. Engine executes SP: EXEC sp_queue_stats_summary @from=..., @to=..., @queue_dns=..., @sla_seconds=..., @report_timezone=...
6. Result sets populate report bands:
   - KPI data → ReportHeader KPI card expressions
   - Chart data → XRChart series (Answered/Abandoned area chart)
   - Agent data → DetailReportBand table rows
7. Rendered HTML sent to browser via SignalR
```

### Flow 4: Report Viewer Loads a Report

```
1. Browser navigates to /reportviewer
2. ReportViewer.razor calls ReportStorage.GetUrls() → populates dropdown
3. User selects a report from dropdown
4. OnReportSelected() → ReportStorage.GetData(name) → reads .repx bytes
5. Creates new XtraReport(), calls LoadLayoutFromXml(stream)
6. Sets CurrentReport = report; triggers <DxReportViewer Report="@CurrentReport"/>
7. DxReportViewer renders the report with parameter panel
8. Same SP execution flow as Flow 3 above
```

---

## 6. Program.cs

`Program.cs` is the **single most important file** in the application. It configures every service, middleware, and pipeline component.

### Execution Order (Top to Bottom)

```csharp
// 1. Create the application builder
var builder = WebApplication.CreateBuilder(args);

// 2. Response Compression — Brotli + Gzip
//    WHY: Blazor Server sends everything over SignalR WebSocket.
//    Compressing these frames reduces bandwidth 60-80%.
builder.Services.AddResponseCompression(opts => { ... });

// 3. In-Memory Cache
//    WHY: FileReportStorageService caches .repx file reads.
//    Avoids re-reading disk for every GetData() call.
builder.Services.AddMemoryCache();

// 4. MVC Controllers
//    WHY: DevExpress Reporting exposes REST API endpoints via MVC controllers.
//    Without this, the Designer wizard and export functions fail.
builder.Services.AddControllersWithViews();

// 5. Razor Components + Interactive Server mode
//    WHY: Core Blazor Server setup. Enables server-side rendering
//    with SignalR-based interactivity.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// 6. SignalR Hub Optimization
//    WHY: Default 32KB message limit is too small for report payloads.
//    1MB limit prevents "message too large" disconnects.
builder.Services.AddSignalR(opts => {
    opts.MaximumReceiveMessageSize = 1024 * 1024;  // 1 MB
    opts.StreamBufferCapacity = 30;
    opts.ClientTimeoutInterval = TimeSpan.FromSeconds(60);
    opts.KeepAliveInterval = TimeSpan.FromSeconds(15);
});

// 7. DevExpress Blazor (core UI components)
builder.Services.AddDevExpressBlazor();

// 8. DevExpress Reporting services
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// 9. Configure Report Designer — ENABLE CUSTOM SQL
//    WHY: Without EnableCustomSql(), any custom SQL query in the Designer
//    throws "Query X is not allowed". This is DevExpress's security gate.
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(d => d.EnableCustomSql());
    configurator.ConfigureWebDocumentViewer(v => v.UseCachedReportSourceBuilder());
});

// 10-14. Register the 5 custom services (see Section 7)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, ...>();
builder.Services.AddScoped<IConnectionProviderService, ...>();
builder.Services.AddScoped<IConnectionProviderFactory, ...>();
builder.Services.AddScoped<IDBSchemaProviderExFactory, ...>();

// 15. Scheduled Reports services
//     WHY: Enables automated report generation and email delivery.
builder.Services.AddScoped<IReportScheduleRepository, ReportScheduleRepository>();
builder.Services.AddSingleton<IEmailService, EmailService>();
builder.Services.AddSingleton<IReportGeneratorService, ReportGeneratorService>();
builder.Services.AddHostedService<ReportSchedulerBackgroundService>();

var app = builder.Build();

// 15. Generate the production report .repx on startup
//     WHY: QueuePerformanceDashboardGenerator creates the report with correct
//     XML post-processing (chart data bindings, ResultSchema injection).
//     This runs EVERY startup, overwriting the existing .repx.
QueuePerformanceDashboardGenerator.GenerateAndSave(repxPath);

// 16. Middleware pipeline (ORDER MATTERS)
app.UseHttpsRedirection();
app.UseResponseCompression();      // Must be early
app.UseStaticFiles(/* 7-day cache */);
app.UseAntiforgery();
app.MapControllers();              // DevExpress REST endpoints
app.UseDevExpressBlazorReporting(); // BEFORE MapRazorComponents
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
app.Run();
```

### Critical Registration Order

```
AddDevExpressBlazor()                          ← 1st: Core components
AddDevExpressBlazorReporting()                 ← 2nd: Reporting services
AddDevExpressServerSideBlazorReportViewer()    ← 3rd: Server-side viewer
ConfigureReportingServices(...)                 ← 4th: Designer/Viewer config
AddScoped<ReportStorageWebExtension, ...>()    ← 5th: File storage
AddScoped<IDataSourceWizardConnectionStringsProvider, ...>()  ← 6th+: DB providers
...
UseDevExpressBlazorReporting()                 ← Middleware: BEFORE MapRazorComponents
MapRazorComponents<App>()                      ← LAST
```

> **WARNING:** Changing this order can cause silent failures — the Designer loads but wizard steps fail, or the Viewer renders but exports produce empty files.

---

## 7. Services Layer

Six files in `Services/` contain all backend logic.

### 7.1 FileReportStorageService.cs

**Purpose:** Implements `ReportStorageWebExtension` — DevExpress's contract for reading/writing/listing reports.

**Why it exists:** DevExpress Designer and Viewer don't know WHERE reports are stored. This abstraction lets us use the file system (could be swapped for database storage later).

```
Inheritance: FileReportStorageService → ReportStorageWebExtension (abstract)

Methods overridden:
├── GetData(url)      → Reads .repx bytes from disk (cached via IMemoryCache)
├── GetUrls()         → Lists all .repx files as dictionary {name: displayName}
├── CanSetData(url)   → Always returns true (allow saves)
├── IsValidUrl(url)   → Validates filename (no path traversal, no invalid chars)
├── SetData(report, url) → Saves report XML to Templates/ folder
└── SetNewData(report, defaultUrl) → Generates unique filename if exists
```

**File lookup strategy:**
```
GetReportFilePath(url):
  1. Check Reports/Templates/{url}.repx  ← Preferred
  2. Check Reports/{url}.repx            ← Backward compatibility
  3. Default to Templates/ for new files
```

**Caching strategy:**
```
GetData(url):
  cacheKey = "Report_{url}_{lastWriteTimeTicks}"
  If cache hit → return cached bytes (no disk read)
  If cache miss → read from disk, cache for 10 minutes

GetUrls():
  Cached under "ReportUrls" key, 10-minute expiration
  Cache invalidated on every SetData() call
```

### 7.2 ReportDataSourceProviders.cs

**Purpose:** Five classes that enable the Designer to connect to SQL Server.

```
Classes in this file:
│
├── CustomDataSourceWizardConnectionStringsProvider
│   Implements: IDataSourceWizardConnectionStringsProvider
│   PURPOSE: Populates the "Choose a data connection" dropdown in the
│            Data Source Wizard. Returns two named connections:
│            - "3CX_Exporter_Production" → 3.132.72.134
│            - "3CX_Exporter_Local" → LAPTOP-A5UI98NJ\SQLEXPRESS
│
├── AllowAllQueriesValidator
│   Implements: ICustomQueryValidator
│   PURPOSE: Validates custom SQL queries. Currently allows ALL queries.
│            In production, restrict to SELECT/EXEC only.
│
├── CustomConnectionProviderService
│   Implements: IConnectionProviderService
│   PURPOSE: Called at RUNTIME when a report executes. Resolves a
│            connection NAME (stored in .repx) to an actual SqlDataConnection
│            with connection string. This is the critical runtime resolver.
│   METHOD: LoadConnection(connectionName) → SqlDataConnection
│
├── CustomConnectionProviderFactory
│   Implements: IConnectionProviderFactory
│   PURPOSE: Factory wrapper that returns CustomConnectionProviderService.
│            Required by DevExpress architecture (factory pattern).
│
└── CustomDBSchemaProviderExFactory
    Implements: IDBSchemaProviderExFactory
    PURPOSE: Creates DBSchemaProviderEx instances for the Query Builder
             in the Designer. Without this, the Query Builder fails to
             load table/column metadata.
```

**Connection resolution flow:**

```
.repx file contains: <Connection Name="3CX_Exporter_Production">

At runtime:
  CustomConnectionProviderFactory.Create()
    → returns CustomConnectionProviderService instance
      → LoadConnection("3CX_Exporter_Production")
        → new CustomStringConnectionParameters("XpoProvider=MSSqlServer;Data Source=3.132.72.134;...")
          → new SqlDataConnection("3CX_Exporter_Production", parameters)
```

> **KEY INSIGHT:** The .repx file stores the connection NAME, not the connection string. The connection string is resolved at runtime by `CustomConnectionProviderService`. This means you can change the database server without modifying any report files.

### 7.3 ReportScheduleRepository.cs

**Purpose:** ADO.NET CRUD operations for the `report_schedules` SQL table.

```
Interface: IReportScheduleRepository
│
├── GetAllAsync()              → All schedules (for UI list)
├── GetByIdAsync(id)           → Single schedule by ID
├── GetDueSchedulesAsync(utcNow) → Enabled schedules where next_run_utc <= now
├── CreateAsync(schedule)      → INSERT + return new ID
├── UpdateAsync(schedule)      → UPDATE all fields by ID
├── DeleteAsync(id)            → DELETE by ID
└── UpdateRunStatusAsync(...)  → Update last_run_status, error, next_run, run_count
```

**Connection:** Uses `DefaultConnection` from `IConfiguration`. Pure ADO.NET — no Entity Framework.

### 7.4 EmailService.cs

**Purpose:** Sends emails with report file attachments via SMTP.

```
Interface: IEmailService
└── SendReportEmailAsync(to, cc, subject, body, attachmentData, fileName, mimeType)

Configuration: SmtpSettings class bound from "SmtpSettings" section
├── Host           (e.g., smtp.office365.com)
├── Port           (587)
├── EnableSsl      (true)
├── Username       (stored in User Secrets / env vars)
├── Password       (stored in User Secrets / env vars)
├── FromAddress    (stored in User Secrets / env vars)
└── FromDisplayName
```

**Supports:** Comma/semicolon-separated addresses, HTML body, 30-second timeout.

### 7.5 ReportGeneratorService.cs

**Purpose:** Server-side report generation from `.repx` templates, outputting PDF, XLSX, or CSV byte arrays.

```
Interface: IReportGeneratorService
└── GenerateReportAsync(reportName, parameters, format)
    → Returns (byte[] Data, string FileName, string MimeType)

Flow:
  1. Load .repx from Templates/ or Reports/ directory
  2. Set parameter values with automatic type conversion
  3. Export via DevExpress XtraReport.ExportToPdf / ExportToXlsx / ExportToCsv
```

### 7.6 ReportSchedulerBackgroundService.cs

**Purpose:** `BackgroundService` that polls every 60 seconds for due report schedules and executes them.

```
Lifecycle:
  1. Startup delay: 30 seconds (let app initialize)
  2. Loop every 60 seconds:
     a. GetDueSchedulesAsync(utcNow) → find enabled schedules past due
     b. For each schedule:
        i.   Mark status = Running
        ii.  Generate report (PDF/XLSX/CSV)
        iii. Send email with attachment
        iv.  Calculate next run time
        v.   Mark status = Success or Failed

Static helper: CalculateNextRun(schedule)
  → Computes next UTC run time based on frequency, day of week/month,
    scheduled time, and timezone
```

---

## 8. Report Generator

### QueuePerformanceDashboardGenerator.cs (568 lines)

**Purpose:** Generates the `Similar_to_samuel_sirs_report.repx` file programmatically using the DevExpress API on every application startup.

**Why code generation instead of manual design?**

DevExpress's `SaveLayoutToXml()` method strips certain properties when it can't validate the data source schema at generation time. Specifically:
1. `DataMember` on XRChart controls
2. `ArgumentDataMember` and `ValueDataMembersSerializable` on chart series
3. `ResultSchema` on StoredProcQuery data sources

Without these properties, the chart renders **blank** at runtime. The generator creates the report, saves to XML, then **post-processes the XML** to inject the missing properties.

### Generator Architecture

```
GenerateAndSave(outputPath)
│
├── 1. CreateReport() → builds XtraReport object tree
│   ├── 4 Report Parameters (pPeriodFrom, pPeriodTo, pQueueDns, pWaitInterval)
│   ├── 3 SqlDataSources (KPIs, ChartData, Agents) with StoredProcQuery
│   ├── Bands:
│   │   ├── TopMarginBand
│   │   ├── ReportHeaderBand (height: 580)
│   │   │   ├── Title + Subtitle labels
│   │   │   ├── Filter Info panel (bound to [queue_dn], [Parameters.*])
│   │   │   ├── 8 KPI card panels (bound to KPI SP fields)
│   │   │   ├── XRChart with 2 Area series (Answered/Abandoned)
│   │   │   └── Agent Table title label
│   │   ├── DetailBand (hidden, height: 0)
│   │   ├── DetailReportBand "AgentDetail"
│   │   │   ├── GroupHeaderBand (RepeatEveryPage=true)
│   │   │   │   └── XRTable: Header row (6 columns)
│   │   │   └── DetailBand "AgentDetailBand"
│   │   │       └── XRTable: Data row (6 cells with expressions)
│   │   ├── PageFooterBand (DateTime + PageInfo)
│   │   └── BottomMarginBand
│   └── Alternating row style "EvenRow"
│
├── 2. report.SaveLayoutToXml(outputPath)
│
├── 3. XML Post-Processing (4 fixes):
│   ├── Fix 0: Set DataMember="ChartData" and ValidateDataMembers="false"
│   │          on the chart's DataContainer element
│   ├── Fix 1: Set DataMember="ChartData" on the XRChart control element
│   ├── Fix 2: Inject ArgumentDataMember + ValueDataMembersSerializable
│   │          on each chart series element
│   └── Fix 3: Inject <ResultSchema> into the chart's SqlDataSource
│              Base64-encoded XML (inside <ComponentStorage>)
│
└── 4. Write final XML to disk
```

### SP Parameter Binding Pattern

```csharp
// Each data source binds SP parameters to Report Parameters via expressions
spQuery.Parameters.Add(new QueryParameter(
    "@period_from",                              // SQL Server SP parameter name
    typeof(DevExpress.DataAccess.Expression),    // Type = Expression
    new DevExpress.DataAccess.Expression("[Parameters.pPeriodFrom]")  // Report parameter reference
));
```

This creates the chain: `[Parameters.pPeriodFrom]` → `@period_from` → SQL Server

---

## 9. Blazor Pages — Designer, Viewer & Schedule Reports

### ReportDesigner.razor

```
Route:     /reportdesigner
           /reportdesigner/{ReportUrl}
Directive: @rendermode InteractiveServer
Component: <DxReportDesigner>
```

**How it works:**
- Renders the DevExpress Report Designer — a full WYSIWYG editor running as JavaScript in the browser
- Communicates with the server via SignalR + DevExpress REST controllers
- `ReportName` parameter: if empty → new blank report; if set → loads existing .repx
- The `AllowMDI="true"` enables multiple reports open in tabs
- Height set to `calc(100vh - 180px)` for full-screen experience

**The Designer provides:**
- Visual report canvas with drag-and-drop
- Data Source Wizard (connects to SQL Server, picks SPs, sets parameters)
- Expression Editor (binds fields to controls)
- Chart Designer (configures XRChart series, axes, legends)
- Report Explorer (tree view of all bands and controls)
- Properties panel (font, color, size, bindings)
- Preview mode with parameter input panel

### ReportViewer.razor

```
Route:     /reportviewer
           /reportviewer/{ReportUrl}
Directive: @rendermode InteractiveServer
Injected:  ReportStorageWebExtension, ILogger
Component: <DxReportViewer>
```

**How it works:**
- On initialization, calls `ReportStorage.GetUrls()` to get all available reports
- Renders a dropdown (`<select>`) at the top for report selection
- When a report is selected:
  1. Calls `ReportStorage.GetData(reportName)` → gets .repx bytes
  2. Creates `new XtraReport()`, loads layout from XML stream
  3. Sets `CurrentReport` → triggers `<DxReportViewer Report="@CurrentReport"/>`
- The Viewer provides:
  - Parameter panel (Start Date, End Date, Queue DN, SLA)
  - Report preview with page navigation
  - Export toolbar (PDF, Excel, CSV, HTML, RTF, DOCX, image)
  - Print button
  - Search within report

### ScheduleReports.razor

```
Route:     /schedulereports
Directive: @rendermode InteractiveServer
Injected:  IReportScheduleRepository, ReportStorageWebExtension, ILogger
```

**How it works:**
- On initialization, loads all existing schedules from `report_schedules` table
- Loads available report templates from `ReportStorage.GetUrls()`
- Provides a create/edit form with:
  - Schedule name, report template selection
  - Frequency picker (Daily / Weekly / Monthly)
  - Day of week (for Weekly), day of month (for Monthly)
  - Time and timezone selection
  - Export format (PDF / XLSX / CSV)
  - Report parameter inputs (period dates, queue DN, SLA, wait interval, timezone)
  - Email recipients (To / CC), custom subject and body
  - Enable/disable toggle
- Schedule list table with status badges, last run info, and action buttons
- Delete confirmation modal
- Enable/disable inline toggle per schedule

---

## 10. Layout & Navigation

### Two MainLayout Files (Be Careful!)

The application has **two** `MainLayout.razor` files that work together:

```
Components/MainLayout.razor    ← HTML document structure (<html>, <head>, <body>)
Shared/MainLayout.razor        ← Page layout structure (sidebar + content area)
```

**Components/MainLayout.razor** — The outer shell:
```html
<html>
  <head>
    <link rel="stylesheet" href="css/bootstrap/bootstrap.min.css" />
    <link rel="stylesheet" href="css/site.css" />
    <link rel="stylesheet" href="_content/DevExpress.Blazor.Themes/blazing-berry.bs5.min.css" />
  </head>
  <body>
    <div class="page">
      <NavMenu />     ← Sidebar navigation
      <main>
        <article class="content">@Body</article>   ← Page content renders here
      </main>
    </div>
    <script src="_framework/blazor.web.js"></script>
    <script src="_content/DevExpress.Blazor/dx-blazor.js"></script>
  </body>
</html>
```

**Shared/MainLayout.razor** — Defines the `@Body` slot for child pages:
```html
@inherits LayoutComponentBase
@Body
```

### NavMenu.razor

Collapsible sidebar with three navigation links:

```
┌──────────────────────┐
│ ☰ VoIPTools Reporting│  ← Brand header with collapse toggle
├──────────────────────┤
│ 🖌️ Report Designer   │  ← href="reportdesigner"
│ 📄 Report Viewer      │  ← href="reportviewer"
│ ⏰ Schedule Reports   │  ← href="schedulereports"
├──────────────────────┤
│ ⚙️ Settings           │  ← Placeholder (not implemented)
└──────────────────────┘
```

The sidebar uses CSS classes `sidebar-expanded` / `sidebar-collapsed` toggled by `IsCollapsed` boolean. Active link detection uses `NavigationManager.ToBaseRelativePath()`.

### Index.razor

```razor
@page "/"
@code {
    protected override void OnInitialized()
    {
        Navigation.NavigateTo("/reportdesigner");  // Auto-redirect
    }
}
```

Visiting the root URL immediately redirects to the Report Designer.

---

## 11. DevExpress Integration

### Package Architecture

```
DevExpress.Blazor (v25.2.3)
  └── Core Blazor UI components (DxButton, DxListBox, etc.)

DevExpress.Blazor.Reporting (v25.2.3)
  └── DxReportDesigner component

DevExpress.Blazor.Reporting.JSBasedControls (v25.2.3)
  └── JavaScript-based Designer internals

DevExpress.Blazor.Reporting.Viewer (v25.2.3)
  └── DxReportViewer component

DevExpress.AspNetCore.Reporting (v25.2.3)
  └── Server-side reporting engine, MVC controllers, export providers
```

> **CRITICAL:** All 5 DevExpress packages MUST be the **same version**. Mixing versions causes cryptic JavaScript errors.

### Theme

The application uses the **Blazing Berry** Bootstrap 5 theme:
```html
<link rel="stylesheet" href="_content/DevExpress.Blazor.Themes/blazing-berry.bs5.min.css" />
```

### .repx File Format

DevExpress reports are stored as `.repx` files — XML documents describing:
- Report bands (header, detail, footer, sub-reports)
- Controls (labels, tables, charts, panels)
- Data sources (SQL connections, queries, parameters)
- Expressions and bindings
- Styles and formatting

The XML contains Base64-encoded sections for `SqlDataSource` objects inside `<ComponentStorage>`.

---

## 12. Database Configuration

### Connection Strings

**Production (Live Data):**
```
Server: 3.132.72.134
Database: 3CX Exporter
User: sa
Password: V01PT0y5
```

**Local Development (Test Data):**
```
Server: LAPTOP-A5UI98NJ\SQLEXPRESS
Database: Test_3CX_Exporter
User: sa
Password: V01PT0y5
```

### Where Connections Are Defined

| Location | Purpose |
|----------|---------|
| `appsettings.json` → `ConnectionStrings.DefaultConnection` | ADO.NET connections (if any) |
| `ReportDataSourceProviders.cs` → `GetConnectionDescriptions()` | Designer wizard dropdown |
| `ReportDataSourceProviders.cs` → `GetDataConnectionParameters()` | Design-time connections |
| `ReportDataSourceProviders.cs` → `LoadConnection()` | Runtime connections |
| `.repx` files → `<Connection Name="3CX_Exporter_Production">` | Stored connection name (resolved at runtime) |

> **Note:** Connection strings are currently hardcoded in `ReportDataSourceProviders.cs`. For production, move them to `appsettings.json` and inject `IConfiguration`.

### Key Database Objects

| Object | Type | Used By |
|--------|------|---------|
| `CallCent_QueueCalls_View` | View | All 3 stored procedures |
| `extensions_by_queues_view` | View | SP1 (KPIs) + SP3 (Agents) |
| `sp_queue_stats_summary` | Stored Procedure | KPI cards |
| `sp_queue_stats_daily_summary` | Stored Procedure | Area chart |
| `qcall_cent_get_extensions_statistics_by_queues` | Stored Procedure | Agent table |

---

## 13. NuGet Packages

```xml
<PackageReference Include="DevExpress.AspNetCore.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.JSBasedControls" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.Viewer" Version="25.2.3" />
<PackageReference Include="Microsoft.Data.SqlClient" Version="6.1.2" />
```

| Package | Why |
|---------|-----|
| `DevExpress.AspNetCore.Reporting` | Server-side reporting engine, REST controllers for Designer/Viewer |
| `DevExpress.Blazor` | Core Blazor components and theme CSS |
| `DevExpress.Blazor.Reporting` | `DxReportDesigner` Blazor component |
| `DevExpress.Blazor.Reporting.JSBasedControls` | JavaScript runtime for the visual Designer |
| `DevExpress.Blazor.Reporting.Viewer` | `DxReportViewer` Blazor component |
| `Microsoft.Data.SqlClient` | SQL Server ADO.NET driver (used by DevExpress data sources) |

---

## 14. Build & Run

### Prerequisites

1. **.NET 8 SDK** installed
2. **DevExpress NuGet feed** configured (requires DevExpress license)
3. **SQL Server** accessible (3.132.72.134 or local instance)
4. 3CX Exporter database with required stored procedures deployed

### First-Time Setup

```powershell
# 1. Clone the repository
git clone https://github.com/SubZero2714/VoipTools-ReportingToolMVP.git

# 2. Navigate to project
cd VoipTools-ReportingToolMVP/ReportingToolMVP

# 3. Copy and configure settings
Copy-Item appsettings.json.sample appsettings.json
# Edit appsettings.json → set your connection string

# 4. Restore packages
dotnet restore

# 5. Build
dotnet build

# 6. Run
dotnet run
# Application starts at https://localhost:7209
```

### Development with Hot Reload

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet watch run
```

### Running Tests

```powershell
cd ../ReportingToolMVP.Tests
dotnet test
```

### Application URLs

| URL | Purpose |
|-----|---------|
| `https://localhost:7209` | Main app (redirects to Designer) |
| `https://localhost:7209/reportdesigner` | Report Designer |
| `https://localhost:7209/reportviewer` | Report Viewer |
| `http://localhost:5193` | HTTP (redirects to HTTPS) |

---

## 15. Report Template (.repx) System

### How .repx Files Work

```
                          Application Startup
                                 │
                                 ▼
              QueuePerformanceDashboardGenerator.GenerateAndSave()
                                 │
                                 ▼
              Similar_to_samuel_sirs_report.repx (XML file)
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼             ▼
               Designer      Viewer       File System
             (edit/save)   (read/render)   (Templates/)
```

### .repx XML Structure (Simplified)

```xml
<?xml version="1.0" encoding="utf-8"?>
<XtraReportsLayoutSerializer>
  <!-- Report-level properties -->
  <Item Name="QueuePerformanceDashboard" Landscape="true" PageWidth="1100">
    
    <!-- Report Parameters (user inputs) -->
    <Parameters>
      <Item Name="pPeriodFrom" Type="DateTime" Value="2025-06-01" Visible="true"/>
      ...
    </Parameters>
    
    <!-- Bands (report sections) -->
    <Bands>
      <Item xsi:type="TopMarginBand"/>
      <Item xsi:type="ReportHeaderBand">
        <!-- KPI cards, chart, labels -->
      </Item>
      <Item xsi:type="DetailBand" Visible="false"/>
      <Item xsi:type="DetailReportBand" DataMember="Agents">
        <!-- Agent table -->
      </Item>
      <Item xsi:type="PageFooterBand"/>
    </Bands>
    
    <!-- SQL Data Sources (Base64-encoded) -->
    <ComponentStorage>
      <Item Name="dsKPIs" Base64="..." />
      <Item Name="dsChartData" Base64="..." />
      <Item Name="dsAgents" Base64="..." />
    </ComponentStorage>
  </Item>
</XtraReportsLayoutSerializer>
```

### Auto-Generation on Startup

Every time the application starts, `Program.cs` calls:
```csharp
QueuePerformanceDashboardGenerator.GenerateAndSave(repxPath);
```

This **overwrites** `Similar_to_samuel_sirs_report.repx`. If you modify this report in the Designer and save, your changes will be **lost on next restart**. To preserve manual changes:
1. Save the report under a DIFFERENT name in the Designer
2. Or comment out the generator call in `Program.cs`

---

## 16. SignalR & Performance

### Why SignalR Tuning Matters

Blazor Server renders UI on the server and sends HTML diffs to the browser via SignalR WebSocket. Report payloads (Designer JS components, preview data, export files) can be large. Default SignalR limits cause disconnections.

### Tuned Settings

```csharp
opts.MaximumReceiveMessageSize = 1024 * 1024;    // 1 MB (default: 32 KB)
opts.StreamBufferCapacity = 30;                    // default: 10
opts.ClientTimeoutInterval = TimeSpan.FromSeconds(60);  // default: 30s
opts.KeepAliveInterval = TimeSpan.FromSeconds(15);      // default: 15s
```

### Response Compression

```csharp
// Brotli (primary, ~20% better than Gzip) + Gzip (fallback)
// Applied to: application/octet-stream, application/javascript, text/css, image/svg+xml
// Compression level: Fastest (CPU trade-off for Blazor real-time needs)
```

### Static Asset Caching

```csharp
// CSS, JS, fonts cached for 7 days
ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=604800,immutable");
```

---

## 17. Scheduled Reports (Email Delivery)

### Overview

The application includes an automated report scheduling system that generates reports on a configurable schedule and delivers them via email as PDF, XLSX, or CSV attachments.

### Architecture

```
┌─────────────────────────────────┐
│  ScheduleReports.razor (UI)     │  ← User configures schedules
│  /schedulereports               │
└───────────────┬─────────────────┘
                │ CRUD operations
                ▼
┌─────────────────────────────────┐
│  ReportScheduleRepository       │  ← ADO.NET ↔ report_schedules table
│  (IReportScheduleRepository)    │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│  report_schedules (SQL table)   │  ← Persists schedule config, run history
│  Server: 3.132.72.134           │
└───────────────┬─────────────────┘
                │ Polled every 60s
                ▼
┌─────────────────────────────────┐
│  ReportSchedulerBackgroundService│  ← BackgroundService (hosted)
│  (polls for due schedules)      │
│                                 │
│  For each due schedule:         │
│  ├── ReportGeneratorService     │  ← Loads .repx, exports to PDF/XLSX/CSV
│  └── EmailService               │  ← Sends email via SMTP with attachment
└─────────────────────────────────┘
```

### Database Table: `report_schedules`

Created by `SQL/CreateReportSchedulesTable.sql`. Key columns:

| Column | Type | Purpose |
|--------|------|---------|
| `schedule_name` | NVARCHAR(200) | User-friendly name |
| `report_name` | NVARCHAR(500) | .repx filename (without extension) |
| `frequency` | NVARCHAR(20) | Daily, Weekly, or Monthly |
| `day_of_week` | INT | 0=Sun..6=Sat (Weekly only) |
| `day_of_month` | INT | 1-28 (Monthly only) |
| `scheduled_time` | TIME | Time of day to run |
| `timezone` | NVARCHAR(100) | IANA/Windows timezone ID |
| `report_params_json` | NVARCHAR(MAX) | JSON dict of report parameter values |
| `email_to` / `email_cc` | NVARCHAR(MAX) | Comma-separated email addresses |
| `export_format` | NVARCHAR(10) | PDF, XLSX, or CSV |
| `next_run_utc` | DATETIME2 | Pre-calculated next execution time |
| `last_run_status` | NVARCHAR(20) | Success, Failed, or Running |

Index: `IX_report_schedules_next_run` on `(is_enabled, next_run_utc)` for efficient polling.

### Model: `ReportSchedule.cs`

```csharp
// Enums
public enum ScheduleFrequency { Daily, Weekly, Monthly }
public enum ExportFormat { PDF, XLSX, CSV }
public enum RunStatus { Success, Failed, Running }

// Entity class maps 1:1 to the SQL table
// Helper methods:
//   GetReportParams() / SetReportParams() — JSON ↔ Dictionary<string,string>
//   GetScheduleDescription() — "Daily at 08:00 AM (India Standard Time)"
```

---

## 18. Secrets & Configuration Management

### Configuration Hierarchy (Priority: highest → lowest)

```
1. Environment Variables     ← Production (SmtpSettings__Host, etc.)
2. User Secrets              ← Development (dotnet user-secrets)
3. appsettings.{Environment}.json
4. appsettings.json          ← Contains empty SMTP placeholders
```

.NET 8's `WebApplication.CreateBuilder()` loads all these sources automatically. Higher-priority sources override lower ones.

### Development: User Secrets

SMTP credentials are stored outside the repository using .NET User Secrets:

```powershell
# View all secrets
dotnet user-secrets list

# Set a secret
dotnet user-secrets set "SmtpSettings:Username" "mail@voiptools.com"
dotnet user-secrets set "SmtpSettings:Password" "your-password"

# Clear all secrets
dotnet user-secrets clear
```

Secrets are stored at: `%APPDATA%\Microsoft\UserSecrets\{UserSecretsId}\secrets.json`

The `UserSecretsId` is defined in `ReportingToolMVP.csproj`.

### Production: Environment Variables

Use the `__` (double underscore) separator to map to JSON hierarchy:

| appsettings.json Path | Environment Variable |
|----------------------|---------------------|
| `SmtpSettings:Host` | `SmtpSettings__Host` |
| `SmtpSettings:Port` | `SmtpSettings__Port` |
| `SmtpSettings:EnableSsl` | `SmtpSettings__EnableSsl` |
| `SmtpSettings:Username` | `SmtpSettings__Username` |
| `SmtpSettings:Password` | `SmtpSettings__Password` |
| `SmtpSettings:FromAddress` | `SmtpSettings__FromAddress` |
| `SmtpSettings:FromDisplayName` | `SmtpSettings__FromDisplayName` |

Set on Windows (machine-level, persists across reboots):
```powershell
[Environment]::SetEnvironmentVariable("SmtpSettings__Host", "smtp.office365.com", "Machine")
[Environment]::SetEnvironmentVariable("SmtpSettings__Username", "mail@voiptools.com", "Machine")
# ... etc.
```

### What's in appsettings.json (safe for git)

```json
"SmtpSettings": {
  "Host": "",
  "Port": 587,
  "EnableSsl": true,
  "Username": "",
  "Password": "",
  "FromAddress": "",
  "FromDisplayName": "VoIPTools Reporting"
}
```

> **IMPORTANT:** Never commit real SMTP credentials to `appsettings.json`. The file contains only empty placeholders and structural defaults.

---

## 19. Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Designer loads blank | DevExpress JS not loaded | Check `dx-blazor.js` script tag in MainLayout |
| "Query X is not allowed" | Custom SQL not enabled | Ensure `EnableCustomSql()` in Program.cs |
| Chart shows blank | Missing ResultSchema in .repx | Generator handles this; if manual, see MANUAL_REPORT_CREATION_GUIDE.md |
| "An error occurred while rebuilding data source schema" | Wrong SP parameter types in wizard | Use Expression type with `#date#` syntax for dates |
| SignalR disconnects | Message too large | Increase `MaximumReceiveMessageSize` |
| Report preview timeout | Slow SP execution | Add `WITH (NOLOCK)` to SP queries |
| Port already in use | Previous instance running | `Stop-Process` the dotnet process, or use a different port |
| All DevExpress components broken | Version mismatch | Ensure ALL DevExpress packages use exact same version |

### Debugging Tips

1. **Check browser console** (F12) for JavaScript errors from DevExpress components
2. **Enable detailed logging** in appsettings.json:
   ```json
   "Logging": { "LogLevel": { "Default": "Information", "DevExpress": "Debug" } }
   ```
3. **FileReportStorageService** logs all GetData/SetData/GetUrls calls
4. **ReportDataSourceProviders** logs all connection requests

---

## 20. Glossary

| Term | Definition |
|------|-----------|
| **.repx** | DevExpress report template file (XML format) |
| **Band** | Horizontal section of a report (Header, Detail, Footer, SubReport) |
| **Blazor Server** | .NET UI framework where components run on server, UI updates sent via SignalR |
| **ComponentStorage** | XML section in .repx that holds Base64-encoded SqlDataSource definitions |
| **DetailReportBand** | A sub-report band that has its own data source (used for the Agent table) |
| **DxReportDesigner** | DevExpress Blazor component providing WYSIWYG report editing |
| **DxReportViewer** | DevExpress Blazor component for viewing/exporting reports |
| **Expression** | DevExpress formula language: `[field_name]`, `[Parameters.name]`, `FormatString(...)` |
| **GroupHeaderBand** | Band inside DetailReportBand that repeats on every page (table headers) |
| **IConnectionProviderService** | Interface for resolving connection names to SqlDataConnection at runtime |
| **ReportStorageWebExtension** | DevExpress abstract class for report persistence (file system, DB, etc.) |
| **ResultSchema** | XML element defining the expected columns/types from a SqlDataSource query |
| **SignalR** | Real-time communication library (WebSocket) used by Blazor Server |
| **SqlDataSource** | DevExpress data source that executes SQL queries/stored procedures |
| **StoredProcQuery** | DevExpress query type for calling stored procedures with parameters |
| **XRChart** | DevExpress report control for charts (area, bar, line, pie, etc.) |
| **XRTable** | DevExpress report control for tabular data with rows and cells |
| **XtraReport** | DevExpress root report object (the "document" containing all bands, sources, params) |
| **?paramName** | Syntax in Data Source Wizard to bind SP parameters to Report Parameters |
| **BackgroundService** | .NET hosted service that runs continuously in the background (used for schedule polling) |
| **report_schedules** | SQL table storing schedule configuration, email recipients, and run history |
| **User Secrets** | .NET development-time secret storage outside the project directory |
| **SmtpSettings** | Configuration section for outbound email (host, port, credentials) |

---

*End of Developer Guide*
