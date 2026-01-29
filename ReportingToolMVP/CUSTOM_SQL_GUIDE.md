# Custom SQL Guide for End Users

This guide explains how to create reports with custom SQL queries in the Report Designer.

## Quick Reference Links

| Topic | Documentation URL |
|-------|-------------------|
| **Report Parameters** | https://devexpress.github.io/dotnet-eud/reporting-for-web/articles/report-designer/use-report-parameters.html |
| **Bind Reports to Data** | https://devexpress.github.io/dotnet-eud/reporting-for-web/articles/report-designer/bind-to-data.html |
| **Reference Parameters** | https://docs.devexpress.com/XtraReports/402962/detailed-guide-to-devexpress-reporting/use-report-parameters/reference-report-parameters |
| **Data Binding Modes** | https://docs.devexpress.com/XtraReports/119236/detailed-guide-to-devexpress-reporting/use-expressions/data-binding-modes |
| **Expression Editor** | https://docs.devexpress.com/XtraReports/403357/detailed-guide-to-devexpress-reporting/use-expressions/expressions-overview |

---

## Part 1: Creating a New Report with Custom SQL

### Step 1: Open the Report Designer
1. Navigate to `/reportdesigner` in your browser
2. A blank report opens by default, or select an existing report

### Step 2: Add a SQL Data Source
1. In the **Field List** panel (right side), click the **+ (Add Data Source)** button
2. Select **SQL Data Source**
3. On the "Select data connection" page, choose **3CX_Exporter**
4. Click **Next**

### Step 3: Choose "Custom SQL" Query Type
1. On the "Create a query or select a stored procedure" page, you'll see options:
   - **Table** - Select from existing tables
   - **Custom SQL** - Write your own SQL query ← **Select this**
2. Click **Next**

### Step 4: Enter Your Custom SQL Query
Enter your SQL query in the Query Editor. Here are example queries:

**Simple Query (no parameters):**
```sql
SELECT q_num, time_start, ts_waiting, ts_servicing, reason_noanswercode
FROM callcent_queuecalls
WHERE time_start >= '2024-01-01'
```

**Query with Parameters (recommended):**
```sql
SELECT 
    q_num AS QueueNumber,
    COUNT(*) AS TotalCalls,
    AVG(DATEDIFF(SECOND, 0, ts_waiting)) AS AvgWaitSeconds
FROM callcent_queuecalls
WHERE q_num = @QueueNumber
  AND time_start BETWEEN @StartDate AND @EndDate
GROUP BY q_num
```

### Step 5: Configure SQL Parameters (Critical Step!)
If your query contains parameters (like `@QueueNumber`, `@StartDate`), you **must** configure them:

1. In the Query Editor, click **Configure Parameters** or the **Parameters** tab
2. For each parameter, set:
   - **Name**: Match exactly (e.g., `QueueNumber`)
   - **Type**: Choose **Expression** (not Constant or Value)
   - **Value**: Enter `[Parameters.YourReportParam]`

**Example Configuration:**
| Parameter Name | Type | Value |
|----------------|------|-------|
| QueueNumber | Expression | `[Parameters.paramQueueNumber]` |
| StartDate | Expression | `[Parameters.paramStartDate]` |
| EndDate | Expression | `[Parameters.paramEndDate]` |

> ⚠️ **Common Error**: If you see "Must declare the scalar variable @paramQueueNumber", your SQL parameter is not linked to a Report Parameter.

### Step 6: Finish the Data Source Wizard
1. Click **Finish** to complete the wizard
2. Your new data source appears in the Field List with the query fields

---

## Part 2: Creating Report Parameters

Report parameters allow users to filter data at runtime (e.g., select date range, queue number).

### Step 1: Add a Report Parameter
1. In the **Field List** panel, expand **Parameters**
2. Right-click **Parameters** → **Add Parameter**
3. Configure the parameter:
   - **Name**: `paramQueueNumber` (must match what you used in SQL)
   - **Description**: `Queue Number` (displayed to users)
   - **Type**: String (or appropriate type)
   - **Default Value**: `8000` (optional)

### Step 2: Add More Parameters as Needed
Create parameters for each SQL parameter:
- `paramStartDate` (DateTime type)
- `paramEndDate` (DateTime type)

---

## Part 3: Binding Data to Report Controls

### Option A: Drag and Drop (Easiest)
1. Expand your data source in the **Field List**
2. Drag a field (e.g., `QueueNumber`) onto the **Detail** band
3. A Label control is created automatically, bound to that field

### Option B: Use Expression Binding
1. Select a Label or other control
2. In **Properties** panel, go to the **Expressions** tab
3. Click the **...** button next to **Text**
4. In the Expression Editor, enter: `[QueueNumber]`

