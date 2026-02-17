# Manual Report Creation Guide
## VoIPTools Customer Service – Queue Performance Dashboard

> **Purpose:** Step-by-step guide to manually create a production report using the Report Designer UI with stored procedures from the `3CX Exporter` database.

---

## Prerequisites

- Application running at `https://localhost:7209`
- Access to Report Designer (`/reportdesigner`)
- Database: `3CX Exporter` on server `3.132.72.134`
- Database credentials: User `sa`, Password `V01PT0y5`

## Stored Procedures Used

| SP Name | Purpose | Parameters |
|---------|---------|------------|
| `sp_queue_kpi_summary_shushant` | KPI summary (Total Calls, Answered, Abandoned, SLA%, etc.) | `@period_from`, `@period_to`, `@queue_dns`, `@wait_interval` |
| `sp_queue_calls_by_date_shushant` | Daily call trends (for area chart) | `@period_from`, `@period_to`, `@queue_dns`, `@wait_interval` |
| `qcall_cent_get_extensions_statistics_by_queues` | Agent/extension performance (for agent table) | `@period_from`, `@period_to`, `@queue_dns`, `@wait_interval` |

### SP Parameter Types

| Parameter | SQL Type | Description |
|-----------|----------|-------------|
| `@period_from` | `datetimeoffset` | Report start date |
| `@period_to` | `datetimeoffset` | Report end date |
| `@queue_dns` | `varchar(max)` | Queue DN filter (use `%` for all queues, or comma-separated like `8077,8089`) |
| `@wait_interval` | `time` | SLA threshold (typically `00:00:20` = 20 seconds) |

---

## Step 1: Create a New Report

1. Navigate to `https://localhost:7209/reportdesigner`
2. Click **"+"** or create a new report
3. Name it (e.g., `Similar to samuel sirs report manualtest_2`)
4. The designer opens with an empty report canvas

---

## Step 2: Add Data Source – KPI Summary

This data source powers the KPI cards (Total Calls, Answered, Abandoned, SLA%, Avg Talk, Total Talk, Avg Wait, Callbacks).

1. In the **Field List** panel (right side), click **"+ Add Data Source"**
2. Select **"Database"** → click Next
3. On the **"Specify Data Source Settings"** page:

### Section 1 – Choose a data connection
- Select **"3CX Exporter Production Database (LIVE DATA)"**

### Section 2 – Choose stored procedure
- Expand **"Stored Procedures"**
- Check ✅ **`sp_queue_kpi_summary_shushant(@period_from, @period_to, @queue_dns, @wait_interval)`**

### Section 4 – Configure query parameters

> **IMPORTANT:** The parameter Type dropdown varies depending on the SQL data type. Use the settings below exactly.

| Parameter | Type | Value |
|-----------|------|-------|
| `@period_from` | **Expression** | `#2026-02-01#` |
| `@period_to` | **Expression** | `#2026-02-16#` |
| `@queue_dns` | **Expression** | `'%'` |
| `@wait_interval` | **Time** | `00:00:20` |

> **Notes:**
> - For date parameters: Select **"Expression"** type and wrap the date in `#` hash marks (DevExpress expression syntax for date literals)
> - For `@queue_dns`: Select **"Expression"** type and wrap the value in single quotes
> - For `@wait_interval`: The dropdown only offers **"Time"** or "Expression" — use **"Time"** and enter `00:00:20`
> - These are temporary defaults for schema discovery. We will later bind them to Report Parameters.

### Common Error
❌ **"An error occurred while rebuilding a data source schema"**
- **Cause:** Parameters set with wrong type or empty values. The designer must execute the SP to discover output columns.
- **Fix:** Ensure all 4 parameters have valid values as shown above. Date expressions MUST use `#` syntax, not plain date strings.

4. Click **Finish**

