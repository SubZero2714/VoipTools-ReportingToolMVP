using DevExpress.XtraReports.UI;
using DevExpress.XtraReports.Web.Extensions;
using System.IO;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// File-based report storage service for saving/loading .repx report templates
    /// Reports are stored in the Reports folder in the application root
    /// </summary>
    public class FileReportStorageService : ReportStorageWebExtension
    {
        private readonly string _reportsDirectory;
        private readonly ILogger<FileReportStorageService> _logger;

        public FileReportStorageService(IWebHostEnvironment environment, ILogger<FileReportStorageService> logger)
        {
            _logger = logger;
            _reportsDirectory = Path.Combine(environment.ContentRootPath, "Reports");
            
            // Ensure the Reports directory exists
            if (!Directory.Exists(_reportsDirectory))
            {
                Directory.CreateDirectory(_reportsDirectory);
                _logger.LogInformation($"Created Reports directory at: {_reportsDirectory}");
            }
        }

        /// <summary>
        /// Determines whether a report with the specified URL can be set (saved/updated)
        /// </summary>
        public override bool CanSetData(string url)
        {
            // Allow saving any report
            return true;
        }

        /// <summary>
        /// Determines whether a new report with the specified URL is valid for creation
        /// </summary>
        public override bool IsValidUrl(string url)
        {
            // Validate URL - must be a valid filename without path separators
            return !string.IsNullOrEmpty(url) && 
                   !url.Contains("..") && 
                   !Path.IsPathRooted(url) &&
                   url.IndexOfAny(Path.GetInvalidFileNameChars().Where(c => c != '.').ToArray()) < 0;
        }

        /// <summary>
        /// Loads report data from the file system
        /// Returns a blank report if URL is empty (for new report creation)
        /// </summary>
        public override byte[] GetData(string url)
        {
            try
            {
                // Handle empty URL - return a blank report for new report creation
                if (string.IsNullOrEmpty(url))
                {
                    _logger.LogInformation("Creating new blank report");
                    var blankReport = new ReportingToolMVP.Reports.BlankReport();
                    using (var stream = new MemoryStream())
                    {
                        blankReport.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                var filePath = GetReportFilePath(url);
                
                if (!File.Exists(filePath))
                {
                    _logger.LogWarning($"Report file not found: {filePath}. Creating blank report.");
                    // Return blank report instead of throwing error
                    var blankReport = new ReportingToolMVP.Reports.BlankReport();
                    using (var stream = new MemoryStream())
                    {
                        blankReport.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                _logger.LogInformation($"Loading report from: {filePath}");
                return File.ReadAllBytes(filePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error loading report: {url}");
                throw;
            }
        }

        /// <summary>
        /// Returns a dictionary of available report URLs and display names
        /// </summary>
        public override Dictionary<string, string> GetUrls()
        {
            var reports = new Dictionary<string, string>();

            try
            {
                if (Directory.Exists(_reportsDirectory))
                {
                    var reportFiles = Directory.GetFiles(_reportsDirectory, "*.repx");
                    
                    foreach (var file in reportFiles)
                    {
                        var fileName = Path.GetFileNameWithoutExtension(file);
                        var displayName = FormatDisplayName(fileName);
                        reports[fileName] = displayName;
                    }
                }

                _logger.LogInformation($"Found {reports.Count} reports in storage");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting report URLs");
            }

            return reports;
        }

        /// <summary>
        /// Saves report data to the file system
        /// </summary>
        public override void SetData(XtraReport report, string url)
        {
            try
            {
                var filePath = GetReportFilePath(url);
                
                _logger.LogInformation($"Saving report to: {filePath}");
                
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    report.SaveLayoutToXml(stream);
                }

                _logger.LogInformation($"Report saved successfully: {url}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error saving report: {url}");
                throw;
            }
        }

        /// <summary>
        /// Generates a new unique report name if the specified URL already exists
        /// </summary>
        public override string SetNewData(XtraReport report, string defaultUrl)
        {
            try
            {
                var url = defaultUrl;
                var counter = 1;

                // Generate unique filename if exists
                while (File.Exists(GetReportFilePath(url)))
                {
                    url = $"{defaultUrl}_{counter}";
                    counter++;
                }

                SetData(report, url);
                return url;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error creating new report: {defaultUrl}");
                throw;
            }
        }

        /// <summary>
        /// Gets the full file path for a report URL
        /// </summary>
        private string GetReportFilePath(string url)
        {
            // Ensure .repx extension
            var fileName = url.EndsWith(".repx", StringComparison.OrdinalIgnoreCase) 
                ? url 
                : $"{url}.repx";
            
            return Path.Combine(_reportsDirectory, fileName);
        }

        /// <summary>
        /// Formats a filename into a display-friendly name
        /// </summary>
        private string FormatDisplayName(string fileName)
        {
            // Convert PascalCase or snake_case to readable format
            var result = fileName
                .Replace("_", " ")
                .Replace("-", " ");

            // Add spaces before capital letters (for PascalCase)
            for (int i = result.Length - 1; i > 0; i--)
            {
                if (char.IsUpper(result[i]) && !char.IsUpper(result[i - 1]) && result[i - 1] != ' ')
                {
                    result = result.Insert(i, " ");
                }
            }

            return result.Trim();
        }
    }
}
