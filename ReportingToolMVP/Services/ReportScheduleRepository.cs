using Microsoft.Data.SqlClient;
using ReportingToolMVP.Models;
using System.Data;
using System.Text.Json;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Data access service for report schedule CRUD operations.
    /// Uses raw ADO.NET (Microsoft.Data.SqlClient) — no EF dependency needed.
    /// </summary>
    public interface IReportScheduleRepository
    {
        Task<List<ReportSchedule>> GetAllAsync();
        Task<ReportSchedule?> GetByIdAsync(int id);
        Task<List<ReportSchedule>> GetDueSchedulesAsync(DateTime utcNow);
        Task<int> CreateAsync(ReportSchedule schedule);
        Task UpdateAsync(ReportSchedule schedule);
        Task DeleteAsync(int id);
        Task UpdateRunStatusAsync(int id, RunStatus status, string? error, DateTime? nextRunUtc);
    }

    public class ReportScheduleRepository : IReportScheduleRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<ReportScheduleRepository> _logger;

        public ReportScheduleRepository(IConfiguration configuration, ILogger<ReportScheduleRepository> logger)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("DefaultConnection not found in appsettings.json");
            _logger = logger;
        }

        public async Task<List<ReportSchedule>> GetAllAsync()
        {
            var schedules = new List<ReportSchedule>();

            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(
                "SELECT * FROM report_schedules ORDER BY schedule_name", conn);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                schedules.Add(MapFromReader(reader));
            }

            return schedules;
        }

        public async Task<ReportSchedule?> GetByIdAsync(int id)
        {
            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(
                "SELECT * FROM report_schedules WHERE id = @id", conn);
            cmd.Parameters.AddWithValue("@id", id);

            using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapFromReader(reader) : null;
        }

        public async Task<List<ReportSchedule>> GetDueSchedulesAsync(DateTime utcNow)
        {
            var schedules = new List<ReportSchedule>();

            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(@"
                SELECT * FROM report_schedules 
                WHERE is_enabled = 1 
                  AND next_run_utc IS NOT NULL 
                  AND next_run_utc <= @utcNow
                  AND (last_run_status IS NULL OR last_run_status != 'Running')
                ORDER BY next_run_utc", conn);
            cmd.Parameters.AddWithValue("@utcNow", utcNow);

            using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                schedules.Add(MapFromReader(reader));
            }

            return schedules;
        }

        public async Task<int> CreateAsync(ReportSchedule schedule)
        {
            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(@"
                INSERT INTO report_schedules 
                    (schedule_name, report_name, is_enabled, frequency, day_of_week, day_of_month,
                     scheduled_time, timezone, report_params_json, email_to, email_cc, 
                     email_subject, email_body, export_format, next_run_utc, created_by, created_utc, updated_utc)
                VALUES 
                    (@schedule_name, @report_name, @is_enabled, @frequency, @day_of_week, @day_of_month,
                     @scheduled_time, @timezone, @report_params_json, @email_to, @email_cc,
                     @email_subject, @email_body, @export_format, @next_run_utc, @created_by, SYSUTCDATETIME(), SYSUTCDATETIME());
                SELECT SCOPE_IDENTITY();", conn);

            AddParameters(cmd, schedule);

            var result = await cmd.ExecuteScalarAsync();
            var newId = Convert.ToInt32(result);

            _logger.LogInformation("Created report schedule '{Name}' (ID: {Id})", schedule.ScheduleName, newId);
            return newId;
        }

        public async Task UpdateAsync(ReportSchedule schedule)
        {
            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(@"
                UPDATE report_schedules SET
                    schedule_name = @schedule_name,
                    report_name = @report_name,
                    is_enabled = @is_enabled,
                    frequency = @frequency,
                    day_of_week = @day_of_week,
                    day_of_month = @day_of_month,
                    scheduled_time = @scheduled_time,
                    timezone = @timezone,
                    report_params_json = @report_params_json,
                    email_to = @email_to,
                    email_cc = @email_cc,
                    email_subject = @email_subject,
                    email_body = @email_body,
                    export_format = @export_format,
                    next_run_utc = @next_run_utc,
                    updated_utc = SYSUTCDATETIME()
                WHERE id = @id", conn);

            cmd.Parameters.AddWithValue("@id", schedule.Id);
            AddParameters(cmd, schedule);

            await cmd.ExecuteNonQueryAsync();

            _logger.LogInformation("Updated report schedule '{Name}' (ID: {Id})", schedule.ScheduleName, schedule.Id);
        }

        public async Task DeleteAsync(int id)
        {
            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand("DELETE FROM report_schedules WHERE id = @id", conn);
            cmd.Parameters.AddWithValue("@id", id);

            await cmd.ExecuteNonQueryAsync();
            _logger.LogInformation("Deleted report schedule ID: {Id}", id);
        }

        public async Task UpdateRunStatusAsync(int id, RunStatus status, string? error, DateTime? nextRunUtc)
        {
            using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new SqlCommand(@"
                UPDATE report_schedules SET
                    last_run_utc = SYSUTCDATETIME(),
                    last_run_status = @status,
                    last_run_error = @error,
                    next_run_utc = @next_run_utc,
                    run_count = run_count + CASE WHEN @status = 'Success' THEN 1 ELSE 0 END,
                    updated_utc = SYSUTCDATETIME()
                WHERE id = @id", conn);

            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@status", status.ToString());
            cmd.Parameters.AddWithValue("@error", (object?)error ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@next_run_utc", (object?)nextRunUtc ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
        }

        // ── Private Helpers ──

        private static void AddParameters(SqlCommand cmd, ReportSchedule s)
        {
            cmd.Parameters.AddWithValue("@schedule_name", s.ScheduleName);
            cmd.Parameters.AddWithValue("@report_name", s.ReportName);
            cmd.Parameters.AddWithValue("@is_enabled", s.IsEnabled);
            cmd.Parameters.AddWithValue("@frequency", s.Frequency.ToString());
            cmd.Parameters.AddWithValue("@day_of_week", (object?)((int?)s.DayOfWeek) ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@day_of_month", (object?)s.DayOfMonth ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@scheduled_time", s.ScheduledTime.ToTimeSpan());
            cmd.Parameters.AddWithValue("@timezone", s.Timezone);
            cmd.Parameters.AddWithValue("@report_params_json", (object?)s.ReportParamsJson ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@email_to", s.EmailTo);
            cmd.Parameters.AddWithValue("@email_cc", (object?)s.EmailCc ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@email_subject", (object?)s.EmailSubject ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@email_body", (object?)s.EmailBody ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@export_format", s.ExportFormat.ToString());
            cmd.Parameters.AddWithValue("@next_run_utc", (object?)s.NextRunUtc ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@created_by", (object?)s.CreatedBy ?? DBNull.Value);
        }

        private static ReportSchedule MapFromReader(SqlDataReader reader)
        {
            return new ReportSchedule
            {
                Id = reader.GetInt32(reader.GetOrdinal("id")),
                ScheduleName = reader.GetString(reader.GetOrdinal("schedule_name")),
                ReportName = reader.GetString(reader.GetOrdinal("report_name")),
                IsEnabled = reader.GetBoolean(reader.GetOrdinal("is_enabled")),
                Frequency = Enum.Parse<ScheduleFrequency>(reader.GetString(reader.GetOrdinal("frequency"))),
                DayOfWeek = reader.IsDBNull(reader.GetOrdinal("day_of_week"))
                    ? null : (DayOfWeek)reader.GetInt32(reader.GetOrdinal("day_of_week")),
                DayOfMonth = reader.IsDBNull(reader.GetOrdinal("day_of_month"))
                    ? null : reader.GetInt32(reader.GetOrdinal("day_of_month")),
                ScheduledTime = TimeOnly.FromTimeSpan(reader.GetFieldValue<TimeSpan>(reader.GetOrdinal("scheduled_time"))),
                Timezone = reader.GetString(reader.GetOrdinal("timezone")),
                ReportParamsJson = reader.IsDBNull(reader.GetOrdinal("report_params_json"))
                    ? null : reader.GetString(reader.GetOrdinal("report_params_json")),
                EmailTo = reader.GetString(reader.GetOrdinal("email_to")),
                EmailCc = reader.IsDBNull(reader.GetOrdinal("email_cc"))
                    ? null : reader.GetString(reader.GetOrdinal("email_cc")),
                EmailSubject = reader.IsDBNull(reader.GetOrdinal("email_subject"))
                    ? null : reader.GetString(reader.GetOrdinal("email_subject")),
                EmailBody = reader.IsDBNull(reader.GetOrdinal("email_body"))
                    ? null : reader.GetString(reader.GetOrdinal("email_body")),
                ExportFormat = Enum.Parse<ExportFormat>(reader.GetString(reader.GetOrdinal("export_format"))),
                LastRunUtc = reader.IsDBNull(reader.GetOrdinal("last_run_utc"))
                    ? null : reader.GetDateTime(reader.GetOrdinal("last_run_utc")),
                LastRunStatus = reader.IsDBNull(reader.GetOrdinal("last_run_status"))
                    ? null : Enum.Parse<RunStatus>(reader.GetString(reader.GetOrdinal("last_run_status"))),
                LastRunError = reader.IsDBNull(reader.GetOrdinal("last_run_error"))
                    ? null : reader.GetString(reader.GetOrdinal("last_run_error")),
                NextRunUtc = reader.IsDBNull(reader.GetOrdinal("next_run_utc"))
                    ? null : reader.GetDateTime(reader.GetOrdinal("next_run_utc")),
                RunCount = reader.GetInt32(reader.GetOrdinal("run_count")),
                CreatedBy = reader.IsDBNull(reader.GetOrdinal("created_by"))
                    ? null : reader.GetString(reader.GetOrdinal("created_by")),
                CreatedUtc = reader.GetDateTime(reader.GetOrdinal("created_utc")),
                UpdatedUtc = reader.GetDateTime(reader.GetOrdinal("updated_utc"))
            };
        }
    }
}
