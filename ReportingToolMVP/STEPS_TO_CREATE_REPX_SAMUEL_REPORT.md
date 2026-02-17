# Steps to Create a .repx Report — Queue Performance Dashboard (Samuel's Report)

> **Version:** 1.0 | **Last Updated:** February 12, 2026
> **DevExpress Version:** 25.2.3 | **.NET:** 8.0 | **Blazor Server**

This document provides the complete, accurate, step-by-step guide to create the Queue Performance Dashboard report **entirely from the Report Designer UI** — no code required. It also covers all the backend prerequisites that a developer must set up **once** so that any end user can then create reports visually.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites — What Must Exist Before a User Can Create Reports](#2-prerequisites)
3. [Capabilities and Limitations](#3-capabilities-and-limitations)
4. [How It All Works — The Full Data Flow](#4-how-it-all-works)
5. [Step-by-Step: Create the Report from the Designer UI](#5-step-by-step-create-the-report)
6. [Viewing the Report](#6-viewing-the-report)
7. [Troubleshooting](#7-troubleshooting)
8. [Reference: Stored Procedure Schemas](#8-reference-stored-procedure-schemas)
9. [Reference: Backend Service Registration](#9-reference-backend-service-registration)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER'S BROWSER                               │
│                                                                     │
│  /reportdesigner ──► DxReportDesigner (WYSIWYG, JS-based)          │
│  /reportviewer   ──► DxReportViewer   (Blazor native component)    │
└─────────────────────┬───────────────────────────────────────────────┘
                      │ Blazor SignalR
┌─────────────────────▼───────────────────────────────────────────────┐
│                     ASP.NET CORE SERVER                              │
│                                                                     │
│  FileReportStorageService                                           │
│    └─ Reports/Templates/*.repx  (saved/loaded here)                │
│                                                                     │
│  CustomDataSourceWizardConnectionStringsProvider                    │
│    └─ Shows "3CX_Exporter_Production" in the wizard dropdown       │
│                                                                     │
│  CustomDBSchemaProviderExFactory                                    │
│    └─ Enables Query Builder to browse tables & stored procedures   │
│                                                                     │
│  CustomConnectionProviderService                                    │
│    └─ Resolves "3CX_Exporter_Production" → actual SQL connection   │
│       at preview/runtime (never embedded in .repx)                 │
└─────────────────────┬───────────────────────────────────────────────┘
                      │ SQL via XPO Provider
┌─────────────────────▼───────────────────────────────────────────────┐
│               SQL SERVER (3.132.72.134)                              │
│               Database: "3CX Exporter"                              │
│                                                                     │
│  Stored Procedures:                                                 │
│    sp_queue_kpi_summary_shushant      → KPI card data              │
│    sp_queue_calls_by_date_shushant    → Daily chart data           │
│    qcall_cent_get_extensions_statistics_by_queues → Agent table    │
└─────────────────────────────────────────────────────────────────────┘
```

### What is a .repx file?

A `.repx` file is an XML document that DevExpress XtraReports uses to store a report's complete layout and data binding configuration. It contains:

- **Layout** — Bands, controls, positions, sizes, fonts, colors
- **Data Sources** — Connection name + stored procedure name + parameter bindings (Base64-encoded XML inside the repx)
- **Report Parameters** — Name, type, default value, visibility
- **Expression Bindings** — How controls get their values from data fields

The `.repx` file does **NOT** contain actual data or connection credentials. It only stores the connection **name** (e.g., `3CX_Exporter_Production`), which the server resolves at runtime.

---

## 2. Prerequisites

These must be set up by a **developer** before any user can create reports from the UI.

### 2.1 Stored Procedures on SQL Server

All three SPs must exist on the target database. They are located in:
`SQL/Similar_to_samuel_sirs_report/`

| SQL File | Stored Procedure Name | Purpose |
|---|---|---|
| `sp_queue_kpi_summary.sql` | `sp_queue_kpi_summary_shushant` | Aggregated queue-level KPI metrics (one row per queue) |
| `sp_queue_calls_by_date.sql` | `sp_queue_calls_by_date_shushant` | Daily breakdown for chart (one row per queue per day) |
| `Agent_table.sql` | `qcall_cent_get_extensions_statistics_by_queues` | Agent-level statistics (one row per agent per queue) |

All three SPs accept the **same 4 parameters**:

| SP Parameter | SQL Type | Purpose |
|---|---|---|
| `@period_from` | `DATETIMEOFFSET` | Start of reporting period |
| `@period_to` | `DATETIMEOFFSET` | End of reporting period |
| `@queue_dns` | `VARCHAR(MAX)` | Comma-separated queue DNs (e.g., `8000` or `8000,8089`) |
| `@wait_interval` | `TIME` | SLA threshold — calls abandoned before this time are excluded |

**To deploy the SPs:** Open each `.sql` file in SQL Server Management Studio (SSMS), connect to `3.132.72.134` → database `3CX Exporter`, and execute.

### 2.2 NuGet Packages (all must be same version: 25.2.3)

```xml
<PackageReference Include="DevExpress.AspNetCore.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.JSBasedControls" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.Viewer" Version="25.2.3" />
```

> ⚠️ **CRITICAL:** All DevExpress packages MUST be the exact same version. Mixing versions causes runtime failures.

### 2.3 Backend Services in Program.cs

These 6 service registrations make the Report Designer's Data Source Wizard work:

```csharp
// 1. Core DevExpress Blazor components
builder.Services.AddDevExpressBlazor();

// 2. Reporting engine + server-side viewer
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// 3. Enable custom SQL and stored procedures in designer
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(designerConfigurator => {
        designerConfigurator.EnableCustomSql();
    });
});

// 4. File-based report storage (saves .repx to Reports/Templates/)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// 5. Connection names shown in the Data Source Wizard dropdown
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider,
    CustomDataSourceWizardConnectionStringsProvider>();

// 6. Resolves connection names to actual SQL connections at runtime
builder.Services.AddScoped<IConnectionProviderService, CustomConnectionProviderService>();
builder.Services.AddScoped<IConnectionProviderFactory, CustomConnectionProviderFactory>();

// 7. Enables Query Builder to browse database schema (tables, SPs, views)
builder.Services.AddScoped<IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();
```

**Middleware order (critical):**
```csharp
app.UseDevExpressBlazorReporting();    // BEFORE MapRazorComponents
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();
```

### 2.4 Backend Services — What Each Does

| Service | Interface | Purpose |
|---|---|---|
| `CustomDataSourceWizardConnectionStringsProvider` | `IDataSourceWizardConnectionStringsProvider` | Returns the list of named connections shown in the wizard dropdown. Currently returns `3CX_Exporter_Production` and `3CX_Exporter_Local`. |
| `CustomConnectionProviderService` | `IConnectionProviderService` | At runtime (preview/print), resolves a connection name like `3CX_Exporter_Production` into an actual SQL Server connection string. This is called every time a report executes a query. |
| `CustomConnectionProviderFactory` | `IConnectionProviderFactory` | Factory wrapper that DI uses to create `CustomConnectionProviderService` instances. Required by DevExpress. |
| `CustomDBSchemaProviderExFactory` | `IDBSchemaProviderExFactory` | Enables the Report Designer's Query Builder to browse the database schema — it's what lets you see tables, views, and **stored procedures** in the wizard. Without this, the SP list would be empty. |
| `FileReportStorageService` | `ReportStorageWebExtension` | Loads/saves .repx files from `Reports/Templates/` folder. Also handles listing available reports and creating new ones. |

### 2.5 Razor Pages

| Route | Component | Purpose |
|---|---|---|
| `/reportdesigner` | `ReportDesigner.razor` | WYSIWYG designer — uses `DxReportDesigner` (JS-based) |
| `/reportdesigner/{ReportUrl}` | Same | Opens a specific saved report for editing |
| `/reportviewer` | `ReportViewer.razor` | View/print/export — uses `DxReportViewer` (Blazor native) |
| `/reportviewer/{ReportUrl}` | Same | Opens a specific report for viewing |

### 2.6 Folder Structure

```
Reports/
  Templates/                    ← .repx files saved here
    Similar_to_samuel_sirs_report.repx
SQL/
  Similar_to_samuel_sirs_report/
    sp_queue_kpi_summary.sql    ← SP #1: KPI cards
    sp_queue_calls_by_date.sql  ← SP #2: Chart data
    Agent_table.sql             ← SP #3: Agent table
Services/
    ReportDataSourceProviders.cs  ← All 5 backend services
    FileReportStorageService.cs   ← File-based report storage
```

---

## 3. Capabilities and Limitations

### ✅ What Users CAN Do from the Designer UI

- Create a new blank report from scratch
- Add SQL Data Sources using stored procedures or custom SQL
- Browse the database schema (tables, views, stored procedures)
- Bind SP parameters to report parameters using Expressions
- Add report parameters (DateTime, String, Int, Boolean, etc.)
- Drag and drop controls: Labels, Tables, Panels, Charts, Images, Page Info
- Use expression bindings for dynamic text (e.g., `FormatString('{0:N0}', [total_calls])`)
- Add XRChart with multiple series (Area, Bar, Line, Pie, etc.)
- Add DetailReportBand for sub-reports bound to different data sources
- Set styling: fonts, colors, borders, backgrounds, padding, alignment
- Preview with parameter input panel
- Save reports (stored as .repx in `Reports/Templates/`)
- Export to PDF, Excel, Word, CSV, HTML from the viewer

### ⚠️ Limitations

| Limitation | Details |
|---|---|
| **Connection names are pre-defined** | Users can only select connections registered in `CustomDataSourceWizardConnectionStringsProvider`. They cannot enter arbitrary connection strings from the UI. To add a new database, a developer must register it in the backend code. |
| **Stored procedures must already exist** | The wizard browses the database schema. If a SP hasn't been deployed to SQL Server, it won't appear in the list. |
| **No C# code-behind** | The .repx format supports expressions (FormatString, IIF, Sum, etc.) but NOT custom C# code. Complex calculations must be done in the SP or via DevExpress expressions. |
| **Parameter types** | Report parameters support: String, DateTime, Int16/32/64, Decimal, Float, Double, Boolean, Guid. No custom objects or arrays. For multi-value (e.g., multiple queues), pass as comma-separated string. |
| **Chart DataMember** | When creating a chart bound to a secondary data source, you must set the chart's `DataSource` and `DataMember` properties. If the chart wizard doesn't auto-populate fields, set them manually in the Properties panel. |
| **Chart ValidateDataMembers** | **CRITICAL:** When binding a chart to a `StoredProcQuery` data source, the chart's `DataContainer.ValidateDataMembers` must be set to `False`. By default it is `True`, which causes DevExpress to validate series data members (ArgumentDataMember, ValueDataMembersSerializable) against the data source schema at report load time. For stored procedures, the schema isn't available until the SP actually executes — so validation silently strips the bindings, resulting in an **empty chart** (axes show 0–1). See [Troubleshooting](#7-troubleshooting) for how to fix this from the Designer UI. |
| **No cascading parameters** | DevExpress XtraReports doesn't natively support cascading parameter dropdowns (where one parameter filters another's options). All parameters are independent. |
| **File storage only** | Reports are saved as .repx files on disk. There is no database-backed report catalog. Moving to another server requires copying the `Reports/Templates/` folder. |
| **Single connection per data source** | Each `SqlDataSource` is bound to exactly one named connection. You cannot join data from two different databases in a single data source. Use multiple data sources instead. |
| **Evaluation watermark** | Without a DevExpress license, reports show a red watermark: "For evaluation purposes only." A license key removes this. |

### DevExpress Expression Examples (Usable in UI)

```
FormatString('{0:N0}', [total_calls])              → "191"
FormatString('{0:N1}%', [answered_within_sla_percent]) → "94.1%"
FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodFrom]) → "Jun 01, 2025"
[mean_talking]                                       → "00:02:10" (TIME fields display as-is)
'Queue: ' + [queue_display_name]                    → "Queue: Relay"
IIF([abandoned_calls] > 10, 'High', 'Normal')       → Conditional text
```

---

## 4. How It All Works

### 4.1 Data Flow: From User Click to Report Render

```
┌──────────────┐    ┌──────────────────┐    ┌────────────────────┐    ┌──────────────┐
│  User enters │    │ Report Parameter │    │ QueryParameter     │    │ SQL Server   │
│  values in   │───►│ stores the value │───►│ Expression pulls   │───►│ executes the │
│  Preview     │    │                  │    │ from parameter     │    │ stored proc  │
│  panel       │    │ pPeriodFrom =    │    │ [Parameters.       │    │ with @params │
│              │    │ 2025-06-01       │    │  pPeriodFrom]      │    │              │
└──────────────┘    └──────────────────┘    └────────────────────┘    └──────┬───────┘
                                                                            │
                    ┌──────────────────┐    ┌────────────────────┐          │
                    │ Controls display │◄───│ DevExpress binds   │◄─────────┘
                    │ formatted values │    │ result columns to  │    Result rows
                    │ in the report    │    │ expression bindings│
                    └──────────────────┘    └────────────────────┘
```

### 4.2 Connection Resolution Chain

```
.repx file contains:
  ConnectionName = "3CX_Exporter_Production"     (just a name, no credentials)
        │
        ▼
CustomConnectionProviderService.LoadConnection("3CX_Exporter_Production")
        │
        ▼
Returns: XpoProvider=MSSqlServer;Data Source=3.132.72.134;
         Initial Catalog=3CX Exporter;User Id=sa;Password=***
        │
        ▼
DevExpress executes: EXEC sp_queue_kpi_summary_shushant @period_from=..., @period_to=...
```

### 4.3 Parameter Binding Chain

```
Report Parameter          SP Parameter         Binding Expression
─────────────────    →    ──────────────    →  ─────────────────────────────
pPeriodFrom (DateTime)    @period_from         [Parameters.pPeriodFrom]
pPeriodTo (DateTime)      @period_to           [Parameters.pPeriodTo]
pQueueDns (String)        @queue_dns           [Parameters.pQueueDns]
pWaitInterval (String)    @wait_interval       [Parameters.pWaitInterval]
```

In the .repx XML, this is serialized by DevExpress as:
```xml
<Parameter Name="@period_from" Type="DevExpress.DataAccess.Expression">
  (null)([Parameters.pPeriodFrom])
</Parameter>
```

The `(null)` prefix is DevExpress's internal serialization format — it means "no static default; always use the expression." You don't type this yourself — DevExpress generates it automatically when you select **Expression** as the parameter type in the wizard.

---

## 5. Step-by-Step: Create the Report

### Overview

The report has **3 sections** powered by **3 separate data sources**:

| Section | Data Source | Stored Procedure | Visual Element |
|---|---|---|---|
| KPI Cards (8 boxes) | dsKPIs | `sp_queue_kpi_summary_shushant` | Panels with expression-bound labels |
| Call Trends Chart | dsChartData | `sp_queue_calls_by_date_shushant` | XRChart with 2 Area series |
| Agent Performance Table | dsAgents | `qcall_cent_get_extensions_statistics_by_queues` | DetailReportBand with XRTable |

---

### Step 1: Open the Report Designer

1. Start the application: `dotnet run` from `ReportingToolMVP/`
2. Open browser: `https://localhost:7209/reportdesigner`
3. A blank report opens in the designer

---

### Step 2: Configure Page Setup

4. Click the **hamburger menu** (☰) in the toolbar → **Design in Report Wizard...** → Cancel (we'll do it manually)
5. Instead, click on the empty area of the report (the grey background outside any band) to select the report itself
6. In the **Properties** panel (right side), set:
   - **Landscape** = `True`
   - **Paper Kind** = `Custom`
   - **Page Width** = `1100`
   - **Page Height** = `850`
   - **Margins** = `30, 30, 30, 30`

---

### Step 3: Create Report Parameters (4 total)

7. In the **Field List** panel (right side), find the **Parameters** node
8. Right-click **Parameters** → **Add Parameter**
9. Create each parameter:

**Parameter 1: pPeriodFrom**
- **Name:** `pPeriodFrom`
- **Description:** `Start Date:`
- **Type:** `DateTime`
- **Default Value:** `6/1/2025 12:00:00 AM`
- **Visible:** ✅ (checked)

**Parameter 2: pPeriodTo**
- **Name:** `pPeriodTo`
- **Description:** `End Date:`
- **Type:** `DateTime`
- **Default Value:** `2/12/2026 12:00:00 AM`
- **Visible:** ✅ (checked)

**Parameter 3: pQueueDns**
- **Name:** `pQueueDns`
- **Description:** `Queue DN (e.g. 8000):`
- **Type:** `String`
- **Default Value:** `8000`
- **Visible:** ✅ (checked)

**Parameter 4: pWaitInterval**
- **Name:** `pWaitInterval`
- **Description:** `SLA Threshold (HH:MM:SS):`
- **Type:** `String`
- **Default Value:** `00:00:20`
- **Visible:** ✅ (checked)

---

### Step 4: Add Data Source 1 — KPIs

10. In the **Field List** panel, right-click the report root → **Add Data Source...**
11. The **Data Source Wizard** opens
12. Select **SQL Data Source** → click **Next**
13. In the connection dropdown, select: **`3CX Exporter Production Database (LIVE DATA)`** → **Next**
14. On the query configuration page, select the **Stored Procedure** radio button (not "Query")
15. From the stored procedure list, find and select: **`sp_queue_kpi_summary_shushant`**
16. The wizard shows 4 SP parameters. For **each one**:
    - Click the parameter row
    - Change the **Type** column from `Value` to **`Expression`**
    - In the **Value** column, enter the expression:

    | SP Parameter | Expression Value |
    |---|---|
    | `@period_from` | `[Parameters.pPeriodFrom]` |
    | `@period_to` | `[Parameters.pPeriodTo]` |
    | `@queue_dns` | `[Parameters.pQueueDns]` |
    | `@wait_interval` | `[Parameters.pWaitInterval]` |

17. Click **Next** → Name the query: **`KPIs`** → click **Finish**
18. The data source appears in Field List. Right-click it → **Rename** → type `dsKPIs`
19. Now bind the report to this data source:
    - Click the report background (grey area) to select the report root
    - In **Properties** panel: **Data Source** = `dsKPIs`, **Data Member** = `KPIs`

> After this step, the Field List should show `dsKPIs > KPIs >` with fields like `queue_dn`, `queue_display_name`, `total_calls`, `answered_calls`, `abandoned_calls`, `answered_within_sla_percent`, `mean_talking`, `total_talking`, `avg_waiting`, `serviced_callbacks`.

---

### Step 5: Add Data Source 2 — Chart Data

20. Right-click Field List root → **Add Data Source...** → SQL Data Source → **Next**
21. Same connection: **`3CX Exporter Production Database (LIVE DATA)`** → **Next**
22. **Stored Procedure** → select **`sp_queue_calls_by_date_shushant`**
23. Same 4 parameter bindings (Expression → `[Parameters.pPeriodFrom]`, etc.)
24. Query name: **`ChartData`** → **Finish**
25. Rename to **`dsChartData`**

> Fields available: `queue_dn`, `queue_display_name`, `call_date`, `total_calls`, `answered_calls`, `abandoned_calls`, `answered_within_sla`, `answer_rate`, `sla_percent`

---

### Step 6: Add Data Source 3 — Agents

26. Right-click Field List root → **Add Data Source...** → SQL Data Source → **Next**
27. Same connection → **Next**
28. **Stored Procedure** → select **`qcall_cent_get_extensions_statistics_by_queues`**
29. Same 4 parameter bindings
30. Query name: **`Agents`** → **Finish**
31. Rename to **`dsAgents`**

> Fields available: `queue_dn`, `queue_display_name`, `extension_dn`, `extension_display_name`, `queue_received_count`, `extension_answered_count`, `talk_time`, `avg_talk_time`, `avg_answer_time`

---

### Step 7: Build the Report Header — Title & Filter Info

32. The **Report Header** band should already exist. If not, right-click the report → **Insert Band** → **Report Header**
33. Drag the Report Header's bottom edge down to make it approximately **520px** tall (check `HeightF` in Properties)

**Title label:**
34. From the **Toolbox** (left panel), drag a **Label** onto the Report Header
35. Properties:
    - **Text:** `VoIPTools Customer Service`
    - **Location:** `30, 5`
    - **Size:** `400 × 32`
    - **Font:** Segoe UI, 20pt, Bold
    - **Foreground Color:** `#4361ee` (67, 97, 238)

**Subtitle label:**
36. Drag another Label below:
    - **Text:** `Queue Performance Dashboard (Production)`
    - **Location:** `30, 38`
    - **Size:** `350 × 16`
    - **Font:** Segoe UI, 9pt
    - **Foreground Color:** `#718096` (113, 128, 150)

**Filter Info Panel** (top-right corner):
37. Drag a **Panel** control:
    - **Location:** `730, 5`
    - **Size:** `280 × 55`
    - **Background Color:** `#F8FAFC` (248, 250, 252)
    - **Borders:** All, Width: 1, Color: `#E2E8F0`

38. Inside the panel, add 3 labels with **Expression Bindings**:
    - **Queue label** (10, 5, 260×14): Expression for Text → `'Queue: ' + [queue_display_name]`
    - **Date range** (10, 22, 260×14): Expression for Text → `'Period: ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodFrom]) + ' - ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodTo])`
    - **SLA info** (10, 38, 260×12): Expression for Text → `'SLA Threshold: ' + [Parameters.pWaitInterval]`

> **How to set an Expression Binding:** Select the label → in Properties, find **Expression Bindings** → click the `...` button → select property `Text` → enter the expression.

---

### Step 8: Build KPI Cards (8 cards)

39. Create 8 **Panel** controls arranged horizontally starting at Y=80, each approximately `118 × 55` pixels, spaced 126px apart (X positions: 30, 156, 282, 408, 534, 660, 786, 912)

For **each** panel:
- **Background:** White
- **Borders:** All sides, Width: 1, Color: `#E2E8F0`
- Inside, add a small accent panel (4px wide, full height) on the left edge with the accent color
- Add a **value label** (centered, large font) with Expression Binding
- Add a **caption label** below (centered, small font, static text)

| Card | Caption | Expression Binding for Value | Accent Color |
|---|---|---|---|
| 1 | Total Calls | `FormatString('{0:N0}', [total_calls])` | `#4361ee` (blue) |
| 2 | Answered | `FormatString('{0:N0}', [answered_calls])` | `#48BB78` (green) |
| 3 | Abandoned | `FormatString('{0:N0}', [abandoned_calls])` | `#F56565` (red) |
| 4 | SLA % | `FormatString('{0:N1}%', [answered_within_sla_percent])` | `#9B59B6` (purple) |
| 5 | Avg Talk | `[mean_talking]` | `#4361ee` (blue) |
| 6 | Total Talk | `[total_talking]` | `#ED8936` (orange) |
| 7 | Avg Wait | `[avg_waiting]` | `#38B2AC` (teal) |
| 8 | Callbacks | `FormatString('{0:N0}', [serviced_callbacks])` | `#48BB78` (green) |

---

### Step 9: Build the Call Trends Chart

40. Add a label: **"Call Trends by Date"** at (30, 145), Font: Segoe UI 11pt Bold, Color: `#2D3748`

41. From the Toolbox, drag an **XRChart** onto the Report Header:
    - **Location:** `30, 168`
    - **Size:** `980 × 180`

42. Select the chart → in **Properties** panel:
    - **Data Source:** `dsChartData`
    - **Data Member:** `ChartData`

43. Right-click the chart → **Run Designer...** (opens the Chart Designer wizard)

44. In the Chart Designer:

    **Series 1 — Answered:**
    - Click **Add Series** (or select existing Series 1)
    - **Name:** `Answered`
    - **View Type:** `Area`
    - **Argument Data Member:** `call_date`
    - **Value Data Members:** `answered_calls`
    - In the **View** properties: **Color** = `#48BB78` (green), **Transparency** = `140`

    **Series 2 — Abandoned:**
    - Click **Add Series**
    - **Name:** `Abandoned`
    - **View Type:** `Area`
    - **Argument Data Member:** `call_date`
    - **Value Data Members:** `abandoned_calls`
    - In the **View** properties: **Color** = `#F56565` (red), **Transparency** = `140`

45. Configure the Legend:
    - **Alignment Horizontal:** Center
    - **Alignment Vertical:** Bottom Outside
    - **Direction:** Left to Right

46. Click **OK** to close the Chart Designer

---

### Step 10: Build the Agent Performance Table Header

47. Add a label: **"Agent Performance"** at (30, 358), Font: Segoe UI 11pt Bold, Color: `#2D3748`

48. Drag an **XRTable** from the Toolbox onto the Report Header:
    - **Location:** `30, 380`
    - **Size:** `980 × 22`

49. Right-click the table → **Insert Row** until you have **1 row with 6 cells**

50. Configure each cell as a header:

| Cell | Text | Weight | Font | Colors |
|---|---|---|---|---|
| 1 | Agent | 2.8 | Segoe UI 9pt Bold | White text, `#4A5568` background |
| 2 | Answered | 1.0 | Same | Same |
| 3 | Avg Answer | 1.0 | Same | Same |
| 4 | Avg Talk | 1.0 | Same | Same |
| 5 | Talk Time | 1.2 | Same | Same |
| 6 | Q Received | 1.0 | Same | Same |

- Cell 1 (Agent): Text Alignment = Middle Left, Left Padding = 10
- Cells 2-6: Text Alignment = Middle Center

---

### Step 11: Add the Agent Detail Report Band

51. Right-click the report surface → **Insert Band** → **Detail Report**
52. A `DetailReportBand` appears at the bottom of the report
53. Select it → in Properties:
    - **Data Source:** `dsAgents`
    - **Data Member:** `Agents`

54. Inside the DetailReportBand, there's a **Detail** band. Set its:
    - **Height:** `22`
    - **Even Style:** (optionally create a style with BackColor `#F8FAFC` for alternating rows)

55. Drag an **XRTable** into the Detail band:
    - **Location:** `30, 0`
    - **Size:** `980 × 22`
    - **1 row, 6 cells**

56. Configure each cell with **Expression Bindings**:

| Cell | Expression Binding (Text) | Weight | Alignment |
|---|---|---|---|
| 1 | `[extension_display_name]` | 2.8 | Middle Left (padding 10) |
| 2 | `FormatString('{0:N0}', [extension_answered_count])` | 1.0 | Middle Center |
| 3 | `[avg_answer_time]` | 1.0 | Middle Center |
| 4 | `[avg_talk_time]` | 1.0 | Middle Center |
| 5 | `[talk_time]` | 1.2 | Middle Center |
| 6 | `FormatString('{0:N0}', [queue_received_count])` | 1.0 | Middle Center |

- All cells: Font = Segoe UI 8pt, Color = `#2D3748`

---

### Step 12: Add Page Footer

57. The **Page Footer** band should already exist. If not, right-click → **Insert Band** → **Page Footer**
58. Set **Height** = `25`

59. Drag an **XRPageInfo** control to the left:
    - **Page Info:** `Date Time`
    - **Location:** `30, 2`
    - **Size:** `200 × 20`
    - **Font:** Segoe UI 7pt, Color: `#A0AEC0`

60. Drag another **XRPageInfo** to the right:
    - **Page Info:** `Number of Total`
    - **Text Format String:** `Page {0} of {1}`
    - **Location:** `810, 2`
    - **Size:** `200 × 20`
    - **Text Alignment:** Top Right
    - **Font:** Segoe UI 7pt, Color: `#A0AEC0`

---

### Step 13: Hide the Main Detail Band

61. Click the **Detail** band (the main one, not the one inside the DetailReportBand)
62. In Properties: **Height** = `0`, **Visible** = `False`

> This is because the report root is bound to `dsKPIs` which returns one row per queue. The KPI cards in the Report Header already display those values. The main Detail band has nothing to show.

---

### Step 14: Save the Report

63. Click the **Save** button (floppy disk icon) in the toolbar
64. Enter name: `Similar_to_samuel_sirs_report`
65. Click **OK**
66. The file is saved to: `Reports/Templates/Similar_to_samuel_sirs_report.repx`

---

### Step 15: Preview the Report

67. Click the **PREVIEW** button (top-right corner of the designer)
68. The **Preview Parameters** panel appears on the right side:
    - Start Date: `6/1/2025, 12:00 AM`
    - End Date: `2/12/2026, 12:00 AM`
    - Queue DN: `8000`
    - SLA Threshold: `00:00:20`
69. Click **SUBMIT**
70. The report renders with live data from the production database:
    - KPI cards show numeric values (191 total calls, 185 answered, etc.)
    - Chart shows area plot of daily answered vs abandoned calls
    - Agent table lists all agents with their performance metrics

---

## 6. Viewing the Report

Once saved, the report can be viewed in two ways:

### From the Report Viewer page
1. Navigate to `https://localhost:7209/reportviewer`
2. Select **"Similar to samuel sirs report"** from the dropdown
3. The report loads with the parameter panel
4. Enter parameters → Click **Submit**
5. Use the viewer toolbar to: **Print**, **Export to PDF**, **Export to Excel**, **Search**

### From a direct URL
- `https://localhost:7209/reportviewer/Similar_to_samuel_sirs_report`

### From the Designer
- `https://localhost:7209/reportdesigner/Similar_to_samuel_sirs_report`
- Click **PREVIEW** to preview, **DESIGN** to edit

---

## 7. Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| **"Query KPIs failed to execute"** | SP parameter types don't match, or connection name not recognized | Verify parameter type is set to **Expression** (not Value). Verify connection name matches exactly. |
| **Stored procedure not in list** | SP not deployed to the target database, or DB Schema Provider not registered | Deploy the SP SQL files. Ensure `IDBSchemaProviderExFactory` is registered in Program.cs. |
| **"The datasource doesn't contain a data member with the 'X' name"** | Data member set on a control before the data source schema is loaded | Remove the data member, save, reopen. Set data source first, then data member. |
| **Empty chart (axes show 0-1)** | **Four things must ALL be correct** for SP-backed charts: (1) `ValidateDataMembers` must be `False`, (2) chart's `DataContainer.DataMember` must be set, (3) chart's root `DataMember` must be set, (4) the data source must contain a `ResultSchema` so DevExpress knows the column types. Missing **any one** of these causes a blank chart. See **Section 7.1** and **Section 7.2** for the full investigation. | **Quick fix from Designer UI:** See Section 7.1 (ValidateDataMembers) + Section 7.2 (ResultSchema). **Quick fix in code:** See `QueuePerformanceDashboardGenerator.cs` which applies all 4 fixes via XML post-processing. |
| **"Query X is not allowed"** | `EnableCustomSql()` not called in Program.cs | Add `designerConfigurator.EnableCustomSql();` to the ConfigureReportDesigner block. |
| **Connection dropdown empty** | `IDataSourceWizardConnectionStringsProvider` not registered | Register `CustomDataSourceWizardConnectionStringsProvider` in Program.cs. |
| **Parameters not passed to SP** | Type set to "Value" instead of "Expression" in the wizard | Re-edit the data source → change each parameter type to Expression → re-enter `[Parameters.pXxx]`. |
| **Agent table empty** | DetailReportBand DataSource/DataMember not set | Select the DetailReportBand → set DataSource = `dsAgents`, DataMember = `Agents`. |
| **Report shows blank** | Report's root DataSource/DataMember not set | Click report background → set DataSource = `dsKPIs`, DataMember = `KPIs`. |
| **Red evaluation watermark** | No DevExpress license | Purchase and apply a DevExpress license key. |

### 7.1 Deep Dive: Empty Chart with StoredProcQuery (ValidateDataMembers)

This is the **most common pitfall** when adding charts to reports that use stored procedures as data sources.

#### The Problem

You add an XRChart to your report, bind it to a `StoredProcQuery` data source, configure series with `ArgumentDataMember = "call_date"` and `ValueDataMembersSerializable = "answered_calls"`, and everything looks correct in the Design view (sample data may appear). But when you **Preview** the report, the chart is empty — showing axes 0–1 and a minimal date range.

#### Root Cause

DevExpress charts have a property `DataContainer.ValidateDataMembers` that defaults to `True`. When enabled, DevExpress **validates** that the series data member names (ArgumentDataMember, ValueDataMembersSerializable) exist in the data source schema **at report load time** — before the stored procedure actually executes.

For `StoredProcQuery` data sources, the schema is NOT available at load time because the SP must be executed with parameters to return its result set. So the validation **silently fails** and DevExpress **strips the data member bindings** from the series. The chart renders with no data.

**Why KPI labels and Agent tables work but the chart doesn't:** Labels use `ExpressionBindings` (evaluated at render time), and DetailReportBand data sources are populated during report generation. Chart series bindings, however, are validated against the schema upfront by the DataContainer.

#### How to Fix from the Report Designer UI

1. **Select the chart** in the design surface
2. Open the **Properties** panel (right side)
3. Expand **Chart** → **DataContainer**
4. Set **`ValidateDataMembers`** = **`False`**
5. Verify the chart's **DataSource** and **DataMember** are correctly set
6. Verify each series has **ArgumentDataMember** and **ValueDataMembersSerializable** set
7. Save and Preview — the chart should now render with data

#### How to Fix in Code (QueuePerformanceDashboardGenerator.cs)

The generator uses XML post-processing after `SaveLayoutToXml()`:

```csharp
// In GenerateAndSave():
xml = xml.Replace(
    "ValidateDataMembers=\"true\"",
    "ValidateDataMembers=\"false\"");
```

This is necessary because `SaveLayoutToXml()` also strips `ArgumentDataMember` and `ValueDataMembersSerializable` from series when the data source schema can't be validated — requiring additional XML post-processing to re-inject them.

#### How to Avoid This When Creating Reports Manually

**Always** set `ValidateDataMembers = False` on any chart that uses a StoredProcQuery data source. Do this **before** configuring series bindings. This is a one-time property change per chart.

> **⚠️ Important:** `ValidateDataMembers = False` is **necessary but NOT sufficient** by itself. You also need a `ResultSchema` on the data source — see Section 7.2 below.

### 7.2 Deep Dive: Missing ResultSchema on StoredProcQuery Data Sources

This is the **second half** of the empty chart puzzle. Even with `ValidateDataMembers = False`, a chart can still be empty if the data source's `StoredProcQuery` lacks a `ResultSchema`.

#### Background: What Is a ResultSchema?

When DevExpress serializes a `SqlDataSource` to `.repx` XML, each query is Base64-encoded inside a `<Query>` element. For **SELECT-based queries** (views, custom SQL), DevExpress automatically resolves the column names and types at save time and embeds a `<ResultSchema>` inside the Base64 block. This tells DevExpress what columns exist (and their types) without executing the query.

For **StoredProcQuery** data sources, DevExpress **cannot** resolve the schema automatically because stored procedures require parameters to execute. So the `<ResultSchema>` is **not generated** — and without it, the chart has no way to know what data columns are available for binding.

#### The Investigation — What We Tried and Why It Failed

We went through **four attempts** to fix the empty chart. Understanding why each failed is critical for avoiding the same traps:

**Attempt 1: ValidateDataMembers = False (Necessary but not sufficient)**
- Setting `DataContainer.ValidateDataMembers = False` stopped DevExpress from stripping the series bindings at load time
- But the chart was **still empty** because the data source had no ResultSchema, so DevExpress couldn't wire up the data columns to the series at render time

**Attempt 2: CustomSqlQuery with EXEC statement**
- We tried switching from `StoredProcQuery` to `CustomSqlQuery` with `EXEC sp_name @param1, @param2`
- This generates a ResultSchema automatically since DevExpress treats it as a SQL statement
- **Failed with error:** *"A custom SQL query should contain only SELECT statements"*
- DevExpress validates CustomSqlQuery content and rejects anything containing `EXEC`

**Attempt 3: ResultSchemaSerializable property in code**
- We tried setting `storedProcQuery.ResultSchemaSerializable` in the C# code before calling `SaveLayoutToXml()`
- This **silently converted** the `StoredProcQuery` into a `CustomSqlQuery` during serialization!
- DevExpress internally rewrites the query type when ResultSchemaSerializable is set on a StoredProcQuery
- The resulting .repx contained `EXEC sp_name` as a CustomSqlQuery → same "only SELECT statements" error

**Attempt 4: XML Post-Processing to Inject ResultSchema (✅ THE WORKING FIX)**
- Generate the report normally with `StoredProcQuery` (no ResultSchemaSerializable in code)
- Call `SaveLayoutToXml()` to get the .repx XML
- Decode the Base64-encoded data source, inject the `<ResultSchema>` XML manually, re-encode to Base64
- Write the modified XML back to the .repx file
- This preserves `StoredProcQuery` type while adding the schema DevExpress needs

#### The 4-Part Fix (All Required)

For a chart bound to a StoredProcQuery data source to render correctly, **all four** of these must be applied:

| # | Fix | Where | Why |
|---|-----|-------|-----|
| 1 | `ValidateDataMembers = False` | `DataContainer` element | Prevents DevExpress from stripping series bindings at load time |
| 2 | `DataMember = "ChartData"` on DataContainer | `DataContainer` element | Tells the chart's internal data container which query to use |
| 3 | `DataMember = "ChartData"` on XRChart | `XRChart` control | Tells the chart control itself which data member to render |
| 4 | `ResultSchema` with column definitions | Inside the Base64-encoded `StoredProcQuery` | Tells DevExpress what columns exist and their .NET types, enabling data binding |

#### How the ResultSchema XML Post-Processing Works

The code in `QueuePerformanceDashboardGenerator.cs` does this:

```
1. SaveLayoutToXml() → produces .repx XML string
2. Find all Base64="..." attributes in the XML
3. For each Base64 block, decode and check if it contains "StoredProcQuery" AND "ChartData"
4. When found, inject <ResultSchema> XML before <ConnectionOptions>
5. Re-encode to Base64 and replace in the XML
6. Write final XML to .repx file
```

The injected `<ResultSchema>` looks like this:

```xml
<ResultSchema>
  <DataSet Name="QueryResults">
    <Table Name="ChartData">
      <Column Name="queue_dn" Type="System.String" />
      <Column Name="call_date" Type="System.DateTime" />
      <Column Name="total_calls" Type="System.Int32" />
      <Column Name="answered_calls" Type="System.Int32" />
      <Column Name="abandoned_calls" Type="System.Int32" />
    </Table>
  </DataSet>
</ResultSchema>
```

> **Critical:** Column names MUST exactly match the stored procedure's output column names. Column types MUST match the .NET equivalents of the SQL types.

#### How to Fix from the Report Designer UI (Manual Approach)

Unfortunately, there is **no UI button** in the DevExpress Report Designer to add a ResultSchema to a StoredProcQuery. The Designer UI can only auto-generate schemas for SELECT-based queries. For stored procedure data sources, you have two options:

**Option A: Use the "Manage Queries" trick (Recommended)**
1. In the Report Designer, open the data source's **Manage Queries** dialog
2. For the chart's stored procedure query, click **Run Query** to execute it with test parameters
3. If DevExpress successfully executes the SP and retrieves data, it **may** save the ResultSchema when you click OK
4. Save the report and verify the `.repx` file contains a `<ResultSchema>` block for that query

**Option B: Edit the .repx XML directly**
1. Save the report from the Designer
2. Close the Designer
3. Open the `.repx` file in a text editor
4. Find the `<Item1>` (or `<Item2>`, etc.) block for your chart's data source
5. Decode the `Base64="..."` attribute (use any Base64 decoder)
6. Locate the `<ConnectionOptions>` tag inside the decoded XML
7. Insert the `<ResultSchema>` block (shown above) **immediately before** `<ConnectionOptions>`
8. Re-encode the entire XML block to Base64
9. Replace the `Base64="..."` value in the .repx
10. Reopen in the Designer and verify

**Option C: Use the code generator (Recommended for new reports)**
- Use `QueuePerformanceDashboardGenerator.cs` as a template
- The generator handles all 4 fixes automatically via XML post-processing
- This is the most reliable approach since it's repeatable and version-controlled

#### How to Avoid This Issue When Creating New Reports

1. **For charts using stored procedures:** Always use the code generator approach (`QueuePerformanceDashboardGenerator.cs`) which handles all 4 fixes automatically
2. **For charts using views or SELECT queries:** The Designer handles ResultSchema automatically — no special steps needed
3. **If you must use the Designer UI with SP-based charts:**
   - Set `ValidateDataMembers = False` on the chart FIRST
   - Use **Manage Queries → Run Query** to force schema generation
   - Always verify the .repx XML contains `<ResultSchema>` after saving
4. **Never set `ResultSchemaSerializable` in C# code** on a StoredProcQuery — it silently converts the query type to CustomSqlQuery during serialization

#### Key Insight: Why VoIPToolsDashboard.repx Worked but This Report Didn't

The earlier `VoIPToolsDashboard.repx` used **SQL views** (not stored procedures) as data sources. When a SQL view or SELECT query is used, DevExpress executes it at design time and automatically embeds the `ResultSchema`. That's why that chart worked without any post-processing — the schema was already there.

When we switched to stored procedures for better parameterization, we lost the automatic schema generation, which is what triggered this entire investigation.

---

## 8. Reference: Stored Procedure Schemas

### SP 1: `sp_queue_kpi_summary_shushant` — KPI Cards

Returns **1 row per queue** with aggregated metrics.

| Column | Type | Description |
|---|---|---|
| `queue_dn` | varchar | Queue DN number (e.g., "8000") |
| `queue_display_name` | varchar | Queue friendly name (e.g., "Relay") |
| `total_calls` | int | Total qualifying calls in period |
| `abandoned_calls` | int | Calls not answered |
| `answered_calls` | int | Calls answered |
| `answered_percent` | decimal(5,2) | Answered / Total × 100 |
| `answered_within_sla` | int | Answered within SLA threshold |
| `answered_within_sla_percent` | decimal(5,2) | SLA answered / Total answered × 100 |
| `serviced_callbacks` | int | Callback count (placeholder, always 0) |
| `total_talking` | time | Sum of all talk time |
| `mean_talking` | time | Average talk time per answered call |
| `avg_waiting` | time | Average ring/wait time for answered calls |

### SP 2: `sp_queue_calls_by_date_shushant` — Chart Data

Returns **1 row per queue per day**.

| Column | Type | Description |
|---|---|---|
| `queue_dn` | varchar | Queue DN |
| `queue_display_name` | varchar | Queue name |
| `call_date` | date | Day of the calls |
| `total_calls` | int | Total calls that day |
| `answered_calls` | int | Answered calls that day |
| `abandoned_calls` | int | Abandoned calls that day |
| `answered_within_sla` | int | Answered within SLA that day |
| `answer_rate` | decimal(5,2) | Answer rate % that day |
| `sla_percent` | decimal(5,2) | SLA % that day |

### SP 3: `qcall_cent_get_extensions_statistics_by_queues` — Agent Table

Returns **1 row per agent per queue**.

| Column | Type | Description |
|---|---|---|
| `queue_dn` | varchar | Queue DN |
| `queue_display_name` | varchar | Queue name |
| `extension_dn` | varchar | Agent extension number |
| `extension_display_name` | varchar | Agent name (e.g., "Voip Tester") |
| `queue_received_count` | int | Total calls received by the queue |
| `extension_answered_count` | int | Calls answered by this agent |
| `talk_time` | time | Total talk time for this agent |
| `avg_talk_time` | time | Average talk time per call |
| `avg_answer_time` | time | Average ring time before answering |

---

## 9. Reference: Backend Service Registration

Complete `Program.cs` service registration block required for the Report Designer to work:

```csharp
// ─── DevExpress Core ─────────────────────────────────────────────
builder.Services.AddDevExpressBlazor();
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// ─── Enable Stored Procedures & Custom SQL in Designer ──────────
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(designerConfigurator => {
        designerConfigurator.EnableCustomSql();
    });
    configurator.ConfigureWebDocumentViewer(viewerConfigurator => {
        viewerConfigurator.UseCachedReportSourceBuilder();
    });
});

// ─── Report File Storage ────────────────────────────────────────
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// ─── Data Source Wizard (shows connections in dropdown) ─────────
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider,
    CustomDataSourceWizardConnectionStringsProvider>();

// ─── Runtime Connection Resolution ─────────────────────────────
builder.Services.AddScoped<IConnectionProviderService, CustomConnectionProviderService>();
builder.Services.AddScoped<IConnectionProviderFactory, CustomConnectionProviderFactory>();

// ─── Database Schema Browser (tables, views, SPs) ──────────────
builder.Services.AddScoped<IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();

// ─── Middleware (MUST be before MapRazorComponents) ─────────────
app.UseDevExpressBlazorReporting();
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
```

### Adding a New Database Connection

To add a new database that users can select in the wizard:

1. **In `CustomDataSourceWizardConnectionStringsProvider.GetConnectionDescriptions()`:** Add a new entry:
   ```csharp
   { "My_New_Database", "My New Database (Description)" }
   ```

2. **In `CustomDataSourceWizardConnectionStringsProvider.GetDataConnectionParameters()`:** Add the connection string:
   ```csharp
   if (name == "My_New_Database")
   {
       return new CustomStringConnectionParameters(
           "XpoProvider=MSSqlServer;Data Source=server;Initial Catalog=db;...");
   }
   ```

3. **In `CustomConnectionProviderService.LoadConnection()`:** Add the same mapping for runtime:
   ```csharp
   else if (connectionName == "My_New_Database")
   {
       connectionString = "XpoProvider=MSSqlServer;Data Source=server;...";
   }
   ```

### Adding a New Stored Procedure

1. Write the SQL and deploy it to the target database
2. That's it — the designer's Query Builder will automatically discover it via `IDBSchemaProviderExFactory`
3. No code changes needed; any user can immediately use it from the wizard

---

*End of document.*
