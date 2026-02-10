# VoIPTools Dashboard - Comprehensive Technical Guide

> **Complete reference for the VoIPToolsDashboard report system**  
> Covers: Backend implementation, UI design, data flow, SQL queries, project structure, and visual flow diagrams

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture & Data Flow](#2-architecture--data-flow)
3. [3CX Exporter Database](#3-3cx-exporter-database)
4. [SQL Views & Transformations](#4-sql-views--transformations)
5. [Backend Implementation](#5-backend-implementation)
6. [Report Designer UI](#6-report-designer-ui)
7. [Manual Report Creation Guide](#7-manual-report-creation-guide)
8. [Project Structure & File Reference](#8-project-structure--file-reference)
9. [Flow Diagrams](#9-flow-diagrams)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. System Overview

### What is VoIPToolsDashboard?

The **VoIPToolsDashboard** is a DevExpress XtraReports-based dashboard that provides real-time analytics for 3CX call center queues. It displays:

- **KPI Summary Cards** - 8 metrics (Total Calls, Answered, Abandoned, etc.)
- **Agent Performance Table** - Top 10 agents ranked by call volume
- **Call Trends Chart** - Daily area chart showing call patterns
- **Page 2: All Agents** - Complete agent list sorted by extension

### Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| **Frontend** | Blazor Server + DevExpress | .NET 8, DevExpress 25.2.3 |
| **Report Engine** | DevExpress XtraReports | 25.2.3 |
| **Backend** | ASP.NET Core Services | .NET 8 |
| **Database** | SQL Server | 2019+ |
| **Data** | 3CX Call Center Exporter | Dec 2023 - Oct 2025 |

### Application URLs

| Route | Purpose |
|-------|---------|
| `https://localhost:7209/reportdesigner` | Visual report designer |
| `https://localhost:7209/reportviewer` | View/export reports |
| `https://localhost:7209/reportdesigner/VoIPToolsDashboard` | Edit this specific report |

---

## 2. Architecture & Data Flow

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           USER INTERFACE                                  │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  Report Designer │    │   Report Viewer  │    │   Report Builder │   │
│  │  (DxReportDesign)│    │  (DxReportViewer)│    │    (DxGrid)      │   │
│  └────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘   │
└───────────┼───────────────────────┼───────────────────────┼─────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        BLAZOR SERVER SERVICES                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ FileReportStorageService    │ ReportDataSourceProviders         │    │
│  │ (Load/Save .repx files)     │ (SQL connections for designer)    │    │
│  └─────────────────────────────┴───────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ CustomReportService         │ ReportExportService               │    │
│  │ (Dynamic queries)           │ (PDF/Excel export)                │    │
│  └─────────────────────────────┴───────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
            │                       │
            ▼                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           SQL SERVER DATABASE                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Raw Tables (3CX Exporter)                     │    │
│  │  callcent_queuecalls  │  dn  │  queue  │  cl_calls  │ ...       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     SQL Views (Transformations)                  │    │
│  │  vw_QueueKPIs  │  vw_QueueAgentPerformance  │  vw_QueueCallTrends│    │
│  │  vw_QueueAgentPerformanceAll  │  vw_QueueSummary                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Sequence

```
1. USER ACTION
   └── Opens /reportviewer → Selects "VoIPToolsDashboard"
                │
2. BLAZOR COMPONENT
   └── DxReportViewer requests report from FileReportStorageService
                │
3. FILE STORAGE SERVICE
   └── Loads VoIPToolsDashboard.repx from Reports/Templates/
   └── Returns XML bytes to DevExpress engine
                │
4. DEVEXPRESS REPORT ENGINE
   └── Parses .repx XML
   └── Finds 3 SqlDataSource definitions (dsKPIs, dsTrends, dsAgentsAll)
   └── Decodes Base64 connection strings
                │
5. DATA SOURCE EXECUTION
   └── CustomConnectionProviderFactory provides SQL connection
   └── Executes queries:
       ├── SELECT * FROM vw_QueueKPIs (1 row)
       ├── SELECT TOP 15 ... FROM vw_QueueCallTrends (15 rows)
       └── SELECT * FROM vw_QueueAgentPerformanceAll (all agents)
                │
6. SQL SERVER VIEWS
   └── Views aggregate raw data from callcent_queuecalls table
   └── Return formatted, calculated results
                │
7. REPORT RENDERING
   └── DevExpress binds data to XRLabel, XRTable, XRChart controls
   └── Renders HTML/PDF output
                │
8. DISPLAY
   └── User sees fully rendered dashboard with live data
```

---

## 3. 3CX Exporter Database

### Database Connection

```
Server:   LAPTOP-A5UI98NJ\SQLEXPRESS
Database: Test_3CX_Exporter
User:     sa
Password: V01PT0y5
```

### Core Tables

#### `callcent_queuecalls` - Primary Call Records

This is the **main table** containing all queue call data. Every record represents one call that entered a queue.

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `id` | int | Unique call ID | 45231 |
| `time_start` | datetime | When call entered queue | 2024-08-15 09:23:45 |
| `time_end` | datetime | When call ended | 2024-08-15 09:28:12 |
| `q_num` | varchar(50) | Queue number | "8000" |
| `q_name` | varchar(100) | Queue display name | "Support Queue" |
| `from_no` | varchar(50) | Caller phone number | "+1555123456" |
| `from_dn` | varchar(100) | Caller display name | "John Smith" |
| `to_no` | varchar(50) | Destination number | "1006" |
| `to_dn` | varchar(100) | Agent extension who answered | "1006" |
| `ts_waiting` | time(7) | Time waiting in queue | 00:00:23.4530000 |
| `ts_servicing` | time(7) | Talk time with agent | 00:04:27.1200000 |
| `ts_polling` | time(7) | Time polling agents | 00:00:05.0000000 |
| `reason_noanswercode` | varchar(50) | Code if not answered | "TIMEOUT" |
| `reason_noanswer` | varchar(200) | Description if not answered | "All agents busy" |

**Critical Business Logic:**

```sql
-- ANSWERED CALL: Agent picked up and talked
ts_servicing != '00:00:00.0000000'

-- ABANDONED CALL: Caller hung up before answer
ts_servicing = '00:00:00.0000000'

-- MISSED CALL: Abandoned WITH a reason code (agent timeout, etc.)
ts_servicing = '00:00:00.0000000' AND reason_noanswercode IS NOT NULL

-- SLA MET: Answered within 20 seconds
ts_servicing != '00:00:00.0000000' 
AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20
```

#### `dn` - Directory Numbers (Extensions)

| Column | Type | Description |
|--------|------|-------------|
| `iddn` | int | Unique ID |
| `value` | varchar(50) | Extension number (e.g., "1006") |
| `display_name` | varchar(100) | Display name |

#### `queue` - Queue Definitions

| Column | Type | Description |
|--------|------|-------------|
| `fkiddn` | int | Links to dn.iddn |
| `name` | varchar(100) | Queue name |

### Data Characteristics

- **Date Range:** December 2023 - October 2025
- **Total Records:** ~4,000+ queue calls
- **Queue Numbers:** 8000-8030 (31 queues)
- **Agent Extensions:** Various 4-digit numbers (1006, 1007, etc.)

---

## 4. SQL Views & Transformations

### Overview: Raw Data → Views → Report

```
┌─────────────────────────────────────────────────────────────────────┐
│                     RAW TABLE: callcent_queuecalls                  │
│  (Individual call records with timestamps and outcomes)             │
└─────────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐      ┌────────────────┐      ┌────────────────┐
│ vw_QueueKPIs  │      │vw_QueueAgent   │      │vw_QueueCall    │
│               │      │Performance     │      │Trends          │
│ Aggregates    │      │               │      │                │
│ ALL calls →   │      │ Groups by     │      │ Groups by      │
│ single row    │      │ Agent         │      │ Date           │
│ of metrics    │      │ (TOP 10)      │      │ (daily counts) │
└───────────────┘      └────────────────┘      └────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DEVEXPRESS REPORT                              │
│  ┌──────────┐    ┌─────────────────┐    ┌──────────────────────┐   │
│  │ KPI Cards│    │ Agent Table     │    │ Area Chart           │   │
│  │ 8 values │    │ 10 rows         │    │ 15 data points       │   │
│  └──────────┘    └─────────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### View 1: `vw_QueueKPIs`

**Purpose:** Single row with all dashboard KPI values

**Location:** `SQL/VoIPToolsDashboard/01_KPIs.sql` and `SQL/VoIPToolsDashboard_Views.sql`

```sql
CREATE VIEW dbo.vw_QueueKPIs AS
SELECT
    -- Call Counts
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL 
             AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    
    -- Today's calls
    SUM(CASE WHEN CAST(time_start AS DATE) = CAST(GETDATE() AS DATE) 
        THEN 1 ELSE 0 END) AS CallsToday,
    
    -- SLA Percentage (answered within 20 seconds)
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(
            (CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
                           AND DATEDIFF(SECOND, '00:00:00', ts_waiting) <= 20 
                      THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS SLA1Percentage,
    
    -- Percentages
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND((CAST(SUM(CASE WHEN ts_servicing != '00:00:00.0000000' 
              THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)) * 100, 0)
    END AS AnsweredPercentage,
    
    -- Average Times (formatted HH:MM:SS)
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        MAX(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS MaxTalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS AvgWaitTime,
    
    -- Metadata
    GETDATE() AS ReportGeneratedAt
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01';
```

**Output (1 row):**
| TotalCalls | AnsweredCalls | AbandonedCalls | SLA1Percentage | AvgTalkTime |
|------------|---------------|----------------|----------------|-------------|
| 4192 | 2530 | 1662 | 60 | 00:00:57 |

### View 2: `vw_QueueAgentPerformance`

**Purpose:** Top 10 agents by call volume (for embedded subreport table)

```sql
CREATE VIEW dbo.vw_QueueAgentPerformance AS
SELECT
    COALESCE(to_dn, 'Unknown') AS AgentDN,
    CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
    COUNT(*) AS Calls,
    
    -- Average Answer Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
            ELSE NULL END), 0), 108) AS AvgAnswer,
    
    -- Average Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk,
    
    -- Total Talk Time
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TalkTime,
    
    -- Queue Percentage
    CAST(ROUND(
        (CAST(COUNT(*) AS FLOAT) / 
         NULLIF((SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
                 WHERE time_start >= '2023-01-01'), 0)) * 100, 2
    ) AS VARCHAR(10)) + '%' AS InQPercent

FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01' AND to_dn IS NOT NULL
GROUP BY to_dn;
```

**Query in Report (TOP 10):**
```sql
SELECT TOP 10 Agent, Calls, AvgAnswer, AvgTalk, TalkTime, QTime, InQPercent
FROM dbo.vw_QueueAgentPerformance
ORDER BY Calls DESC
```

### View 3: `vw_QueueCallTrends`

**Purpose:** Daily call counts for area chart

```sql
CREATE VIEW dbo.vw_QueueCallTrends AS
SELECT
    CAST(time_start AS DATE) AS CallDate,
    FORMAT(time_start, 'MMM d') AS CallDateLabel,
    
    SUM(CASE WHEN ts_servicing != '00:00:00.0000000' THEN 1 ELSE 0 END) AS AnsweredCalls,
    SUM(CASE WHEN reason_noanswercode IS NOT NULL 
             AND ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS MissedCalls,
    SUM(CASE WHEN ts_servicing = '00:00:00.0000000' THEN 1 ELSE 0 END) AS AbandonedCalls,
    COUNT(*) AS TotalCalls

FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01'
GROUP BY CAST(time_start AS DATE), FORMAT(time_start, 'MMM d');
```

**Query in Report (TOP 15):**
```sql
SELECT TOP 15 CallDate, CallDateLabel, AnsweredCalls, MissedCalls, AbandonedCalls
FROM dbo.vw_QueueCallTrends
ORDER BY CallDate ASC
```

### View 4: `vw_QueueAgentPerformanceAll`

**Purpose:** All agents sorted by extension (for Page 2)

```sql
CREATE VIEW dbo.vw_QueueAgentPerformanceAll AS
SELECT
    COALESCE(to_dn, 'Unknown') AS AgentDN,
    CONCAT(COALESCE(to_dn, 'Unknown'), ' - Agent') AS Agent,
    COUNT(*) AS Calls,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(CASE WHEN ts_servicing != '00:00:00.0000000' 
            THEN DATEDIFF(SECOND, '00:00:00', ts_waiting) 
            ELSE NULL END), 0), 108) AS AvgAnswer,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        AVG(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS AvgTalk,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_servicing)), 0), 108) AS TalkTime,
    CONVERT(VARCHAR(8), DATEADD(SECOND, 
        SUM(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS QTime,
    CAST(ROUND(
        (CAST(COUNT(*) AS FLOAT) / 
         NULLIF((SELECT COUNT(*) FROM [dbo].[callcent_queuecalls] 
                 WHERE time_start >= '2023-01-01'), 0)) * 100, 2
    ) AS VARCHAR(10)) + '%' AS InQPercent
FROM [dbo].[callcent_queuecalls]
WHERE time_start >= '2023-01-01' AND to_dn IS NOT NULL
GROUP BY to_dn;
```

**Query in Report:**
```sql
SELECT * FROM vw_QueueAgentPerformanceAll ORDER BY AgentDN ASC
```

---

## 5. Backend Implementation

### Service Registration (Program.cs)

```csharp
// 1. DevExpress Blazor Components
builder.Services.AddDevExpressBlazor();

// 2. DevExpress Reporting Services
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// 3. Enable Custom SQL in Report Designer
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(designerConfigurator => {
        designerConfigurator.EnableCustomSql();  // CRITICAL!
    });
});

// 4. Register File-based Report Storage
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// 5. Register Data Source Providers
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, 
    CustomDataSourceWizardConnectionStringsProvider>();
builder.Services.AddScoped<IConnectionProviderFactory, CustomConnectionProviderFactory>();
builder.Services.AddScoped<IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();

// ... later in pipeline ...
app.UseDevExpressBlazorReporting();  // MUST be before MapRazorComponents
```

### FileReportStorageService.cs

**Purpose:** Loads/saves .repx files from `Reports/Templates/` folder

```csharp
public class FileReportStorageService : ReportStorageWebExtension
{
    private readonly string _templatesDirectory;

    public FileReportStorageService(IWebHostEnvironment environment)
    {
        _templatesDirectory = Path.Combine(environment.ContentRootPath, 
                                           "Reports", "Templates");
    }

    // Load report from disk
    public override byte[] GetData(string url)
    {
        // Check for code-based reports first
        if (url == "QueueDashboardReport")
            return LoadCodeBasedReport<QueueDashboardReport>();

        // Load .repx file
        var filePath = Path.Combine(_templatesDirectory, 
                                    EnsureRepxExtension(url));
        return File.ReadAllBytes(filePath);
    }

    // Save report to disk
    public override void SetData(XtraReport report, string url)
    {
        var filePath = Path.Combine(_templatesDirectory, 
                                    EnsureRepxExtension(url));
        report.SaveLayoutToXml(filePath);
    }

    // List available reports (for dropdown)
    public override Dictionary<string, string> GetUrls()
    {
        var reports = new Dictionary<string, string>();
        
        // Add code-based reports
        reports.Add("QueueDashboardReport", "Queue Dashboard (Code)");
        
        // Add .repx files
        foreach (var file in Directory.GetFiles(_templatesDirectory, "*.repx"))
        {
            var name = Path.GetFileNameWithoutExtension(file);
            reports.Add(name, name);
        }
        
        return reports;
    }
}
```

### ReportDataSourceProviders.cs

**Purpose:** Provides SQL connections to the Report Designer

```csharp
public class CustomDataSourceWizardConnectionStringsProvider 
    : IDataSourceWizardConnectionStringsProvider
{
    // Show these connections in Data Source Wizard dropdown
    public Dictionary<string, string> GetConnectionDescriptions()
    {
        return new Dictionary<string, string>
        {
            { "3CX_Exporter", "3CX Exporter Database (Call Queue Data)" }
        };
    }

    // Return actual connection parameters
    public DataConnectionParametersBase? GetDataConnectionParameters(string name)
    {
        var connectionString = @"XpoProvider=MSSqlServer;
            Server=LAPTOP-A5UI98NJ\SQLEXPRESS;
            Database=Test_3CX_Exporter;
            User Id=sa;Password=V01PT0y5;
            TrustServerCertificate=True;Encrypt=False;";
            
        return new CustomStringConnectionParameters(connectionString);
    }
}

public class CustomConnectionProviderService : IConnectionProviderService
{
    // Called when report needs to execute a query
    public SqlDataConnection? LoadConnection(string connectionName)
    {
        var connectionString = @"XpoProvider=MSSqlServer;
            Server=LAPTOP-A5UI98NJ\SQLEXPRESS;
            Database=Test_3CX_Exporter;
            User Id=sa;Password=V01PT0y5;
            TrustServerCertificate=True;Encrypt=False;";
            
        return new SqlDataConnection(connectionName, 
            new CustomStringConnectionParameters(connectionString));
    }
}
```

---

## 6. Report Designer UI

### Component: ReportDesigner.razor

```razor
@page "/reportdesigner"
@page "/reportdesigner/{ReportUrl}"
@using DevExpress.Blazor.Reporting
@rendermode InteractiveServer

<DxReportDesigner @ref="DesignerComponent"
                  ReportName="@CurrentReportName"
                  AllowMDI="true"
                  Height="calc(100vh - 180px)"
                  Width="100%" />

@code {
    [Parameter]
    public string? ReportUrl { get; set; }

    private DxReportDesigner? DesignerComponent;
    private string CurrentReportName = string.Empty;

    protected override void OnInitialized()
    {
        // Empty string = new blank report
        CurrentReportName = ReportUrl ?? string.Empty;
    }
}
```

### Component: ReportViewer.razor

```razor
@page "/reportviewer"
@page "/reportviewer/{ReportUrl}"
@inject ReportStorageWebExtension ReportStorage

<select @onchange="OnReportSelected">
    @foreach (var report in AvailableReports)
    {
        <option value="@report.Key">@report.Value</option>
    }
</select>

<DxReportViewer @ref="ViewerComponent"
                ReportName="@CurrentReportName"
                Height="calc(100vh - 180px)" />

@code {
    protected override void OnInitialized()
    {
        AvailableReports = ReportStorage.GetUrls();
    }
}
```

---

## 7. Manual Report Creation Guide

### Prerequisites

1. **Run SQL Views:** Execute `SQL/VoIPToolsDashboard/00_CreateAllViews.sql`
2. **Start Application:** `dotnet run`
3. **Open Designer:** https://localhost:7209/reportdesigner

### Step-by-Step Process

#### Step 1: Create Blank Report
1. Click **File** → **New**
2. Choose **Blank Report**
3. Save as `VoIPToolsDashboard`

#### Step 2: Add Data Sources

**Data Source 1: dsKPIs**
1. Right-click report → **Add Data Source**
2. Choose **SQL Database**
3. Configure connection:
   - Server: `LAPTOP-A5UI98NJ\SQLEXPRESS`
   - Database: `Test_3CX_Exporter`
   - Auth: SQL Server (sa / V01PT0y5)
4. Custom SQL: `SELECT TOP 1 * FROM vw_QueueKPIs`
5. Name: `dsKPIs`

**Data Source 2: dsTrends**
1. Add new SQL data source (same connection)
2. Custom SQL:
   ```sql
   SELECT TOP 15 CallDate, CallDateLabel, AnsweredCalls, MissedCalls, AbandonedCalls
   FROM vw_QueueCallTrends ORDER BY CallDate ASC
   ```
3. Name: `dsTrends`

**Data Source 3: dsAgentsAll**
1. Add new SQL data source
2. Custom SQL:
   ```sql
   SELECT * FROM vw_QueueAgentPerformanceAll ORDER BY AgentDN ASC
   ```
3. Name: `dsAgentsAll`

#### Step 3: Design Page 1 - Header

1. Set **Report Data Source**: `dsKPIs`
2. Add **Report Header** band, Height: 155px
3. Add Title Label:
   - Text: `VoIPTools Customer Service`
   - Font: Segoe UI, 20pt, Bold
   - Color: #4361ee

#### Step 4: Add KPI Cards

Create 8 Panel controls with value + label inside:

| Card | Field Binding | Color |
|------|---------------|-------|
| Total Calls | `[TotalCalls]` | #4a5568 |
| Answered | `[AnsweredCalls]` | #48bb78 (green) |
| Abandoned | `[AbandonedCalls]` | #f56565 (red) |
| Missed | `[MissedCalls]` | #ed8936 (orange) |
| SLA % | `[SLA1Percentage]` | #48bb78 |
| Avg Talk | `[AvgTalkTime]` | #4a5568 |
| Max Talk | `[MaxTalkTime]` | #4a5568 |
| Avg Wait | `[AvgWaitTime]` | #4a5568 |

#### Step 5: Add Agent Table (XRSubreport)

1. Create separate report: `AgentTableSubreport.repx`
2. In AgentTableSubreport:
   - Data source with TOP 10 agents
   - XRTable with 7 columns
3. In main report:
   - Add XRSubreport control
   - Set ReportSource: `AgentTableSubreport`
   - Position at fixed X/Y for side-by-side layout

#### Step 6: Add Area Chart

1. Add **XRChart** control
2. Data Source: `dsTrends`
3. Add 3 Series (all AreaSeriesView):
   - **Answered** - Green (#48bb78)
   - **Missed** - Yellow (#ecc94b)  
   - **Abandoned** - Red (#f56565)
4. Argument: `CallDateLabel`
5. Value: respective call count fields

#### Step 7: Add Page 2 - All Agents

1. Add **DetailReportBand**
2. Set **PageBreak**: BeforeBand
3. Data Source: `dsAgentsAll`
4. Add XRTable for all agents, sorted by AgentDN

#### Step 8: Save and Preview

1. Click **Save**
2. Click **Preview**
3. Verify all data binds correctly

---

## 8. Project Structure & File Reference

### Complete Folder Structure

```
ReportingToolMVP/
├── Components/
│   ├── App.razor                    # Root Blazor component
│   ├── MainLayout.razor             # Main layout with navigation
│   ├── Pages/
│   │   ├── ReportBuilder.razor      # Query-based report builder (DxGrid)
│   │   ├── ReportDesigner.razor     # Visual report designer (DxReportDesigner)
│   │   ├── ReportViewer.razor       # Report viewer (DxReportViewer)
│   │   └── TestSuite.razor          # Test page for validation
│   └── Shared/
│       └── NavMenu.razor            # Navigation menu
│
├── Models/
│   ├── Feature.cs                   # Feature tracking model
│   ├── QueueBasicInfo.cs            # Queue information model
│   ├── ReportConfig.cs              # User filter selections
│   └── ReportDataRow.cs             # Dynamic row for DxGrid
│
├── Services/
│   ├── CustomReportService.cs       # Dynamic query building for ReportBuilder
│   ├── ICustomReportService.cs      # Interface
│   ├── FileReportStorageService.cs  # Load/save .repx files
│   ├── ReportDataSourceProviders.cs # SQL connections for designer
│   ├── ReportExportService.cs       # PDF/Excel export
│   └── IReportExportService.cs      # Interface
│
├── Reports/
│   ├── CodeBased/
│   │   ├── BlankReport.cs           # Empty report template
│   │   ├── QueueDashboardReport.cs  # Code-based dashboard
│   │   └── CallDetailsReport.cs     # Code-based call details
│   ├── Templates/
│   │   ├── VoIPToolsDashboard.repx  # ⭐ Main dashboard report
│   │   ├── AgentTableSubreport.repx # Embedded agent table
│   │   └── [other .repx files]
│   └── logo_base64.txt              # Base64 encoded logo
│
├── SQL/
│   ├── VoIPToolsDashboard/
│   │   ├── 00_CreateAllViews.sql    # Master script - run this
│   │   ├── 01_KPIs.sql              # KPI view only
│   │   ├── 02_AgentPerformance.sql  # Agent view only
│   │   ├── 03_CallTrends.sql        # Trends view only
│   │   ├── 04_QueueSummary.sql      # Queue summary view
│   │   ├── 05_FilterStoredProcedures.sql  # Advanced filtering
│   │   └── README.md
│   ├── VoIPToolsDashboard_Views.sql # Consolidated all views
│   ├── AgentSummaryReport/          # Views for agent report
│   ├── QueueSummaryReport/          # Views for queue report
│   ├── MonthlySummaryReport/        # Views for monthly report
│   └── Views/                       # Older view scripts
│
├── Documentation/
│   ├── REPORT_CATALOG.md            # List of all reports
│   └── VoIPToolsDashboard/
│       ├── 00_Overview.md           # Quick start guide
│       ├── 01_Prerequisites.md      # Setup requirements
│       ├── 02_StepByStep_Guide.md   # Manual creation guide
│       ├── 03_SQL_Reference.md      # SQL documentation
│       ├── 04_Customization.md      # Styling guide
│       ├── 05_Future_Reports.md     # Roadmap
│       └── COMPREHENSIVE_GUIDE.md   # ⭐ This file
│
├── wwwroot/
│   ├── css/
│   │   └── site.css                 # Global styles
│   ├── reportbuilder.css            # ReportBuilder styles
│   └── testsuite.css                # TestSuite styles
│
├── Program.cs                       # ⭐ Service registration
├── appsettings.json                 # Configuration
├── FEATURES.md                      # Feature tracking
├── README.md                        # Project overview
└── ReportingToolMVP.csproj          # Project file
```

### File Purpose Quick Reference

| File | Purpose | When Modified |
|------|---------|---------------|
| `Program.cs` | Service registration, middleware | Adding new services |
| `FileReportStorageService.cs` | Report file I/O | New report types |
| `ReportDataSourceProviders.cs` | DB connections | Connection changes |
| `VoIPToolsDashboard.repx` | Dashboard report | Visual design changes |
| `AgentTableSubreport.repx` | Agent table subreport | Table layout changes |
| `00_CreateAllViews.sql` | Database views | Schema changes |
| `ReportDesigner.razor` | Designer UI | UI customization |
| `ReportViewer.razor` | Viewer UI | Export features |

### Potentially Unused Files

These files may be candidates for cleanup:

| File | Status | Notes |
|------|--------|-------|
| `SQL/Views/*.sql` | Legacy | Older view scripts, superceded by VoIPToolsDashboard folder |
| `SQL/CreateDashboardFunctions.sql` | Legacy | May be outdated functions |
| `Reports/CodeBased/BlankReport.cs` | Active | Used for new reports |
| `Reports/Templates/Report.repx` | Unknown | May be test file |
| `Reports/Templates/Testing1_*.repx` | Test | Testing files |

---

## 9. Flow Diagrams

### Diagram 1: Report Loading Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER OPENS REPORT                             │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  /reportviewer/VoIPToolsDashboard                                   │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ ReportViewer.razor                                          │    │
│  │   └── DxReportViewer ReportName="VoIPToolsDashboard"       │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  FileReportStorageService.GetData("VoIPToolsDashboard")             │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Check if code-based report → No                          │    │
│  │ 2. Build path: Reports/Templates/VoIPToolsDashboard.repx    │    │
│  │ 3. File.ReadAllBytes(path) → byte[]                         │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  DevExpress Report Engine                                           │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ 1. Parse XML from .repx file                                │    │
│  │ 2. Find SqlDataSource elements (dsKPIs, dsTrends, etc.)    │    │
│  │ 3. Decode Base64 connection string                          │    │
│  │ 4. Request connection from CustomConnectionProviderService  │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SQL Server Query Execution                                         │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ dsKPIs:    SELECT TOP 1 * FROM vw_QueueKPIs                │    │
│  │ dsTrends:  SELECT TOP 15 ... FROM vw_QueueCallTrends       │    │
│  │ dsAgentsAll: SELECT * FROM vw_QueueAgentPerformanceAll     │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Data Binding & Rendering                                           │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ XRLabel[TotalCalls] ← DataRow["TotalCalls"] = 4192         │    │
│  │ XRTable rows ← 10 agent records                             │    │
│  │ XRChart series ← 15 daily data points                       │    │
│  │ DetailReportBand ← All agents (Page 2)                     │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RENDERED DASHBOARD                             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ ┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐    │  │
│  │ │4,192││2,530││1,662││1,662││ 60% ││00:57││03:45││00:23│    │  │
│  │ │Total││Answ.││Aband││Miss.││ SLA ││AvgTk││MaxTk││AvgWt│    │  │
│  │ └─────┘└─────┘└─────┘└─────┘└─────┘└─────┘└─────┘└─────┘    │  │
│  │ ┌──────────────────┐ ┌────────────────────────────────────┐ │  │
│  │ │ Agent  │ Calls   │ │         📈 Call Trends             │ │  │
│  │ │--------│---------│ │   ∧     Green = Answered           │ │  │
│  │ │ 1006   │   772   │ │  / \    Yellow = Missed            │ │  │
│  │ │ 1007   │   650   │ │ /   \   Red = Abandoned            │ │  │
│  │ │ ...    │   ...   │ │/     \________________________     │ │  │
│  │ └──────────────────┘ └────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Diagram 2: Data Transformation Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                     LAYER 1: RAW DATA                               │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │               callcent_queuecalls table                     │    │
│  │  ┌───────────────────────────────────────────────────────┐  │    │
│  │  │ id │ time_start │ q_num │ to_dn │ ts_waiting │ ts_srv │  │    │
│  │  │ 1  │ 2024-08-15 │ 8000  │ 1006  │ 00:00:23   │ 00:04  │  │    │
│  │  │ 2  │ 2024-08-15 │ 8000  │ NULL  │ 00:02:15   │ 00:00  │  │    │
│  │  │ 3  │ 2024-08-15 │ 8001  │ 1007  │ 00:00:08   │ 00:02  │  │    │
│  │  │... │    ...     │  ...  │  ...  │    ...     │  ...   │  │    │
│  │  └───────────────────────────────────────────────────────┘  │    │
│  │  (4,192 individual call records)                            │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: SQL VIEWS                               │
│  ┌──────────────────┐ ┌────────────────┐ ┌────────────────────────┐│
│  │   vw_QueueKPIs   │ │vw_QueueAgent   │ │  vw_QueueCallTrends    ││
│  │                  │ │Performance     │ │                        ││
│  │  COUNT(*)        │ │                │ │  GROUP BY              ││
│  │  SUM(CASE...)    │ │ GROUP BY       │ │  CAST(time_start       ││
│  │  AVG(...)        │ │ to_dn          │ │       AS DATE)         ││
│  │  ────────────    │ │ ────────────── │ │  ──────────────────    ││
│  │  1 row total     │ │ 1 row per agent│ │  1 row per day         ││
│  │  aggregates      │ │                │ │                        ││
│  └──────────────────┘ └────────────────┘ └────────────────────────┘│
│       │                      │                      │              │
│       ▼                      ▼                      ▼              │
│  ┌──────────────────┐ ┌────────────────┐ ┌────────────────────────┐│
│  │ TotalCalls: 4192 │ │ Agent: 1006    │ │ Date: 2024-08-15       ││
│  │ Answered: 2530   │ │ Calls: 772     │ │ Answered: 156          ││
│  │ Abandoned: 1662  │ │ AvgTalk: 00:01 │ │ Missed: 23             ││
│  │ SLA%: 60         │ │ ...            │ │ Abandoned: 45          ││
│  └──────────────────┘ └────────────────┘ └────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  LAYER 3: REPORT DATA SOURCES                       │
│  ┌──────────────────┐ ┌────────────────┐ ┌────────────────────────┐│
│  │ dsKPIs           │ │ dsAgents (TOP10)│ │ dsTrends (TOP 15)     ││
│  │ (1 record)       │ │ (10 records)   │ │ (15 records)           ││
│  └──────────────────┘ └────────────────┘ └────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  LAYER 4: REPORT CONTROLS                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │   8 XRLabels        XRSubreport         XRChart             │   │
│  │   (KPI Cards)       (Agent Table)       (Area Chart)        │   │
│  │   bound to          references          3 series bound      │   │
│  │   dsKPIs fields     AgentTable.repx     to dsTrends         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 5: RENDERED OUTPUT                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │   PDF  │  HTML  │  Excel  │  Print Preview                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Diagram 3: Report Designer Data Source Wizard Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  USER: Right-click → Add Data Source → SQL Database                 │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CustomDataSourceWizardConnectionStringsProvider                    │
│  .GetConnectionDescriptions()                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Returns:                                                    │   │
│  │  { "3CX_Exporter" → "3CX Exporter Database (Call Data)" }   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  USER: Selects "3CX_Exporter" from dropdown                         │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CustomDataSourceWizardConnectionStringsProvider                    │
│  .GetDataConnectionParameters("3CX_Exporter")                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Returns: CustomStringConnectionParameters(                  │   │
│  │    "XpoProvider=MSSqlServer;Server=...;Database=...;")      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  USER: Clicks "Custom SQL" → Enters query                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  SELECT TOP 1 * FROM vw_QueueKPIs                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CustomDBSchemaProviderExFactory.Create()                           │
│  → DBSchemaProviderEx executes query to get column metadata         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Columns detected: TotalCalls (int), AnsweredCalls (int)... │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Data source "dsKPIs" added to report with fields visible           │
│  in Field List panel for drag-and-drop binding                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Troubleshooting

### Common Issues

#### "Invalid data member" Error

**Cause:** Field name in report doesn't match column in data source

**Solution:**
1. Open Field List panel
2. Expand data source to see actual column names
3. Update binding expressions to match exactly

#### "Query X is not allowed" Error

**Cause:** Custom SQL not enabled in Report Designer

**Solution:** Ensure this is in Program.cs:
```csharp
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(designerConfigurator => {
        designerConfigurator.EnableCustomSql();  // THIS LINE
    });
});
```

#### Chart Shows Wrong Type (Bar instead of Area)

**Cause:** Series view type not set correctly

**Solution:**
1. Double-click chart in designer
2. Select series in Chart Designer
3. Change **View Type** to "Area" or "Spline Area"
4. Save and preview

#### Subreport Shows No Data

**Cause:** Subreport data source not embedded properly

**Solution:** The subreport must have its own SqlDataSource with Base64-encoded connection. Check that:
1. Subreport has its own data source (not shared reference)
2. Connection string is Base64 encoded in .repx XML

#### Page 2 Not Appearing

**Cause:** DetailReportBand not configured correctly

**Solution:**
1. Ensure DetailReportBand has `PageBreak="BeforeBand"`
2. Verify data source binding is set
3. Check that band is not collapsed (Height > 0)

---

## Appendix: Key XML Elements in .repx

```xml
<!-- Data Source Definition -->
<Item1 Ref="3" ObjectType="DevExpress.DataAccess.Sql.SqlDataSource">
  <Name>dsKPIs</Name>
  <Connection Name="3CX_Exporter" 
              ConnectionString="[Base64 encoded]" />
  <Query Type="CustomSqlQuery" Name="KPIs">
    <Sql>SELECT TOP 1 * FROM vw_QueueKPIs</Sql>
  </Query>
</Item1>

<!-- Label with Data Binding -->
<XRLabel Name="lblTotalCalls">
  <ExpressionBindings>
    <Item1 Expression="FormatString('{0:N0}', [TotalCalls])" 
           PropertyName="Text" />
  </ExpressionBindings>
</XRLabel>

<!-- Subreport Control -->
<XRSubreport Name="subreportAgents">
  <ReportSourceUrl>AgentTableSubreport</ReportSourceUrl>
  <Location>15,175</Location>
  <Size>475,180</Size>
</XRSubreport>

<!-- Chart with Area Series -->
<XRChart Name="chartCallTrends">
  <Series>
    <Item1 Name="Answered" ValueDataMember="AnsweredCalls">
      <View TypeName="AreaSeriesView">
        <Color>#48BB78</Color>
      </View>
    </Item1>
  </Series>
</XRChart>

<!-- Page 2 DetailReportBand -->
<DetailReportBand Name="detailAllAgents" 
                  PageBreak="BeforeBand">
  <DataSource>dsAgentsAll</DataSource>
</DetailReportBand>
```

---

*Document Version: 1.0*  
*Last Updated: February 2025*  
*Report Version: VoIPToolsDashboard v1.0*
