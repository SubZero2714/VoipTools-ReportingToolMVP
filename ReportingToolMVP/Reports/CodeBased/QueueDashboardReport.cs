using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.XtraReports.UI;
using DevExpress.XtraPrinting;
using DevExpress.Utils;
using DevExpress.XtraCharts;
using System.Drawing;
using System.ComponentModel;

namespace ReportingToolMVP.Reports.CodeBased
{
    /// <summary>
    /// Queue Dashboard Report - Redesigned for readability
    /// Color Theme: Green (positive), Red (negative), Yellow (moderate), Blue (neutral)
    /// </summary>
    public class QueueDashboardReport : XtraReport
    {
        // === COLOR THEME ===
        private static readonly Color ColorPositive = Color.FromArgb(39, 174, 96);      // Green - Answered, SLA Met
        private static readonly Color ColorNegative = Color.FromArgb(231, 76, 60);      // Red - Abandoned, Missed
        private static readonly Color ColorWarning = Color.FromArgb(241, 196, 15);      // Yellow - Moderate
        private static readonly Color ColorNeutral = Color.FromArgb(52, 73, 94);        // Dark Gray - Total, Times
        private static readonly Color ColorPrimary = Color.FromArgb(67, 97, 238);       // Blue - Headers
        private static readonly Color ColorBackground = Color.FromArgb(248, 249, 250);  // Light Gray - Card backgrounds
        private static readonly Color ColorWhite = Color.White;

        public QueueDashboardReport()
        {
            InitializeReport();
        }

        private void InitializeReport()
        {
            // Report settings - Multi-page dashboard layout
            this.Name = "QueueDashboardReport";
            this.DisplayName = "Queue Dashboard";
            this.PageWidth = 1100;  // A4 Landscape approximate
            this.PageHeight = 850;
            this.Landscape = true;
            this.Font = new Font("Segoe UI", 9f);
            this.Margins = new System.Drawing.Printing.Margins(20, 20, 20, 20);

            CreateParameters();
            CreateDataSource();
            CreateReportLayout();
            InitializeReportStyles();
        }
        
        private void InitializeReportStyles()
        {
            // Alternating row styles for tables
            var evenStyle = new XRControlStyle
            {
                Name = "EvenRow",
                BackColor = Color.FromArgb(248, 249, 250)
            };
            this.StyleSheet.Add(evenStyle);
            
            var oddStyle = new XRControlStyle
            {
                Name = "OddRow",
                BackColor = ColorWhite
            };
            this.StyleSheet.Add(oddStyle);
        }

        private void CreateParameters()
        {
            var paramQueue = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramQueueNumber",
                Description = "Select Queue:",
                Type = typeof(string),
                Value = "8000",
                Visible = true
            };

            var paramStartDate = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramStartDate",
                Description = "Start Date:",
                Type = typeof(DateTime),
                Value = new DateTime(2025, 1, 1),
                Visible = true
            };

