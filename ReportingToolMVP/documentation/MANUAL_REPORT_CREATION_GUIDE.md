# Manual Report Creation Guide
## VoIPTools Customer Service – Queue Performance Dashboard

> **Purpose:** Complete step-by-step guide to manually create a Queue Performance Dashboard report using the DevExpress Report Designer UI. This guide walks through creating all three data sources, binding KPI cards, configuring the area chart, setting up the agent performance table, and connecting everything to dynamic Report Parameters.  
> **Audience:** End users with access to the Report Designer. No coding required.  
> **Time:** Approximately 30-45 minutes for first-time creation.  
> **Last Updated:** February 18, 2026

---

## What You Will Build

By following this guide, you will create a report with three sections:

```
┌─────────────────────────────────────────────────────────────────┐
│  HEADER                                                         │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Title: "VoIPTools Customer Service"                        │ │
│  │ Subtitle: "Queue Performance Dashboard (Production)"       │ │
│  │ Filter Info: Queue DN, Date Range, SLA Threshold           │ │
│  │ Generated: Date/Time stamp                                 │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │ │
│  │ │Total │ │Answ'd│ │Aband.│ │SLA % │ │AvgTk │ │TotTk │  │ │
│  │ │Calls │ │      │ │      │ │      │ │      │ │      │  │ │
│  │ │ 487  │ │ 435  │ │  52  │ │87.4% │ │01:45 │ │12:45 │  │ │
│  │ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘  │ │
│  │ ┌──────┐ ┌──────┐                                        │ │
│  │ │AvgWt │ │Callbk│    ← 8 KPI cards from SP1             │ │
│  │ │00:23 │ │  0   │                                        │ │
│  │ └──────┘ └──────┘                                        │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ CALL TRENDS BY DATE (Area Chart)                          │ │
│  │ ▄▄▄▄█████▄▄▄▄                                            │ │
│  │ ▀▀▀▄▄▄▄▄▀▀▀▀  ← Two area series from SP2               │ │
│  │ Green = Answered, Red = Abandoned                         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  AGENT PERFORMANCE TABLE (from SP3)                             │
│  ┌────────────┬───────┬──────┬──────┬──────┬──────┐            │
│  │ Agent      │Ans'd  │AvgAns│AvgTk │QTime │InQ%  │            │
│  ├────────────┼───────┼──────┼──────┼──────┼──────┤            │
│  │ 1001-John  │  45   │00:08 │01:51 │  -   │  -   │            │
│  │ 1002-Jane  │  38   │00:06 │01:50 │  -   │  -   │            │
│  └────────────┴───────┴──────┴──────┴──────┴──────┘            │
│                                                                 │
│  FOOTER: Generated date + Page X of Y                           │
└─────────────────────────────────────────────────────────────────┘
```

Each section uses a different stored procedure:
- **KPI Cards** → `sp_queue_stats_summary` (returns 1 aggregated row)
- **Area Chart** → `sp_queue_stats_daily_summary` (returns 1 row per day)
- **Agent Table** → `qcall_cent_get_extensions_statistics_by_queues` (returns 1 row per agent per queue)

The KPI and Chart SPs share 5 parameters (`@from`, `@to`, `@queue_dns`, `@sla_seconds`, `@report_timezone`). The Agent SP uses 4 parameters (`@period_from`, `@period_to`, `@queue_dns`, `@wait_interval`). All become user inputs in the report's PREVIEW panel via 6 Report Parameters.

---

## Prerequisites

Before starting, ensure:

- **Application is running** at `https://localhost:7209` (see DEVELOPER_GUIDE.md for setup)
- **Report Designer is accessible** at `/reportdesigner`
- **Database connection works** — the Designer must connect to the `3CX Exporter` database
  - Server: `3.132.72.134`
  - Database: `3CX Exporter`
  - Credentials: User `sa`, Password `V01PT0y5`
- **Stored procedures are deployed** — all three SPs must exist in the database
- **An existing report template** (e.g., `Similar_to_samuel_sirs_report`) should exist as a reference. You can open it in the Designer to compare your progress at any point.

> **Tip:** Open the existing production report side-by-side in a separate browser tab for reference while following this guide.

## Stored Procedures Used

