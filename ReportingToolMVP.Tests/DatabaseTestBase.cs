using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace ReportingToolMVP.Tests;

/// <summary>
/// Base class for all data integrity tests.
/// Provides shared database connection, test parameters, and helper methods.
/// </summary>
public abstract class DatabaseTestBase : IDisposable
{
    protected readonly string ConnectionString;
    protected readonly DateTimeOffset PeriodFrom;
    protected readonly DateTimeOffset PeriodTo;
    protected readonly string SingleQueue;
    protected readonly string MultiQueue;
    protected readonly string InvalidQueue;
    protected readonly TimeSpan WaitInterval;

    protected DatabaseTestBase()
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.Test.json", optional: false)
            .Build();

        ConnectionString = config.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("DefaultConnection not found in appsettings.Test.json");

        var testParams = config.GetSection("TestParameters");
        PeriodFrom = DateTimeOffset.Parse(testParams["PeriodFrom"]!);
        PeriodTo = DateTimeOffset.Parse(testParams["PeriodTo"]!).Date.AddDays(1).AddSeconds(-1); // end of day
        SingleQueue = testParams["SingleQueue"]!;
        MultiQueue = testParams["MultiQueue"]!;
        InvalidQueue = testParams["InvalidQueue"]!;
        WaitInterval = TimeSpan.Parse(testParams["WaitInterval"]!);
    }

    protected SqlConnection CreateConnection()
    {
        var conn = new SqlConnection(ConnectionString);
        conn.Open();
        return conn;
    }

    /// <summary>
    /// Execute a stored procedure and return results as a DataTable
    /// </summary>
    protected DataTable ExecuteSP(SqlConnection conn, string spName,
        DateTimeOffset from, DateTimeOffset to, string queueDns, string waitInterval)
    {
        using var cmd = new SqlCommand(spName, conn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 30 };
        cmd.Parameters.AddWithValue("@period_from", from);
        cmd.Parameters.AddWithValue("@period_to", to);
        cmd.Parameters.AddWithValue("@queue_dns", queueDns);
        cmd.Parameters.AddWithValue("@wait_interval", TimeSpan.Parse(waitInterval));

        var dt = new DataTable();
        using var adapter = new SqlDataAdapter(cmd);
        adapter.Fill(dt);
        return dt;
    }

    /// <summary>
    /// Get raw count from CallCent_QueueCalls_View for cross-validation
    /// </summary>
    protected (int total, int answered, int abandoned, int sla) GetRawCounts(
        SqlConnection conn, DateTimeOffset from, DateTimeOffset to, string queueDns, TimeSpan wait)
    {
        var queueList = string.Join(",", queueDns.Split(',').Select(q => $"'{q.Trim()}'"));

        var sql = $@"
            SELECT
                COUNT(*) AS total,
                SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END) AS answered,
                SUM(CASE WHEN is_answered = 0 THEN 1 ELSE 0 END) AS abandoned,
                SUM(CASE WHEN is_answered = 1 AND ring_time <= @wait THEN 1 ELSE 0 END) AS sla
            FROM CallCent_QueueCalls_View WITH (NOLOCK)
            WHERE time_start BETWEEN @from AND @to
              AND q_num IN ({queueList})
              AND (is_answered = 1 OR ring_time >= @wait)";

        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 30 };
        cmd.Parameters.AddWithValue("@from", from);
        cmd.Parameters.AddWithValue("@to", to);
        cmd.Parameters.AddWithValue("@wait", wait);

        using var reader = cmd.ExecuteReader();
        if (reader.Read())
        {
            return (
                reader.GetInt32(0),
                reader.GetInt32(1),
                reader.GetInt32(2),
                reader.GetInt32(3)
            );
        }
        return (0, 0, 0, 0);
    }

    public void Dispose()
    {
        GC.SuppressFinalize(this);
    }
}