### Expected Result
After finishing, the Field List should show:
```
▸ sqlDataSource1
    ▸ sp_queue_kpi_summary_shushant
        queue_dn
        queue_display_name
        total_calls
        abandoned_calls
        answered_calls
        answered_percent
        answered_within_sla
        answered_within_sla_percent
        serviced_callbacks
        total_talking
        mean_talking
        avg_waiting
  ? Parameters
```

---

## Step 3: Assign Data Source to the Report

1. Click on the **report surface background** (not on any control) — or click **"Report"** at the top of the Report Explorer
2. In the **Properties panel** (right side, click the gear ⚙️ icon if not visible), find:
   - **Data Source** → select **`sqlDataSource1`**
   - **Data Member** → select **`sp_queue_kpi_summary_shushant`**

This tells the report to use the KPI stored procedure as its main data source. The KPI cards in the ReportHeader can now bind to fields like `total_calls`, `answered_calls`, etc.

---

## Step 4: Bind KPI Card 1 (Total Calls) to data

1. In the Report Explorer, expand **pnlCard1**
2. Click the **value label** inside (named `pnlCard1Value`)
3. In the Properties/Expressions panel, click the **`f`** button next to the **Text** property
4. In the Expression Editor, select **Text** in the left list, then enter:
   ```
   FormatString('{0:N0}', [total_calls])
   ```
5. Click **OK**

---

## Step 5: Bind remaining 7 KPI cards

Repeat Step 4 for each card — expand the card in Report Explorer, click the value label, set the Text expression:

| Card | Value Label | Text Expression | Card Label |
|------|-----------|-----------------|------------|
| pnlCard1 | pnlCard1Value | `FormatString('{0:N0}', [total_calls])` | Total Calls |
| pnlCard2 | pnlCard2Value | `FormatString('{0:N0}', [answered_calls])` | Answered |
| pnlCard3 | pnlCard3Value | `FormatString('{0:N0}', [abandoned_calls])` | Abandoned |
| pnlCard4 | pnlCard4Value | `FormatString('{0:N1}%', [answered_within_sla_percent])` | SLA % |
| pnlCard5 | pnlCard5Value | `[mean_talking]` | Avg Talk |
| pnlCard6 | pnlCard6Value | `[total_talking]` | Total Talk |
| pnlCard7 | pnlCard7Value | `[avg_waiting]` | Avg Wait |
| pnlCard8 | pnlCard8Value | `FormatString('{0:N0}', [serviced_callbacks])` | Callbacks |

> **Notes:**
> - Cards 5, 6, 7 use plain `[field_name]` — no FormatString needed (values are already time format like `00:03:38`)
> - Card 4 uses `{0:N1}%` for one decimal + percent sign (e.g., `100.0%`)

---

## Step 6: Bind Filter Info Panel

The filter info panel (`pnlFilterInfo`) shows 3 labels at the top-right of the report with context about the current report filters.

1. **Click `lblQueueFilter`** in the report (or find it in Report Explorer under `pnlFilterInfo`)
2. In Properties, click the **`f`** button next to **Text**
3. Enter the expression:
   ```
   'Queue DN: ' + [queue_dn] + ' - ' + [queue_display_name]
   ```
4. Click **OK**

5. **Click `lblDateRange`** → set Text expression:
   ```
   'Period: ' + FormatString('{0:MMM dd, yyyy}', #2026-02-01#) + ' - ' + FormatString('{0:MMM dd, yyyy}', #2026-02-16#)
   ```

6. **Click `lblSLAInfo`** → set Text expression:
   ```
   'SLA Threshold: 00:00:20'
   ```

> **Note:** The date range and SLA labels use hardcoded values for now. Later (Step 13), we'll create Report Parameters and replace these with `[Parameters.pPeriodFrom]` etc.

---

## Step 7: Bind Report Date Label

1. **Click `lblReportDate`** in the report (usually at the top of ReportHeader)
2. In Properties, click the **`f`** button next to **Text**
3. Enter the expression:
   ```
   'Generated: ' + FormatString('{0:MM-dd-yyyy hh:mm tt}', Now())
   ```
4. Click **OK**

