# Customization Guide

How to modify the VoIPTools Dashboard for your needs.

---

## Color Scheme

### Current Colors

| Element | Color | Hex Code | Usage |
|---------|-------|----------|-------|
| Primary Blue | ![#4361ee](https://via.placeholder.com/15/4361ee/4361ee.png) | `#4361ee` | Title, headers, primary actions |
| Success Green | ![#48bb78](https://via.placeholder.com/15/48bb78/48bb78.png) | `#48bb78` | Answered calls, positive metrics |
| Danger Red | ![#f56565](https://via.placeholder.com/15/f56565/f56565.png) | `#f56565` | Abandoned calls, negative metrics |
| Warning Orange | ![#ed8936](https://via.placeholder.com/15/ed8936/ed8936.png) | `#ed8936` | Missed calls, warnings |
| Warning Yellow | ![#ecc94b](https://via.placeholder.com/15/ecc94b/ecc94b.png) | `#ecc94b` | Chart missed series |
| Text Primary | ![#2d3748](https://via.placeholder.com/15/2d3748/2d3748.png) | `#2d3748` | Main text |
| Text Secondary | ![#718096](https://via.placeholder.com/15/718096/718096.png) | `#718096` | Subtitles, labels |
| Border | ![#e2e8f0](https://via.placeholder.com/15/e2e8f0/e2e8f0.png) | `#e2e8f0` | Card borders, table lines |

### Changing Colors in Designer

1. Select the element (label, chart series, etc.)
2. In Properties panel, find `ForeColor` or `BackColor`
3. Click the color picker and enter new hex code

---

## Fonts

### Current Font Stack
- **Primary:** Segoe UI (Windows system font)
- **Fallback:** Arial, sans-serif

### Font Sizes Used

| Element | Size | Weight |
|---------|------|--------|
| Report Title | 20pt | Bold |
| KPI Values | 14pt | Bold |
| KPI Labels | 7pt | Regular |
| Section Titles | 10pt | Bold |
| Table Headers | 7pt | Bold |
| Table Data | 7pt | Regular |
| Subtitle | 9pt | Regular |

---

## Layout Dimensions

### Page Settings
- **Size:** Letter (8.5" x 11")
- **Orientation:** Portrait
- **Margins:** 40px all sides

### Band Heights
| Band | Height | Content |
|------|--------|---------|
| TopMargin | 40px | Empty |
| ReportHeader | 155px | Title, KPIs, table header |
| DetailBand (Agents) | 20px | Per-row height |
| ReportHeader (Chart) | 320px | Chart section |
| BottomMargin | 15px | Empty |

### KPI Card Dimensions
- **Width:** 90px
- **Height:** 50px
- **Spacing:** 10px between cards
- **Start Position:** X=15, Y=65

---

## Adding a New KPI Card

### Step 1: Add SQL Field
In `vw_QueueKPIs` view, add your new metric:
```sql
-- Example: Add "Longest Wait Time"
MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)) AS MaxWaitSeconds,
CONVERT(VARCHAR(8), DATEADD(SECOND, 
    MAX(DATEDIFF(SECOND, '00:00:00', ts_waiting)), 0), 108) AS MaxWaitTime
```

### Step 2: Re-run SQL Script
```powershell
sqlcmd -S "YOUR_SERVER" -d "YOUR_DATABASE" -i "00_CreateAllViews.sql"
```

### Step 3: Add Card in Designer
1. Open VoIPToolsDashboard in Report Designer
2. Copy an existing KPI panel (Ctrl+C, Ctrl+V)
3. Position it next to existing cards
4. Update the Expression Binding to `[MaxWaitTime]`
5. Update the label text to "Max Wait"
6. Save the report

---

## Adding More Agents to Table

### Change Query Limit
In the .repx file's `dsAgents` data source, change:
```sql
-- Current: Top 10 agents
SELECT TOP 10 ...

-- Change to: Top 20 agents
SELECT TOP 20 ...
```

Or modify in Designer:
1. Field List → dsAgents → Right-click → Edit...
2. Change the SQL query
3. Click OK

### Adjust Page Layout
If showing more rows:
1. Reduce chart height
2. Or allow report to span 2 pages
3. Or use smaller font (6pt instead of 7pt)

---

## Changing Chart Type

### Available Chart Types

| Type | Best For |
|------|----------|
| SplineArea | Trends over time (current) |
| Bar | Comparing categories |
| StackedBar | Part-to-whole comparisons |
| Line | Simple trends |
| Pie | Distribution percentages |

### Steps to Change
1. Double-click the chart to open Chart Designer
2. Select a series (e.g., "Answered")
3. In Properties → VIEW section
4. Change View dropdown to desired type
5. Repeat for other series
6. Click OK

---

## Filtering by Date Range

### Add Report Parameters

1. In Designer, right-click report → **Insert Parameter**
2. Add `StartDate` (DateTime type)
3. Add `EndDate` (DateTime type)

### Update SQL Query
```sql
SELECT ...
FROM vw_QueueKPIs
WHERE CallDate >= @StartDate AND CallDate <= @EndDate
```

### Bind Parameters
1. In Data Source properties
2. Find Parameters section
3. Map `@StartDate` to report parameter

---

## Filtering by Queue

### Add Queue Parameter

1. Add parameter: `QueueNumber` (String type)
2. Set value options: List from database or manual list

### Update Views
Create filtered version:
```sql
CREATE VIEW vw_QueueKPIs_Filtered AS
SELECT ... 
FROM callcent_queuecalls
WHERE q_num = @QueueNumber  -- This won't work in view!
```

**Better approach:** Create stored procedure:
```sql
CREATE PROCEDURE sp_GetQueueKPIs
    @QueueNumber VARCHAR(20) = NULL
AS
BEGIN
    SELECT ...
    FROM callcent_queuecalls
    WHERE (@QueueNumber IS NULL OR q_num = @QueueNumber)
END
```

---

## Export Options

### Available Formats
- **PDF:** Best for printing/sharing
- **Excel:** Best for further analysis
- **Word:** Best for editing text
- **HTML:** Best for web viewing

### Enable in Viewer
All formats are enabled by default in `ReportViewer.razor`.

### Programmatic Export
```csharp
// In CustomReportService.cs
var report = new XtraReport();
report.LoadLayout("Reports/Templates/VoIPToolsDashboard.repx");
report.ExportToPdf("output.pdf");
```

---

## Performance Tips

1. **Use TOP clauses:** Limit rows in queries
2. **Index columns:** Create indexes on `time_start`, `q_num`, `to_dn`
3. **Cache views:** Consider materialized views for complex aggregations
4. **Limit date range:** Don't load all historical data
5. **Reduce chart points:** 15-30 points maximum for smooth rendering

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Data not refreshing | Refresh browser, check data source connection |
| Chart empty | Verify `dsTrends` connection string and DataMember binding |
| Wrong values | Check SQL view logic, verify date filters |
| Report too long | Reduce band heights, use smaller fonts |
| Slow loading | Add database indexes, limit query results |