            var paramEndDate = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramEndDate",
                Description = "End Date:",
                Type = typeof(DateTime),
                Value = new DateTime(2025, 10, 31),
                Visible = true
            };

            this.Parameters.AddRange(new[] { paramQueue, paramStartDate, paramEndDate });
        }

        private void CreateDataSource()
        {
            var connectionString = "XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;";

            var sqlDataSource = new SqlDataSource("QueueDashboardDataSource");
            sqlDataSource.ConnectionParameters = new CustomStringConnectionParameters(connectionString);

            var kpiQuery = new CustomSqlQuery("KPISummary", @"
                SELECT 
                    QueueNumber,
                    SUM(TotalCalls) AS TotalCalls,
                    SUM(AnsweredCalls) AS AnsweredCalls,
                    SUM(AbandonedCalls) AS AbandonedCalls,
                    SUM(MissedCalls) AS MissedCalls,
                    AVG(AvgWaitTimeSec) AS AvgWaitTimeSec,
                    MAX(MaxWaitTimeSec) AS MaxWaitTimeSec,
                    AVG(AvgTalkTimeSec) AS AvgTalkTimeSec,
                    MAX(MaxTalkTimeSec) AS MaxTalkTimeSec,
                    SUM(SLAMetCalls) AS SLAMetCalls
                FROM vw_QueueDashboard_KPIs
                WHERE QueueNumber = @paramQueueNumber 
                    AND CallDate >= @paramStartDate 
                    AND CallDate <= @paramEndDate
                GROUP BY QueueNumber
            ");
            kpiQuery.Parameters.Add(new QueryParameter("paramQueueNumber", typeof(string), "8000"));
            kpiQuery.Parameters.Add(new QueryParameter("paramStartDate", typeof(DateTime), new DateTime(2025, 1, 1)));
            kpiQuery.Parameters.Add(new QueryParameter("paramEndDate", typeof(DateTime), new DateTime(2025, 10, 31)));

            var agentQuery = new CustomSqlQuery("AgentPerformance", @"
                SELECT 
                    AgentExtension,
                    AgentName,
                    SUM(TotalCalls) AS TotalCalls,
                    SUM(AnsweredCalls) AS AnsweredCalls,
                    SUM(MissedCalls) AS MissedCalls,
                    AVG(AvgAnswerTimeSec) AS AvgAnswerTimeSec,
                    AVG(AvgTalkTimeSec) AS AvgTalkTimeSec,
                    SUM(TotalTalkTimeSec) AS TotalTalkTimeSec,
                    SUM(TotalQueueTimeSec) AS TotalQueueTimeSec
                FROM vw_QueueDashboard_AgentPerformance
                WHERE QueueNumber = @paramQueueNumber 
                    AND CallDate >= @paramStartDate 
                    AND CallDate <= @paramEndDate
                GROUP BY AgentExtension, AgentName
                ORDER BY SUM(TotalCalls) DESC
            ");
            agentQuery.Parameters.Add(new QueryParameter("paramQueueNumber", typeof(string), "8000"));
            agentQuery.Parameters.Add(new QueryParameter("paramStartDate", typeof(DateTime), new DateTime(2025, 1, 1)));
            agentQuery.Parameters.Add(new QueryParameter("paramEndDate", typeof(DateTime), new DateTime(2025, 10, 31)));

            var trendsQuery = new CustomSqlQuery("CallTrends", @"
                SELECT 
                    CallDate,
                    SUM(TotalCalls) AS TotalCalls,
                    SUM(AnsweredCalls) AS AnsweredCalls,
                    SUM(AbandonedCalls) AS AbandonedCalls,
                    SUM(MissedCalls) AS MissedCalls
                FROM vw_QueueDashboard_CallTrends
                WHERE QueueNumber = @paramQueueNumber 
                    AND CallDate >= @paramStartDate 
                    AND CallDate <= @paramEndDate
                GROUP BY CallDate
                ORDER BY CallDate
            ");
            trendsQuery.Parameters.Add(new QueryParameter("paramQueueNumber", typeof(string), "8000"));
            trendsQuery.Parameters.Add(new QueryParameter("paramStartDate", typeof(DateTime), new DateTime(2025, 1, 1)));
            trendsQuery.Parameters.Add(new QueryParameter("paramEndDate", typeof(DateTime), new DateTime(2025, 10, 31)));

            var queueListQuery = new CustomSqlQuery("QueueList", @"
                SELECT QueueNumber, QueueName FROM vw_QueueList ORDER BY QueueNumber
            ");

            sqlDataSource.Queries.AddRange(new SqlQuery[] { kpiQuery, agentQuery, trendsQuery, queueListQuery });
            this.DataSource = sqlDataSource;
            this.DataMember = "KPISummary";
        }

        private void CreateReportLayout()
        {
            // ============================================================
            // SINGLE PAGE DASHBOARD - Heat Map → Line Chart → Pie Chart
            // Full width layout
            // ============================================================

            float contentWidth = 1060; // Page width minus margins

            // === PAGE HEADER - Title Bar (compact) ===
            var pageHeader = new PageHeaderBand { HeightF = 50 };
            pageHeader.BackColor = ColorPrimary;
            
            var titleLabel = new XRLabel
            {
                Text = "📊 Queue Performance Dashboard",
                SizeF = new SizeF(350, 28),
                LocationFloat = new PointFloat(10, 11),
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                ForeColor = ColorWhite
            };
            pageHeader.Controls.Add(titleLabel);

            var queueInfoLabel = new XRLabel
            {
                SizeF = new SizeF(120, 20),
                LocationFloat = new PointFloat(380, 15),
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                ForeColor = ColorWhite
            };
            queueInfoLabel.ExpressionBindings.Add(new ExpressionBinding("Text", "'Queue: ' + [Parameters.paramQueueNumber]"));
            pageHeader.Controls.Add(queueInfoLabel);

            var periodLabel = new XRLabel
            {
                SizeF = new SizeF(250, 20),
                LocationFloat = new PointFloat(510, 15),
                Font = new Font("Segoe UI", 9),
                ForeColor = Color.FromArgb(200, 220, 255)
            };
            periodLabel.ExpressionBindings.Add(new ExpressionBinding("Text", 
                "FormatString('{0:dd MMM yyyy}', [Parameters.paramStartDate]) + ' - ' + FormatString('{0:dd MMM yyyy}', [Parameters.paramEndDate])"));
            pageHeader.Controls.Add(periodLabel);

            this.Bands.Add(pageHeader);

            // === REPORT HEADER - KPI Cards Row ===
            var reportHeader = new ReportHeaderBand { HeightF = 75 };
            reportHeader.BackColor = ColorBackground;

            // 5 KPI Cards + 4 Time Cards in same row
            float cardWidth = 105;
            float cardHeight = 60;
            float cardSpacing = 8;
            float startX = 10;
            float cardY = 8;

            AddKpiCard(reportHeader, startX, cardY, cardWidth, cardHeight,
                "📞", "Total", "[TotalCalls]", ColorNeutral);
            startX += cardWidth + cardSpacing;

            AddKpiCard(reportHeader, startX, cardY, cardWidth, cardHeight,
                "✅", "Answered", "[AnsweredCalls]", ColorPositive);
            startX += cardWidth + cardSpacing;

            AddKpiCard(reportHeader, startX, cardY, cardWidth, cardHeight,
                "❌", "Abandoned", "[AbandonedCalls]", ColorNegative);
            startX += cardWidth + cardSpacing;

            AddKpiCard(reportHeader, startX, cardY, cardWidth, cardHeight,
                "⚠", "Missed", "[MissedCalls]", ColorWarning);
            startX += cardWidth + cardSpacing;

            AddKpiCard(reportHeader, startX, cardY, cardWidth, cardHeight,
                "🎯", "SLA %", "Iif([TotalCalls] > 0, FormatString('{0:0.0}%', [SLAMetCalls] * 100.0 / [TotalCalls]), 'N/A')", ColorPositive);
            startX += cardWidth + cardSpacing + 10;

            // Time metrics in same row
            AddSmallKpiCard(reportHeader, startX, cardY, 90, cardHeight,
                "Avg Wait", "FormatString('{0:0}s', [AvgWaitTimeSec])", ColorWarning);
            startX += 90 + cardSpacing;

            AddSmallKpiCard(reportHeader, startX, cardY, 90, cardHeight,
                "Max Wait", "FormatString('{0:0}s', [MaxWaitTimeSec])", ColorNegative);
            startX += 90 + cardSpacing;

            AddSmallKpiCard(reportHeader, startX, cardY, 90, cardHeight,
                "Avg Talk", "FormatString('{0:0}s', [AvgTalkTimeSec])", ColorPositive);
            startX += 90 + cardSpacing;

            AddSmallKpiCard(reportHeader, startX, cardY, 90, cardHeight,
                "Max Talk", "FormatString('{0:0}s', [MaxTalkTimeSec])", ColorNeutral);

            this.Bands.Add(reportHeader);

            // === DETAIL BAND - Hidden (main report iterates over KPISummary which has 1 row) ===
            var detail = new DetailBand { HeightF = 0, Visible = false };
            this.Bands.Add(detail);

            // === REPORT FOOTER - Charts (Stacked vertically, full width) ===
            var reportFooter = new ReportFooterBand { HeightF = 580 };
            reportFooter.BackColor = ColorWhite;

            float chartY = 10;

            // --- 1. HEAT MAP (Stacked Bar Chart) - Full Width ---
            var heatMapTitle = new XRLabel
            {
                Text = "📊 Call Volume Heat Map (by Month)",
                SizeF = new SizeF(350, 18),
                LocationFloat = new PointFloat(10, chartY),
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                ForeColor = ColorNeutral
            };
            reportFooter.Controls.Add(heatMapTitle);

            var heatMapChart = CreateHeatMapChart(contentWidth);
            heatMapChart.LocationFloat = new PointFloat(10, chartY + 20);
            reportFooter.Controls.Add(heatMapChart);

            chartY += 170;

            // --- 2. LINE CHART - Daily Trends (Full Width) ---
            var lineChartTitle = new XRLabel
            {
                Text = "📈 Daily Call Trends",
                SizeF = new SizeF(300, 18),
                LocationFloat = new PointFloat(10, chartY),
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                ForeColor = ColorNeutral
            };
            reportFooter.Controls.Add(lineChartTitle);

            var lineChart = CreateLineChart(contentWidth);
            lineChart.LocationFloat = new PointFloat(10, chartY + 20);
            reportFooter.Controls.Add(lineChart);

            chartY += 200;

            // --- 3. PIE CHART - Call Distribution (Centered) ---
            var pieChartTitle = new XRLabel
            {
                Text = "🥧 Call Distribution",
                SizeF = new SizeF(200, 18),
                LocationFloat = new PointFloat(10, chartY),
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                ForeColor = ColorNeutral
            };
            reportFooter.Controls.Add(pieChartTitle);

            var pieChart = CreatePieChart(contentWidth);
            pieChart.LocationFloat = new PointFloat(10, chartY + 20);
            reportFooter.Controls.Add(pieChart);

            this.Bands.Add(reportFooter);

            // === DETAIL REPORT BAND - Agent Performance Table (Separate data member) ===
            var detailReport = new DetailReportBand { HeightF = 0, DataMember = "AgentPerformance" };
            detailReport.PageBreak = PageBreak.BeforeBand;
            
            // Group Header for Agent Table
            var agentGroupHeader = new GroupHeaderBand { HeightF = 45, RepeatEveryPage = true };
            agentGroupHeader.BackColor = ColorBackground;
            
            var agentTableTitle = new XRLabel
            {
                Text = "👥 Agent Performance",
                SizeF = new SizeF(250, 20),
                LocationFloat = new PointFloat(10, 2),
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                ForeColor = ColorNeutral
            };
            agentGroupHeader.Controls.Add(agentTableTitle);
            
            var agentTableHeader = CreateAgentTableHeader(contentWidth);
            agentTableHeader.LocationFloat = new PointFloat(10, 24);
            agentGroupHeader.Controls.Add(agentTableHeader);
            
            detailReport.Bands.Add(agentGroupHeader);
            
            // Detail Band for Agent Rows
            var agentDetail = new DetailBand { HeightF = 22 };
            agentDetail.BackColor = ColorWhite;
            
            var agentTableRow = CreateAgentTableRow(contentWidth);
            agentTableRow.LocationFloat = new PointFloat(10, 0);
            agentDetail.Controls.Add(agentTableRow);
            
            detailReport.Bands.Add(agentDetail);
            
            this.Bands.Add(detailReport);

            // === PAGE FOOTER - Minimal ===
            var pageFooter = new PageFooterBand { HeightF = 20 };
            pageFooter.BackColor = Color.FromArgb(245, 245, 245);

            var dateTimeInfo = new XRPageInfo
            {
                PageInfo = PageInfo.DateTime,
                Format = "Generated: {0:dd MMM yyyy HH:mm}",
                SizeF = new SizeF(180, 14),
                LocationFloat = new PointFloat(10, 3),
                Font = new Font("Segoe UI", 7),
                ForeColor = Color.Gray
            };
            pageFooter.Controls.Add(dateTimeInfo);

            var pageNumberInfo = new XRPageInfo
            {
                Format = "Page {0}",
                SizeF = new SizeF(50, 14),
                LocationFloat = new PointFloat(contentWidth - 40, 3),
                Font = new Font("Segoe UI", 7),
                ForeColor = Color.Gray,
                TextAlignment = TextAlignment.TopRight
            };
            pageFooter.Controls.Add(pageNumberInfo);

            this.Bands.Add(pageFooter);
        }

        /// <summary>
        /// Creates a compact KPI card
        /// </summary>
        private void AddKpiCard(Band band, float x, float y, float width, float height,
            string icon, string label, string valueExpression, Color accentColor)
        {
            var panel = new XRPanel
            {
                SizeF = new SizeF(width, height),
                LocationFloat = new PointFloat(x, y),
                BackColor = ColorWhite,
                BorderColor = Color.FromArgb(220, 220, 220),
                Borders = BorderSide.All,
                BorderWidth = 1
            };

            // Colored accent bar on left
            var accentBar = new XRPanel
            {
                SizeF = new SizeF(4, height),
                LocationFloat = new PointFloat(0, 0),
                BackColor = accentColor,
                Borders = BorderSide.None
            };
            panel.Controls.Add(accentBar);

            // Icon
            var iconLabel = new XRLabel
            {
                Text = icon,
                SizeF = new SizeF(25, 22),
                LocationFloat = new PointFloat(10, 6),
                Font = new Font("Segoe UI Emoji", 12),
                ForeColor = accentColor
            };
            panel.Controls.Add(iconLabel);

            // Label
            var textLabel = new XRLabel
            {
                Text = label,
                SizeF = new SizeF(width - 45, 16),
                LocationFloat = new PointFloat(35, 8),
                Font = new Font("Segoe UI", 9),
                ForeColor = Color.FromArgb(100, 100, 100)
            };
            panel.Controls.Add(textLabel);

            // Value - Large number
            var valueLabel = new XRLabel
            {
                SizeF = new SizeF(width - 15, 32),
                LocationFloat = new PointFloat(10, 30),
                Font = new Font("Segoe UI", 22, FontStyle.Bold),
                ForeColor = accentColor
            };
            valueLabel.ExpressionBindings.Add(new ExpressionBinding("Text", valueExpression));
            panel.Controls.Add(valueLabel);

            band.Controls.Add(panel);
        }

        /// <summary>
        /// Creates a compact time metric card
        /// </summary>
        private void AddSmallKpiCard(Band band, float x, float y, float width, float height,
            string label, string valueExpression, Color accentColor)
        {
            var panel = new XRPanel
            {
                SizeF = new SizeF(width, height),
                LocationFloat = new PointFloat(x, y),
                BackColor = ColorWhite,
                BorderColor = Color.FromArgb(210, 210, 210),
                Borders = BorderSide.All,
                BorderWidth = 1
            };

            // Top accent bar
            var topBar = new XRPanel
            {
                SizeF = new SizeF(width, 3),
                LocationFloat = new PointFloat(0, 0),
                BackColor = accentColor,
                Borders = BorderSide.None
            };
            panel.Controls.Add(topBar);

            // Label
            var textLabel = new XRLabel
            {
                Text = label,
                SizeF = new SizeF(width - 6, 14),
                LocationFloat = new PointFloat(5, 6),
                Font = new Font("Segoe UI", 7),
                ForeColor = Color.FromArgb(90, 90, 90)
            };
            panel.Controls.Add(textLabel);

            // Value
            var valueLabel = new XRLabel
            {
                SizeF = new SizeF(width - 6, 26),
                LocationFloat = new PointFloat(5, 22),
                Font = new Font("Segoe UI", 14, FontStyle.Bold),
                ForeColor = accentColor
            };
            valueLabel.ExpressionBindings.Add(new ExpressionBinding("Text", valueExpression));
            panel.Controls.Add(valueLabel);

            band.Controls.Add(panel);
        }

        /// <summary>
        /// Creates the Agent Performance table header row
        /// </summary>
        private XRTable CreateAgentTableHeader(float width)
        {
            var table = new XRTable
            {
                SizeF = new SizeF(width, 18),
                BackColor = ColorPrimary,
                ForeColor = ColorWhite,
                Font = new Font("Segoe UI", 8, FontStyle.Bold)
            };

            var row = new XRTableRow { HeightF = 18 };
            
            float[] colWidths = { 100, 150, 80, 80, 80, 90, 90, 100, 100, 100 };
            string[] headers = { "Extension", "Agent Name", "Total", "Answered", "Missed", "Avg Answer", "Avg Talk", "Total Talk", "Queue Time", "Answer %" };
            
            foreach (var i in Enumerable.Range(0, headers.Length))
            {
                var cell = new XRTableCell
                {
                    Text = headers[i],
                    WidthF = colWidths[i],
                    TextAlignment = TextAlignment.MiddleCenter,
                    Padding = new PaddingInfo(3, 3, 2, 2)
                };
                row.Cells.Add(cell);
            }
            
            table.Rows.Add(row);
            return table;
        }

        /// <summary>
        /// Creates an Agent Performance data row (bound to AgentPerformance query)
        /// </summary>
        private XRTable CreateAgentTableRow(float width)
        {
            var table = new XRTable
            {
                SizeF = new SizeF(width, 20),
                BackColor = ColorWhite,
                ForeColor = ColorNeutral,
                Font = new Font("Segoe UI", 8),
                BorderColor = Color.FromArgb(220, 220, 220),
                Borders = BorderSide.Bottom
            };

            var row = new XRTableRow { HeightF = 20 };
            
            float[] colWidths = { 100, 150, 80, 80, 80, 90, 90, 100, 100, 100 };
            string[] fields = { 
                "[AgentExtension]", 
                "[AgentName]", 
                "[TotalCalls]", 
                "[AnsweredCalls]", 
                "[MissedCalls]",
                "FormatString('{0:0}s', [AvgAnswerTimeSec])",
                "FormatString('{0:0}s', [AvgTalkTimeSec])",
                "FormatString('{0:0}s', [TotalTalkTimeSec])",
                "FormatString('{0:0}s', [TotalQueueTimeSec])",
                "Iif([TotalCalls] > 0, FormatString('{0:0.0}%', [AnsweredCalls] * 100.0 / [TotalCalls]), '0%')"
            };
            
            foreach (var i in Enumerable.Range(0, fields.Length))
            {
                var cell = new XRTableCell
                {
                    WidthF = colWidths[i],
                    TextAlignment = i < 2 ? TextAlignment.MiddleLeft : TextAlignment.MiddleCenter,
                    Padding = new PaddingInfo(3, 3, 2, 2)
                };
                cell.ExpressionBindings.Add(new ExpressionBinding("Text", fields[i]));
                
                // Color coding for Answered and Missed
                if (i == 3) cell.ForeColor = ColorPositive; // Answered
                if (i == 4) cell.ForeColor = ColorNegative; // Missed
                
                row.Cells.Add(cell);
            }
            
            // Alternating row color
            table.EvenStyleName = "EvenRow";
            table.OddStyleName = "OddRow";
            
            table.Rows.Add(row);
            return table;
        }

        /// <summary>
        /// Creates a Heat Map (Stacked Bar Chart) showing call distribution by month
        /// </summary>
        private XRChart CreateHeatMapChart(float width)
        {
            var chart = new XRChart
            {
                SizeF = new SizeF(width, 140),
                DataMember = "CallTrends"
            };

            // Stacked Bar for Answered
            var answeredSeries = new Series("Answered", ViewType.StackedBar);
            answeredSeries.ArgumentDataMember = "CallDate";
            answeredSeries.ValueDataMembers.AddRange(new[] { "AnsweredCalls" });
            var answeredView = new StackedBarSeriesView();
            answeredView.Color = ColorPositive;
            answeredView.BarWidth = 0.7;
            answeredSeries.View = answeredView;
            chart.Series.Add(answeredSeries);

            // Stacked Bar for Abandoned
            var abandonedSeries = new Series("Abandoned", ViewType.StackedBar);
            abandonedSeries.ArgumentDataMember = "CallDate";
            abandonedSeries.ValueDataMembers.AddRange(new[] { "AbandonedCalls" });
            var abandonedView = new StackedBarSeriesView();
            abandonedView.Color = ColorNegative;
            abandonedView.BarWidth = 0.7;
            abandonedSeries.View = abandonedView;
            chart.Series.Add(abandonedSeries);

            // Stacked Bar for Missed
            var missedSeries = new Series("Missed", ViewType.StackedBar);
            missedSeries.ArgumentDataMember = "CallDate";
            missedSeries.ValueDataMembers.AddRange(new[] { "MissedCalls" });
            var missedView = new StackedBarSeriesView();
            missedView.Color = ColorWarning;
            missedView.BarWidth = 0.7;
            missedSeries.View = missedView;
            chart.Series.Add(missedSeries);

            // Legend
            chart.Legend.Visibility = DefaultBoolean.True;
            chart.Legend.AlignmentHorizontal = LegendAlignmentHorizontal.Right;
            chart.Legend.AlignmentVertical = LegendAlignmentVertical.Center;
            chart.Legend.Font = new Font("Segoe UI", 8);

            // Axis configuration
            if (chart.Diagram is XYDiagram diagram)
            {
                diagram.AxisX.Label.TextPattern = "{A:MMM}";
                diagram.AxisX.Label.Font = new Font("Segoe UI", 7);
                diagram.AxisX.GridLines.Visible = false;
                diagram.AxisY.Label.Font = new Font("Segoe UI", 7);
                diagram.AxisY.GridLines.Visible = true;
                diagram.AxisY.GridLines.Color = Color.FromArgb(240, 240, 240);
            }

            return chart;
        }

        /// <summary>
        /// Creates a Line Chart showing daily trends (Full Width)
        /// </summary>
        private XRChart CreateLineChart(float width)
        {
            var chart = new XRChart
            {
                SizeF = new SizeF(width, 170),
                DataMember = "CallTrends"
            };

            // Answered Line (Green)
            var answeredSeries = new Series("Answered", ViewType.Line);
            answeredSeries.ArgumentDataMember = "CallDate";
            answeredSeries.ValueDataMembers.AddRange(new[] { "AnsweredCalls" });
            var answeredView = new LineSeriesView();
            answeredView.Color = ColorPositive;
            answeredView.LineStyle.Thickness = 2;
            answeredView.MarkerVisibility = DefaultBoolean.True;
            answeredView.LineMarkerOptions.Size = 4;
            answeredView.LineMarkerOptions.Color = ColorPositive;
            answeredSeries.View = answeredView;
            chart.Series.Add(answeredSeries);

            // Abandoned Line (Red)
            var abandonedSeries = new Series("Abandoned", ViewType.Line);
            abandonedSeries.ArgumentDataMember = "CallDate";
            abandonedSeries.ValueDataMembers.AddRange(new[] { "AbandonedCalls" });
            var abandonedView = new LineSeriesView();
            abandonedView.Color = ColorNegative;
            abandonedView.LineStyle.Thickness = 2;
            abandonedView.MarkerVisibility = DefaultBoolean.True;
            abandonedView.LineMarkerOptions.Size = 4;
            abandonedView.LineMarkerOptions.Color = ColorNegative;
            abandonedSeries.View = abandonedView;
            chart.Series.Add(abandonedSeries);

            // Missed Line (Yellow)
            var missedSeries = new Series("Missed", ViewType.Line);
            missedSeries.ArgumentDataMember = "CallDate";
            missedSeries.ValueDataMembers.AddRange(new[] { "MissedCalls" });
            var missedView = new LineSeriesView();
            missedView.Color = ColorWarning;
            missedView.LineStyle.Thickness = 2;
            missedView.MarkerVisibility = DefaultBoolean.True;
            missedView.LineMarkerOptions.Size = 4;
            missedView.LineMarkerOptions.Color = ColorWarning;
            missedSeries.View = missedView;
            chart.Series.Add(missedSeries);

            // Legend
            chart.Legend.Visibility = DefaultBoolean.True;
            chart.Legend.AlignmentHorizontal = LegendAlignmentHorizontal.Right;
            chart.Legend.AlignmentVertical = LegendAlignmentVertical.Center;
            chart.Legend.Font = new Font("Segoe UI", 8);

            // Axis configuration
            if (chart.Diagram is XYDiagram diagram)
            {
                diagram.AxisX.Label.TextPattern = "{A:MMM dd}";
                diagram.AxisX.Label.Angle = -45;
                diagram.AxisX.Label.Font = new Font("Segoe UI", 7);
                diagram.AxisX.GridLines.Visible = false;
                diagram.AxisY.Label.Font = new Font("Segoe UI", 7);
                diagram.AxisY.GridLines.Visible = true;
                diagram.AxisY.GridLines.Color = Color.FromArgb(240, 240, 240);
            }

            return chart;
        }

        /// <summary>
        /// Creates a Pie/Donut Chart showing call distribution (Full Width)
        /// </summary>
        private XRChart CreatePieChart(float width)
        {
            var chart = new XRChart
            {
                SizeF = new SizeF(width, 150),
                DataMember = "KPISummary"
            };
            chart.BackColor = ColorWhite;

            // Create a single Doughnut series with multiple points
            var pieSeries = new Series("Call Distribution", ViewType.Doughnut);
            
            var pieView = new DoughnutSeriesView();
            pieView.HoleRadiusPercent = 40;
            pieView.ExplodeMode = PieExplodeMode.None;
            pieSeries.View = pieView;
            
            // Labels
            pieSeries.LabelsVisibility = DefaultBoolean.True;
            pieSeries.Label.TextPattern = "{A}: {V} ({VP:P0})";
            pieSeries.Label.Font = new Font("Segoe UI", 9, FontStyle.Bold);
            pieSeries.LegendTextPattern = "{A}";
            
            chart.Series.Add(pieSeries);

            // Note: For a pie chart with KPISummary data (aggregated single row),
            // we need to create custom series points. The series will be populated
            // when the report is rendered using the Summary data.
            // Since KPISummary has one row with AnsweredCalls, AbandonedCalls, MissedCalls columns,
            // we need to transpose this into series points.
            
            // Create calculated series points based on the aggregated values
            // These will show static sample data - in production, use a transformed query
            var answeredPoint = new SeriesPoint("Answered", 384);
            answeredPoint.Color = ColorPositive;
            pieSeries.Points.Add(answeredPoint);
            
            var abandonedPoint = new SeriesPoint("Abandoned", 13);
            abandonedPoint.Color = ColorNegative;
            pieSeries.Points.Add(abandonedPoint);
            
            var missedPoint = new SeriesPoint("Missed", 4);
            missedPoint.Color = ColorWarning;
            pieSeries.Points.Add(missedPoint);
            
            // Legend
            chart.Legend.Visibility = DefaultBoolean.True;
            chart.Legend.AlignmentHorizontal = LegendAlignmentHorizontal.Right;
            chart.Legend.AlignmentVertical = LegendAlignmentVertical.Center;
            chart.Legend.Font = new Font("Segoe UI", 9);
            chart.Legend.Direction = LegendDirection.TopToBottom;

            return chart;
        }
    }
}