This displays the current date/time when the report is generated.

---

## Step 8: Add Data Source – Chart Data (Call Trends)

This data source powers the area chart showing daily call trends.

1. Click **"+ Add Data Source"** in the Field List panel
2. Select **"Database"** → Next
3. Choose **"3CX Exporter Production Database"** connection → Next
4. Select **"Stored Procedures"** → check ✅ **`sp_queue_calls_by_date_shushant`** → Next
5. Configure parameters (same pattern as Step 2):

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `#2026-02-01#` |
   | `@period_to` | **Expression** | `#2026-02-16#` |
   | `@queue_dns` | **Expression** | `'%'` |
   | `@wait_interval` | **Time** | `00:00:20` |

6. Click **Finish**

### Expected Result
Field List shows `sqlDataSource2` with fields:
- `queue_dn`, `call_date`, `total_calls`, `answered_calls`, `abandoned_calls`, `answered_within_sla`, `answer_rate`, `sla_percent`

---

## Step 9: Bind the Chart to sqlDataSource2

1. **Click on the chart** (the big empty box labeled "There are no visible series in the chart")
2. Click **"Run Designer..."** button (appears in the top-right corner of the chart when selected)
3. In the Chart Designer dialog:
   - Set **Data Source** = `sqlDataSource2`
   - Set **Data Member** = `sp_queue_calls_by_date_shushant`

4. **Add Series 1 — Answered Calls:**
   - Click **"+"** to add a new series
   - **Series Type:** Area
   - **Name:** `Answered`
   - **Argument Data Member:** `call_date`
   - **Value Data Member:** `answered_calls`
   - **Color:** Green (`#2ecc71` or similar)

5. **Add Series 2 — Abandoned Calls:**
   - Click **"+"** to add another series
   - **Series Type:** Area
   - **Name:** `Abandoned`
   - **Argument Data Member:** `call_date`
   - **Value Data Member:** `abandoned_calls`
   - **Color:** Red (`#e74c3c` or similar)

6. Click **OK** to close the Chart Designer

> **Tip:** The chart preview in the designer should immediately show 2 overlapping area series with real data.

---

## Step 10: Add Data Source – Agent Performance

This data source powers the Agent Performance table.

1. Click **"+ Add Data Source"** in the Field List panel
2. Select **"Database"** → Next
3. Choose **"3CX Exporter Production Database"** connection → Next
4. Select **"Stored Procedures"** → check ✅ **`qcall_cent_get_extensions_statistics_by_queues`** → Next
5. Configure parameters (same pattern as before):

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `#2026-02-01#` |
   | `@period_to` | **Expression** | `#2026-02-17#` |
   | `@queue_dns` | **Expression** | `'%'` |
   | `@wait_interval` | **Time** | `00:00:20` |

6. Click **Finish**

### Expected Result
Field List shows `sqlDataSource3` with fields:
- `avg_answer_time`, `avg_talk_time`, `extension_answered_count`, `extension_display_name`, `extension_dn`, `queue_display_name`, `queue_dn`, `queue_received_count`, `talk_time`

---

## Step 11: Bind AgentDetail Band to sqlDataSource3

### Step 11a: Set Data Source on the AgentDetail Band

> ⚠️ **COMMON MISTAKE:** There are TWO bands with similar names:
> - **AgentDetail (DetailReportBand)** — the parent container. **This is the one you need.**
> - **AgentDetailBand (Detail)** — the inner band for placing cells. This one does NOT have Data Source properties.

1. In the **Properties panel** dropdown (top-right), select **"AgentDetail (Detail Report)"** — NOT "AgentDetailBand (Detail)"
2. Set the properties:
   - **Data Source** = `sqlDataSource3`
   - **Data Member** = `qcall_cent_get_extensions_statistics_by_queues`

### Step 11b: Add Table Header Row (GroupHeader)

The original report has a **GroupHeaderBand** inside AgentDetail with column headers styled in dark slate with white text.

