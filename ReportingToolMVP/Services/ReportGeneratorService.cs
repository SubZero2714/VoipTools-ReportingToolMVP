using DevExpress.XtraReports.UI;
using ReportingToolMVP.Models;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Service to generate report output (PDF, XLSX, CSV) from a .repx template
    /// with the given parameter values. Used by the background scheduler.
    /// </summary>
    public interface IReportGeneratorService
    {
        Task<(byte[] Data, string FileName, string MimeType)> GenerateReportAsync(
            string reportName,
            Dictionary<string, string> parameters,
            ExportFormat format);
    }

    public class ReportGeneratorService : IReportGeneratorService
    {
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<ReportGeneratorService> _logger;

        public ReportGeneratorService(
            IWebHostEnvironment environment,
            ILogger<ReportGeneratorService> logger)
        {
            _environment = environment;
            _logger = logger;
        }

        public async Task<(byte[] Data, string FileName, string MimeType)> GenerateReportAsync(
            string reportName,
            Dictionary<string, string> parameters,
            ExportFormat format)
        {
            // Locate the .repx file
            var repxPath = FindRepxFile(reportName);
            if (repxPath == null)
                throw new FileNotFoundException($"Report template not found: {reportName}");

            _logger.LogInformation("Generating report '{Report}' as {Format}", reportName, format);

            // Load the report from .repx
            var report = new XtraReport();
            report.LoadLayoutFromXml(repxPath);

            // Set parameters
            foreach (var param in parameters)
            {
                var reportParam = report.Parameters[param.Key];
                if (reportParam != null)
                {
                    reportParam.Value = ConvertParameterValue(reportParam.Type, param.Value);
                    _logger.LogDebug("Set param {Key} = {Value} (type: {Type})", param.Key, param.Value, reportParam.Type);
                }
            }

            // Generate the report data
            using var stream = new MemoryStream();
            string extension;
            string mimeType;

            switch (format)
            {
                case ExportFormat.XLSX:
                    await Task.Run(() => report.ExportToXlsx(stream));
                    extension = ".xlsx";
                    mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                    break;

                case ExportFormat.CSV:
                    await Task.Run(() => report.ExportToCsv(stream));
                    extension = ".csv";
                    mimeType = "text/csv";
                    break;

                case ExportFormat.PDF:
                default:
                    await Task.Run(() => report.ExportToPdf(stream));
                    extension = ".pdf";
                    mimeType = "application/pdf";
                    break;
            }

            var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            var safeReportName = reportName.Replace(" ", "_");
            var fileName = $"{safeReportName}_{timestamp}{extension}";

            _logger.LogInformation("Generated {Format} report: {File} ({Size} bytes)",
                format, fileName, stream.Length);

            return (stream.ToArray(), fileName, mimeType);
        }

        private string? FindRepxFile(string reportName)
        {
            var templatesDir = Path.Combine(_environment.ContentRootPath, "Reports", "Templates");
            var reportsDir = Path.Combine(_environment.ContentRootPath, "Reports");

            // Try exact match with .repx extension
            var candidates = new[]
            {
                Path.Combine(templatesDir, reportName + ".repx"),
                Path.Combine(templatesDir, reportName),
                Path.Combine(reportsDir, reportName + ".repx"),
                Path.Combine(reportsDir, reportName),
            };

            return candidates.FirstOrDefault(File.Exists);
        }

        private static object? ConvertParameterValue(Type paramType, string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return null;

            if (paramType == typeof(DateTime))
                return DateTime.Parse(value);
            if (paramType == typeof(int) || paramType == typeof(Int32))
                return int.Parse(value);
            if (paramType == typeof(decimal))
                return decimal.Parse(value);
            if (paramType == typeof(double))
                return double.Parse(value);
            if (paramType == typeof(bool))
                return bool.Parse(value);

            return value; // string
        }
    }
}
