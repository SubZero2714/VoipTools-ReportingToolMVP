# Step-by-Step Guide: Create VoIPTools Dashboard Manually

This guide walks you through creating the VoIPTools Customer Service Dashboard from scratch using the DevExpress Report Designer.

---

## Part 1: Create a New Report

### Step 1.1: Open Report Designer
1. Start the application: `dotnet run`
2. Navigate to: `https://localhost:7209/reportdesigner`
3. Click **Create New Report**
4. Choose **Blank Report**

### Step 1.2: Configure Page Settings
1. In the **Properties** panel (right side), find **PAGE SETTINGS**
2. Set:
   - **Paper Kind**: Letter
   - **Margins**: 40, 40, 40, 40 (Left, Right, Top, Bottom)
   - **Landscape**: No (Portrait orientation)

### Step 1.3: Save the Report
1. Click the **Save** button (disk icon)
2. Enter name: `VoIPToolsDashboard`
3. Save to: `Templates` folder

---

## Part 2: Add Data Sources

You need **3 separate SQL data sources**:

### Step 2.1: Add KPI Data Source (dsKPIs)

1. Click **Field List** tab (right panel)
2. Right-click the report → **Add Data Source**
3. Select **SQL Database**
4. Configure connection:
   ```
   Server: LAPTOP-A5UI98NJ\SQLEXPRESS
   Authentication: SQL Server
   Username: sa
   Password: V01PT0y5
   Database: Test_3CX_Exporter
   ```
5. Click **Next** → Choose **Custom SQL Query**
6. Enter query:
   ```sql
   SELECT TOP 1 * FROM dbo.vw_QueueKPIs
   ```
7. Name the query: `KPIs`
8. Finish wizard → Name data source: `dsKPIs`

### Step 2.2: Add Agent Data Source (dsAgents)

1. Right-click report → **Add Data Source** → **SQL Database**
2. Use same connection settings as above
3. Custom SQL Query:
   ```sql
   SELECT TOP 10 Agent, Calls, AvgAnswer, AvgTalk, TalkTime, QTime, InQPercent
   FROM dbo.vw_QueueAgentPerformance
   ORDER BY Calls DESC
   ```
4. Name the query: `Agents`
5. Name data source: `dsAgents`

### Step 2.3: Add Trends Data Source (dsTrends)

1. Right-click report → **Add Data Source** → **SQL Database**
2. Use same connection settings
3. Custom SQL Query:
   ```sql
   SELECT TOP 15 CallDate, CallDateLabel, AnsweredCalls, MissedCalls, AbandonedCalls
   FROM dbo.vw_QueueCallTrends
   ORDER BY CallDate ASC
   ```
4. Name the query: `Trends`
5. Name data source: `dsTrends`

### Step 2.4: Set Primary Data Source
1. Click the report background (gray area)
2. In Properties panel → **REPORT TASKS**
3. Set **Data Source**: `dsKPIs`
4. Set **Data Member**: `KPIs`

---

## Part 3: Design the Header (KPI Cards)

### Step 3.1: Configure Report Header Band
1. Click **ReportHeader** band
2. Set **Height**: 155 pixels

### Step 3.2: Add Title
1. Drag a **Label** from toolbox to Report Header
2. Position: X=15, Y=10
3. Size: Width=350, Height=35
4. Text: `VoIPTools Customer Service`
5. Font: **Segoe UI, 20pt, Bold**
6. Color: `#4361ee` (Primary Blue)

### Step 3.3: Add Subtitle
1. Add another Label below title
2. Position: X=15, Y=45
3. Text: `Queue Performance Dashboard`
4. Font: **Segoe UI, 9pt**
5. Color: `#718096` (Gray)

### Step 3.4: Add Date/Time Label
1. Add Label in top-right corner
2. Position: X=800, Y=15
3. Size: Width=200, Height=15
4. Right-click → **Expression Binding** → Text:
   ```
   'Data as of ' + FormatString('{0:MM-dd-yyyy hh:mm tt}', Now())
   ```