1. **Right-click on the "AgentDetail" band** (on the left vertical label area) → **"Insert Band"** → select **"GroupHeader"**
   - This adds a **GroupHeaderBand** inside the AgentDetail band

2. From the **Toolbox** (left panel), drag a **Table** control onto the new **GroupHeader band**
   - Set the table width to fill the band (~980 pixels wide)
   - Set height to **22 pixels**

3. The table needs **6 columns**. Right-click the table → **Insert** → **Column to the Right** until you have exactly 6 columns.

4. Set the **text** for each header cell:

   | Cell # | Text | Alignment |
   |--------|------|-----------|
   | 1 | `Agent` | Middle Left |
   | 2 | `Answered Calls` | Middle Center |
   | 3 | `Avg Answered` | Middle Center |
   | 4 | `Avg Talk Time` | Middle Center |
   | 5 | `Q Time` | Middle Center |
   | 6 | `In Q%` | Middle Center |

5. Style all 6 header cells:
   - **Font:** Segoe UI, 8pt, **Bold**
   - **Fore Color:** White
   - **Back Color:** `#4A5568` (dark slate) — RGB(74, 85, 104)

> **Tip:** Select all 6 cells at once (Ctrl+Click each), then set Font, ForeColor, BackColor in bulk.

> ⚠️ **COMMON MISTAKE:** Make sure you have exactly 6 columns, not 7. Check that "Avg Talk Time" doesn't appear twice.

### Step 11c: Bind the Data Row Cells

Now bind each cell in the **data row** (inside the AgentDetailBand) to the stored procedure fields.

Click each cell → Properties → click the **`f`** button next to **Text** → enter the expression:

| Cell (under header) | Expression | Notes |
|---------------------|-----------|-------|
| Under "Agent" | `[extension_dn] + ' - ' + [extension_display_name]` | Combines extension number and name |
| Under "Answered Calls" | `FormatString('{0:N0}', [extension_answered_count])` | Formatted with thousands separator |
| Under "Avg Answered" | `[avg_answer_time]` | Time format from SP |
| Under "Avg Talk Time" | `[avg_talk_time]` | Time format from SP |
| Under "Q Time" | `'-'` | Placeholder — SP doesn't return this field |
| Under "In Q%" | `'-'` | Placeholder — SP doesn't return this field |

> **Note:** The cell names may differ from the original report (e.g., `tableCell8`, `tableCell9`, etc.) — what matters is each cell is under the correct header column and has the right expression.

### Step 11d: Preview and Verify Structure

Click **PREVIEW** to verify all sections render:
- KPI cards (may show zeros until parameters are connected)
- Chart with legend (may be empty until parameters are connected)
- Agent table header with data row

> **Note:** Data will appear empty/zero at this point because the data sources still use hardcoded parameter values. The next steps connect them to Report Parameters.

---

## Step 12: Create Report Parameters

Report Parameters create input fields that appear when the user clicks PREVIEW.

1. In the **Field List** panel (right side), find **"Parameters"** at the bottom
2. Click the **"+"** button next to Parameters

### Parameter 1: pPeriodFrom
- **Name:** `pPeriodFrom`
- **Description:** `Start Date`
- **Type:** `Date and Time`
- **Visible:** Yes
- **Value:** `2/1/2026, 12:00 AM`

### Parameter 2: pPeriodTo
- **Name:** `pPeriodTo`
- **Description:** `End Date`
- **Type:** `Date and Time`
- **Value:** `2/17/2026, 12:00 AM`

### Parameter 3: pQueueDns
- **Name:** `pQueueDns`
- **Description:** `Queue DN (e.g., 8077 or % for all)`
- **Type:** `String`
- **Value:** `8077`

### Parameter 4: pWaitInterval
- **Name:** `pWaitInterval`
- **Description:** `SLA Threshold`
- **Type:** `String`
- **Value:** `00:00:20`

### Expected Result
Field List shows:
```
? Parameters
    pPeriodFrom
    pPeriodTo
    pQueueDns
    pWaitInterval
```