| SP Name | Purpose | Report Section | Output |
|---------|---------|----------------|--------|
| `sp_queue_stats_summary` | KPI summary metrics | 8 KPI cards + filter info | Always 1 row |
| `sp_queue_stats_daily_summary` | Daily call volume breakdown | Area chart (Answered vs Abandoned) | 1 row per day |
| `qcall_cent_get_extensions_statistics_by_queues` | Per-agent answered call stats | Agent performance table | 1 row per agent per queue |

### SP Parameter Types

**KPI & Chart SPs** (`sp_queue_stats_summary`, `sp_queue_stats_daily_summary`) share these 5 parameters:

| Parameter | SQL Type | Description | Example Value |
|-----------|----------|-------------|---------------|
| `@from` | `datetimeoffset` | Report start date (inclusive) | `2026-02-01 00:00:00` |
| `@to` | `datetimeoffset` | Report end date (inclusive) | `2026-02-17 00:00:00` |
| `@queue_dns` | `varchar(max)` | Queue DN filter — comma-separated like `8000,8089` | `8000,8089` |
| `@sla_seconds` | `int` | SLA threshold in seconds | `20` |
| `@report_timezone` | `varchar(100)` | Timezone for date display (from `sys.time_zone_info`) | `India Standard Time` |

**Agent SP** (`qcall_cent_get_extensions_statistics_by_queues`) uses these 4 parameters:

| Parameter | SQL Type | Description | Example Value |
|-----------|----------|-------------|---------------|
| `@period_from` | `datetimeoffset` | Report start date (inclusive) | `2026-02-01 00:00:00` |
| `@period_to` | `datetimeoffset` | Report end date (inclusive) | `2026-02-17 00:00:00` |
| `@queue_dns` | `varchar(max)` | Queue DN filter — comma-separated | `8000,8089` |
| `@wait_interval` | `time` | Exclude calls dropped before this interval | `00:00:20` (20 seconds) |

> **Important:** See `SQL_REFERENCE.md` for complete documentation on what each SP does, how the CTEs work, and what each output column means.

---

## Step 1: Create a New Report

1. Navigate to `https://localhost:7209/reportdesigner`
2. Click **"+"** or create a new report
3. Name it (e.g., `Similar to samuel sirs report manualtest_2`)
4. The designer opens with an empty report canvas

---

## Step 2: Add Data Source – KPI Summary

This data source powers the KPI cards (Total Calls, Answered, Abandoned, SLA%, Avg Talk, Total Talk, Avg Wait, Callbacks). It connects to the `sp_queue_stats_summary` stored procedure, which returns a **single aggregated row** with all the metrics.

> **Why this is the first data source:** The KPI SP returns exactly 1 row. We assign it as the report's "main" data source so that all labels in the ReportHeader band can directly reference its fields (like `[total_calls]`, `[answered_calls]`). The chart and agent table will use their own separate data sources.

1. In the **Field List** panel (right side), click **"+ Add Data Source"**
2. Select **"Database"** → click Next
3. On the **"Specify Data Source Settings"** page:

### Section 1 – Choose a data connection
- Select **"3CX Exporter Production Database (LIVE DATA)"**

### Section 2 – Choose stored procedure
- Expand **"Stored Procedures"**
- Check ✅ **`sp_queue_stats_summary(@from, @to, @queue_dns, @sla_seconds, @report_timezone)`**

### Section 4 – Configure query parameters

> **IMPORTANT:** The parameter Type dropdown varies depending on the SQL data type. Use the settings below exactly. The Designer executes the stored procedure during this step to discover the output columns — if parameters have wrong types or values, you'll get a schema error.

| Parameter | Type | Value | Why This Setting |
|-----------|------|-------|------------------|
| `@from` | **Expression** | `?pPeriodFrom` | Binds to Report Parameter for dynamic filtering |
| `@to` | **Expression** | `?pPeriodTo` | Binds to Report Parameter for dynamic filtering |
| `@queue_dns` | **Expression** | `?pQueueDns` | Binds to Report Parameter for dynamic filtering |
| `@sla_seconds` | **Expression** | `?pSlaSeconds` | Binds to Report Parameter (integer → SLA in seconds) |
| `@report_timezone` | **Expression** | `?pReportTimezone` | Binds to Report Parameter (timezone name) |

