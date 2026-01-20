using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.XtraReports.UI;
using DevExpress.XtraPrinting;
using DevExpress.Utils;
using DevExpress.XtraCharts;
using System.Drawing;
using System.ComponentModel;

namespace ReportingToolMVP.Reports
{
    /// <summary>
    /// Queue Dashboard Report - Pre-configured with SQL data sources
    /// Displays KPIs, Agent Performance, and Call Trends
    /// </summary>
    public class QueueDashboardReport : XtraReport
    {
        public QueueDashboardReport()
        {
            InitializeReport();
        }

        private void InitializeReport()
        {
            // Report settings
            this.Name = "QueueDashboardReport";
            this.DisplayName = "Queue Dashboard";
            this.PageWidth = 1100;
            this.PageHeight = 850;
            this.Landscape = true;
            this.Font = new Font("Arial", 10f);

            // Create parameters
            CreateParameters();

            // Create data source
            CreateDataSource();

            // Create report layout
            CreateReportLayout();
        }

        private void CreateParameters()
        {
            // Queue Number parameter
            var paramQueue = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramQueueNumber",
                Description = "Select Queue:",
                Type = typeof(string),
                Value = "8000",
                Visible = true
            };

            // Start Date parameter - default to data range (test data: Dec 2023 - Oct 2025)
            var paramStartDate = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramStartDate",
                Description = "Start Date:",
                Type = typeof(DateTime),
                Value = new DateTime(2025, 1, 1),  // Default to Jan 2025 (within data range)
                Visible = true
            };

