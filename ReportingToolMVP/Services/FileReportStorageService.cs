using DevExpress.XtraReports.UI;
using DevExpress.XtraReports.Web.Extensions;
using Microsoft.Extensions.Caching.Memory;
using System.IO;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// File-based report storage service for saving/loading .repx report templates.
    /// Reports are stored in the Reports folder in the application root.
    /// Uses IMemoryCache to avoid repeated disk reads for unchanged reports.
    /// </summary>
    public class FileReportStorageService : ReportStorageWebExtension
    {
        private readonly string _reportsDirectory;
        private readonly string _templatesDirectory;
        private readonly ILogger<FileReportStorageService> _logger;
        private readonly IMemoryCache _cache;

        // Cache keys
        private const string UrlsCacheKey = "ReportUrls";
        private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(10);

        public FileReportStorageService(
            IWebHostEnvironment environment,
            ILogger<FileReportStorageService> logger,
            IMemoryCache cache)
        {
            _logger = logger;
            _cache = cache;
            _reportsDirectory = Path.Combine(environment.ContentRootPath, "Reports");
            _templatesDirectory = Path.Combine(_reportsDirectory, "Templates");
            
            // Ensure the Reports directories exist
            if (!Directory.Exists(_reportsDirectory))
            {
                Directory.CreateDirectory(_reportsDirectory);
                _logger.LogInformation($"Created Reports directory at: {_reportsDirectory}");
            }
            
            if (!Directory.Exists(_templatesDirectory))
            {
                Directory.CreateDirectory(_templatesDirectory);
                _logger.LogInformation($"Created Templates directory at: {_templatesDirectory}");
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
        /// Supports code-based reports (QueueDashboardReport) and .repx files
        /// </summary>
        public override byte[] GetData(string url)
        {
            try
            {
                // Handle empty URL - return a blank report for new report creation
                if (string.IsNullOrEmpty(url))
                {
                    _logger.LogInformation("Creating new blank report");
                    var blankReport = new ReportingToolMVP.Reports.CodeBased.BlankReport();
                    using (var stream = new MemoryStream())
                    {
                        blankReport.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                // Handle code-based reports
                if (url == "QueueDashboardReport" || url == "Queue Dashboard Report")
                {
                    _logger.LogInformation("Loading code-based QueueDashboardReport");
                    var report = new ReportingToolMVP.Reports.CodeBased.QueueDashboardReport();
                    using (var stream = new MemoryStream())
                    {
                        report.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                if (url == "CallDetailsReport" || url == "Call Details Report")
                {
                    _logger.LogInformation("Loading code-based CallDetailsReport");
                    var report = new ReportingToolMVP.Reports.CodeBased.CallDetailsReport();
                    using (var stream = new MemoryStream())
                    {
                        report.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                var filePath = GetReportFilePath(url);
                
                if (!File.Exists(filePath))
                {
                    _logger.LogWarning($"Report file not found: {filePath}. Creating blank report.");
                    // Return blank report instead of throwing error
                    var blankReport = new ReportingToolMVP.Reports.CodeBased.BlankReport();
                    using (var stream = new MemoryStream())
                    {
                        blankReport.SaveLayoutToXml(stream);
                        return stream.ToArray();
                    }
                }

                // Use cache with file-modified timestamp as invalidation key
                var lastWrite = File.GetLastWriteTimeUtc(filePath).Ticks;
                var cacheKey = $"Report_{url}_{lastWrite}";

                return _cache.GetOrCreate(cacheKey, entry =>
                {
                    entry.SetAbsoluteExpiration(CacheDuration);
                    entry.SetSize(1); // for SizeLimit if ever configured
                    _logger.LogInformation($"Loading report from disk (cache miss): {filePath}");
                    return File.ReadAllBytes(filePath);
                })!;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error loading report: {url}");
                throw;
            }
        }

        /// <summary>
        /// Returns a dictionary of available report URLs and display names
        /// Includes both .repx files and code-based reports
        /// </summary>
        public override Dictionary<string, string> GetUrls()
        {
            // Cache the URL list to avoid directory scans on every call
            return _cache.GetOrCreate(UrlsCacheKey, entry =>
            {
                entry.SetAbsoluteExpiration(CacheDuration);
                return BuildReportUrlDictionary();
            })!;
        }

        private Dictionary<string, string> BuildReportUrlDictionary()
        {
            var reports = new Dictionary<string, string>();

            try
            {
                // Add code-based reports first
                reports["QueueDashboardReport"] = "Queue Dashboard (Code-Based)";
                reports["CallDetailsReport"] = "Call Details (Code-Based)";

                // Look in Templates subfolder for .repx files
                if (Directory.Exists(_templatesDirectory))
                {
                    var reportFiles = Directory.GetFiles(_templatesDirectory, "*.repx");
                    
                    foreach (var file in reportFiles)
                    {
                        var fileName = Path.GetFileNameWithoutExtension(file);
                        var displayName = FormatDisplayName(fileName);
                        reports[fileName] = displayName;
                    }
                }
                
                // Also check root Reports folder for backward compatibility
                if (Directory.Exists(_reportsDirectory))
                {
                    var rootReportFiles = Directory.GetFiles(_reportsDirectory, "*.repx");
                    foreach (var file in rootReportFiles)
                    {
                        var fileName = Path.GetFileNameWithoutExtension(file);
                        if (!reports.ContainsKey(fileName))
                        {
                            var displayName = FormatDisplayName(fileName);
                            reports[fileName] = displayName;
                        }
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

                // Invalidate caches so next read picks up changes
                _cache.Remove(UrlsCacheKey);
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
        /// Checks Templates folder first, then root Reports folder
        /// </summary>
        private string GetReportFilePath(string url)
        {
            // Ensure .repx extension
            var fileName = url.EndsWith(".repx", StringComparison.OrdinalIgnoreCase) 
                ? url 
                : $"{url}.repx";
            
            // Check Templates folder first (preferred location)
            var templatesPath = Path.Combine(_templatesDirectory, fileName);
            if (File.Exists(templatesPath))
            {
                return templatesPath;
            }
            
            // Fall back to root Reports folder for backward compatibility
            var rootPath = Path.Combine(_reportsDirectory, fileName);
            if (File.Exists(rootPath))
            {
                return rootPath;
            }
            
            // Default to Templates folder for new reports
            return templatesPath;
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
