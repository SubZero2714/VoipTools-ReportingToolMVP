# VoIPTools Reporting Tool - AI Agent Instructions

## Project Overview
.NET 8 Blazor Server reporting application for 3CX call queue analytics. Uses DevExpress XtraReports v25.2.3 with a WYSIWYG Report Designer and Report Viewer. Reports are stored as `.repx` XML templates on the file system.

## Architecture

```
ReportDesigner.razor → DxReportDesigner → FileReportStorageService → Reports/Templates/*.repx
ReportViewer.razor → DxReportViewer → ReportStorageWebExtension → .repx → SQL Server
QueuePerformanceDashboardGenerator.cs → generates .repx on startup with XML post-processing
```

### Database Objects Used
- `CallCent_QueueCalls_View` – call records with queue metrics (3CX managed)
- `extensions_by_queues_view` – queue-to-agent mappings with display names (3CX managed)
- 3 Stored Procedures (custom):
  - `sp_queue_kpi_summary_shushant` – single aggregated row for KPI cards
  - `sp_queue_calls_by_date_shushant` – daily call trends for area chart
  - `qcall_cent_get_extensions_statistics_by_queues` – per-agent performance for table

### Key Connection
- Connection name in .repx: `3CX_Exporter_Production`
- Resolved at runtime by `CustomConnectionProviderService.LoadConnection()`
- Server: `3.132.72.134`, Database: `3CX Exporter`

## Critical Patterns

### DevExpress Service Registration Order (Program.cs)
**All DevExpress packages must be same version (25.2.3).**
```csharp
builder.Services.AddDevExpressBlazor();                    // 1. Core components
builder.Services.AddDevExpressBlazorReporting();           // 2. Reporting services
builder.Services.AddDevExpressServerSideBlazorReportViewer(); // 3. Server-side viewer
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(d => d.EnableCustomSql());  // 4. Enable SP queries
    configurator.ConfigureWebDocumentViewer(v => v.UseCachedReportSourceBuilder());
});
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, ...>();
builder.Services.AddScoped<IConnectionProviderService, ...>();
builder.Services.AddScoped<IConnectionProviderFactory, ...>();
builder.Services.AddScoped<IDBSchemaProviderExFactory, ...>();
// ...
app.UseDevExpressBlazorReporting();  // BEFORE MapRazorComponents
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
```

### Report Generator (QueuePerformanceDashboardGenerator.cs)
The production report is generated programmatically at startup because DevExpress `SaveLayoutToXml()` strips:
1. `DataMember` on XRChart controls
2. `ArgumentDataMember` / `ValueDataMembersSerializable` on chart series
3. `ResultSchema` on StoredProcQuery data sources

The generator creates the report, saves to XML, then **post-processes the XML** to re-inject these properties. Any changes to the generated report in the Designer will be **overwritten on restart**.

### File Storage Service (FileReportStorageService.cs)
- Reports stored in `Reports/` and `Reports/Templates/` (.repx files)
- `IMemoryCache` with 10-min TTL + file-modified-timestamp invalidation
- Template lookup: `Templates/` first, `Reports/` fallback
- `FormatDisplayName()` converts snake_case filenames to readable names

### Data Source Providers (ReportDataSourceProviders.cs)
5 classes enabling Designer SQL connections:
- `CustomDataSourceWizardConnectionStringsProvider` – populates wizard dropdown (Production + Local)
- `AllowAllQueriesValidator` – allows all SQL queries (dev mode)
- `CustomConnectionProviderService` – resolves connection NAME to SqlDataConnection at runtime
- `CustomConnectionProviderFactory` – factory wrapper for above
- `CustomDBSchemaProviderExFactory` – enables Query Builder table/column discovery

### SignalR Optimization
```csharp
MaximumReceiveMessageSize = 1 MB   // Default 32KB too small for report payloads
StreamBufferCapacity = 30
ClientTimeoutInterval = 60s
KeepAliveInterval = 15s
```

## Routes

| Route | Component | Purpose |
|-------|-----------|---------|
| `/` | Index.razor | Redirects to /reportdesigner |
| `/reportdesigner` | ReportDesigner.razor | Visual WYSIWYG report template editor |
| `/reportdesigner/{ReportUrl}` | ReportDesigner.razor | Open specific report for editing |
| `/reportviewer` | ReportViewer.razor | View/export reports with parameter filtering |
| `/reportviewer/{ReportUrl}` | ReportViewer.razor | Open specific report for viewing |

## Developer Workflow

```powershell
cd ReportingToolMVP
dotnet restore
dotnet run                         # https://localhost:7209
$env:ASPNETCORE_ENVIRONMENT = "Development"; dotnet watch run  # Hot reload
```

**First-time setup:** Copy `appsettings.json.sample` → `appsettings.json`, set connection strings.

## CSS & Theme
- **DevExpress theme:** `blazing-berry.bs5.min.css` (all DX packages must match version)
- **Custom CSS:** `wwwroot/css/site.css`
- Static file caching: 7-day Cache-Control header

## Key Files Reference
- `Program.cs` – DI registration, middleware pipeline, report generation on startup
- `Services/FileReportStorageService.cs` – .repx file storage with caching
- `Services/ReportDataSourceProviders.cs` – 5 DB connection provider classes
- `Reports/QueuePerformanceDashboardGenerator.cs` – Code-based .repx generator with XML post-processing
- `Components/Pages/ReportDesigner.razor` – DxReportDesigner page
- `Components/Pages/ReportViewer.razor` – DxReportViewer with dropdown selector
- `Shared/NavMenu.razor` – Sidebar navigation (Designer + Viewer links)
- `SQL/Similar_to_samuel_sirs_report/` – All 3 stored procedure definitions

## Documentation
- `documentation/DEVELOPER_GUIDE.md` – Comprehensive architecture, data flow, every file explained
- `documentation/SQL_REFERENCE.md` – Complete SP documentation with CTE explanations
- `documentation/MANUAL_REPORT_CREATION_GUIDE.md` – End-user step-by-step report creation guide

## Test Project
`ReportingToolMVP.Tests/` contains xUnit integration tests:
- `KpiStoredProcTests.cs` – SP1 validation
- `ChartStoredProcTests.cs` – SP2 validation
- `AgentStoredProcTests.cs` – SP3 validation