### Referencing Parameters in Expressions
To display a parameter value in a label:
- Expression: `[Parameters.paramQueueNumber]`
- Or in Text property: `Queue: [Parameters.paramQueueNumber]`

---

## Part 4: Understanding Binding Status Icons

When you bind data to controls, you may see status indicators:

| Icon | Color | Meaning |
|------|-------|---------|
| ✓ | Green | Valid binding - field exists in data source |
| X | Red/Yellow | Invalid binding - field not found |
| ⚠ | Yellow | Warning - possible issue with binding |

**How to fix a red X:**
1. Verify the data source is properly configured
2. Check that the field name matches exactly (case-sensitive)
3. Rebuild the data source schema if needed

---

## Part 5: Preview and Test

### Step 1: Preview the Report
1. Click the **Preview** tab in the Report Designer
2. If you have parameters, enter values in the **Parameters Panel**
3. Click **Submit** to generate the report

### Step 2: Troubleshooting Blank Reports
If Preview shows blank data:

1. **Check Parameters**: Ensure all required parameters have values
2. **Verify SQL**: Test your query in SSMS with actual values
3. **Check Data Member**: Ensure the report's Data Member property matches your query name
4. **Check Connection**: Verify the database connection is working

---

## Part 6: Complete Working Example

Here's a step-by-step example to create a "Queue Summary" report:

### 1. Create Report Parameters First
Add these parameters to the report:
- `paramStartDate` (DateTime, Default: Today - 30 days)
- `paramEndDate` (DateTime, Default: Today)

### 2. Add SQL Data Source
Use this query:
```sql
SELECT 
    q_num AS QueueNumber,
    CAST(time_start AS DATE) AS CallDate,
    COUNT(*) AS TotalCalls,
    SUM(CASE WHEN reason_noanswercode = 0 THEN 1 ELSE 0 END) AS AnsweredCalls,
    AVG(DATEDIFF(SECOND, 0, ts_waiting)) AS AvgWaitSeconds
FROM [dbo].[callcent_queuecalls]
WHERE time_start BETWEEN @StartDate AND @EndDate
GROUP BY q_num, CAST(time_start AS DATE)
ORDER BY q_num, CallDate
```

### 3. Configure Query Parameters
| SQL Parameter | Type | Expression Value |
|---------------|------|------------------|
| StartDate | Expression | `[Parameters.paramStartDate]` |
| EndDate | Expression | `[Parameters.paramEndDate]` |

### 4. Design the Report Layout
1. Add a **GroupHeader** band, group by `QueueNumber`
2. Add labels bound to data fields in the **Detail** band
3. Add a **GroupFooter** for summary calculations

### 5. Save and Preview
1. Save the report with a descriptive name
2. Preview and test with different date ranges

---

## Common Issues and Solutions

### Error: "Must declare the scalar variable @paramName"
**Cause**: SQL parameter not linked to Report Parameter
**Solution**: In Query Parameters, set Type to "Expression" and Value to `[Parameters.yourParam]`

### Error: "Invalid data member 'FieldName'"
**Cause**: Report is bound to a field that doesn't exist in the data source
**Solution**: 
1. Remove the invalid binding
2. Rebuild the data source schema
3. Re-bind to a valid field

### Blank Preview / No Data
**Cause**: Query returns no rows or parameters have invalid values
**Solution**:
1. Test SQL in SSMS with actual parameter values
2. Check parameter default values
3. Verify date formats match your data

### Yellow X Next to Data Member
**Cause**: Data source schema doesn't match the report bindings
**Solution**:
1. Right-click the data source → **Rebuild Schema**
2. Or re-create the data source with correct query

---

## Best Practices

1. **Always test SQL in SSMS first** before adding to Report Designer
2. **Use parameters** for date ranges and filters (more flexible)
3. **Name parameters clearly** with a prefix like `param` (e.g., `paramStartDate`)
4. **Save frequently** while designing reports
5. **Use GROUP BY** for summary reports to reduce row count
6. **Add WHERE clauses** to limit data and improve performance

---

## Available Database Tables

The 3CX database contains these key tables for reporting:

| Table | Description |
|-------|-------------|
| `callcent_queuecalls` | Queue call records with wait times, servicing times |
| `callcent_ag_dropped_calls` | Agent dropped calls |
| `callcent_ag_queuestatus` | Agent queue status |
| `queue` | Queue definitions (names) |
| `dn` | Phone extensions |
| `users` | User information |
| `callhistory3` | General call history |

### Key Columns in callcent_queuecalls
- `q_num` - Queue number (e.g., "8000")
- `time_start` - Call start time
- `time_end` - Call end time
- `ts_waiting` - Time spent waiting
- `ts_servicing` - Time spent being serviced
- `reason_noanswercode` - 0 = answered, other = unanswered
- `to_dn` - Agent/destination that answered
