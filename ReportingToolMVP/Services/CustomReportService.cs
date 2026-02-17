using Dapper;
using Microsoft.Data.SqlClient;
using ReportingToolMVP.Models;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Service for building and executing custom reports from 3CX Exporter database
    /// </summary>
    public class CustomReportService : ICustomReportService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<CustomReportService> _logger;

        // Whitelist of allowed columns to prevent SQL injection
        // Based on callcent_queuecalls table structure
        private static readonly Dictionary<string, string> AllowedColumns = new()
        {
            { "QueueNumber", "[q_num] as [QueueNumber]" },
            { "TotalCalls", "COUNT(*) as [TotalCalls]" },
            { "PolledCount", "SUM([count_polls]) as [PolledCount]" },
            { "DialedCount", "SUM([count_dialed]) as [DialedCount]" },
            { "RejectedCount", "SUM([count_rejected]) as [RejectedCount]" },
            { "AvgWaitTime", "AVG(DATEDIFF(SECOND, 0, [ts_waiting])) as [AvgWaitTime]" },
            { "AvgServiceTime", "AVG(DATEDIFF(SECOND, 0, [ts_servicing])) as [AvgServiceTime]" },
            { "Date", "CAST([time_start] AS DATE) as [Date]" },
        };

        public CustomReportService(IConfiguration configuration, ILogger<CustomReportService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        /// <summary>
        /// Get list of all available queues (from call data with actual records)
        /// </summary>
        public async Task<List<QueueBasicInfo>> GetQueuesAsync()
        {
            try
            {
                var connectionString = _configuration.GetConnectionString("DefaultConnection");
                
                using (var connection = new SqlConnection(connectionString))
                {
                    await connection.OpenAsync();
                    
                    // Get queues from call data that have actual records
                    // Join with queue table for names where available
                    var sql = @"
                        SELECT 
                            c.q_num as QueueId,
                            ISNULL(q.name, 'Queue ' + c.q_num) as QueueName
                        FROM (
                            SELECT DISTINCT q_num FROM [dbo].[callcent_queuecalls]
                        ) c
                        LEFT JOIN [dbo].[dn] d ON c.q_num = d.iddn
                        LEFT JOIN [dbo].[queue] q ON d.iddn = q.fkiddn
                        ORDER BY c.q_num
                    ";
                    
                    var queues = (await connection.QueryAsync<QueueBasicInfo>(sql, commandTimeout: 15)).ToList();
                    
                    _logger.LogInformation($"Retrieved {queues.Count} queues from database");
                    return queues;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error retrieving queues: {ex.Message}", ex);
                throw;
            }
        }

        /// <summary>
        /// Get custom report data based on selected columns and filters
        /// </summary>
        public async Task<List<Dictionary<string, object>>> GetCustomReportDataAsync(
            DateTime startDate,
            DateTime endDate,
            List<string> selectedColumns,
            List<string> selectedQueueIds,
            int maxRows = 10000)
        {
            try
            {
                if (selectedColumns == null || !selectedColumns.Any())
                {
                    throw new ArgumentException("At least one column must be selected");
                }

                // Validate columns exist in whitelist
                var invalidColumns = selectedColumns.Where(c => !AllowedColumns.ContainsKey(c)).ToList();
                if (invalidColumns.Any())
                {
                    throw new ArgumentException($"Invalid columns: {string.Join(", ", invalidColumns)}");
                }

                // Build SELECT clause
                var selectParts = new List<string>();
                foreach (var col in selectedColumns)
                {
                    if (AllowedColumns.TryGetValue(col, out var sqlExpression))
                    {
                        selectParts.Add(sqlExpression);
                    }
                }

                var selectClause = string.Join(",\n", selectParts);

                // Build WHERE clause
                var whereClauses = new List<string>
                {
                    "[time_start] >= @StartDate",
                    "[time_start] < DATEADD(DAY, 1, @EndDate)"
                };

                if (selectedQueueIds != null && selectedQueueIds.Any())
                {
                    // q_num is varchar - quote values as strings for proper comparison
                    var queueIdList = string.Join(",", selectedQueueIds.Select(q => $"'{q.Trim('"').Replace("'", "''")}'"));
                    whereClauses.Add($"[q_num] IN ({queueIdList})");
                }

                var whereClause = string.Join(" AND ", whereClauses);

                // Build GROUP BY clause (for aggregate functions)
                var groupByClauses = new List<string>();
                if (selectedColumns.Contains("QueueNumber"))
                {
                    groupByClauses.Add("[q_num]");
                }
                if (selectedColumns.Contains("Date"))
                {
                    groupByClauses.Add("CAST([time_start] AS DATE)");
                }

                var groupByClause = groupByClauses.Any() ? $"\nGROUP BY {string.Join(",", groupByClauses)}" : "";

                // Build ORDER BY clause - must use fields in GROUP BY or aggregate
                string orderByClause;
                if (selectedColumns.Contains("Date"))
                {
                    orderByClause = "ORDER BY CAST([time_start] AS DATE) DESC";
                }
                else if (selectedColumns.Contains("QueueNumber"))
                {
                    orderByClause = "ORDER BY [q_num]";
                }
                else if (groupByClauses.Any())
                {
                    // If we have GROUP BY but no Date/QueueNumber, order by first group column
                    orderByClause = $"ORDER BY {groupByClauses.First()}";
                }
                else
                {
                    orderByClause = "ORDER BY [time_start] DESC";
                }

                // Build final SQL
                var sql = $@"
                    SELECT TOP {maxRows}
                        {selectClause}
                    FROM [dbo].[callcent_queuecalls]
                    WHERE {whereClause}
                    {groupByClause}
                    {orderByClause}
                ";

                _logger.LogInformation($"Executing custom report query:\n{sql}");
                _logger.LogInformation($"Parameters: StartDate={startDate}, EndDate={endDate}, QueueIds=[{string.Join(",", selectedQueueIds ?? new List<string>())}]");
                var startTime = DateTime.Now;

                var connectionString = _configuration.GetConnectionString("DefaultConnection");
                using (var connection = new SqlConnection(connectionString))
                {
                    await connection.OpenAsync();
                    _logger.LogInformation("Database connection opened successfully.");
                    
                    var parameters = new DynamicParameters();
                    parameters.Add("@StartDate", startDate);
                    parameters.Add("@EndDate", endDate);

                    var results = (await connection.QueryAsync(sql, parameters, commandTimeout: 30)).ToList();
                    
                    var executionTime = (DateTime.Now - startTime).TotalSeconds;
                    _logger.LogInformation($"Query executed in {executionTime:F2} seconds. Returned {results.Count} rows.");

                    // Convert dynamic results to Dictionary<string, object>
                    var resultList = new List<Dictionary<string, object>>();
                    foreach (var row in results)
                    {
                        var dict = new Dictionary<string, object>();
                        foreach (var prop in ((IDictionary<string, object>)row))
                        {
                            dict[prop.Key] = prop.Value;
                        }
                        resultList.Add(dict);
                    }

                    return resultList;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error executing custom report: {ex.Message}", ex);
                throw;
            }
        }

        /// <summary>
        /// Get list of available columns for user selection
        /// </summary>
        public Task<List<string>> GetAvailableColumnsAsync()
        {
            var columns = AllowedColumns.Keys.ToList();
            return Task.FromResult(columns);
        }

        /// <summary>
        /// Validate if a column is allowed (whitelist check)
        /// </summary>
        public bool IsColumnAllowed(string columnName)
        {
            return AllowedColumns.ContainsKey(columnName);
        }
    }
}
