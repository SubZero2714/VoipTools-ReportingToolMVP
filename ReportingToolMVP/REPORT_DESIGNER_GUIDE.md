# DevExpress Report Designer - Knowledge Base

This document serves as a comprehensive guide for the DevExpress Report Designer integration in the VoIPTools Reporting Tool MVP. It covers configuration, components, and step-by-step usage instructions.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Files and Configuration](#files-and-configuration)
4. [Program.cs Setup](#programcs-setup)
5. [Data Source Configuration](#data-source-configuration)
6. [Report Designer UI Guide](#report-designer-ui-guide)
7. [Creating a Report Step-by-Step](#creating-a-report-step-by-step)
8. [Report Storage](#report-storage)
9. [Troubleshooting](#troubleshooting)
10. [Resources](#resources)

---

## Overview

The DevExpress Report Designer is a visual WYSIWYG (What You See Is What You Get) tool that allows users to create, edit, and customize report templates directly in the browser. Reports are saved as `.repx` files and can be viewed/exported using the Report Viewer.

### Key Features
- Drag-and-drop report element placement
- SQL data source binding with wizard
- Band-based report structure (Header, Detail, Footer)
- Export to PDF, Excel, Word, HTML
- Print functionality
- Parameters and filtering support

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser (Client)                          │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │  Report Designer    │    │      Report Viewer              │ │
│  │  /reportdesigner    │    │      /reportviewer              │ │
│  │  (DxReportDesigner) │    │      (DxReportViewer)           │ │
│  └──────────┬──────────┘    └───────────────┬─────────────────┘ │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ASP.NET Core Server                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              DevExpress Reporting Middleware                 ││
│  │              (UseDevExpressBlazorReporting)                  ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │ FileReportStorage   │    │ DataSourceWizardConnection      │ │
│  │ Service.cs          │    │ StringsProvider.cs              │ │
│  │ (Saves .repx files) │    │ (SQL connection config)         │ │
│  └──────────┬──────────┘    └───────────────┬─────────────────┘ │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────┐         ┌─────────────────────────────────┐
│   Reports/ folder   │         │    SQL Server Database          │
│   (.repx files)     │         │    (Test_3CX_Exporter)          │
└─────────────────────┘         └─────────────────────────────────┘
```

---

## Files and Configuration

### Core Files

| File | Purpose |
|------|---------|
| `Components/Pages/ReportDesigner.razor` | Report Designer page component |
| `Components/Pages/ReportViewer.razor` | Report Viewer page component |
| `Services/FileReportStorageService.cs` | Handles saving/loading .repx files |
| `Services/ReportDataSourceProviders.cs` | SQL connection configuration for wizard |
| `Reports/BlankReport.cs` | Blank starter template for new reports |
| `Components/MainLayout.razor` | Contains CSS/JS references for reporting |
| `Program.cs` | Service registration and middleware |

### NuGet Packages Required

```xml
<PackageReference Include="DevExpress.Blazor.Reporting" Version="25.1.6" />
<PackageReference Include="DevExpress.Blazor.Reporting.Viewer" Version="25.1.6" />
<PackageReference Include="DevExpress.Blazor.Reporting.JSBasedControls" Version="25.1.6" />
<PackageReference Include="DevExpress.AspNetCore.Reporting" Version="25.1.6" />
```

---

## Program.cs Setup

The following services must be registered in `Program.cs`:

```csharp
// Add MVC services (required by DevExpress Reporting)
builder.Services.AddControllersWithViews();

// Add DevExpress Reporting services
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// Register report storage service (file-based)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// Register SQL Data Source provider for Report Designer wizard
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, CustomDataSourceWizardConnectionStringsProvider>();
```

Middleware configuration:

```csharp
// Map MVC controllers (required by DevExpress Reporting)
app.MapControllers();

// DevExpress Reporting middleware
app.UseDevExpressBlazorReporting();
```

---

## Data Source Configuration

### File: `Services/ReportDataSourceProviders.cs`

This service provides SQL connection strings to the Report Designer's Data Source Wizard.

```csharp
public class CustomDataSourceWizardConnectionStringsProvider : IDataSourceWizardConnectionStringsProvider
{
    // Returns connections shown in the wizard dropdown
    public Dictionary<string, string> GetConnectionDescriptions()
    {
        return new Dictionary<string, string>
        {
            { "3CX_Exporter", "3CX Exporter Database (Call Queue Data)" },
            { "DefaultConnection", "Default SQL Server Connection" }
        };
    }

    // Returns actual connection parameters
    public DataConnectionParametersBase? GetDataConnectionParameters(string name)
    {
        if (name == "3CX_Exporter" || name == "DefaultConnection")
        {
            // IMPORTANT: Use XpoProvider and TrustServerCertificate for SSL compatibility
            var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
            
            return new CustomStringConnectionParameters(connectionString);
        }
        return null;
    }
}
```

### Key Points:
- `XpoProvider=MSSqlServer` - Required for DevExpress XPO data access
- `TrustServerCertificate=True` - Required for SQL Server Express with self-signed certs
- `Encrypt=False` - Disables SSL encryption requirement

---

## Report Designer UI Guide

### Left Panel - Toolbox

| Icon | Name | Description |
|------|------|-------------|
| **A** | Label | Static text, titles, headers |
| **☑** | Check Box | Display boolean values |
| **☐** | Panel | Container to group controls |
| **⊞** | Table | Tabular data layout (rows/columns) |
| **▭** | Rich Text | Formatted text with HTML support |
| **📊** | Chart | Bar, Line, Pie charts |
| **📈** | Sparkline | Mini inline charts |
| **∑** | Summary | Calculated totals (Sum, Avg, Count) |
| **📄** | Page Info | Page numbers, date, report name |
| **🖼️** | Picture Box | Images and logos |
| **▮** | Line / Shape | Decorative lines and shapes |
| **📋** | Subreport | Embed another report |
| **📊** | Cross Tab | Pivot table for data analysis |
| **🔲** | Barcode | Generate barcodes (QR, Code128, etc.) |

### Report Bands (Yellow/Orange sections)

| Band | Purpose |
|------|---------|
| **TopMargin** | Top page margin (usually empty) |
| **PageHeader** | Repeats at top of every page (column headers) |
| **Detail** | Main data area - repeats for each data row |
| **PageFooter** | Repeats at bottom of every page (page numbers) |
| **BottomMargin** | Bottom page margin (usually empty) |

### Right Panel - Properties

| Section | Description |
|---------|-------------|
| **DATA** | Data Source, Data Member, Filter String settings |
| **APPEARANCE** | Colors, fonts, borders, styles |
| **BEHAVIOR** | Visibility, page breaks, keep together |
| **DESIGN** | Size, position, anchoring |
| **NAVIGATION** | Bookmarks, hyperlinks |
| **PAGE SETTINGS** | Paper size, orientation, margins |

---

## Creating a Report Step-by-Step

### Step 1: Add Data Source

1. Click **Menu (☰)** → **"Add Data Source..."**
2. Select **"3CX Exporter Database (Call Queue Data)"**
3. Expand **Tables** → Check `callcent_queuecalls`
4. Click **Finish**

### Step 2: Add Report Title

1. Drag **Label** (A) to **PageHeader** band
2. Double-click to edit text: `Queue Performance Report`
3. In Properties → Font: Bold, 18pt
4. Set Text Alignment: Middle Center

### Step 3: Add Data Table

1. Click on the **Detail** band
2. Drag **Table** control to the Detail band
3. Configure columns for your data fields

### Step 4: Bind Data Fields

1. Open **Field List** (right panel, data icon)
2. Drag fields from your data source to table cells:
   - `q_num` → Queue Number
   - `time_start` → Call Date
   - etc.

### Step 5: Preview Report

1. Click **PREVIEW** button (top-right)
2. Report executes query and displays data
3. Use toolbar to print or export

### Step 6: Save Report

1. Click **Menu (☰)** → **"Save As..."**
2. Enter report name (e.g., `QueuePerformanceReport`)
3. Report saves to `Reports/` folder as `.repx` file

---

## Report Storage

### File: `Services/FileReportStorageService.cs`

Reports are stored as `.repx` XML files in the `Reports/` folder.

```csharp
public class FileReportStorageService : ReportStorageWebExtension
{
    private readonly string _reportDirectory;

    public FileReportStorageService(IWebHostEnvironment env)
    {
        _reportDirectory = Path.Combine(env.ContentRootPath, "Reports");
        Directory.CreateDirectory(_reportDirectory);
    }

    // Load report from file
    public override byte[] GetData(string url)
    {
        if (string.IsNullOrEmpty(url))
            return CreateBlankReport(); // Return blank for new reports
            
        var filePath = Path.Combine(_reportDirectory, $"{url}.repx");
        return File.ReadAllBytes(filePath);
    }

    // Save report to file
    public override void SetData(XtraReport report, string url)
    {
        var filePath = Path.Combine(_reportDirectory, $"{url}.repx");
        report.SaveLayoutToXml(filePath);
    }

    // List available reports
    public override Dictionary<string, string> GetUrls()
    {
        var reports = new Dictionary<string, string>();
        foreach (var file in Directory.GetFiles(_reportDirectory, "*.repx"))
        {
            var name = Path.GetFileNameWithoutExtension(file);
            reports[name] = name;
        }
        return reports;
    }
}
```

---

## Troubleshooting

### Issue: "Schema loading failed. Unable to open a database"

**Cause:** SSL certificate not trusted (self-signed cert on SQL Server Express)

**Solution:** Use `CustomStringConnectionParameters` with:
```
TrustServerCertificate=True;Encrypt=False;
```

### Issue: Report Designer page is blank

**Cause:** Missing CSS/JS references or blank report not configured

**Solution:** 
1. Ensure MainLayout.razor has DevExpress CSS/JS references
2. Ensure `BlankReport.cs` exists and `FileReportStorageService.GetData()` returns it for empty URLs

### Issue: "DxReportDesigner does not have property 'Report'"

**Cause:** Using wrong parameter name

**Solution:** Use `ReportName` (string URL) not `Report` (XtraReport object):
```razor
<DxReportDesigner ReportName="@CurrentReportName" />
```

### Issue: Data source not appearing in wizard

**Cause:** `IDataSourceWizardConnectionStringsProvider` not registered

**Solution:** Add to Program.cs:
```csharp
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, CustomDataSourceWizardConnectionStringsProvider>();
```

---

## Resources

### Official Documentation

| Topic | URL |
|-------|-----|
| Blazor Report Designer | https://docs.devexpress.com/XtraReports/401971/web-reporting/blazor-reporting |
| End-User Report Designer | https://docs.devexpress.com/XtraReports/119176/web-reporting/web-end-user-report-designer |
| Data Binding Guide | https://docs.devexpress.com/XtraReports/15034/detailed-guide-to-devexpress-reporting/bind-reports-to-data |
| IDataSourceWizardConnectionStringsProvider | https://docs.devexpress.com/CoreLibraries/DevExpress.DataAccess.Web.IDataSourceWizardConnectionStringsProvider |

### DevExpress Demos

| Demo | URL |
|------|-----|
| Blazor Report Designer | https://demos.devexpress.com/blazor/ReportDesigner |
| Blazor Report Viewer | https://demos.devexpress.com/blazor/ReportViewer |

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-30 | Initial integration - Report Designer and Viewer pages created |
| 2026-01-06 | Fixed SSL certificate issue with CustomStringConnectionParameters |
| 2026-01-06 | Added Data Source Wizard with 3CX Exporter database connection |

---

*This document will be updated as we continue building the reporting features.*
