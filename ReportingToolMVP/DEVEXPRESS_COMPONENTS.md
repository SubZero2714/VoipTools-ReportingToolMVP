# DevExpress Components & Report Designer Guide

> **Single authoritative reference** for all DevExpress Blazor components, the Report Designer/Viewer system, capabilities, limitations, and troubleshooting.  
> **DevExpress Version:** 25.2.3 | **.NET:** 8.0 | **Last Updated:** February 17, 2026

---

## Table of Contents

1. [Package References](#package-references)
2. [Program.cs Service Registration (Critical Order)](#programcs-service-registration)
3. [Report Designer (DxReportDesigner)](#report-designer)
4. [Report Viewer (DxReportViewer)](#report-viewer)
5. [v25.2.3 Breaking Changes & Gotchas](#v2523-breaking-changes)
6. [Backend Services](#backend-services)
7. [Report Template (.repx) Authoring](#repx-authoring)
8. [Data Sources in Reports](#data-sources-in-reports)
9. [Report Parameters](#report-parameters)
10. [Stored Procedure Binding Pattern](#stored-procedure-binding-pattern)
11. [Report Bands & Layout](#report-bands-and-layout)
12. [XRChart Configuration](#xrchart-configuration)
13. [DetailReportBand (Sub-reports)](#detailreportband)
14. [Blazor UI Components (Report Builder)](#blazor-ui-components)
15. [CSS & Theme](#css-and-theme)
16. [Capabilities & Limitations](#capabilities-and-limitations)
17. [Troubleshooting](#troubleshooting)
18. [Version History](#version-history)

---

## Package References

All packages **MUST** be the same version (25.2.3):
```xml
<PackageReference Include="DevExpress.Blazor" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.Viewer" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.JSBasedControls" Version="25.2.3" />
<PackageReference Include="DevExpress.AspNetCore.Reporting" Version="25.2.3" />
```

**Theme:** Blazing Berry (BS5) — `_content/DevExpress.Blazor.Themes/blazing-berry.bs5.min.css`

---

## Program.cs Service Registration

Order matters. DevExpress reporting requires specific registration:

```csharp
// 1. Core Blazor + DevExpress
builder.Services.AddDevExpressBlazor();

// 2. Reporting services
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// 3. Custom services (scoped)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, CustomDataSourceWizardConnectionStringsProvider>();
builder.Services.AddScoped<IConnectionProviderService, CustomConnectionProviderService>();
builder.Services.AddScoped<ICustomQueryValidator, AllowAllQueriesValidator>();
builder.Services.AddScoped<IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();

// ... middleware ...
app.UseDevExpressBlazorReporting();   // BEFORE MapRazorComponents
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
```

---

## Report Designer

**Component:** `DxReportDesigner` (JS-based control)  
**File:** `Components/Pages/ReportDesigner.razor`  
**Route:** `/reportdesigner` or `/reportdesigner/{ReportUrl}`

### Properties (v25.2.3)
| Property | Type | Description |
|----------|------|-------------|
| `ReportName` | `string` | URL/name of the report to load (maps to `FileReportStorageService.GetData()`) |
| `AllowMDI` | `bool` | Enable multiple document interface |
| `Height` | `string` | Component height (CSS value) |
| `Width` | `string` | Component width (CSS value) |

### Usage
```razor
@page "/reportdesigner/{ReportUrl}"
@using DevExpress.Blazor.Reporting
@rendermode InteractiveServer

<DxReportDesigner @ref="DesignerComponent"
                  ReportName="@CurrentReportName"
                  AllowMDI="true"
                  Height="calc(100vh - 180px)"
                  Width="100%" />
```

### Capabilities
- Drag-and-drop report element placement
- Data binding to SQL data sources via wizard
- Band-based report structure (ReportHeader, Detail, PageHeader, PageFooter, GroupHeader, etc.)
- Property grid for element customization
- Query Builder with schema browser (requires `IDBSchemaProviderExFactory`)
- Custom SQL execution (requires `ICustomQueryValidator`)
- Built-in preview and export
- Multiple data sources per report
- Expression editor for calculated fields
- Stored procedure parameter binding via expressions

### Key Notes
- The designer is a **JS-based** control (not native Blazor). It uses `ReportName` (string), not an `XtraReport` object.
- `ReportName` is passed to `FileReportStorageService.GetData(url)` to load the report bytes.
- The designer serializes connection strings into the `.repx` XML as base64-encoded `ObjectStorage` entries.

---

## Report Viewer

**Component:** `DxReportViewer` (native Blazor control in v25.2.3)  
**File:** `Components/Pages/ReportViewer.razor`  
**Route:** `/reportviewer` or `/reportviewer/{ReportUrl}`

### ⚠️ CRITICAL: v25.2.3 Native Viewer API

In v25.2.3, `DxReportViewer` is a **native Blazor component** (not JS-based). Its API is different from the JS-based designer:

| Property | Type | Description |
|----------|------|-------------|
| `Report` | `XtraReport` | **The report object** (NOT a string name) |

**Does NOT support:** `ReportName` (string), `Height`, `Width` as component properties.

### Usage (Correct for v25.2.3)
```razor
@using DevExpress.Blazor.Reporting
@using DevExpress.XtraReports.UI
@inject ReportStorageWebExtension ReportStorage

<div style="width:100%; height:calc(100vh - 180px);">
    <DxReportViewer @ref="ViewerComponent"
                    Report="@CurrentReport" />
</div>

@code {
    private XtraReport? CurrentReport;

    private void LoadReport(string reportName)
    {
        var reportBytes = ReportStorage.GetData(reportName);
        var report = new XtraReport();
        using (var stream = new MemoryStream(reportBytes))
        {
            report.LoadLayoutFromXml(stream);
        }
        CurrentReport = report;
    }
}
```

### Features
- Report preview with pagination
- Print functionality
- Export to PDF, Excel, Word, HTML, etc.
- Search within report
- Zoom controls
- Parameter panel (auto-generated from report parameters)

---

## v25.2.3 Breaking Changes

### DxReportViewer Changes (from v25.1 → v25.2)

| Aspect | v25.1 (JS-based) | v25.2.3 (Native Blazor) |
|--------|-------------------|-------------------------|
| Report loading | `ReportName="@name"` (string) | `Report="@xtraReport"` (XtraReport object) |
| Sizing | `Height="100%" Width="100%"` | Wrap in `<div style="...">` |
| Component type | JS interop control | Native Blazor component |
| Namespace | `DevExpress.Blazor.Reporting` | `DevExpress.Blazor.Reporting` + `DevExpress.XtraReports.UI` |

### DxReportDesigner (Unchanged)
The designer remains JS-based and still accepts `ReportName` (string), `Height`, and `Width`.

---

## Backend Services

### FileReportStorageService
**File:** `Services/FileReportStorageService.cs`  
**Implements:** `ReportStorageWebExtension`

| Method | Purpose |
|--------|---------|
| `GetData(url)` | Load report bytes from `.repx` file or code-based report |
| `SetData(report, url)` | Save report to file |
| `SetNewData(report, url)` | Create new report file |
| `GetUrls()` | List all available reports (returns `Dictionary<string, string>`) |
| `IsValidUrl(url)` | Validate report URL |

**Storage locations** (checked in order):
1. `Reports/Templates/{name}.repx`
2. `Reports/{name}.repx`
3. Code-based reports (e.g., `QueueDashboardReport`, `BlankReport`)

### ReportDataSourceProviders
**File:** `Services/ReportDataSourceProviders.cs`

| Class | Purpose |
|-------|---------|
| `CustomDataSourceWizardConnectionStringsProvider` | Provides connection names for Data Source wizard dropdown |
| `CustomConnectionProviderService` | Resolves connection names to actual `XpoProvider=MSSqlServer` connection strings |
| `AllowAllQueriesValidator` | Allows custom SQL in Query Builder (dev mode) |
| `CustomDBSchemaProviderExFactory` | Required for Query Builder schema browsing |

**Available Connections:**
- `3CX_Exporter_Production` → `3.132.72.134` (LIVE)
- `3CX_Exporter_Local` → `LAPTOP-A5UI98NJ\SQLEXPRESS` (test)

---

## Report Template (.repx) Authoring

### File Format
`.repx` files are XML serializations of `XtraReport` objects. They contain:
- Report bands and controls (labels, tables, charts)
- Data source definitions (base64-encoded in `ObjectStorage`)
- Parameter definitions
- Expression bindings
- Formatting rules

### Storage Location
```
Reports/
├── Templates/
│   ├── VoIPToolsDashboard.repx
│   ├── AgentSummaryReport.repx
│   ├── QueueSummaryReport.repx
│   ├── MonthlySummaryReport.repx
│   └── Similar_to_samuel_sirs_report.repx    ← Queue Performance Dashboard
├── BlankReport.cs                              ← Code-based starter template
└── QueuePerformanceSummary.repx
```

---

## Data Sources in Reports

### SqlDataSource with Stored Procedures
Reports use `SqlDataSource` objects that connect to SQL Server stored procedures. Each data source is serialized as base64-encoded XML in the `.repx` file's `ObjectStorage` section.

### Structure (inside .repx XML)
```xml
<ObjectStorage>
    <Item1 ObjectType="DevExpress.DataAccess.Sql.SqlDataSource,DevExpress.DataAccess..."
           Base64="..." Ref="0" />
    <!-- Base64 decodes to XML with connection, SP name, and parameter bindings -->
</ObjectStorage>
```

### Connection String Format (for XpoProvider)
```
XpoProvider=MSSqlServer;Data Source=3.132.72.134;Initial Catalog=3CX Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;
```

### Multiple Data Sources
A single report can have multiple `SqlDataSource` objects. Each is referenced by `#Ref-N` and bound to different report elements:
- Root report band → `DataSource="#Ref-0"` + `DataMember="QueryName"`
- XRChart → `DataSource="#Ref-1"` + series bind to columns
- DetailReportBand → `DataSource="#Ref-2"` + `DataMember="QueryName"`

---

## Report Parameters

### Defining Parameters (in .repx)
```xml
<Parameters>
    <Item1 Name="pPeriodFrom" Type="System.DateTime" />
    <Item2 Name="pPeriodTo" Type="System.DateTime" />
    <Item3 Name="pQueueDns" Type="System.String" />
    <Item4 Name="pWaitInterval" Type="System.String" />
</Parameters>
```

### Parameter → SP Binding (Expression Type)
Stored procedure parameters are bound to report parameters using expressions.

**In .repx XML:**
```xml
<Parameter Name="@period_from" Type="Expression">[Parameters.pPeriodFrom]</Parameter>
<Parameter Name="@period_to" Type="Expression">[Parameters.pPeriodTo]</Parameter>
<Parameter Name="@queue_dns" Type="Expression">[Parameters.pQueueDns]</Parameter>
<Parameter Name="@wait_interval" Type="Expression">[Parameters.pWaitInterval]</Parameter>
```

**In Designer UI (Data Source Wizard):**
Use `?paramName` syntax in the Expression value field:
| SP Parameter | Type | Value |
|-------------|------|-------|
| `@period_from` | Expression | `?pPeriodFrom` |
| `@period_to` | Expression | `?pPeriodTo` |
| `@queue_dns` | Expression | `?pQueueDns` |
| `@wait_interval` | Expression | `?pWaitInterval` |

> **Key insight:** `?paramName` in the wizard is equivalent to `[Parameters.paramName]` in XML. Both reference Report Parameters.
>
> **Important:** Data source parameters **cannot be edited after creation** in the Designer UI. To change bindings, remove the data source and re-add it.

### User Experience
When the report loads in the viewer, a **parameter panel** appears automatically. Users enter values and click **Submit** to execute the stored procedures and populate the report.

---

## Stored Procedure Binding Pattern

### Current Report: Similar_to_samuel_sirs_report

**4 Common Parameters:**
| Report Parameter | SP Parameter | Type | Default | Description |
|------------------|-------------|------|---------|-------------|
| `pPeriodFrom` | `@period_from` | DateTime → DATETIMEOFFSET | 2026-02-01 | Start date |
| `pPeriodTo` | `@period_to` | DateTime → DATETIMEOFFSET | 2026-02-17 | End date |
| `pQueueDns` | `@queue_dns` | String → VARCHAR(MAX) | "8089" | Comma-separated queue DNs |
| `pWaitInterval` | `@wait_interval` | String → TIME | "00:00:20" | SLA threshold |

**3 Data Sources:**
| Data Source | Stored Procedure | Report Section | Key Columns |
|-------------|------------------|----------------|-------------|
| `dsKPIs` | `sp_queue_kpi_summary_shushant` | KPI Cards | total_calls, answered_calls, abandoned_calls, answered_within_sla_percent, mean_talking, total_talking, avg_waiting, serviced_callbacks |
| `dsChartData` | `sp_queue_calls_by_date_shushant` | Area Chart | call_date (X), answered_calls (Y1), abandoned_calls (Y2) |
| `dsAgents` | `qcall_cent_get_extensions_statistics_by_queues` | Agent Table | extension_display_name, extension_answered_count, avg_answer_time, avg_talk_time, talk_time, queue_received_count |

**Note:** SP names with `_shushant` suffix are the production versions on server 3.132.72.134.

---

## Report Bands and Layout

### Band Types Used
| Band | Purpose | Example |
|------|---------|---------|
| `ReportHeaderBand` | Title, filter info, KPI cards (appears once at top) | Dashboard header + 8 KPI panels |
| `DetailBand` | Repeats for each data row in root data source | (Minimal in dashboard reports) |
| `DetailReportBand` | Sub-report with its own data source | Agent Performance Table |
| `PageHeaderBand` | Repeated at top of every page | Report title on subsequent pages |
| `PageFooterBand` | Repeated at bottom of every page | Page numbers |

### XRLabel with Expression Bindings
```xml
<Item1 ControlType="XRLabel" Text="Total Calls">
    <ExpressionBindings>
        <Item1 PropertyName="Text" Expression="[total_calls]" />
    </ExpressionBindings>
</Item1>
```

### XRTable Structure
```xml
<Item1 ControlType="XRTable">
    <Rows>
        <Item1 ControlType="XRTableRow">
            <Cells>
                <Item1 ControlType="XRTableCell" Text="Agent" Weight="2" />
                <Item2 ControlType="XRTableCell" Text="Answered" Weight="1" />
            </Cells>
        </Item1>
    </Rows>
</Item1>
```

---

## XRChart Configuration

### Area Series (for call trends)
```xml
<Item1 ControlType="XRChart" Name="chartTrends" DataSource="#Ref-100" SizeF="750,280">
    <Series>
        <Item1 Name="Answered" ArgumentDataMember="call_date" ValueDataMembers="answered_calls"
               ViewType="AreaSeriesView" Color="Green" />
        <Item2 Name="Abandoned" ArgumentDataMember="call_date" ValueDataMembers="abandoned_calls"
               ViewType="AreaSeriesView" Color="Red" />
    </Series>
</Item1>
```

### Key Properties
- `DataSource` — Reference to a SqlDataSource (`#Ref-N`)
- `ArgumentDataMember` — X-axis column
- `ValueDataMembers` — Y-axis column(s)
- `ViewType` — `AreaSeriesView`, `BarSeriesView`, `LineSeriesView`, `PieSeriesView`

---

## DetailReportBand

Used when a report section needs its **own data source** (different from the root):

```xml
<Item1 ControlType="DetailReportBand" DataSource="#Ref-101" DataMember="Agents"
       Level="0" Name="agentDetail">
    <Bands>
        <Item1 ControlType="ReportHeaderBand">
            <!-- Agent table header row -->
        </Item1>
        <Item2 ControlType="DetailBand">
            <!-- Repeating row with expression bindings -->
        </Item2>
    </Bands>
</Item1>
```

---

## Blazor UI Components

### Report Builder Page Components
| # | Component | Purpose | File |
|---|-----------|---------|------|
| 1 | `DxDateEdit` | Date range pickers | ReportBuilder.razor |
| 2 | `DxListBox` | Multi-select for queues and columns | ReportBuilder.razor |
| 3 | `DxComboBox` | Chart type/axis selection | ReportBuilder.razor |
| 4 | `DxButton` | Action buttons | ReportBuilder.razor |
| 5 | `DxGrid` | Dynamic data grid with runtime columns | ReportBuilder.razor |
| 6 | `DxChart` | Bar and line charts | ReportBuilder.razor |
| 7 | `DxPieChart` | Pie chart visualization | ReportBuilder.razor |

### DxGrid Dynamic Column Pattern
```razor
<DxGrid Data="@ReportData" ShowFilterRow="true" ShowGroupPanel="true"
        PageSize="50" PagerVisible="true">
    <Columns>
        @foreach (var col in SelectedColumnsList)
        {
            <DxGridDataColumn FieldName="@col" Caption="@FormatColumnName(col)" />
        }
    </Columns>
</DxGrid>
```

DxGrid requires `ExpandoObject` for runtime-determined columns:
```csharp
var expando = new ExpandoObject();
var dict = (IDictionary<string, object>)expando;
foreach (var kvp in row.Data)
    dict[kvp.Key] = kvp.Value ?? string.Empty;
```

---

## CSS & Theme

- **DevExpress theme:** `blazing-berry.bs5.min.css`
- **Custom CSS:** `wwwroot/reportbuilder.css`, `wwwroot/testsuite.css`
- **Colors:** Primary blue `#4361ee`, accent purple `#9b59b6`, success green `#48bb78`, danger red `#f56565`
- **Date format:** `dd-MM-yyyy` throughout UI

---

## Capabilities and Limitations

### ✅ What Works
- Multiple `SqlDataSource` objects per report (stored procedures or custom SQL)
- Report parameters with expression bindings to SP parameters
- XRChart with multiple series (Area, Bar, Line, Pie)
- DetailReportBand for sub-reports with separate data sources
- Parameter panel auto-generated in Report Viewer
- Export to PDF, Excel, Word, HTML, CSV
- Query Builder with schema browser in designer
- Custom SQL execution in designer (with validator)
- Code-based reports (C# classes inheriting `XtraReport`)
- File-based `.repx` storage with `FileReportStorageService`

### ⚠️ Known Limitations
- **v25.2 DxReportViewer** is native Blazor — uses `Report` property (XtraReport object), NOT `ReportName` (string)
- **v25.2 DxReportViewer** does NOT accept `Height`/`Width` as component properties — wrap in a styled `<div>`
- **DxReportDesigner** remains JS-based — still uses `ReportName` (string), `Height`, `Width`
- SP parameter type mapping: DateTime ↔ DATETIMEOFFSET works, but String ↔ TIME requires the user to enter time as a string (e.g., "00:00:20")
- Report Designer's Data Source wizard serializes connection strings into the `.repx` — changing DB credentials requires re-editing the data source
- Base64-encoded data sources in `.repx` are not human-readable — use the designer UI or a generation script to modify
- `EnableCustomSql()` must be called during DI setup for the Query Builder to allow freeform SQL
- All DX packages must be the **exact same version** — mixing versions causes runtime errors

### 🚫 Not Supported
- Dynamic parameter lists (parameters are fixed at design time)
- Cross-database joins in a single data source
- Real-time streaming data (reports are snapshot-based)
- Client-side Blazor (WASM) — requires Server render mode

---

## Troubleshooting

### "does not have a property matching the name 'ReportName'"
**Cause:** Using `ReportName="@name"` on `DxReportViewer` in v25.2.3.  
**Fix:** Use `Report="@xtraReport"` with an `XtraReport` object loaded via `LoadLayoutFromXml()`.

### "does not have a property matching the name 'Height'"
**Cause:** Using `Height="..."` on `DxReportViewer` in v25.2.3.  
**Fix:** Remove `Height`/`Width` properties. Wrap the viewer in a `<div style="width:100%; height:calc(100vh - 180px);">`.

### Report shows blank / no data
**Check:**
1. Are stored procedures deployed on the target database?
2. Do SP parameter names match exactly (including `@` prefix)?
3. Are expression bindings correct? (`?paramName` in wizard or `[Parameters.pPeriodFrom]` in XML)
4. Does the connection string in the `.repx` data source point to the correct server?
5. Check server logs for SQL execution errors.
6. Were Report Parameters created before data sources? (Required for `?paramName` to resolve)

### Data source parameter values cannot be changed after creation
**Situation:** You created a data source with hardcoded values and now need to bind to Report Parameters.  
**Fix:** Remove the data source entirely (right-click → Remove Data Source), then re-add it using `?paramName` syntax in the Expression value fields.

### Schema rebuild error when adding data source
**Cause:** Parameter values are invalid — the wizard executes the SP to discover output columns.  
**Fix:** Ensure date expressions use `#2026-02-01#` hash syntax (not plain strings). If using `?paramName`, ensure Report Parameters have valid default values first.

### Designer shows "Cannot load data source"
**Check:**
1. Is `CustomConnectionProviderService` registered in DI?
2. Does the connection name in the `.repx` match one returned by `GetConnectionDescriptions()`?
3. Is `XpoProvider=MSSqlServer` included in the connection string?

### Build errors about Font (CA1416 warnings)
**Cause:** `System.Drawing.Font` is Windows-only. DevExpress reports use fonts internally.  
**Fix:** These are warnings, not errors. Safe to suppress for Windows-deployed applications.

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-25 | 1.0 | Initial: DxDateEdit, DxListBox, DxComboBox, DxButton, DxGrid, DxChart, DxPieChart |
| 2025-12-30 | 1.1 | Added DevExpress Reporting: DxReportDesigner, DxReportViewer |
| 2026-02-12 | 2.0 | **Major update:** Upgraded to v25.2.3. Fixed DxReportViewer for native Blazor API (Report property, no Height/Width). Added SP binding patterns, 3 data sources, troubleshooting guide. Consolidated all report designer knowledge into this file. |
| 2026-02-17 | 2.1 | Added `?paramName` syntax for Designer UI parameter binding. Documented data source re-creation workflow. Added manual report creation learnings (14-step guide). Updated SP defaults and troubleshooting. |