> **Understanding `?paramName` Syntax:**
> - The `?` prefix tells DevExpress to look up the Report Parameter by name.
> - So `?pPeriodFrom` will use whatever the user enters in the "Start Date" field.
> - The Report Parameters' default values are used during schema discovery.
> - All parameters use **Expression** type because `?paramName` is a DevExpress expression.

### Common Error
❌ **"An error occurred while rebuilding a data source schema"**
- **Cause:** Parameters set with wrong type or empty values. The designer must execute the SP to discover output columns.
- **Fix:** Ensure Report Parameters exist with valid default values BEFORE adding the data source. The `?paramName` references need working defaults.

4. Click **Finish**

### Expected Result
After finishing, the Field List should show:
```
▸ sqlDataSource1
    ▸ sp_queue_stats_summary
        queue_group
        description
        total_calls
        abandoned_calls
        answered_calls
        answered_percent
        answered_within_sla
        answered_within_sla_percent
        serviced_callbacks
        total_talking
        mean_talking_time
        avg_wait_time
        longest_wait_time
        period_from_utc
        period_to_utc
        period_from_local
        period_to_local
        report_timezone_used
  ? Parameters
```

---

## Step 3: Assign Data Source to the Report

This step tells the entire report to use the KPI data source as its "default" data source. This is required for the KPI card labels and filter info panel to access fields like `[total_calls]`, `[queue_dn]`, etc.

> **How DevExpress data binding works:** A DevExpress report has a hierarchy of bands. The "Report" level is the outermost container. When you set a Data Source on the Report itself, all bands inside it (ReportHeader, Detail, etc.) can reference fields from that data source using `[field_name]` expressions. Sub-reports (like the Agent DetailReportBand) can override this with their own data source.

1. Click on the **report surface background** (not on any control) — or click **"Report"** at the top of the Report Explorer
2. In the **Properties panel** (right side, click the gear ⚙️ icon if not visible), find:
   - **Data Source** → select **`sqlDataSource1`**
   - **Data Member** → select **`sp_queue_stats_summary`**

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
| pnlCard5 | pnlCard5Value | `[mean_talking_time]` | Avg Talk |
| pnlCard6 | pnlCard6Value | `[total_talking]` | Total Talk |
| pnlCard7 | pnlCard7Value | `[avg_wait_time]` | Avg Wait |
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
   'Queue: ' + [description]
   ```
   > **Note:** The new `sp_queue_stats_summary` returns a `description` field that combines queue DN and display name (e.g., `"8089 - Cedar wallboard queue-005"`). The old SP returned separate `queue_dn` and `queue_display_name` fields.
4. Click **OK**

5. **Click `lblDateRange`** → set Text expression:
   ```
   'Period: ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodFrom]) + ' - ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodTo])
   ```

6. **Click `lblSLAInfo`** → set Text expression:
   ```
   'SLA Threshold: ' + ToStr([Parameters.pSlaSeconds]) + ' seconds'
   ```

> **Note:** Since Report Parameters are created before data sources (Step 2), the filter info labels can reference `[Parameters.pPeriodFrom]`, `[Parameters.pPeriodTo]`, and `[Parameters.pSlaSeconds]` directly. No need for hardcoded values.

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
4. Select **"Stored Procedures"** → check ✅ **`sp_queue_stats_daily_summary(@from, @to, @queue_dns, @sla_seconds, @report_timezone)`** → Next
5. Configure parameters (same pattern as Step 2 — all use Expression type with `?paramName`):

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@from` | **Expression** | `?pPeriodFrom` |
   | `@to` | **Expression** | `?pPeriodTo` |
   | `@queue_dns` | **Expression** | `?pQueueDns` |
   | `@sla_seconds` | **Expression** | `?pSlaSeconds` |
   | `@report_timezone` | **Expression** | `?pReportTimezone` |

6. Click **Finish**

### Expected Result
Field List shows `sqlDataSource2` with fields:
- `report_date_local`, `total_calls`, `answered_calls`, `abandoned_calls`, `answered_percent`, `answered_within_sla`, `answered_within_sla_percent`, `total_talking`, `mean_talking_time`, `avg_wait_time`, `longest_wait_time`, `period_from_utc`, `period_to_utc`, `report_timezone_used`