Preview mode shows a **PREVIEW PARAMETERS** panel on the right with input fields for each parameter plus RESET and SUBMIT buttons.

---

## Step 13: Re-bind Data Source Parameters to Report Parameters ✅

Since the data source parameter values cannot be edited after creation through the UI, we need to **remove and re-create** each data source with parameter values pointing to the Report Parameters.

> ⚠️ **WHY THIS STEP IS NEEDED:** When we first created the data sources, we used hardcoded values like `#2026-02-01#`. Now that we have Report Parameters (pPeriodFrom, pPeriodTo, etc.), we need the data sources to use those parameters so the user can control the report from the PREVIEW PARAMETERS panel.
>
> ✅ **STATUS:** All 3 data sources re-created and re-bound successfully. Preview shows live data from the PREVIEW PARAMETERS panel.

### Step 13a: Remove Existing Data Sources

1. In the **Field List** panel, right-click **sqlDataSource1** → **"Remove Data Source"**
2. Right-click **sqlDataSource2** → **"Remove Data Source"**
3. Right-click **sqlDataSource3** → **"Remove Data Source"**

> **Note:** Removing data sources will break the existing bindings (KPI cards, chart, agent table). That's OK — we will re-bind everything after re-adding.

### Step 13b: Re-add sqlDataSource1 (KPIs) with Report Parameter Bindings ✅

1. Click **"+ Add Data Source"** → Database → Next
2. Choose **"3CX Exporter Production Database"** → Next
3. Select **"Stored Procedures"** → check ✅ **`sp_queue_kpi_summary_shushant`** → Next
4. Configure parameters — **this time use `?paramName` syntax** to reference report parameters:

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `?pPeriodFrom` |
   | `@period_to` | **Expression** | `?pPeriodTo` |
   | `@queue_dns` | **Expression** | `?pQueueDns` |
   | `@wait_interval` | **Expression** | `?pWaitInterval` |

   > **KEY SYNTAX:** The `?` prefix tells DevExpress to look up the Report Parameter by name. So `?pPeriodFrom` will use whatever the user enters in the "Start Date" field.

5. Click **Finish**

> **CONFIRMED WORKING:** The `?paramName` syntax works for **all 4 parameters** including `@wait_interval`. The Report Parameters' default values are used during schema discovery, so no schema rebuild error occurs.

### Step 13c: Re-add sqlDataSource2 (Chart Data) with Report Parameter Bindings ✅

1. Click **"+ Add Data Source"** → Database → Next
2. Choose **"3CX Exporter Production Database"** → Next
3. Select **"Stored Procedures"** → check ✅ **`sp_queue_calls_by_date_shushant`** → Next
4. Configure parameters:

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `?pPeriodFrom` |
   | `@period_to` | **Expression** | `?pPeriodTo` |
   | `@queue_dns` | **Expression** | `?pQueueDns` |
   | `@wait_interval` | **Expression** | `?pWaitInterval` |

5. Click **Finish**

### Step 13d: Re-add sqlDataSource3 (Agent Data) with Report Parameter Bindings ✅

1. Click **"+ Add Data Source"** → Database → Next
2. Choose **"3CX Exporter Production Database"** → Next
3. Select **"Stored Procedures"** → check ✅ **`qcall_cent_get_extensions_statistics_by_queues`** → Next
4. Configure parameters:

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `?pPeriodFrom` |
   | `@period_to` | **Expression** | `?pPeriodTo` |
   | `@queue_dns` | **Expression** | `?pQueueDns` |
   | `@wait_interval` | **Expression** | `?pWaitInterval` |

5. Click **Finish**

### Step 13e: Re-bind Report, Chart, and Agent Band ✅

After re-creating the data sources, re-attach them:

1. **Report (KPI cards):** Click on the report background → Properties → Data Source = `sqlDataSource1`, Data Member = `sp_queue_kpi_summary_shushant`

