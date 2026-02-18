using DevExpress.XtraCharts;
using DevExpress.XtraReports.UI;
using DevExpress.XtraReports.Web.Extensions;
using Microsoft.Extensions.Caching.Memory;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

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
                    var blankReport = new XtraReport();
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
                    var blankReport = new XtraReport();
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
        /// Saves report data to the file system.
        /// Includes XML post-processing to preserve chart series data-binding properties
        /// (ArgumentDataMember, ValueDataMembersSerializable) that SaveLayoutToXml() strips.
        /// </summary>
        public override void SetData(XtraReport report, string url)
        {
            try
            {
                var filePath = GetReportFilePath(url);
                _logger.LogInformation($"Saving report to: {filePath}");

                // WORKAROUND: DevExpress SaveLayoutToXml() strips chart series
                // data-binding properties (ArgumentDataMember, ValueDataMembersSerializable)
                // when the SqlDataSource schema can't be validated at serialization time.
                // Step 1: Capture bindings from the in-memory report BEFORE serialization.
                var chartBindings = ExtractChartSeriesBindings(report);

                // Step 2: Serialize report to XML string
                string xml;
                using (var ms = new MemoryStream())
                {
                    report.SaveLayoutToXml(ms);
                    ms.Position = 0;
                    xml = new StreamReader(ms, Encoding.UTF8).ReadToEnd();
                }

                // Step 3: Post-process XML to restore any stripped chart bindings
                if (chartBindings.Count > 0)
                {
                    xml = PostProcessChartXml(xml, chartBindings);
                }

                // Step 4: Write corrected XML to disk
                File.WriteAllText(filePath, xml);

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

        // ── Chart Post-Processing Helpers ──────────────────────────────────

        /// <summary>
        /// Holds chart series data-binding properties captured from the in-memory report.
        /// </summary>
        private class ChartSeriesBinding
        {
            public string ChartName { get; set; } = "";
            public string SeriesName { get; set; } = "";
            public string ArgumentDataMember { get; set; } = "";
            public string ValueDataMembers { get; set; } = "";
        }

        /// <summary>
        /// Extracts chart series data-binding properties from the in-memory report object.
        /// These properties are captured BEFORE SaveLayoutToXml() which may strip them.
        /// </summary>
        private List<ChartSeriesBinding> ExtractChartSeriesBindings(XtraReport report)
        {
            var bindings = new List<ChartSeriesBinding>();

            foreach (var chart in FindAllControls<XRChart>(report))
            {
                foreach (Series series in chart.Series)
                {
                    var argMember = series.ArgumentDataMember ?? "";
                    var valMembers = series.ValueDataMembersSerializable ?? "";

                    if (!string.IsNullOrEmpty(argMember) || !string.IsNullOrEmpty(valMembers))
                    {
                        bindings.Add(new ChartSeriesBinding
                        {
                            ChartName = chart.Name,
                            SeriesName = series.Name,
                            ArgumentDataMember = argMember,
                            ValueDataMembers = valMembers
                        });
                        _logger.LogDebug(
                            "Captured chart '{Chart}' series '{Series}': Arg={Arg}, Val={Val}",
                            chart.Name, series.Name, argMember, valMembers);
                    }
                }
            }

            return bindings;
        }

        /// <summary>
        /// Post-processes serialized report XML to restore chart series data-binding
        /// properties that SaveLayoutToXml() strips. Also disables ValidateDataMembers
        /// on chart DataContainers to prevent runtime validation from clearing bindings.
        /// </summary>
        private string PostProcessChartXml(string xml, List<ChartSeriesBinding> bindings)
        {
            var modified = false;

            // 1. Disable ValidateDataMembers on all chart DataContainers.
            //    When true, DevExpress validates data member names against the cached
            //    schema and clears any it can't resolve (common with stored procedures).
            if (xml.Contains("ValidateDataMembers=\"true\""))
            {
                xml = xml.Replace("ValidateDataMembers=\"true\"", "ValidateDataMembers=\"false\"");
                modified = true;
            }

            // 2. For each series, ensure ArgumentDataMember and ValueDataMembersSerializable
            //    match the values from the in-memory report object.
            foreach (var binding in bindings)
            {
                if (string.IsNullOrEmpty(binding.SeriesName))
                    continue;

                // Match the series XML element by Name + SeriesID (unique within chart context)
                var escapedName = Regex.Escape(binding.SeriesName);
                var pattern = $@"(<Item\d+[^>]*Name=""{escapedName}""[^>]*SeriesID=""[^""]*""[^>]*>)";
                var match = Regex.Match(xml, pattern);

                // Try reversed attribute order (SeriesID before Name)
                if (!match.Success)
                {
                    pattern = $@"(<Item\d+[^>]*SeriesID=""[^""]*""[^>]*Name=""{escapedName}""[^>]*>)";
                    match = Regex.Match(xml, pattern);
                }

                if (!match.Success)
                    continue;

                var originalTag = match.Groups[1].Value;
                var updatedTag = originalTag;

                // Restore ArgumentDataMember
                if (!string.IsNullOrEmpty(binding.ArgumentDataMember))
                {
                    if (Regex.IsMatch(updatedTag, @"ArgumentDataMember=""[^""]*"""))
                    {
                        updatedTag = Regex.Replace(updatedTag,
                            @"ArgumentDataMember=""[^""]*""",
                            $"ArgumentDataMember=\"{binding.ArgumentDataMember}\"");
                    }
                    else
                    {
                        // Inject after Name attribute
                        updatedTag = updatedTag.Replace(
                            $"Name=\"{binding.SeriesName}\"",
                            $"Name=\"{binding.SeriesName}\" ArgumentDataMember=\"{binding.ArgumentDataMember}\"");
                    }
                }

                // Restore ValueDataMembersSerializable
                if (!string.IsNullOrEmpty(binding.ValueDataMembers))
                {
                    if (Regex.IsMatch(updatedTag, @"ValueDataMembersSerializable=""[^""]*"""))
                    {
                        updatedTag = Regex.Replace(updatedTag,
                            @"ValueDataMembersSerializable=""[^""]*""",
                            $"ValueDataMembersSerializable=\"{binding.ValueDataMembers}\"");
                    }
                    else
                    {
                        // Inject after Name attribute
                        updatedTag = updatedTag.Replace(
                            $"Name=\"{binding.SeriesName}\"",
                            $"Name=\"{binding.SeriesName}\" ValueDataMembersSerializable=\"{binding.ValueDataMembers}\"");
                    }
                }

                if (updatedTag != originalTag)
                {
                    xml = xml.Replace(originalTag, updatedTag);
                    modified = true;
                    _logger.LogInformation(
                        "Restored chart series '{Series}': ArgumentDataMember='{Arg}', ValueDataMembers='{Val}'",
                        binding.SeriesName, binding.ArgumentDataMember, binding.ValueDataMembers);
                }
            }

            if (modified)
                _logger.LogInformation("Chart XML post-processing completed successfully");

            return xml;
        }

        /// <summary>
        /// Recursively finds all controls of type T in the report's control hierarchy.
        /// Traverses all bands, sub-bands (DetailReportBand), and nested controls.
        /// </summary>
        private static IEnumerable<T> FindAllControls<T>(XtraReport report) where T : XRControl
        {
            var stack = new Stack<XRControl>();

            foreach (Band band in report.Bands)
                stack.Push(band);

            while (stack.Count > 0)
            {
                var current = stack.Pop();

                if (current is T match)
                    yield return match;

                foreach (XRControl child in current.Controls)
                    stack.Push(child);

                // DetailReportBand contains sub-bands that need separate traversal
                if (current is DetailReportBand detailReport)
                {
                    foreach (Band subBand in detailReport.Bands)
                        stack.Push(subBand);
                }
            }
        }
    }
}
