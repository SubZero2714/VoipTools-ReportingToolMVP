using ReportingToolMVP.Models;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Interface for report export functionality
    /// Handles PDF, Excel, and CSV exports
    /// </summary>
    public interface IReportExportService
    {
        /// <summary>
        /// Exports report data to Excel format
        /// </summary>
        Task<byte[]> ExportToExcelAsync(
            List<Dictionary<string, object>> data,
            string reportTitle,
            Dictionary<string, string>? columnFormats = null);

        /// <summary>
        /// Exports report data to CSV format
        /// </summary>
        Task<byte[]> ExportToCsvAsync(
            List<Dictionary<string, object>> data,
            string reportTitle);

        /// <summary>
        /// Exports report data to PDF format
        /// </summary>
        Task<byte[]> ExportToPdfAsync(
            List<Dictionary<string, object>> data,
            string reportTitle,
            Dictionary<string, object>? chartData = null);

        /// <summary>
        /// Generates a standardized file name for exports
        /// </summary>
        string GenerateFileName(string reportName, string fileFormat);
    }
}
