# DevExpress Components Used in VoIPTools Report Builder

This document tracks all DevExpress Blazor components used in the project.

## Package Reference
```xml
<PackageReference Include="DevExpress.Blazor" Version="25.1.6" />
```

## Theme
- **Theme:** Blazing Berry (BS5)
- **Location:** `_content/DevExpress.Blazor.Themes/blazing-berry.bs5.min.css`

---

## Components Used

### 1. DxDateEdit
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Date range selection for report filtering
**Properties Used:**
- `@bind-Date` - Two-way binding for date value
- `Format` - Display format (dd-MM-yyyy)
- `CssClass` - Custom styling
- `ClearButtonDisplayMode` - Hide clear button

```razor
<DxDateEdit @bind-Date="@Config.StartDate" 
            Format="dd-MM-yyyy"
            CssClass="dx-date-input"
            ClearButtonDisplayMode="DataEditorClearButtonDisplayMode.Never" />
```

---

### 2. DxListBox
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Multi-select lists for Queues and Columns
**Properties Used:**
- `Data` - Data source
- `@bind-Values` - Selected values binding
- `TextFieldName` / `ValueFieldName` - Field mappings
- `SelectionMode` - Multiple selection
- `ShowCheckboxes` - Display checkboxes

```razor
<DxListBox Data="@AvailableQueues"
           @bind-Values="@SelectedQueues"
           TextFieldName="QueueName"
           ValueFieldName="QueueId"
           SelectionMode="ListBoxSelectionMode.Multiple"
           ShowCheckboxes="true"
           CssClass="dx-listbox-queues" />
```

---

### 3. DxComboBox
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Dropdown for chart type and axis selection
**Properties Used:**
- `Data` - Data source
- `@bind-Value` - Selected value binding
- `NullText` - Placeholder text
- `CssClass` - Custom styling

```razor
<DxComboBox Data="@ChartTypes"
            @bind-Value="@Config.ChartType"
            CssClass="dx-combo-chart" />
```

---

### 4. DxButton
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Action buttons throughout the UI
**Properties Used:**
- `Text` - Button label
- `Click` - Click handler
- `RenderStyle` - Visual style (Primary, Secondary, Success, Info, Warning, Light)
- `SizeMode` - Button size
- `IconCssClass` - Icon class
- `Enabled` - Enable/disable state
- `CssClass` - Custom styling

```razor
<DxButton Text="Refresh Report"
          Click="@RefreshReport"
          RenderStyle="ButtonRenderStyle.Primary"
          CssClass="w-100"
          IconCssClass="oi oi-reload"
          Enabled="@(!IsLoading)" />
```

---

### 5. DxGrid
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Data grid for displaying report results
**Properties Used:**
- `Data` - Data source
- `ShowFilterRow` - Enable filtering
- `ShowGroupPanel` - Enable grouping
- `ColumnResizeMode` - Column resizing behavior
- `PageSize` - Rows per page
- `PagerVisible` - Show pagination
- `PagerNavigationMode` - Pagination style

**Sub-components:**
- `DxGridDataColumn` - Data columns with FieldName and Caption

```razor
<DxGrid Data="@ReportData"
        ShowFilterRow="true"
        ShowGroupPanel="true"
        ColumnResizeMode="GridColumnResizeMode.NextColumn"
        CssClass="report-grid"
        PageSize="50"
        PagerVisible="true"
        PagerNavigationMode="PagerNavigationMode.NumericButtons">
    <Columns>
        @foreach (var col in SelectedColumnsList)
        {
            <DxGridDataColumn FieldName="@col" Caption="@FormatColumnName(col)" />
        }
    </Columns>
</DxGrid>
```

---

### 6. DxChart (Bar & Line Charts)
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Data visualization with bar and line charts
**Properties Used:**
- `Data` - Chart data source
- `CssClass` - Custom styling

**Sub-components:**
- `DxChartBarSeries` - Bar chart series
- `DxChartLineSeries` - Line chart series
- `DxChartLegend` - Chart legend

```razor
<DxChart Data="@GetChartData()" CssClass="report-chart">
    <DxChartBarSeries ArgumentField="@(x => x.Argument)"
                      ValueField="@(x => x.Value)"
                      Name="@Config.ChartYField" />
    <DxChartLegend Visible="true" Position="RelativePosition.Outside" />
</DxChart>
```

---

### 7. DxPieChart
**File:** `Components/Pages/ReportBuilder.razor`
**Purpose:** Pie chart visualization
**Properties Used:**
- `Data` - Chart data source
- `CssClass` - Custom styling

**Sub-components:**
- `DxPieChartSeries` - Pie chart series
- `DxChartSeriesLabel` - Series labels
- `DxChartLegend` - Chart legend

```razor
<DxPieChart Data="@GetChartData()" CssClass="report-chart">
    <DxPieChartSeries ArgumentField="@(x => x.Argument)"
                      ValueField="@(x => x.Value)"
                      Name="@Config.ChartYField">
        <DxChartSeriesLabel Visible="true" Position="RelativePosition.Outside" />
    </DxPieChartSeries>
    <DxChartLegend Visible="true" Position="RelativePosition.Outside" />
</DxPieChart>
```

---

## Future DevExpress Components to Consider

| Component | Potential Use |
|-----------|--------------|
| DxToolbar | Top action bar with grouped buttons |
| DxPopup | Modal dialogs for settings/export options |
| DxTabs | Tab-based navigation for different report views |
| DxFormLayout | Form layout for advanced configuration |
| DxScheduler | Scheduled report generation |
| DxTreeView | Hierarchical queue/group selection |
| DxSpinEdit | Numeric input for row limits |
| DxProgressBar | Export progress indicator |

---

## Custom CSS Classes for DevExpress Components

Located in: `wwwroot/reportbuilder.css`

- `.dx-date-input` - Date picker styling
- `.dx-listbox-queues` - Queue list styling
- `.dx-listbox-columns` - Column list styling
- `.dx-combo-chart` - Combo box styling
- `.report-grid` - Data grid styling
- `.report-chart` - Chart container styling

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-25 | 1.0 | Initial DevExpress integration with DxDateEdit, DxListBox, DxComboBox, DxButton, DxGrid, DxChart, DxPieChart |
