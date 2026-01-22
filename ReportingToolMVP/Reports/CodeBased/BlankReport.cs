using DevExpress.XtraReports.UI;

namespace ReportingToolMVP.Reports.CodeBased
{
    /// <summary>
    /// A blank starter report that serves as a template for new reports
    /// </summary>
    public class BlankReport : XtraReport
    {
        public BlankReport()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            // Set basic report properties
            this.ReportUnit = ReportUnit.HundredthsOfAnInch;
            this.PageWidth = 850;
            this.PageHeight = 1100;

            // Create a detail band (required for any report)
            var detailBand = new DetailBand();
            detailBand.Name = "Detail";
            detailBand.HeightF = 100F;
            this.Bands.Add(detailBand);

            // Create a page header band
            var pageHeader = new PageHeaderBand();
            pageHeader.Name = "PageHeader";
            pageHeader.HeightF = 50F;
            this.Bands.Add(pageHeader);

            // Create a page footer band
            var pageFooter = new PageFooterBand();
            pageFooter.Name = "PageFooter";
            pageFooter.HeightF = 30F;
            this.Bands.Add(pageFooter);
        }
    }
}