5. Font: **Segoe UI, 7pt**
6. Alignment: Right

### Step 3.5: Create KPI Cards

Create 8 KPI cards in a row. For each card:

**Card Structure:**
```
┌──────────────┐
│     4,192    │  ← Value (large, colored)
│  Total Calls │  ← Label (small, gray)
└──────────────┘
```

**Card 1: Total Calls**
1. Add **Panel** control
2. Position: X=15, Y=65, Width=90, Height=50
3. Border: 1px solid `#e2e8f0`
4. Inside panel, add 2 Labels:
   - **Value Label**: 
     - Expression: `FormatString('{0:N0}', [TotalCalls])`
     - Font: Segoe UI, 14pt, Bold
     - Color: `#4a5568`
   - **Caption Label**:
     - Text: `Total Calls`
     - Font: Segoe UI, 7pt
     - Color: `#a0aec0`

**Repeat for remaining cards:**

| Card | Field | Expression | Color |
|------|-------|------------|-------|
| 2 | Answered | `FormatString('{0:N0}', [AnsweredCalls])` | `#48bb78` (Green) |
| 3 | Abandoned | `FormatString('{0:N0}', [AbandonedCalls])` | `#f56565` (Red) |
| 4 | Missed | `FormatString('{0:N0}', [MissedCalls])` | `#ed8936` (Orange) |
| 5 | SLA % | `FormatString('{0}%', [SLA1Percentage])` | `#48bb78` (Green) |
| 6 | Avg Talk | `[AvgTalkTime]` | `#4a5568` (Gray) |
| 7 | Max Talk | `[MaxTalkTime]` | `#4a5568` |
| 8 | Avg Wait | `[AvgWaitTime]` | `#4a5568` |

---

## Part 4: Create Agent Performance Table

### Step 4.1: Add Detail Report Band
1. Right-click report → **Insert Band** → **Detail Report**
2. This creates a nested report for repeating data
3. In Properties:
   - **Data Source**: `dsAgents`
   - **Data Member**: `Agents`

### Step 4.2: Add Table Header (in Report Header inside Detail Report)
1. Inside the DetailReportBand, add a **ReportHeaderBand**
2. Height: 25 pixels
3. Add a **Table** control with 7 columns:
   ```
   | Agent | Calls | Avg Answer | Avg Talk | Talk Time | Q Time | In Q% |
   ```
4. Style header row:
   - Background: `#4361ee` (Blue)
   - Font: Segoe UI, 7pt, Bold
   - Text Color: White
   - Alignment: Center

### Step 4.3: Add Data Row (in Detail Band)
1. Inside the DetailReportBand, configure the **DetailBand**
2. Height: 20 pixels
3. Add a **Table** with 7 columns matching header
4. Bind each cell to corresponding field:
   - Cell 1: `[Agent]`
   - Cell 2: `[Calls]`
   - Cell 3: `[AvgAnswer]`
   - Cell 4: `[AvgTalk]`
   - Cell 5: `[TalkTime]`
   - Cell 6: `[QTime]`
   - Cell 7: `[InQPercent]`
5. Style data rows:
   - Background: White
   - Border: 1px solid `#e2e8f0`
   - Font: Segoe UI, 7pt

---

## Part 5: Create Call Trends Chart

### Step 5.1: Add Second Detail Report Band
1. Right-click report → **Insert Band** → **Detail Report**
2. Set **Level**: 1 (so it appears after the agent table)
3. In Properties:
   - **Data Source**: `dsTrends`
   - **Data Member**: `Trends`

### Step 5.2: Add Report Header for Chart
1. Inside this DetailReportBand, add **ReportHeaderBand**
2. Height: 320 pixels

### Step 5.3: Add Chart Control
1. Drag **Chart** from toolbox into the Report Header
2. Position: X=15, Y=30
3. Size: Width=980, Height=290

