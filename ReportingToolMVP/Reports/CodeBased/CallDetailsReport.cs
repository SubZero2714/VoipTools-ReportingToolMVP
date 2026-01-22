using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.XtraReports.UI;
using DevExpress.XtraPrinting;
using DevExpress.Utils;
using System.Drawing;

namespace ReportingToolMVP.Reports.CodeBased
{
    /// <summary>
    /// Call Details Report - Shows detailed call records for drill-down
    /// </summary>
    public class CallDetailsReport : XtraReport
    {
        private static readonly Color ColorPrimary = Color.FromArgb(67, 97, 238);
        private static readonly Color ColorPositive = Color.FromArgb(39, 174, 96);
        private static readonly Color ColorNegative = Color.FromArgb(231, 76, 60);
        private static readonly Color ColorWarning = Color.FromArgb(241, 196, 15);
        private static readonly Color ColorNeutral = Color.FromArgb(52, 73, 94);
        private static readonly Color ColorWhite = Color.White;
        private static readonly Color ColorBackground = Color.FromArgb(248, 249, 250);

        public CallDetailsReport()
        {
            InitializeReport();
        }

        private void InitializeReport()
        {
            this.Name = "CallDetailsReport";
            this.DisplayName = "Call Details";
            this.PageWidth = 1100;
            this.PageHeight = 850;
            this.Landscape = true;
            this.Font = new Font("Segoe UI", 9f);
            this.Margins = new System.Drawing.Printing.Margins(20, 20, 20, 20);

            CreateParameters();
            CreateDataSource();
            CreateReportLayout();
        }

        private void CreateParameters()
        {
            var paramQueue = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramQueueNumber",
                Description = "Queue Number:",
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

            var paramCallStatus = new DevExpress.XtraReports.Parameters.Parameter
            {
                Name = "paramCallStatus",
                Description = "Call Status:",
                Type = typeof(string),
                Value = "",
                Visible = true
            };

            this.Parameters.AddRange(new[] { paramQueue, paramStartDate, paramEndDate, paramCallStatus });
        }

