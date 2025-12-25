using ReportingToolMVP.Models;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Interface for custom report data retrieval
    /// Handles dynamic query building based on user selections
    /// </summary>
    public interface ICustomReportService
    {
        /// <summary>
        /// Gets all available queues for dropdown/selection
        /// </summary>
        Task<List<QueueBasicInfo>> GetQueuesAsync();

        /// <summary>
        /// Gets custom report data based on user selections
        /// </summary>
        Task<List<Dictionary<string, object>>> GetCustomReportDataAsync(
            DateTime startDate, 
            DateTime endDate, 
            List<string> selectedColumns, 
            List<string> selectedQueueIds,
            int maxRows = 10000);

        /// <summary>
        /// Gets all available columns that can be selected in reports
        /// </summary>
        Task<List<string>> GetAvailableColumnsAsync();

        /// <summary>
        /// Validates if a column name is allowed (whitelist check)
        /// </summary>
        bool IsColumnAllowed(string columnName);
    }
}