### Step 5.4: Configure Chart
1. Double-click the chart to open **Chart Designer**
2. Delete any default series
3. **Add Series 1: Answered**
   - Click **+** next to Series
   - Name: `Answered`
   - View Type: **Spline Area**
   - Argument Field: `CallDateLabel`
   - Value Field: `AnsweredCalls`
   - Color: `#48bb78` (Green)
   - Transparency: 150

4. **Add Series 2: Missed**
   - Name: `Missed`
   - View Type: **Spline Area**
   - Argument Field: `CallDateLabel`
   - Value Field: `MissedCalls`
   - Color: `#ecc94b` (Yellow)
   - Transparency: 150

5. **Add Series 3: Abandoned**
   - Name: `Abandoned`
   - View Type: **Spline Area**
   - Argument Field: `CallDateLabel`
   - Value Field: `AbandonedCalls`
   - Color: `#f56565` (Red)
   - Transparency: 150

6. **Configure Legend**
   - Position: Top-Right
   - Show: Yes

7. **Configure X-Axis**
   - Label Angle: 45°
   - Enable Anti-aliasing: Yes

8. Click **OK** to close Chart Designer

### Step 5.5: Bind Chart to Data Source
1. Select the XRChart control
2. In Properties:
   - **Data Source**: `dsTrends`
   - **Data Member**: `Trends`

---

## Part 6: Final Adjustments

### Step 6.1: Set Margins
1. Click **TopMargin** band → Height: 40
2. Click **BottomMargin** band → Height: 15

### Step 6.2: Hide Empty Detail Bands
1. For each DetailReportBand, find the inner **DetailBand**
2. If it should show no content (like for chart), set:
   - Height: 0
   - Visible: False

### Step 6.3: Preview and Test
1. Click **Preview** tab
2. Verify:
   - ✅ All 8 KPI cards show correct values
   - ✅ Agent table shows 10 rows
   - ✅ Chart shows colored area lines
   - ✅ Everything fits on 1 page

### Step 6.4: Save
1. Click **Save** button
2. Report is saved to: `Reports/Templates/VoIPToolsDashboard.repx`

---

## Complete! 🎉

Your VoIPTools Customer Service Dashboard is now ready. It should look like this:

```
┌────────────────────────────────────────────────────────────┐
│  VoIPTools Customer Service              Data as of 02-04 │
│  Queue Performance Dashboard                               │
│                                                            │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐... │
│  │ 4,192│ │ 2,530│ │ 1,662│ │ 1,662│ │  60% │ │ 00:57│    │
│  │Total │ │Answer│ │Aband.│ │Missed│ │ SLA  │ │AvgTk │    │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘    │
│                                                            │
│  Agent Performance                                         │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Agent    │Calls│ AvgAns │ AvgTalk │ Time │ Q │ In%  │  │
│  │──────────┼─────┼────────┼─────────┼──────┼───┼──────│  │
│  │ 1006-Agt │ 772 │ 00:00  │ 00:01:28│ ...  │...│18.42%│  │
│  │ ...      │ ... │  ...   │   ...   │ ...  │...│  ... │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  Call Trends                                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │     ╱╲                    ∙─────────────────        │  │
│  │    ╱  ╲   ╱╲             ╱                   Legend:│  │
│  │   ╱    ╲ ╱  ╲   ╱╲      ╱    ■ Answered           │  │
│  │  ╱      ╳    ╲ ╱  ╲    ╱     ■ Missed             │  │
│  │ ╱            ╳    ╲  ╱       ■ Abandoned          │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## Tips for Customization

1. **Change Date Range**: Modify the SQL views to filter by date
2. **Different Colors**: Update the Color properties in chart series
3. **More/Fewer Agents**: Change `TOP 10` to `TOP 5` or `TOP 20` in dsAgents query
4. **Queue-Specific**: Add WHERE clause to filter by queue number