2. **Chart:** Click the chart → Properties panel → set **Data Source** = `sqlDataSource2`, **Data Member** = `sp_queue_calls_by_date_shushant`. Alternatively, click "Run Designer..." to verify series are still linked.

3. **AgentDetail band:** Select "AgentDetail (Detail Report)" from the Properties dropdown → Data Source = `sqlDataSource3`, Data Member = `qcall_cent_get_extensions_statistics_by_queues`

> **Note:** If chart series or cell bindings broke during the remove/re-add, re-bind them following Steps 9 and 11c.

### Step 13f: Update Filter Info Expressions ✅

Update `lblDateRange` expression to use the Report Parameters instead of hardcoded dates:
```
'Period: ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodFrom]) + ' - ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodTo])
```

Update `lblQueueFilter` expression:
```
'Queue DN: ' + [queue_dn] + ' - ' + [queue_display_name]
```

Update `lblSLAInfo` expression:
```
'SLA Threshold: ' + [Parameters.pWaitInterval]
```

> ✅ **Verified:** Filter info panel now shows dynamic values from the parameters:
> - "Queue DN: 8089 - Cedar wallboard queue-005"
> - "Period: Feb 01, 2026 - Feb 16, 2026"
> - "SLA Threshold: 00:00:20"

---

## Step 14: Final Preview & Verification ✅

1. Click **PREVIEW** (top-right of the Designer)
2. The **PREVIEW PARAMETERS** panel appears on the right with:
   - **Start Date:** `2/1/2026, 12:00 AM`
   - **End Date:** `2/17/2026, 12:00 AM`
   - **Queue DN:** `8089`
   - **SLA Threshold:** `00:00:20`
3. Click **SUBMIT**

### Expected Results

The report should render with all sections populated:

#### Header Section
- **Title:** "VoIPTools Customer Service"
- **Subtitle:** "Queue Performance Dashboard (Production)"
- **Filter Info:** Shows queue name, date range, SLA threshold from parameters

#### KPI Cards (8 cards in a row)
| Card | Label | Sample Value |
|------|-------|--------------|
| 1 | Total Calls | 130 |
| 2 | Answered | 7 |
| 3 | Abandoned | 123 |
| 4 | SLA % | 0.0% |
| 5 | Avg Talk | 00:07:39 |
| 6 | Total Talk | 00:53:33 |
| 7 | Avg Wait | 00:00:08 |
| 8 | Callbacks | 0 |

> *Values shown are for Queue 8089, Feb 01–17, 2026.*

#### Call Trends Chart
- **Type:** Area chart with two overlapping series
- **Green area:** Answered calls over time
- **Red area:** Abandoned calls over time
- **X-axis:** Dates (e.g., 02-02-2026, 03-02-2026, ...)
- **Legend:** Shows "Answered" and "Abandoned"

#### Agent Performance Table
- **Header row:** Agent | Answered Calls | Avg Answered | Avg Talk Time | Q Time | In Q%
- **Data rows:** One row per agent/extension, e.g.:
  - `1009 - mahesh danny V20 | 0 | 00:00:00 | 00:00:00 | - | -`
  - `1025 - Sowjanya Ghattamaneni V20 | 1 | 00:00:03 | 00:00:50 | - | -`
  - `1027 - Mahesh Linux V20 | 0 | 00:00:00 | 00:00:00 | - | -`

> **Q Time** and **In Q%** show `-` because the stored procedure does not return these fields.

### Test with Different Parameters

To verify parameters work dynamically:
1. Change **Queue DN** from `8089` to `8077`
2. Click **SUBMIT** again
3. Report should refresh with data for queue 8077 ("Global - 050")

---

## Issues & Fixes Log