        private void CreateDataSource()
        {
            var connectionString = "XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;";

            var sqlDataSource = new SqlDataSource("CallDetailsDataSource");
            sqlDataSource.ConnectionParameters = new CustomStringConnectionParameters(connectionString);

            var callDetailsQuery = new CustomSqlQuery("CallDetails", @"
                SELECT 
                    qc.idcallcent_queuecalls AS CallID,
                    qc.q_num AS QueueNumber,
                    q.qname AS QueueName,
                    qc.time_start AS CallTime,
                    qc.from_dn AS CallerNumber,
                    qc.from_dispname AS CallerName,
                    qc.to_dn AS AgentExtension,
                    u.displayname AS AgentName,
                    CASE 
                        WHEN qc.reason_noanswercode = 0 AND DATEDIFF(SECOND, 0, qc.ts_servicing) > 0 THEN 'Answered'
                        WHEN qc.reason_noanswercode IN (3, 4) THEN 'Abandoned'
                        WHEN qc.reason_noanswercode = 2 THEN 'Missed'
                        ELSE 'Other'
                    END AS CallStatus,
                    DATEDIFF(SECOND, 0, qc.ts_waiting) AS WaitTimeSec,
                    DATEDIFF(SECOND, 0, qc.ts_servicing) AS TalkTimeSec,
                    qc.reason_noanswercode AS ReasonCode
                FROM callcent_queuecalls qc
                LEFT JOIN queue q ON qc.q_num = q.qdn
                LEFT JOIN users u ON qc.to_dn = u.phonenumber
                WHERE qc.q_num = @paramQueueNumber 
                    AND qc.time_start >= @paramStartDate 
                    AND qc.time_start <= @paramEndDate
                    AND (@paramCallStatus = '' OR 
                        (@paramCallStatus = 'Answered' AND qc.reason_noanswercode = 0 AND DATEDIFF(SECOND, 0, qc.ts_servicing) > 0) OR
                        (@paramCallStatus = 'Abandoned' AND qc.reason_noanswercode IN (3, 4)) OR
                        (@paramCallStatus = 'Missed' AND qc.reason_noanswercode = 2))
                ORDER BY qc.time_start DESC
            ");
            callDetailsQuery.Parameters.Add(new QueryParameter("paramQueueNumber", typeof(string), "8000"));
            callDetailsQuery.Parameters.Add(new QueryParameter("paramStartDate", typeof(DateTime), new DateTime(2025, 1, 1)));
            callDetailsQuery.Parameters.Add(new QueryParameter("paramEndDate", typeof(DateTime), new DateTime(2025, 10, 31)));
            callDetailsQuery.Parameters.Add(new QueryParameter("paramCallStatus", typeof(string), ""));

            sqlDataSource.Queries.Add(callDetailsQuery);
            this.DataSource = sqlDataSource;
            this.DataMember = "CallDetails";
        }

        private void CreateReportLayout()
        {
            float contentWidth = 1060;

            // === PAGE HEADER ===
            var pageHeader = new PageHeaderBand { HeightF = 50 };
            pageHeader.BackColor = ColorPrimary;

            var titleLabel = new XRLabel
            {
                Text = "📋 Call Details Report",
                SizeF = new SizeF(300, 28),
                LocationFloat = new PointFloat(10, 11),
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                ForeColor = ColorWhite
            };
            pageHeader.Controls.Add(titleLabel);

            var filterLabel = new XRLabel
            {
                SizeF = new SizeF(400, 20),
                LocationFloat = new PointFloat(400, 15),
                Font = new Font("Segoe UI", 9),
                ForeColor = Color.FromArgb(200, 220, 255)
            };
            filterLabel.ExpressionBindings.Add(new ExpressionBinding("Text",
                "'Queue: ' + [Parameters.paramQueueNumber] + ' | ' + " +
                "FormatString('{0:dd MMM yyyy}', [Parameters.paramStartDate]) + ' - ' + " +
                "FormatString('{0:dd MMM yyyy}', [Parameters.paramEndDate]) + " +
                "Iif([Parameters.paramCallStatus] <> '', ' | Status: ' + [Parameters.paramCallStatus], '')"));
            pageHeader.Controls.Add(filterLabel);

            this.Bands.Add(pageHeader);

            // === GROUP HEADER - Table Header ===
            var groupHeader = new GroupHeaderBand { HeightF = 22, RepeatEveryPage = true };
            groupHeader.BackColor = ColorPrimary;

            var headerTable = new XRTable
            {
                SizeF = new SizeF(contentWidth, 20),
                LocationFloat = new PointFloat(10, 1),
                ForeColor = ColorWhite,
                Font = new Font("Segoe UI", 8, FontStyle.Bold)
            };

            var headerRow = new XRTableRow { HeightF = 20 };
            float[] colWidths = { 80, 130, 120, 100, 100, 80, 80, 80, 80 };
            string[] headers = { "Call ID", "Time", "Caller", "Caller Name", "Agent", "Status", "Wait (s)", "Talk (s)", "Code" };

            for (int i = 0; i < headers.Length; i++)
            {
                var cell = new XRTableCell
                {
                    Text = headers[i],
                    WidthF = colWidths[i],
                    TextAlignment = TextAlignment.MiddleCenter,
                    Padding = new PaddingInfo(3, 3, 2, 2)
                };
                headerRow.Cells.Add(cell);
            }
            headerTable.Rows.Add(headerRow);
            groupHeader.Controls.Add(headerTable);

            this.Bands.Add(groupHeader);

            // === DETAIL BAND - Data Rows ===
            var detail = new DetailBand { HeightF = 22 };
            detail.BackColor = ColorWhite;

            var dataTable = new XRTable
            {
                SizeF = new SizeF(contentWidth, 20),
                LocationFloat = new PointFloat(10, 1),
                ForeColor = ColorNeutral,
                Font = new Font("Segoe UI", 8),
                BorderColor = Color.FromArgb(220, 220, 220),
                Borders = BorderSide.Bottom
            };

            var dataRow = new XRTableRow { HeightF = 20 };
            string[] fields = {
                "[CallID]",
                "FormatString('{0:dd MMM HH:mm}', [CallTime])",
                "[CallerNumber]",
                "[CallerName]",
                "[AgentName]",
                "[CallStatus]",
                "[WaitTimeSec]",
                "[TalkTimeSec]",
                "[ReasonCode]"
            };

            for (int i = 0; i < fields.Length; i++)
            {
                var cell = new XRTableCell
                {
                    WidthF = colWidths[i],
                    TextAlignment = i < 5 ? TextAlignment.MiddleLeft : TextAlignment.MiddleCenter,
                    Padding = new PaddingInfo(3, 3, 2, 2)
                };
                cell.ExpressionBindings.Add(new ExpressionBinding("Text", fields[i]));

                // Status cell color coding
                if (i == 5)
                {
                    cell.ExpressionBindings.Add(new ExpressionBinding("ForeColor",
                        "Iif([CallStatus] = 'Answered', '#27AE60', Iif([CallStatus] = 'Abandoned', '#E74C3C', Iif([CallStatus] = 'Missed', '#F1C40F', '#34495E')))"));
                }

                dataRow.Cells.Add(cell);
            }
            dataTable.Rows.Add(dataRow);
            detail.Controls.Add(dataTable);

            this.Bands.Add(detail);

            // === PAGE FOOTER ===
            var pageFooter = new PageFooterBand { HeightF = 20 };
            pageFooter.BackColor = ColorBackground;

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

            var pageInfo = new XRPageInfo
            {
                Format = "Page {0} of {1}",
                SizeF = new SizeF(80, 14),
                LocationFloat = new PointFloat(contentWidth - 70, 3),
                Font = new Font("Segoe UI", 7),
                ForeColor = Color.Gray,
                TextAlignment = TextAlignment.TopRight
            };
            pageFooter.Controls.Add(pageInfo);

            this.Bands.Add(pageFooter);
        }
    }
}