            // End Date parameter  
            var paramEndDate = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramEndDate",
                Description = "End Date:",
                Type = typeof(DateTime),
                Value = new DateTime(2025, 10, 31),  // Default to Oct 2025 (end of data range)
                Visible = true
            };

            this.Parameters.AddRange(new[] { paramQueue, paramStartDate, paramEndDate });
        }

        private void CreateDataSource()
        {
            // Connection string - uses same connection as app
            var connectionString = "XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;";

            var sqlDataSource = new SqlDataSource("QueueDashboardDataSource");
            sqlDataSource.ConnectionParameters = new CustomStringConnectionParameters(connectionString);

            // Query 1: KPI Summary (aggregated)
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

            // Query 2: Agent Performance
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

            // Query 3: Call Trends (daily)
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

            // Query 4: Queue List (for parameter dropdown) - no parameters needed
            var queueListQuery = new CustomSqlQuery("QueueList", @"
                SELECT QueueNumber, QueueName FROM vw_QueueList ORDER BY QueueNumber
            ");

            sqlDataSource.Queries.AddRange(new SqlQuery[] { kpiQuery, agentQuery, trendsQuery, queueListQuery });

            // Note: Don't call Fill() or RebuildResultSchema() - they fail with Expression parameters
            // The data source will be filled at runtime when parameters are provided

            this.DataSource = sqlDataSource;
            this.DataMember = "KPISummary";
        }

        private void CreateReportLayout()
        {
            // === PAGE HEADER ===
            var pageHeader = new PageHeaderBand { HeightF = 80 };
            
            var titleLabel = new XRLabel
            {
                Text = "Queue Dashboard",
                SizeF = new SizeF(400, 40),
                LocationFloat = new PointFloat(20, 10),
                Font = new Font("Arial", 24, FontStyle.Bold),
                ForeColor = Color.FromArgb(67, 97, 238)
            };
            pageHeader.Controls.Add(titleLabel);

            var queueLabel = new XRLabel
            {
                SizeF = new SizeF(300, 25),
                LocationFloat = new PointFloat(20, 50),
                Font = new Font("Arial", 12)
            };
            queueLabel.ExpressionBindings.Add(new ExpressionBinding("Text", "'Queue: ' + [Parameters.paramQueueNumber]"));
            pageHeader.Controls.Add(queueLabel);

            var dateLabel = new XRLabel
            {
                SizeF = new SizeF(400, 25),
                LocationFloat = new PointFloat(350, 50),
                Font = new Font("Arial", 10),
                ForeColor = Color.Gray
            };
            dateLabel.ExpressionBindings.Add(new ExpressionBinding("Text", 
                "'Period: ' + FormatString('{0:dd-MM-yyyy}', [Parameters.paramStartDate]) + ' to ' + FormatString('{0:dd-MM-yyyy}', [Parameters.paramEndDate])"));
            pageHeader.Controls.Add(dateLabel);

            this.Bands.Add(pageHeader);

            // === REPORT HEADER (KPI Cards) ===
            var reportHeader = new ReportHeaderBand { HeightF = 160 };

            var kpiHeaderLabel = new XRLabel
            {
                Text = "Key Performance Indicators",
                SizeF = new SizeF(300, 25),
                LocationFloat = new PointFloat(20, 5),
                Font = new Font("Arial", 12, FontStyle.Bold),
                ForeColor = Color.FromArgb(67, 97, 238)
            };
            reportHeader.Controls.Add(kpiHeaderLabel);

            // KPI Cards Panel
            float cardX = 20;
            float cardY = 35;
            float cardWidth = 120;
            float cardHeight = 110;
            float cardSpacing = 10;

            // Total Calls Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight, 
                "📞", "Total Calls", "[TotalCalls]", 
                Color.FromArgb(240, 248, 255), Color.FromArgb(67, 97, 238));
            cardX += cardWidth + cardSpacing;

            // Answered Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "✓", "Answered", "[AnsweredCalls]",
                Color.FromArgb(240, 255, 240), Color.FromArgb(46, 204, 113));
            cardX += cardWidth + cardSpacing;

            // Abandoned Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "✗", "Abandoned", "[AbandonedCalls]",
                Color.FromArgb(255, 245, 238), Color.FromArgb(231, 76, 60));
            cardX += cardWidth + cardSpacing;

            // Missed Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "⊘", "Missed", "[MissedCalls]",
                Color.FromArgb(255, 250, 240), Color.FromArgb(243, 156, 18));
            cardX += cardWidth + cardSpacing;

            // SLA Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "%", "SLA (<20s)", "Iif([TotalCalls] > 0, FormatString('{0:0}%', [SLAMetCalls] * 100.0 / [TotalCalls]), 'N/A')",
                Color.FromArgb(245, 245, 255), Color.FromArgb(155, 89, 182));
            cardX += cardWidth + cardSpacing;

            // Avg Wait Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "⏱", "Avg Wait", "FormatString('{0:0}s', [AvgWaitTimeSec])",
                Color.FromArgb(248, 248, 248), Color.FromArgb(100, 100, 100));
            cardX += cardWidth + cardSpacing;

            // Avg Talk Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "💬", "Avg Talk", "FormatString('{0:0}s', [AvgTalkTimeSec])",
                Color.FromArgb(248, 248, 248), Color.FromArgb(100, 100, 100));
            cardX += cardWidth + cardSpacing;

            // Max Wait Card
            AddKpiCard(reportHeader, cardX, cardY, cardWidth, cardHeight,
                "⌛", "Max Wait", "FormatString('{0:0}s', [MaxWaitTimeSec])",
                Color.FromArgb(255, 245, 245), Color.FromArgb(231, 76, 60));

            this.Bands.Add(reportHeader);

            // === DETAIL BAND (hidden - we use summary) ===
            var detail = new DetailBand { HeightF = 0, Visible = false };
            this.Bands.Add(detail);

            // === REPORT FOOTER (Agent Table + Call Trends Chart) ===
            var reportFooter = new ReportFooterBand { HeightF = 350 };

            // --- Agent Performance Section ---
            var agentHeaderLabel = new XRLabel
            {
                Text = "Agent Performance",
                SizeF = new SizeF(200, 25),
                LocationFloat = new PointFloat(20, 10),
                Font = new Font("Arial", 12, FontStyle.Bold),
                ForeColor = Color.FromArgb(67, 97, 238)
            };
            reportFooter.Controls.Add(agentHeaderLabel);

            // Create Agent Performance Table
            var agentTable = CreateAgentPerformanceTable();
            agentTable.LocationFloat = new PointFloat(20, 40);
            reportFooter.Controls.Add(agentTable);

            // --- Call Trends Chart Section ---
            var trendsHeaderLabel = new XRLabel
            {
                Text = "Call Trends",
                SizeF = new SizeF(200, 25),
                LocationFloat = new PointFloat(550, 10),
                Font = new Font("Arial", 12, FontStyle.Bold),
                ForeColor = Color.FromArgb(67, 97, 238)
            };
            reportFooter.Controls.Add(trendsHeaderLabel);

            // Create Call Trends Area Chart
            var trendsChart = CreateCallTrendsChart();
            trendsChart.LocationFloat = new PointFloat(550, 40);
            reportFooter.Controls.Add(trendsChart);

            this.Bands.Add(reportFooter);

            // === PAGE FOOTER ===
            var pageFooter = new PageFooterBand { HeightF = 30 };
            
            var dateTimeInfo = new XRPageInfo
            {
                PageInfo = PageInfo.DateTime,
                SizeF = new SizeF(200, 20),
                LocationFloat = new PointFloat(20, 5),
                Font = new Font("Arial", 8),
                ForeColor = Color.Gray
            };
            pageFooter.Controls.Add(dateTimeInfo);

            var pageNumberInfo = new XRPageInfo
            {
                SizeF = new SizeF(100, 20),
                LocationFloat = new PointFloat(950, 5),
                Font = new Font("Arial", 8),
                ForeColor = Color.Gray,
                TextAlignment = DevExpress.XtraPrinting.TextAlignment.TopRight
            };
            pageFooter.Controls.Add(pageNumberInfo);

            this.Bands.Add(pageFooter);
        }

        private void AddKpiCard(Band band, float x, float y, float width, float height,
            string icon, string label, string valueExpression, Color bgColor, Color accentColor)
        {
            var panel = new XRPanel
            {
                SizeF = new SizeF(width, height),
                LocationFloat = new PointFloat(x, y),
                BackColor = bgColor,
                BorderColor = accentColor,
                Borders = DevExpress.XtraPrinting.BorderSide.All,
                BorderWidth = 2
            };

            var iconLabel = new XRLabel
            {
                Text = icon,
                SizeF = new SizeF(30, 25),
                LocationFloat = new PointFloat(8, 8),
                Font = new Font("Segoe UI Emoji", 14),
                ForeColor = accentColor
            };
            panel.Controls.Add(iconLabel);

            var valueLabel = new XRLabel
            {
                SizeF = new SizeF(width - 16, 35),
                LocationFloat = new PointFloat(8, 35),
                Font = new Font("Arial", 18, FontStyle.Bold),
                ForeColor = accentColor
            };
            valueLabel.ExpressionBindings.Add(new ExpressionBinding("Text", valueExpression));
            panel.Controls.Add(valueLabel);

            var textLabel = new XRLabel
            {
                Text = label,
                SizeF = new SizeF(width - 16, 20),
                LocationFloat = new PointFloat(8, 75),
                Font = new Font("Arial", 9),
                ForeColor = Color.FromArgb(100, 100, 100)
            };
            panel.Controls.Add(textLabel);

            band.Controls.Add(panel);
        }

        /// <summary>
        /// Creates the Agent Performance table with headers
        /// </summary>
        private XRTable CreateAgentPerformanceTable()
        {
            var table = new XRTable
            {
                SizeF = new SizeF(500, 250),
                Font = new Font("Arial", 9)
            };

            // Header Row
            var headerRow = new XRTableRow { HeightF = 25 };
            headerRow.BackColor = Color.FromArgb(67, 97, 238);
            headerRow.ForeColor = Color.White;
            headerRow.Font = new Font("Arial", 9, FontStyle.Bold);

            var headers = new[] { "Agent", "Calls", "Answered", "Avg Answer", "Avg Talk" };
            var widths = new float[] { 150, 60, 70, 90, 90 };

            for (int i = 0; i < headers.Length; i++)
            {
                var cell = new XRTableCell
                {
                    Text = headers[i],
                    WidthF = widths[i],
                    TextAlignment = TextAlignment.MiddleCenter,
                    Borders = BorderSide.All,
                    BorderColor = Color.White
                };
                headerRow.Cells.Add(cell);
            }
            table.Rows.Add(headerRow);

            // Note: Data rows would be populated via data binding
            // For now, add placeholder explaining how to use
            var infoRow = new XRTableRow { HeightF = 25 };
            infoRow.BackColor = Color.FromArgb(248, 249, 250);
            var infoCell = new XRTableCell
            {
                Text = "Bind to AgentPerformance data member for agent statistics",
                WidthF = 500,
                TextAlignment = TextAlignment.MiddleLeft,
                Font = new Font("Arial", 8, FontStyle.Italic),
                ForeColor = Color.Gray,
                Borders = BorderSide.All,
                BorderColor = Color.LightGray
            };
            infoRow.Cells.Add(infoCell);
            table.Rows.Add(infoRow);

            table.BeginInit();
            table.EndInit();

            return table;
        }

        /// <summary>
        /// Creates the Call Trends area chart
        /// </summary>
        private XRChart CreateCallTrendsChart()
        {
            var chart = new XRChart
            {
                SizeF = new SizeF(450, 280),
                DataMember = "CallTrends"
            };

            // Create Area Series for Answered Calls
            var answeredSeries = new Series("Answered", ViewType.Area);
            answeredSeries.ArgumentDataMember = "CallDate";
            answeredSeries.ValueDataMembers.AddRange(new[] { "AnsweredCalls" });
            var answeredView = new AreaSeriesView();
            answeredView.Color = Color.FromArgb(150, 46, 204, 113);
            answeredView.MarkerVisibility = DefaultBoolean.True;
            answeredSeries.View = answeredView;
            chart.Series.Add(answeredSeries);

            // Create Area Series for Abandoned Calls
            var abandonedSeries = new Series("Abandoned", ViewType.Area);
            abandonedSeries.ArgumentDataMember = "CallDate";
            abandonedSeries.ValueDataMembers.AddRange(new[] { "AbandonedCalls" });
            var abandonedView = new AreaSeriesView();
            abandonedView.Color = Color.FromArgb(150, 231, 76, 60);
            abandonedView.MarkerVisibility = DefaultBoolean.True;
            abandonedSeries.View = abandonedView;
            chart.Series.Add(abandonedSeries);

            // Create Area Series for Missed Calls
            var missedSeries = new Series("Missed", ViewType.Area);
            missedSeries.ArgumentDataMember = "CallDate";
            missedSeries.ValueDataMembers.AddRange(new[] { "MissedCalls" });
            var missedView = new AreaSeriesView();
            missedView.Color = Color.FromArgb(150, 243, 156, 18);
            missedView.MarkerVisibility = DefaultBoolean.True;
            missedSeries.View = missedView;
            chart.Series.Add(missedSeries);

            // Configure Chart Legend
            chart.Legend.Visibility = DefaultBoolean.True;
            chart.Legend.AlignmentHorizontal = LegendAlignmentHorizontal.Center;
            chart.Legend.AlignmentVertical = LegendAlignmentVertical.TopOutside;
            chart.Legend.Direction = LegendDirection.LeftToRight;

            // Configure X-Axis (Date)
            if (chart.Diagram is XYDiagram diagram)
            {
                diagram.AxisX.Label.TextPattern = "{A:MMM dd}";
                diagram.AxisX.Label.Angle = -45;
                diagram.AxisY.Title.Text = "Call Count";
                diagram.AxisY.Title.Visibility = DefaultBoolean.True;
            }

            return chart;
        }
    }
}
