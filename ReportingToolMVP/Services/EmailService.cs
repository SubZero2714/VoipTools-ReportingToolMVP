using System.Net;
using System.Net.Mail;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// SMTP configuration from appsettings.json "SmtpSettings" section.
    /// </summary>
    public class SmtpSettings
    {
        public string Host { get; set; } = "smtp.gmail.com";
        public int Port { get; set; } = 587;
        public bool EnableSsl { get; set; } = true;
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string FromAddress { get; set; } = string.Empty;
        public string FromDisplayName { get; set; } = "VoIPTools Reporting";
    }

    /// <summary>
    /// Service for sending emails with report attachments via SMTP.
    /// </summary>
    public interface IEmailService
    {
        Task SendReportEmailAsync(
            string toAddresses,
            string? ccAddresses,
            string subject,
            string body,
            byte[] attachmentData,
            string attachmentFileName,
            string attachmentMimeType);
    }

    public class EmailService : IEmailService
    {
        private readonly SmtpSettings _settings;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
        {
            _settings = new SmtpSettings();
            configuration.GetSection("SmtpSettings").Bind(_settings);
            _logger = logger;
        }

        public async Task SendReportEmailAsync(
            string toAddresses,
            string? ccAddresses,
            string subject,
            string body,
            byte[] attachmentData,
            string attachmentFileName,
            string attachmentMimeType)
        {
            using var message = new MailMessage();
            message.From = new MailAddress(_settings.FromAddress, _settings.FromDisplayName);
            message.Subject = subject;
            message.Body = body;
            message.IsBodyHtml = true;

            // Parse To addresses (comma-separated)
            foreach (var addr in ParseAddresses(toAddresses))
            {
                message.To.Add(new MailAddress(addr));
            }

            // Parse CC addresses
            if (!string.IsNullOrWhiteSpace(ccAddresses))
            {
                foreach (var addr in ParseAddresses(ccAddresses))
                {
                    message.CC.Add(new MailAddress(addr));
                }
            }

            // Attach the report
            using var attachmentStream = new MemoryStream(attachmentData);
            var attachment = new Attachment(attachmentStream, attachmentFileName, attachmentMimeType);
            message.Attachments.Add(attachment);

            // Send
            using var client = new SmtpClient(_settings.Host, _settings.Port)
            {
                EnableSsl = _settings.EnableSsl,
                Credentials = new NetworkCredential(_settings.Username, _settings.Password),
                Timeout = 30000 // 30 seconds
            };

            _logger.LogInformation("Sending report email to {To} (CC: {Cc}), attachment: {File}",
                toAddresses, ccAddresses ?? "none", attachmentFileName);

            await client.SendMailAsync(message);

            _logger.LogInformation("Report email sent successfully to {To}", toAddresses);
        }

        private static IEnumerable<string> ParseAddresses(string addresses)
        {
            return addresses
                .Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(a => a.Trim())
                .Where(a => !string.IsNullOrEmpty(a));
        }
    }
}
