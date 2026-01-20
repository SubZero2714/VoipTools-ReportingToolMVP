# VoIPTools Reporting Tool - AI Agent Instructions

## Project Overview
.NET 8 Blazor Server reporting application for 3CX call queue analytics. Two reporting modes: query-based builder (DxGrid/DxChart) and WYSIWYG designer (DevExpress `.repx` templates + code-based reports).

## Architecture

```
ReportBuilder.razor → CustomReportService.cs → Dapper → SQL Server → DxGrid/DxChart
ReportDesigner.razor → DxReportDesigner → FileReportStorageService → Reports/*.repx OR code-based reports
ReportViewer.razor → DxReportViewer → ReportStorageWebExtension
QueueDashboardReport.cs → SqlDataSource → vw_QueueDashboard_* views → KPI Cards + Charts
```

### Key Tables
- `callcent_queuecalls` – call records with queue metrics
- `queue` – queue definitions (names)
- `dn` – phone extensions (links queues to calls)
- `users` – agent information

### Dashboard SQL Views
- `vw_QueueDashboard_KPIs` – aggregated KPI metrics (Total/Answered/Abandoned/Missed/SLA)
- `vw_QueueDashboard_AgentPerformance` – per-agent call statistics
- `vw_QueueDashboard_CallTrends` – daily call volume trends
- `vw_QueueList` – queue dropdown data

### Call Status Logic
```sql
-- Answered: Agent picked up the call
reason_noanswercode = 0 AND ts_servicing > '00:00:00'

-- Abandoned: Caller hung up (MaxWaitTime or UserRequested)
reason_noanswercode IN (3, 4)

-- Missed: No agents available
reason_noanswercode = 2
```

## Critical Patterns

### SQL Injection Prevention
**All columns MUST be whitelisted** in `Services/CustomReportService.cs`:
```csharp
private static readonly Dictionary<string, string> AllowedColumns = new()
{
    { "QueueNumber", "[q_num]" },
    { "TotalCalls", "COUNT(*) as [TotalCalls]" },
    { "AvgWaitTime", "AVG(DATEDIFF(SECOND, 0, [ts_waiting])) as [AvgWaitTime]" },
    // Add new columns here - NEVER use raw user input in SQL
};
```

### Adding New Report Columns
1. Add to `AllowedColumns` with safe SQL expression
2. **If aggregate** (COUNT, SUM, AVG): no GROUP BY change needed—aggregates work with existing groups
3. **If non-aggregate** (raw column): must add to GROUP BY logic in `GetCustomReportDataAsync()`

**GROUP BY rule:** Only `QueueNumber` and `Date` are grouping columns. All other columns are aggregates.
```
User selects: [Date, QueueNumber, TotalCalls, AvgWaitTime]
→ GROUP BY: CAST(time_start AS DATE), q_num
→ Result: One row per queue per day with aggregated metrics

User selects: [QueueNumber, TotalCalls] (no Date)
→ GROUP BY: q_num  
→ Result: One row per queue, metrics aggregated across all dates
```

### DevExpress Component Usage
```razor
@* All interactive pages require this directive *@
@rendermode InteractiveServer

@* Standard two-way binding pattern *@
<DxDateEdit @bind-Date="@Config.StartDate" Format="dd-MM-yyyy" />

@* Multi-select with checkboxes *@
<DxListBox Data="@Items" @bind-Values="@SelectedItems" 
           SelectionMode="ListBoxSelectionMode.Multiple" ShowCheckboxes="true" />

@* Dynamic grid columns *@
@foreach (var col in SelectedColumnsList)
{
    <DxGridDataColumn FieldName="@col" Caption="@FormatColumnName(col)" />
}
```

### DxGrid Dynamic Data Binding
DxGrid requires `ExpandoObject` for runtime-determined columns:
```csharp
var expando = new ExpandoObject();
var dict = (IDictionary<string, object>)expando;
foreach (var kvp in row.Data)
    dict[kvp.Key] = kvp.Value ?? string.Empty;
```

## Program.cs Service Order (Critical)
DevExpress reporting requires specific registration order. **All DevExpress packages must be same version (25.2.3).**
```csharp
builder.Services.AddDevExpressBlazor();                    // 1. Core components
builder.Services.AddDevExpressBlazorReporting();           // 2. Reporting services
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, ...>();
builder.Services.AddScoped<IDBSchemaProviderExFactory, ...>();  // Required for Query Builder
builder.Services.AddScoped<ICustomQueryValidator, AllowAllQueriesValidator>();  // Allow custom SQL
// ...
app.UseDevExpressBlazorReporting();  // BEFORE MapRazorComponents
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
```

## Code-Based Reports
Reports can be created programmatically in C# (see `Reports/QueueDashboardReport.cs`):
```csharp
public class QueueDashboardReport : XtraReport
{
    private void CreateDataSource()
    {
        var sqlDataSource = new SqlDataSource("QueueDashboardDataSource");
        sqlDataSource.ConnectionParameters = new CustomStringConnectionParameters(connectionString);
        
        var kpiQuery = new CustomSqlQuery("KPISummary", "SELECT ... FROM vw_QueueDashboard_KPIs ...");
        kpiQuery.Parameters.Add(new QueryParameter("paramQueueNumber", typeof(string), "8000"));
        
        sqlDataSource.Queries.AddRange(new[] { kpiQuery, agentQuery, trendsQuery });
        this.DataSource = sqlDataSource;
    }
}
```
**Note:** Expression-based parameter bindings (`new Expression("?paramName")`) cannot be serialized. Use static default values.

## Developer Workflow

```powershell
cd ReportingToolMVP
dotnet restore
dotnet run                         # https://localhost:7XXX
$env:ASPNETCORE_ENVIRONMENT = "Development"; dotnet watch run  # Hot reload
```

**First-time setup:** Copy `appsettings.json.sample` → `appsettings.json`, set `DefaultConnection`.

## Routes

| Route | Component | Purpose |
|-------|-----------|---------|
| `/reportbuilder` | ReportBuilder.razor | Query-based reports with DxGrid/DxChart |
| `/reportdesigner` | ReportDesigner.razor | Visual WYSIWYG template editor |
| `/reportviewer` | ReportViewer.razor | View/export designed reports |
| `/test` | TestSuite.razor | Manual feature checklist |

## File Download Pattern
All exports use JS interop defined in `MainLayout.razor`:
```csharp
await JS.InvokeVoidAsync("downloadFile", fileName, Convert.ToBase64String(bytes), mimeType);
```

## CSS & Theme
- **DevExpress theme:** `blazing-berry.bs5.min.css` (all DX packages must match)
- **Component CSS:** `wwwroot/reportbuilder.css`, `wwwroot/testsuite.css`
- **Colors:** Primary blue `#4361ee`, accent purple `#9b59b6`
- **Date format:** `dd-MM-yyyy` throughout UI

## Test Data
Database contains: Dec 2023 – Oct 2025, 31 queues (8000-8030), max 10,000 rows per query.

## Key Files Reference
- `Services/CustomReportService.cs` – Column whitelist, query building
- `Services/ReportDataSourceProviders.cs` – DevExpress designer SQL providers
- `Services/FileReportStorageService.cs` – .repx template storage
- `Models/ReportConfig.cs` – User filter selections
- `FEATURES.md` – Phase tracking and status
