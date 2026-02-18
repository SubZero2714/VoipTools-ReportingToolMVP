using ReportingToolMVP.Models;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Background service that checks for due report schedules and executes them.
    /// Runs every 60 seconds, checks the database for schedules where next_run_utc <= now,
    /// generates the report, and emails it.
    /// </summary>
    public class ReportSchedulerBackgroundService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<ReportSchedulerBackgroundService> _logger;
        private readonly TimeSpan _checkInterval = TimeSpan.FromSeconds(60);

        public ReportSchedulerBackgroundService(
            IServiceProvider serviceProvider,
            ILogger<ReportSchedulerBackgroundService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Report Scheduler Background Service started.");

            // Wait 30 seconds on startup before first check (let the app fully initialize)
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessDueSchedulesAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in Report Scheduler loop.");
                }

                await Task.Delay(_checkInterval, stoppingToken);
            }

            _logger.LogInformation("Report Scheduler Background Service stopped.");
        }

        private async Task ProcessDueSchedulesAsync(CancellationToken ct)
        {
            using var scope = _serviceProvider.CreateScope();
            var repo = scope.ServiceProvider.GetRequiredService<IReportScheduleRepository>();
            var generator = scope.ServiceProvider.GetRequiredService<IReportGeneratorService>();
            var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();

            var dueSchedules = await repo.GetDueSchedulesAsync(DateTime.UtcNow);

            if (dueSchedules.Count == 0)
                return;

            _logger.LogInformation("Found {Count} due report schedule(s) to process.", dueSchedules.Count);

            foreach (var schedule in dueSchedules)
            {
                if (ct.IsCancellationRequested) break;

                await ExecuteScheduleAsync(schedule, repo, generator, emailService);
            }
        }

        private async Task ExecuteScheduleAsync(
            ReportSchedule schedule,
            IReportScheduleRepository repo,
            IReportGeneratorService generator,
            IEmailService emailService)
        {
            _logger.LogInformation("Executing schedule '{Name}' (ID: {Id}) - Report: {Report}",
                schedule.ScheduleName, schedule.Id, schedule.ReportName);

            // Mark as running
            await repo.UpdateRunStatusAsync(schedule.Id, RunStatus.Running, null, schedule.NextRunUtc);

            try
            {
                // 1. Generate the report
                var parameters = schedule.GetReportParams();
                var (data, fileName, mimeType) = await generator.GenerateReportAsync(
                    schedule.ReportName, parameters, schedule.ExportFormat);

                // 2. Build email subject & body
                var subject = schedule.EmailSubject
                    ?? $"Scheduled Report: {FormatReportName(schedule.ReportName)} - {DateTime.Now:MMM dd, yyyy}";

                var body = schedule.EmailBody ?? BuildDefaultEmailBody(schedule, fileName);

                // 3. Send the email
                await emailService.SendReportEmailAsync(
                    schedule.EmailTo,
                    schedule.EmailCc,
                    subject,
                    body,
                    data,
                    fileName,
                    mimeType);

                // 4. Calculate next run and update status
                var nextRun = CalculateNextRun(schedule);
                await repo.UpdateRunStatusAsync(schedule.Id, RunStatus.Success, null, nextRun);

                _logger.LogInformation("Schedule '{Name}' completed. Next run: {Next}",
                    schedule.ScheduleName, nextRun);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Schedule '{Name}' (ID: {Id}) failed.", schedule.ScheduleName, schedule.Id);

                // Keep the same next_run so it retries next cycle, but record the error
                var nextRun = CalculateNextRun(schedule);
                await repo.UpdateRunStatusAsync(schedule.Id, RunStatus.Failed, ex.Message, nextRun);
            }
        }

        /// <summary>
        /// Calculates the next run time based on frequency and schedule settings.
        /// </summary>
        public static DateTime CalculateNextRun(ReportSchedule schedule)
        {
            try
            {
                var tz = TimeZoneInfo.FindSystemTimeZoneById(schedule.Timezone);
                var nowLocal = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
                DateTime nextLocal;

                switch (schedule.Frequency)
                {
                    case ScheduleFrequency.Daily:
                        nextLocal = nowLocal.Date.Add(schedule.ScheduledTime.ToTimeSpan());
                        if (nextLocal <= nowLocal)
                            nextLocal = nextLocal.AddDays(1);
                        break;

                    case ScheduleFrequency.Weekly:
                        var targetDay = schedule.DayOfWeek ?? DayOfWeek.Monday;
                        nextLocal = nowLocal.Date.Add(schedule.ScheduledTime.ToTimeSpan());
                        // Find next occurrence of target day
                        var daysUntilTarget = ((int)targetDay - (int)nowLocal.DayOfWeek + 7) % 7;
                        if (daysUntilTarget == 0 && nextLocal <= nowLocal)
                            daysUntilTarget = 7;
                        nextLocal = nextLocal.AddDays(daysUntilTarget);
                        break;

                    case ScheduleFrequency.Monthly:
                        var targetDayOfMonth = schedule.DayOfMonth ?? 1;
                        var year = nowLocal.Year;
                        var month = nowLocal.Month;
                        var day = Math.Min(targetDayOfMonth, DateTime.DaysInMonth(year, month));
                        nextLocal = new DateTime(year, month, day).Add(schedule.ScheduledTime.ToTimeSpan());
                        if (nextLocal <= nowLocal)
                        {
                            month++;
                            if (month > 12) { month = 1; year++; }
                            day = Math.Min(targetDayOfMonth, DateTime.DaysInMonth(year, month));
                            nextLocal = new DateTime(year, month, day).Add(schedule.ScheduledTime.ToTimeSpan());
                        }
                        break;

                    default:
                        return DateTime.UtcNow.AddDays(1);
                }

                return TimeZoneInfo.ConvertTimeToUtc(nextLocal, tz);
            }
            catch
            {
                // Fallback: schedule for tomorrow at the configured time
                return DateTime.UtcNow.AddDays(1);
            }
        }

        private static string FormatReportName(string reportName)
        {
            return reportName
                .Replace("_", " ")
                .Replace(".repx", "")
                .Trim();
        }

        private static string BuildDefaultEmailBody(ReportSchedule schedule, string fileName)
        {
            var reportDisplayName = FormatReportName(schedule.ReportName);
            return $@"
<html>
<body style='font-family: Arial, sans-serif; color: #333;'>
    <h2 style='color: #4361ee;'>VoIPTools Scheduled Report</h2>
    <p>Your scheduled report has been generated and is attached to this email.</p>
    <table style='border-collapse: collapse; margin: 16px 0;'>
        <tr><td style='padding: 6px 16px 6px 0; font-weight: bold;'>Report:</td><td>{reportDisplayName}</td></tr>
        <tr><td style='padding: 6px 16px 6px 0; font-weight: bold;'>Schedule:</td><td>{schedule.GetScheduleDescription()}</td></tr>
        <tr><td style='padding: 6px 16px 6px 0; font-weight: bold;'>Format:</td><td>{schedule.ExportFormat}</td></tr>
        <tr><td style='padding: 6px 16px 6px 0; font-weight: bold;'>Generated:</td><td>{DateTime.Now:MMM dd, yyyy hh:mm tt}</td></tr>
        <tr><td style='padding: 6px 16px 6px 0; font-weight: bold;'>Attachment:</td><td>{fileName}</td></tr>
    </table>
    <p style='color: #6c757d; font-size: 0.85em;'>This is an automated email from VoIPTools Reporting. 
    To change or cancel this schedule, visit the Schedule Reports page in the Report Designer application.</p>
</body>
</html>";
        }
    }
}