| # | Issue | Cause | Fix |
|---|-------|-------|-----|
| 1 | Schema rebuild error on Finish | Date params set as "Expression" with plain date string (e.g., `2026-02-01`) | Use DevExpress date literal syntax: `#2026-02-01#` |
| 2 | `@wait_interval` can't be changed to Expression (initial setup) | Designer restricts `time` SQL type to Time/Expression only | Keep as **Time** type with value `00:00:20` for initial setup. When re-creating with `?pWaitInterval`, **Expression** type works fine. |
| 3 | `@period_from` Type dropdown shows only Object/Expression | `datetimeoffset` SQL type maps to Object in wizard | Use **Expression** type with `#date#` syntax |
| 4 | Cannot edit data source parameters after creation | DevExpress Designer UI does not allow modifying parameter values once a data source is created | **Remove** the data source entirely and **re-add** it with correct parameter bindings |
| 5 | Selected wrong band for AgentDetail | Two similar bands: "AgentDetail (DetailReportBand)" vs "AgentDetailBand (Detail)" | Always select **"AgentDetail (Detail Report)"** from the Properties dropdown — this is the parent container that has Data Source/Data Member properties |

---

## Reference: Report Structure

The final report will contain:

```
ReportHeader (height: 580)
├── lblTitle: "VoIPTools Customer Service"
├── lblSubtitle: "Queue Performance Dashboard (Production)"
├── pnlFilterInfo: Queue DN, Date Range, SLA info
├── lblReportDate: "Generated: MM-dd-yyyy hh:mm tt"
├── pnlCard1–pnlCard8: 8 KPI metric cards
│   ├── Card 1: Total Calls (blue accent)
│   ├── Card 2: Answered (green accent)
│   ├── Card 3: Abandoned (red accent)
│   ├── Card 4: SLA % (purple accent)
│   ├── Card 5: Avg Talk (blue accent)
│   ├── Card 6: Total Talk (orange accent)
│   ├── Card 7: Avg Wait (teal accent)
│   └── Card 8: Callbacks (green accent)
├── lblChartTitle: "Call Trends by Date"
├── chartTrends: Area chart (Answered + Abandoned series)
└── lblAgentTitle: "Agent Performance"

Detail Band (hidden)

AgentDetail (DetailReportBand)
├── AgentGroupHeader: Table header row
└── AgentDetailBand: Table data rows (agent stats)

PageFooter: Date/time + Page X of Y
```

## Data Sources Summary

| Data Source | Stored Procedure | Parameters | Used By |
|-------------|------------------|------------|--------|
| sqlDataSource1 | `sp_queue_kpi_summary_shushant` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pWaitInterval` | Report (KPI cards), Filter Info panel |
| sqlDataSource2 | `sp_queue_calls_by_date_shushant` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pWaitInterval` | Area chart (Answered + Abandoned) |
| sqlDataSource3 | `qcall_cent_get_extensions_statistics_by_queues` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pWaitInterval` | Agent performance table |

## Report Parameters Summary

| Parameter | Description | Type | Default Value |
|-----------|-------------|------|---------------|
| `pPeriodFrom` | Start Date | Date and Time | 2/1/2026, 12:00 AM |
| `pPeriodTo` | End Date | Date and Time | 2/17/2026, 12:00 AM |
| `pQueueDns` | Queue DN (e.g., 8077 or % for all) | String | 8089 |
| `pWaitInterval` | SLA Threshold | String | 00:00:20 |

---

## Guide Complete ✅

This report is fully functional with dynamic parameter binding. Users can:
1. Open the report in **Report Designer** (`/reportdesigner`) to modify layout or data sources
2. Open the report in **Report Viewer** (`/reportviewer`) to view and export
3. Use the **PREVIEW PARAMETERS** panel to filter by date range, queue, and SLA threshold
4. Export to PDF, Excel, or other formats from the viewer toolbar

### Key Takeaways
- **`?paramName`** syntax binds data source SP parameters to Report Parameters
- **All 4 SP parameters** can use Expression type with `?paramName` (including `@wait_interval`)
- Data sources **cannot be edited after creation** — remove and re-add if changes are needed
- Always select **"AgentDetail (Detail Report)"** (not "AgentDetailBand") when setting Data Source on the agent sub-report
