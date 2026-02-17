using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.XtraReports.UI;
using DevExpress.XtraCharts;
using DevExpress.Drawing.Printing;
using DevExpress.Utils;
using System.Drawing;

namespace ReportingToolMVP.Reports;

/// <summary>
/// Generates the Queue Performance Dashboard .repx file programmatically
/// using the DevExpress API. This ensures correct serialization of
/// SqlDataSources, stored procedure parameters, and expression bindings.
/// 
/// SPs used (from SQL/Similar_to_samuel_sirs_report/):
///   - sp_queue_kpi_summary_shushant       → KPI cards
///   - sp_queue_calls_by_date_shushant     → Area chart
///   - qcall_cent_get_extensions_statistics_by_queues → Agent table
/// </summary>
public static class QueuePerformanceDashboardGenerator
{
    private const string ConnectionName = "3CX_Exporter_Production";

    public static void GenerateAndSave(string outputPath)
    {
        var report = CreateReport();
        report.SaveLayoutToXml(outputPath);

        // Post-process the XML to inject chart data bindings.
        // SaveLayoutToXml() strips data-binding properties (DataMember,
        // ArgumentDataMember, ValueDataMembersSerializable) when the
        // SqlDataSource schema can't be validated at generation time.
        // At runtime DevExpress loads the schema from the DB, so these work.
        var xml = System.IO.File.ReadAllText(outputPath);

        // 0. Set ValidateDataMembers="false" on the chart DataContainer.
        //    Also inject DataMember="ChartData" on the DataContainer itself
        //    (not just the XRChart control). The internal chart engine uses
        //    DataContainer.DataMember to know which query/table to bind to.
        //    Without it, the chart ignores the XRChart-level DataMember.
        //    Pattern verified against working VoIPToolsDashboard.repx.
        xml = System.Text.RegularExpressions.Regex.Replace(
            xml,
            @"<DataContainer Ref=""\d+"" ValidateDataMembers=""true"">",
            m => m.Value
                .Replace("ValidateDataMembers=\"true\"", "DataMember=\"ChartData\" ValidateDataMembers=\"false\""));

        // 1. Inject DataMember="ChartData" on the XRChart control
        xml = xml.Replace(
            "Name=\"chartTrends\"",
            "Name=\"chartTrends\" DataMember=\"ChartData\"");

        // 2. Inject ArgumentDataMember + ValueDataMembersSerializable on each series
        //    DevExpress strips these when DataSource can't be validated at save time.
        //    The serialized attribute order is: Name, SeriesID, ArgumentScaleType
        xml = xml.Replace(
            "Name=\"Answered\" SeriesID=\"0\" ArgumentScaleType=\"DateTime\"",
            "Name=\"Answered\" ArgumentScaleType=\"DateTime\" ArgumentDataMember=\"call_date\" ValueDataMembersSerializable=\"answered_calls\" SeriesID=\"0\"");
        xml = xml.Replace(
            "Name=\"Abandoned\" SeriesID=\"1\" ArgumentScaleType=\"DateTime\"",
            "Name=\"Abandoned\" ArgumentScaleType=\"DateTime\" ArgumentDataMember=\"call_date\" ValueDataMembersSerializable=\"abandoned_calls\" SeriesID=\"1\"");

        // 3. CRITICAL: Inject ResultSchema into the chart's StoredProcQuery.
        //    Without ResultSchema, DevExpress can't resolve SP column metadata
        //    at report load time → chart series bindings are invalid → empty chart.
        //    NOTE: Cannot use ResultSchemaSerializable in code because it causes
        //    SaveLayoutToXml() to convert StoredProcQuery → CustomSqlQuery, which
        //    then fails with "A custom SQL query should contain only SELECT statements."
        //    Instead, we inject ResultSchema directly into the Base64-encoded XML.
        var b64Pattern = new System.Text.RegularExpressions.Regex("Base64=\"([^\"]+)\"");
        foreach (System.Text.RegularExpressions.Match b64Match in b64Pattern.Matches(xml))
        {
            var oldB64 = b64Match.Groups[1].Value;
            try
            {
                var dsXml = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(oldB64));
                if (dsXml.Contains("StoredProcQuery") && dsXml.Contains("ChartData"))
                {
                    // Insert ResultSchema BEFORE <ConnectionOptions> (matching working VoIPToolsDashboard order)
                    var resultSchema =
                        "<ResultSchema>" +
                        "<DataSet Name=\"dsChartData\">" +
                        "<View Name=\"ChartData\">" +
                        "<Field Name=\"queue_dn\" Type=\"String\" />" +
                        "<Field Name=\"call_date\" Type=\"DateTime\" />" +
                        "<Field Name=\"total_calls\" Type=\"Int32\" />" +
                        "<Field Name=\"answered_calls\" Type=\"Int32\" />" +
                        "<Field Name=\"abandoned_calls\" Type=\"Int32\" />" +
                        "</View>" +
                        "</DataSet>" +
                        "</ResultSchema>";

                    dsXml = dsXml.Replace("<ConnectionOptions", resultSchema + "<ConnectionOptions");
                    var newB64 = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(dsXml));
                    xml = xml.Replace(oldB64, newB64);
                    break;
                }
            }
            catch { /* Skip non-SqlDataSource Base64 values */ }
        }

        System.IO.File.WriteAllText(outputPath, xml);
    }

    public static XtraReport CreateReport()
    {
        var report = new XtraReport
        {
            Name = "QueuePerformanceDashboard",
            DisplayName = "Queue Performance Dashboard",
            Landscape = true,
            PaperKind = DXPaperKind.Custom,
            PageWidth = 1100,
            PageHeight = 850,
            Margins = new System.Drawing.Printing.Margins(30, 30, 30, 30),
            RequestParameters = true,   // Show parameter panel; re-fetch ALL data sources on Submit
        };

        // === REPORT PARAMETERS ===
        var pPeriodFrom = new DevExpress.XtraReports.Parameters.Parameter
        {
            Name = "pPeriodFrom",
            Description = "Start Date:",
            Type = typeof(DateTime),
            Value = new DateTime(2025, 6, 1),
            Visible = true
        };
        var pPeriodTo = new DevExpress.XtraReports.Parameters.Parameter
        {
            Name = "pPeriodTo",
            Description = "End Date:",
            Type = typeof(DateTime),
            Value = new DateTime(2026, 2, 12),
            Visible = true
        };
        var pQueueDns = new DevExpress.XtraReports.Parameters.Parameter
        {
            Name = "pQueueDns",
            Description = "Queue DN (e.g. 8000,8089):",
            Type = typeof(string),
            Value = "8000,8089",
            Visible = true
        };
        var pWaitInterval = new DevExpress.XtraReports.Parameters.Parameter
        {
            Name = "pWaitInterval",
            Description = "SLA Threshold (HH:MM:SS):",
            Type = typeof(string),
            Value = "00:00:20",
            Visible = true
        };
        report.Parameters.AddRange(new[] { pPeriodFrom, pPeriodTo, pQueueDns, pWaitInterval });

        // === DATA SOURCE 1: KPIs (sp_queue_kpi_summary_shushant) ===
        // SP returns a SINGLE aggregated row for all queues in @queue_dns.
        // No FilterString needed — the SP handles filtering internally.
        var dsKPIs = CreateStoredProcDataSource("dsKPIs", "KPIs", "sp_queue_kpi_summary_shushant");
        report.ComponentStorage.Add(dsKPIs);
        report.DataSource = dsKPIs;
        report.DataMember = "KPIs";

        // === DATA SOURCE 2: Chart Data (sp_queue_calls_by_date_shushant) ===
        // Uses StoredProcQuery (same as KPIs/Agents). ResultSchema is injected
        // via XML post-processing in GenerateAndSave() — NOT via
        // ResultSchemaSerializable (which corrupts StoredProcQuery → CustomSqlQuery).
        var dsChartData = CreateStoredProcDataSource("dsChartData", "ChartData", "sp_queue_calls_by_date_shushant");
        report.ComponentStorage.Add(dsChartData);

        // === DATA SOURCE 3: Agents (qcall_cent_get_extensions_statistics_by_queues) ===
        var dsAgents = CreateStoredProcDataSource("dsAgents", "Agents", "qcall_cent_get_extensions_statistics_by_queues");
        report.ComponentStorage.Add(dsAgents);

        // === BANDS ===
        var topMargin = new TopMarginBand { HeightF = 30 };
        var reportHeader = CreateReportHeaderBand(dsChartData);
        var detail = new DetailBand { HeightF = 0, Visible = false };
        var agentDetail = CreateAgentDetailBand(dsAgents);
        var pageFooter = CreatePageFooterBand();
        var bottomMargin = new BottomMarginBand { HeightF = 30 };

        report.Bands.AddRange(new Band[] { topMargin, reportHeader, detail, agentDetail, pageFooter, bottomMargin });

        // Alternating row style
        var evenStyle = new XRControlStyle { Name = "EvenRow", BackColor = Color.FromArgb(248, 250, 252) };
        report.StyleSheet.Add(evenStyle);

        return report;
    }

    private static SqlDataSource CreateStoredProcDataSource(string dsName, string queryName, string spName)
    {
        var ds = new SqlDataSource(dsName);
        ds.ConnectionName = ConnectionName;

        var spQuery = new StoredProcQuery(queryName, spName);

        // Bind SP parameters to report parameters using expressions
        spQuery.Parameters.Add(new QueryParameter("@period_from", typeof(DevExpress.DataAccess.Expression),
            new DevExpress.DataAccess.Expression("[Parameters.pPeriodFrom]")));
        spQuery.Parameters.Add(new QueryParameter("@period_to", typeof(DevExpress.DataAccess.Expression),
            new DevExpress.DataAccess.Expression("[Parameters.pPeriodTo]")));
        spQuery.Parameters.Add(new QueryParameter("@queue_dns", typeof(DevExpress.DataAccess.Expression),
            new DevExpress.DataAccess.Expression("[Parameters.pQueueDns]")));
        spQuery.Parameters.Add(new QueryParameter("@wait_interval", typeof(DevExpress.DataAccess.Expression),
            new DevExpress.DataAccess.Expression("[Parameters.pWaitInterval]")));

        ds.Queries.Add(spQuery);
        return ds;
    }



    private static ReportHeaderBand CreateReportHeaderBand(SqlDataSource dsChartData)
    {
        var header = new ReportHeaderBand { HeightF = 580 };

        // Title
        header.Controls.Add(CreateLabel("lblTitle", "VoIPTools Customer Service",
            30, 5, 400, 32, "Segoe UI", 20, FontStyle.Bold, Color.FromArgb(67, 97, 238)));

        // Subtitle
        header.Controls.Add(CreateLabel("lblSubtitle", "Queue Performance Dashboard (Production)",
            30, 38, 350, 16, "Segoe UI", 9, FontStyle.Regular, Color.FromArgb(113, 128, 150)));

        // Filter Info Panel
        var pnlFilter = new XRPanel
        {
            Name = "pnlFilterInfo",
            SizeF = new SizeF(280, 55),
            LocationFloat = new PointFloat(730, 5),
            BackColor = Color.FromArgb(248, 250, 252),
            BorderColor = Color.FromArgb(226, 232, 240),
            Borders = DevExpress.XtraPrinting.BorderSide.All,
            BorderWidth = 1
        };

        var lblQueueFilter = CreateLabel("lblQueueFilter", "", 10, 5, 260, 14, "Segoe UI", 8, FontStyle.Bold, Color.FromArgb(67, 97, 238));
        lblQueueFilter.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text", "'Queue DN: ' + [queue_dn] + ' - ' + [queue_display_name]"));
        pnlFilter.Controls.Add(lblQueueFilter);

        var lblDateRange = CreateLabel("lblDateRange", "", 10, 22, 260, 14, "Segoe UI", 8, FontStyle.Regular, Color.FromArgb(113, 128, 150));
        lblDateRange.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text",
            "'Period: ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodFrom]) + ' - ' + FormatString('{0:MMM dd, yyyy}', [Parameters.pPeriodTo])"));
        pnlFilter.Controls.Add(lblDateRange);

        var lblSLA = CreateLabel("lblSLAInfo", "", 10, 38, 260, 12, "Segoe UI", 7, FontStyle.Regular, Color.FromArgb(160, 174, 192));
        lblSLA.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text", "'SLA Threshold: ' + [Parameters.pWaitInterval]"));
        pnlFilter.Controls.Add(lblSLA);

        header.Controls.Add(pnlFilter);

        // Report generated date (aligned to right edge of content area: 30 + 980 = 1010)
        var lblGenDate = CreateLabel("lblReportDate", "", 830, 65, 180, 12, "Segoe UI", 7, FontStyle.Regular, Color.FromArgb(160, 174, 192));
        lblGenDate.TextAlignment = DevExpress.XtraPrinting.TextAlignment.TopRight;
        lblGenDate.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text", "'Generated: ' + FormatString('{0:MM-dd-yyyy hh:mm tt}', Now())"));
        header.Controls.Add(lblGenDate);

        // === KPI CARDS ===
        var cards = new[]
        {
            ("Total Calls", "[total_calls]", "{0:N0}", Color.FromArgb(67, 97, 238), Color.FromArgb(45, 55, 72)),
            ("Answered", "[answered_calls]", "{0:N0}", Color.FromArgb(72, 187, 120), Color.FromArgb(72, 187, 120)),
            ("Abandoned", "[abandoned_calls]", "{0:N0}", Color.FromArgb(245, 101, 101), Color.FromArgb(245, 101, 101)),
            ("SLA %", "[answered_within_sla_percent]", "{0:N1}%", Color.FromArgb(155, 89, 182), Color.FromArgb(155, 89, 182)),
            ("Avg Talk", "[mean_talking]", null, Color.FromArgb(67, 97, 238), Color.FromArgb(45, 55, 72)),
            ("Total Talk", "[total_talking]", null, Color.FromArgb(237, 137, 54), Color.FromArgb(237, 137, 54)),
            ("Avg Wait", "[avg_waiting]", null, Color.FromArgb(56, 178, 172), Color.FromArgb(56, 178, 172)),
            ("Callbacks", "[serviced_callbacks]", "{0:N0}", Color.FromArgb(72, 187, 120), Color.FromArgb(72, 187, 120))
        };

        for (int i = 0; i < cards.Length; i++)
        {
            var (label, expr, format, accentColor, valueColor) = cards[i];
            float x = 30 + i * 126;
            var panel = CreateKPICard($"pnlCard{i + 1}", x, 80, 118, 55, accentColor, valueColor, label, expr, format);
            header.Controls.Add(panel);
        }

        // === CHART TITLE ===
        header.Controls.Add(CreateLabel("lblChartTitle", "Call Trends by Date",
            30, 145, 250, 20, "Segoe UI", 11, FontStyle.Bold, Color.FromArgb(45, 55, 72)));

        // === XR CHART ===
        // DataMember is NOT set here because at generation time the SqlDataSource
        // schema isn't loaded, causing "doesn't contain data member" errors.
        // Instead, we post-process the XML in GenerateAndSave() to inject
        // DataMember="ChartData" after serialization.
        var chart = new XRChart
        {
            Name = "chartTrends",
            SizeF = new SizeF(980, 350),
            LocationFloat = new PointFloat(30, 168),
            DataSource = dsChartData
        };

        var answeredSeries = new Series("Answered", ViewType.Area)
        {
            ArgumentDataMember = "call_date",
            ArgumentScaleType = ScaleType.DateTime,
        };
        answeredSeries.ValueDataMembersSerializable = "answered_calls";
        var answeredView = (AreaSeriesView)answeredSeries.View;
        answeredView.Color = Color.FromArgb(72, 187, 120);
        answeredView.Transparency = 80;
        answeredView.MarkerVisibility = DefaultBoolean.True;
        answeredView.Border.Visibility = DefaultBoolean.True;
        answeredView.Border.Color = Color.FromArgb(56, 161, 105);

        var abandonedSeries = new Series("Abandoned", ViewType.Area)
        {
            ArgumentDataMember = "call_date",
            ArgumentScaleType = ScaleType.DateTime,
        };
        abandonedSeries.ValueDataMembersSerializable = "abandoned_calls";
        var abandonedView = (AreaSeriesView)abandonedSeries.View;
        abandonedView.Color = Color.FromArgb(245, 101, 101);
        abandonedView.Transparency = 80;
        abandonedView.MarkerVisibility = DefaultBoolean.True;
        abandonedView.Border.Visibility = DefaultBoolean.True;
        abandonedView.Border.Color = Color.FromArgb(229, 62, 62);

        chart.Series.AddRange(new[] { answeredSeries, abandonedSeries });

        // Note: ValidateDataMembers is set to false via XML post-processing
        // in GenerateAndSave(). XRChart doesn't expose DataContainer in code.

        // Configure axes — use the auto-created diagram (created when series are added)
        // Do NOT create a new XYDiagram() or set chart.Diagram — that throws at runtime.
        if (chart.Diagram is XYDiagram diagram)
        {
            diagram.AxisX.DateTimeScaleOptions.AggregateFunction = AggregateFunction.None;
            diagram.AxisX.Label.TextPattern = "{A:MMM dd}";
            diagram.AxisX.Label.Angle = -45;
            diagram.AxisY.Title.Visibility = DefaultBoolean.True;
            diagram.AxisY.Title.Text = "Calls";
            diagram.AxisY.Title.Font = new Font("Segoe UI", 8);
        }

        chart.Legend.AlignmentHorizontal = LegendAlignmentHorizontal.Center;
        chart.Legend.AlignmentVertical = LegendAlignmentVertical.BottomOutside;
        chart.Legend.Direction = LegendDirection.LeftToRight;

        header.Controls.Add(chart);

        // === AGENT TABLE HEADER ===
        header.Controls.Add(CreateLabel("lblAgentTitle", "Agent Performance",
            30, 528, 250, 20, "Segoe UI", 11, FontStyle.Bold, Color.FromArgb(45, 55, 72)));

        // Note: Agent header table is now inside the DetailReportBand as a GroupHeaderBand
        // so it repeats on every page (Fix #7)

        return header;
    }

    private static XRPanel CreateKPICard(string name, float x, float y, float w, float h,
        Color accentColor, Color valueColor, string label, string expression, string? format)
    {
        var panel = new XRPanel
        {
            Name = name,
            SizeF = new SizeF(w, h),
            LocationFloat = new PointFloat(x, y),
            BackColor = Color.White,
            BorderColor = Color.FromArgb(226, 232, 240),
            Borders = DevExpress.XtraPrinting.BorderSide.All,
            BorderWidth = 1
        };

        // Color accent strip
        panel.Controls.Add(new XRPanel
        {
            Name = name + "Accent",
            SizeF = new SizeF(4, h),
            LocationFloat = new PointFloat(0, 0),
            BackColor = accentColor
        });

        // Value label
        var valueLbl = new XRLabel
        {
            Name = name + "Value",
            TextAlignment = DevExpress.XtraPrinting.TextAlignment.MiddleCenter,
            SizeF = new SizeF(105, 22),
            LocationFloat = new PointFloat(8, 5),
            Font = new Font("Segoe UI", format != null ? 13f : 11f, FontStyle.Bold),
            ForeColor = valueColor,
            Padding = new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
        };
        string exprStr = format != null ? $"FormatString('{format}', {expression})" : expression;
        valueLbl.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text", exprStr));
        panel.Controls.Add(valueLbl);

        // Label
        panel.Controls.Add(new XRLabel
        {
            Name = name + "Label",
            Text = label,
            TextAlignment = DevExpress.XtraPrinting.TextAlignment.MiddleCenter,
            SizeF = new SizeF(105, 14),
            LocationFloat = new PointFloat(8, 32),
            Font = new Font("Segoe UI", 7),
            ForeColor = Color.FromArgb(113, 128, 150),
            Padding = new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
        });

        return panel;
    }

    private static DetailReportBand CreateAgentDetailBand(SqlDataSource dsAgents)
    {
        var detailReport = new DetailReportBand
        {
            Name = "AgentDetail",
            DataSource = dsAgents,
            DataMember = "Agents",
            Level = 0
        };

        // === Fix #7: GroupHeaderBand so the header repeats on every page ===
        var groupHeader = new GroupHeaderBand
        {
            Name = "AgentGroupHeader",
            HeightF = 22,
            RepeatEveryPage = true,
            GroupUnion = GroupUnion.WithFirstDetail
        };

        var headerTable = new XRTable
        {
            Name = "tblAgentHeader",
            SizeF = new SizeF(980, 22),
            LocationFloat = new PointFloat(30, 0)
        };

        var headerRow = new XRTableRow { Name = "rowAgentHeader" };
        var headerColor = Color.FromArgb(74, 85, 104);
        var hdrFont = new Font("Segoe UI", 8, FontStyle.Bold);

        // Fix #6: Updated column names - Q Time and In Q% are placeholders for future data
        var columns = new[] {
            ("Agent", 2.5),
            ("Answered Calls", 1.0),
            ("Avg Answered", 1.0),
            ("Avg Talk Time", 1.0),
            ("Q Time", 0.8),
            ("In Q%", 0.7)
        };
        int hIdx = 0;
        foreach (var (text, weight) in columns)
        {
            var cell = new XRTableCell
            {
                Name = $"cellHdr{hIdx}",
                Text = text,
                Weight = weight,
                Font = hdrFont,
                ForeColor = Color.White,
                BackColor = headerColor,
                TextAlignment = hIdx == 0 ? DevExpress.XtraPrinting.TextAlignment.MiddleLeft : DevExpress.XtraPrinting.TextAlignment.MiddleCenter,
                Padding = hIdx == 0 ? new DevExpress.XtraPrinting.PaddingInfo(10, 2, 0, 0, 100) : new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
            };
            headerRow.Cells.Add(cell);
            hIdx++;
        }
        headerTable.Rows.Add(headerRow);
        groupHeader.Controls.Add(headerTable);
        detailReport.Bands.Add(groupHeader);

        // === Detail Band with agent data rows (Fix #4: no gap, starts right after header) ===
        var detailBand = new DetailBand
        {
            Name = "AgentDetailBand",
            HeightF = 22,
            EvenStyleName = "EvenRow"
        };

        var table = new XRTable
        {
            Name = "tblAgentRow",
            SizeF = new SizeF(980, 22),
            LocationFloat = new PointFloat(30, 0)
        };

        var row = new XRTableRow { Name = "rowAgentData" };
        var font = new Font("Segoe UI", 8);
        var foreColor = Color.FromArgb(45, 55, 72);

        // Fix #5: Agent column shows "extension_dn - extension_display_name"
        // Fix #6: Matching updated columns - Q Time and In Q% show "-" as placeholder
        var fields = new[] {
            ("agent", "[extension_dn] + ' - ' + [extension_display_name]", 2.5, true),
            ("answered", "FormatString('{0:N0}', [extension_answered_count])", 1.0, false),
            ("avgans", "[avg_answer_time]", 1.0, false),
            ("avgtalk", "[avg_talk_time]", 1.0, false),
            ("qtime", "'-'", 0.8, false),
            ("inqpct", "'-'", 0.7, false)
        };

        int idx = 0;
        foreach (var (fieldId, expr, weight, isLeft) in fields)
        {
            var cell = new XRTableCell
            {
                Name = $"cellAgent{idx++}",
                Weight = weight,
                Font = font,
                ForeColor = foreColor,
                TextAlignment = isLeft ? DevExpress.XtraPrinting.TextAlignment.MiddleLeft : DevExpress.XtraPrinting.TextAlignment.MiddleCenter,
                Padding = isLeft ? new DevExpress.XtraPrinting.PaddingInfo(10, 2, 0, 0, 100) : new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
            };
            cell.ExpressionBindings.Add(new ExpressionBinding("BeforePrint", "Text", expr));
            row.Cells.Add(cell);
        }

        table.Rows.Add(row);
        detailBand.Controls.Add(table);
        detailReport.Bands.Add(detailBand);

        return detailReport;
    }

    private static PageFooterBand CreatePageFooterBand()
    {
        var footer = new PageFooterBand { HeightF = 25 };

        footer.Controls.Add(new XRPageInfo
        {
            Name = "pageInfo1",
            PageInfo = DevExpress.XtraPrinting.PageInfo.DateTime,
            SizeF = new SizeF(200, 20),
            LocationFloat = new PointFloat(30, 2),
            Font = new Font("Segoe UI", 7),
            ForeColor = Color.FromArgb(160, 174, 192),
            Padding = new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
        });

        footer.Controls.Add(new XRPageInfo
        {
            Name = "pageInfo2",
            TextAlignment = DevExpress.XtraPrinting.TextAlignment.TopRight,
            SizeF = new SizeF(200, 20),
            LocationFloat = new PointFloat(810, 2),
            Font = new Font("Segoe UI", 7),
            ForeColor = Color.FromArgb(160, 174, 192),
            Padding = new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100),
            TextFormatString = "Page {0} of {1}"
        });

        return footer;
    }

    private static XRLabel CreateLabel(string name, string text, float x, float y, float w, float h,
        string fontFamily, float fontSize, FontStyle fontStyle, Color foreColor)
    {
        return new XRLabel
        {
            Name = name,
            Text = text,
            SizeF = new SizeF(w, h),
            LocationFloat = new PointFloat(x, y),
            Font = new Font(fontFamily, fontSize, fontStyle),
            ForeColor = foreColor,
            Padding = new DevExpress.XtraPrinting.PaddingInfo(2, 2, 0, 0, 100)
        };
    }
}