---

## Step 9: Bind the Chart to sqlDataSource2

The chart displays call trends over time. It needs two "series" (data lines): one for answered calls and one for abandoned calls, both plotted against dates.

> **How DevExpress charts work in reports:** An `XRChart` control has its OWN data source (separate from the report's main data source). You assign a data source and data member, then create "series" that map columns to axes. The X-axis (Argument) is typically a date, and the Y-axis (Value) is a numeric column.

1. **Click on the chart** (the big empty box labeled "There are no visible series in the chart")
2. Click **"Run Designer..."** button (appears in the top-right corner of the chart when selected)
3. In the Chart Designer dialog:
   - Set **Data Source** = `sqlDataSource2`
   - Set **Data Member** = `sp_queue_stats_daily_summary`

4. **Add Series 1 — Answered Calls:**
   - Click **"+"** to add a new series
   - **Series Type:** Area (fills the space under the line with a semi-transparent color)
   - **Name:** `Answered`
   - **Argument Data Member:** `report_date_local` (this becomes the X-axis — dates)
   - **Value Data Member:** `answered_calls` (this becomes the Y-axis — count)
   - **Color:** Green (`#2ecc71` or similar)

5. **Add Series 2 — Abandoned Calls:**
   - Click **"+"** to add another series
   - **Series Type:** Area
   - **Name:** `Abandoned`
   - **Argument Data Member:** `report_date_local` (same X-axis as above — both series share dates)
   - **Value Data Member:** `abandoned_calls`
   - **Color:** Red (`#e74c3c` or similar)

6. Click **OK** to close the Chart Designer

> **Tip:** The chart preview in the designer should immediately show 2 overlapping area series with real data. If the chart appears blank after clicking OK, check that both the Data Source AND Data Member are set correctly. A common mistake is setting the Data Source but forgetting the Data Member.

> **How the chart reads data:** The SP returns rows like:
> ```
> report_date_local | answered_calls | abandoned_calls
> 2026-02-01        | 15             | 3
> 2026-02-02        | 22             | 5
> 2026-02-03        | 18             | 2
> ```
> The chart plots each row as a point: X = report_date_local, Y = answered_calls (green) and Y = abandoned_calls (red). The Area type fills between the line and the X-axis.

---

## Step 10: Add Data Source – Agent Performance

This data source powers the Agent Performance table.

1. Click **"+ Add Data Source"** in the Field List panel
2. Select **"Database"** → Next
3. Choose **"3CX Exporter Production Database"** connection → Next
4. Select **"Stored Procedures"** → check ✅ **`qcall_cent_get_extensions_statistics_by_queues`** → Next
5. Configure parameters (**Agent SP uses different parameter names** from the KPI/Chart SPs):

   | Parameter | Type | Value |
   |-----------|------|-------|
   | `@period_from` | **Expression** | `?pPeriodFrom` |
   | `@period_to` | **Expression** | `?pPeriodTo` |
   | `@queue_dns` | **Expression** | `?pQueueDns` |
   | `@wait_interval` | **Expression** | `?pWaitInterval` |

   > **Note:** The Agent SP uses `@period_from`/`@period_to` (not `@from`/`@to` like the KPI/Chart SPs) and `@wait_interval` (not `@sla_seconds`). This is because the Agent SP is a different, older stored procedure.

6. Click **Finish**

### Expected Result
Field List shows `sqlDataSource3` with fields:
- `avg_answer_time`, `avg_talk_time`, `extension_answered_count`, `extension_display_name`, `extension_dn`, `queue_display_name`, `queue_dn`, `queue_received_count`, `talk_time`

---

## Step 11: Bind AgentDetail Band to sqlDataSource3

### Step 11a: Set Data Source on the AgentDetail Band

> **Understanding the Band Hierarchy:**
> ```
> Report (main data source = sqlDataSource1 for KPIs)
> ├── ReportHeader (uses report's data source → KPI fields available)
> ├── Detail Band (hidden)
> └── AgentDetail (DetailReportBand) ← THIS NEEDS ITS OWN DATA SOURCE
>     ├── GroupHeaderBand (table headers — repeats every page)
>     └── AgentDetailBand (Detail) ← renders one row per agent
> ```
> The `AgentDetail` band is a **DetailReportBand** — a special sub-report container that has its OWN data source. This is how one report can show data from multiple stored procedures: the outer report uses SP1 (KPIs), and the inner DetailReportBand uses SP3 (agents).

> ⚠️ **COMMON MISTAKE:** There are TWO bands with similar names:
> - **AgentDetail (DetailReportBand)** — the parent container. **This is the one you need.**
> - **AgentDetailBand (Detail)** — the inner band for placing cells. This one does NOT have Data Source properties.
>
> In the Properties dropdown at the top-right, make sure you select the one labeled "(Detail Report)", not "(Detail)".

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

> **IMPORTANT:** Report Parameters MUST be created BEFORE adding data sources, because the data source wizard steps (Steps 2, 8, 10) use `?paramName` syntax that references these parameters. The default values are used during schema discovery.

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
- **Description:** `Wait Interval (Agent SP)`
- **Type:** `String`
- **Value:** `00:00:20`

### Parameter 5: pSlaSeconds
- **Name:** `pSlaSeconds`
- **Description:** `SLA Threshold (seconds)`
- **Type:** `Number (Int32)`
- **Visible:** Yes
- **Value:** `20`

### Parameter 6: pReportTimezone
- **Name:** `pReportTimezone`
- **Description:** `Report Timezone`
- **Type:** `String`
- **Value:** `India Standard Time`

> **Note:** `pWaitInterval` is a **time string** (e.g., `00:00:20`) used only by the Agent SP. `pSlaSeconds` is an **integer** (e.g., `20`) used by the KPI and Chart SPs. They represent similar concepts but in different formats for different stored procedures.

### Expected Result
Field List shows:
```
? Parameters
    pPeriodFrom
    pPeriodTo
    pQueueDns
    pWaitInterval
    pSlaSeconds
    pReportTimezone
```

Preview mode shows a **PREVIEW PARAMETERS** panel on the right with input fields for each parameter plus RESET and SUBMIT buttons.

---

## Step 13: Verify Data Source Parameter Bindings

Since we created Report Parameters (Step 12) **before** adding data sources, all three data sources were configured with `?paramName` bindings from the start. No re-binding is needed.

### Verify the Binding Chain

The binding chain works like this:
```
User types "2026-02-01" in Preview panel
  → Report Parameter pPeriodFrom = 2026-02-01
    → Data Source Parameter @from = ?pPeriodFrom
      → SQL Server receives: @from = '2026-02-01'
        → SP filters data for that date range
```

### Checklist

Verify each data source has the correct parameter bindings by clicking on it in the Field List:

**sqlDataSource1 (KPI Summary — `sp_queue_stats_summary`):**
| SP Parameter | Bound To |
|-------------|----------|
| `@from` | `?pPeriodFrom` |
| `@to` | `?pPeriodTo` |
| `@queue_dns` | `?pQueueDns` |
| `@sla_seconds` | `?pSlaSeconds` |
| `@report_timezone` | `?pReportTimezone` |

**sqlDataSource2 (Chart — `sp_queue_stats_daily_summary`):**
| SP Parameter | Bound To |
|-------------|----------|
| `@from` | `?pPeriodFrom` |
| `@to` | `?pPeriodTo` |
| `@queue_dns` | `?pQueueDns` |
| `@sla_seconds` | `?pSlaSeconds` |
| `@report_timezone` | `?pReportTimezone` |

**sqlDataSource3 (Agents — `qcall_cent_get_extensions_statistics_by_queues`):**
| SP Parameter | Bound To |
|-------------|----------|
| `@period_from` | `?pPeriodFrom` |
| `@period_to` | `?pPeriodTo` |
| `@queue_dns` | `?pQueueDns` |
| `@wait_interval` | `?pWaitInterval` |

> **Note:** If you need to change parameter bindings after creation, DevExpress does not allow editing data source parameters in the UI. You must **remove** the data source and **re-add** it with the correct `?paramName` values.

### Verify Report/Chart/Agent Band Assignments

1. **Report (KPI cards):** Click report background → Properties → Data Source = `sqlDataSource1`, Data Member = `sp_queue_stats_summary`
2. **Chart:** Click chart → Run Designer → Data Source = `sqlDataSource2`, Data Member = `sp_queue_stats_daily_summary`
3. **AgentDetail band:** Select "AgentDetail (Detail Report)" from Properties dropdown → Data Source = `sqlDataSource3`, Data Member = `qcall_cent_get_extensions_statistics_by_queues`

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

## Step 15: Add Page Footer (Date/Time + Page Numbers)

1. **Add the PageFooter band** (if not already present):
   - Right-click on the report design surface → **Insert Band** → **PageFooter**

2. **Add Current Date/Time** (left side of footer):
   - From the **Toolbox**, drag an **XRPageInfo** control into the left side of the **PageFooter** band
   - In **Properties**, set:
     - **Page Information** → `DateTime`
     - **Format String** → click `...` → enter `{0:MMM dd, yyyy hh:mm tt}`
     - **Text Alignment** → `TopLeft`
     - Adjust **Font** and **Size** as needed

3. **Add Page Numbers** (right side of footer):
   - Drag another **XRPageInfo** control into the right side of the **PageFooter** band
   - In **Properties**, set:
     - **Page Information** → `NumberOfTotal`
     - **Format String** → click `...` → enter `Page {0} of {1}`
     - **Text Alignment** → `TopRight`

4. **Save** the report (Ctrl+S)

> **Note:** Both controls use the **XRPageInfo** type — just with different `Page Information` property values.

---

## Issues & Fixes Log

| # | Issue | Cause | Fix |
|---|-------|-------|-----|
| 1 | Schema rebuild error on Finish | SP parameters have wrong types or empty values | Ensure Report Parameters exist with valid default values BEFORE adding data sources. Use **Expression** type for all `?paramName` bindings. |
| 2 | `@wait_interval` shows as Time type | Designer infers SQL `time` type as Time dropdown | Use **Expression** type (not Time) when binding with `?pWaitInterval`. |
| 3 | Cannot edit data source parameters after creation | DevExpress Designer UI does not allow modifying parameter values once a data source is created | **Remove** the data source entirely and **re-add** it with correct parameter bindings |
| 4 | Selected wrong band for AgentDetail | Two similar bands: "AgentDetail (DetailReportBand)" vs "AgentDetailBand (Detail)" | Always select **"AgentDetail (Detail Report)"** from the Properties dropdown — this is the parent container that has Data Source/Data Member properties |
| 5 | Chart series bindings lost after save | DevExpress `SaveLayoutToXml()` strips `ArgumentDataMember` and `ValueDataMembersSerializable` from chart series when the SqlDataSource schema can't be validated at serialization time | **Fixed in code** — `FileReportStorageService.SetData()` now captures chart bindings before serialization and post-processes the XML to restore them. No user action required. |

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
| sqlDataSource1 | `sp_queue_stats_summary` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pSlaSeconds`, `?pReportTimezone` | Report (KPI cards), Filter Info panel |
| sqlDataSource2 | `sp_queue_stats_daily_summary` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pSlaSeconds`, `?pReportTimezone` | Area chart (Answered + Abandoned) |
| sqlDataSource3 | `qcall_cent_get_extensions_statistics_by_queues` | `?pPeriodFrom`, `?pPeriodTo`, `?pQueueDns`, `?pWaitInterval` | Agent performance table |

## Report Parameters Summary

| Parameter | Description | Type | Default Value |
|-----------|-------------|------|---------------|
| `pPeriodFrom` | Start Date | Date and Time | 2/1/2026, 12:00 AM |
| `pPeriodTo` | End Date | Date and Time | 2/17/2026, 12:00 AM |
| `pQueueDns` | Queue DN (e.g., 8077 or % for all) | String | 8077 |
| `pWaitInterval` | Wait Interval (Agent SP) | String | 00:00:20 |
| `pSlaSeconds` | SLA Threshold (seconds) | Number (Int32) | 20 |
| `pReportTimezone` | Report Timezone | String | India Standard Time |

---

## Guide Complete

This report is fully functional with dynamic parameter binding. Here's what you can do with it:

### Using the Report

1. **Design/Edit:** Open `/reportdesigner` → select the report → modify layout, data sources, or formatting
2. **View/Export:** Open `/reportviewer` → select the report from the dropdown → enter parameters → Submit
3. **Filter:** Use the PREVIEW PARAMETERS panel to filter by date range, queue, and SLA threshold
4. **Export:** From the viewer toolbar, click the export icon to save as:
   - **PDF** — for printing or email distribution
   - **Excel (XLSX)** — for further data analysis
   - **CSV** — for importing into other systems
   - **HTML** — for web embedding
   - **RTF/DOCX** — for Word document editing
   - **Image (PNG/TIFF)** — for presentations

### Saving Your Report

When you click **Save** in the Designer:
- If it's a new report, you'll be prompted for a name. Use descriptive names (e.g., `Queue_Performance_Q1_2026`)
- The report is saved as a `.repx` file in the `Reports/Templates/` folder on the server
- The report immediately appears in the Report Viewer dropdown

### Key Takeaways

- **`?paramName`** syntax binds data source SP parameters to Report Parameters
- **All SP parameters** can use Expression type with `?paramName`
- **Create Report Parameters FIRST** (Step 12) before adding data sources, so `?paramName` references resolve during schema discovery
- Data sources **cannot be edited after creation** — remove and re-add if changes are needed
- KPI and Chart SPs use `@from`, `@to`, `@queue_dns`, `@sla_seconds`, `@report_timezone`
- Agent SP uses `@period_from`, `@period_to`, `@queue_dns`, `@wait_interval` (different parameter names!)
- Always select **"AgentDetail (Detail Report)"** (not "AgentDetailBand") when setting Data Source on the agent sub-report
- The chart requires both **Data Source** and **Data Member** to be set — missing either results in a blank chart
- Always preview with different parameter values to verify the report works dynamically

### Creating Variations

To create a new report based on this template:
1. Open the existing report in the Designer
2. Click **"Save As"** to save with a new name
3. Modify as needed (change layout, add/remove cards, adjust chart type, etc.)
4. All data source bindings carry over — you don't need to redo the parameter setup

---

## Troubleshooting

### Common Errors and Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| "An error occurred while rebuilding a data source schema" | SP parameters have wrong types or empty values | Use exactly the types shown in this guide: Expression for dates/strings, Time for `@wait_interval`. Date values must use `#date#` syntax. |
| Chart appears blank after binding | Missing DataMember property on the chart | Click the chart → Properties → verify both Data Source AND Data Member are set. Data Member should be the SP name (e.g., `sp_queue_stats_daily_summary`). |
| KPI cards show field names instead of values | Data Source not set on the Report itself | Click the report background → Properties → set Data Source = sqlDataSource1, Data Member = `sp_queue_stats_summary`. |
| Agent table shows no data rows | Data Source set on wrong band | Verify you set Data Source on "AgentDetail (Detail Report)", NOT on "AgentDetailBand (Detail)". |
| Preview shows all zeros / empty | Using hardcoded dates outside available data range | Check that your date parameters fall within the data range in the database. Try a known range. |
| "Cannot find connection" error | Connection name in .repx doesn't match any registered connection | Verify `ReportDataSourceProviders.cs` has the connection name registered in `LoadConnection()`. |
| Parameters panel doesn't appear in Preview | Report Parameters not marked as Visible | Check each parameter's Visible property is set to Yes/True. |
| `@wait_interval` won't accept `?pWaitInterval` | Used Time type during re-bind instead of Expression | When creating data sources, set `@wait_interval` type to **Expression** (not Time). The `?` syntax requires Expression type. |

### Tips for Success

1. **Save often** — use Ctrl+S or the Save button after completing each major step
2. **Preview after each binding** — catch errors early rather than debugging everything at the end
3. **Use the Report Explorer** — the tree view (left panel) is the most reliable way to find and select controls, especially when the visual canvas is crowded
4. **Check the Properties dropdown** — the dropdown at the top of the Properties panel shows which control is currently selected. Always verify before changing properties.
5. **Right-click for context menus** — many actions (Insert Band, Add Column, etc.) are available through right-click menus that aren't visible in the toolbar

---

*End of Manual Report Creation Guide*
