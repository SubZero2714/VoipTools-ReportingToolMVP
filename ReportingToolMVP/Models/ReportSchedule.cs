using System.Text.Json;

namespace ReportingToolMVP.Models
{
    /// <summary>
    /// Represents a scheduled report email configuration.
    /// Maps to the [report_schedules] SQL Server table.
    /// </summary>
    public class ReportSchedule
    {
        public int Id { get; set; }
        public string ScheduleName { get; set; } = string.Empty;
        public string ReportName { get; set; } = string.Empty;
        public bool IsEnabled { get; set; } = true;

        // Schedule Configuration
        public ScheduleFrequency Frequency { get; set; } = ScheduleFrequency.Weekly;
        public DayOfWeek? DayOfWeek { get; set; } = System.DayOfWeek.Monday;
        public int? DayOfMonth { get; set; }
        public TimeOnly ScheduledTime { get; set; } = new TimeOnly(8, 0); // 08:00 AM
        public string Timezone { get; set; } = "India Standard Time";

        // Report Parameters (stored as JSON in DB)
        public string? ReportParamsJson { get; set; }

        // Email Configuration
        public string EmailTo { get; set; } = string.Empty;
        public string? EmailCc { get; set; }
        public string? EmailSubject { get; set; }
        public string? EmailBody { get; set; }
        public ExportFormat ExportFormat { get; set; } = ExportFormat.PDF;

        // Tracking
        public DateTime? LastRunUtc { get; set; }
        public RunStatus? LastRunStatus { get; set; }
        public string? LastRunError { get; set; }
        public DateTime? NextRunUtc { get; set; }
        public int RunCount { get; set; }

        // Audit
        public string? CreatedBy { get; set; }
        public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedUtc { get; set; } = DateTime.UtcNow;

        // ── Helper Methods ──

        /// <summary>
        /// Gets the report parameters as a typed dictionary.
        /// </summary>
        public Dictionary<string, string> GetReportParams()
        {
            if (string.IsNullOrWhiteSpace(ReportParamsJson))
                return new Dictionary<string, string>();

            return JsonSerializer.Deserialize<Dictionary<string, string>>(ReportParamsJson)
                   ?? new Dictionary<string, string>();
        }

        /// <summary>
        /// Sets the report parameters from a dictionary.
        /// </summary>
        public void SetReportParams(Dictionary<string, string> parameters)
        {
            ReportParamsJson = JsonSerializer.Serialize(parameters);
        }

        /// <summary>
        /// Returns a human-readable schedule description.
        /// </summary>
        public string GetScheduleDescription()
        {
            var time = ScheduledTime.ToString("hh:mm tt");
            return Frequency switch
            {
                ScheduleFrequency.Daily => $"Daily at {time}",
                ScheduleFrequency.Weekly => $"Every {DayOfWeek} at {time}",
                ScheduleFrequency.Monthly => $"Monthly on day {DayOfMonth} at {time}",
                _ => "Unknown schedule"
            };
        }
    }

    public enum ScheduleFrequency
    {
        Daily,
        Weekly,
        Monthly
    }

    public enum ExportFormat
    {
        PDF,
        XLSX,
        CSV
    }

    public enum RunStatus
    {
        Success,
        Failed,
        Running
    }
}
