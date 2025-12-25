using OfficeOpenXml;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using ReportingToolMVP.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Service for exporting report data to various formats (Excel, CSV, PDF)
    /// </summary>
    public class ReportExportService : IReportExportService
    {
        private readonly ILogger<ReportExportService> _logger;

        public ReportExportService(ILogger<ReportExportService> logger)
        {
            _logger = logger;
            // Set EPPlus license context (free license for non-commercial use)
            ExcelPackage.LicenseContext = OfficeOpenXml.LicenseContext.NonCommercial;
        }

        /// <summary>
        /// Export data to Excel format
        /// </summary>
        public async Task<byte[]> ExportToExcelAsync(
            List<Dictionary<string, object>> data,
            string reportTitle,
            Dictionary<string, string> columnFormats = null)
        {
            try
            {
                if (data == null || !data.Any())
                {
                    throw new ArgumentException("No data to export");
                }

                using (var package = new ExcelPackage())
                {
                    var worksheet = package.Workbook.Worksheets.Add("Report");

                    // Get column headers from first row
                    var headers = data.First().Keys.ToList();

                    // Write headers
                    for (int i = 0; i < headers.Count; i++)
                    {
                        var cell = worksheet.Cells[1, i + 1];
                        cell.Value = headers[i];
                        cell.Style.Font.Bold = true;
                        cell.Style.Fill.PatternType = OfficeOpenXml.Style.ExcelFillStyle.Solid;
                        cell.Style.Fill.BackgroundColor.SetColor(System.Drawing.Color.FromArgb(79, 129, 189)); // Blue
                        cell.Style.Font.Color.SetColor(System.Drawing.Color.White);
                    }

                    // Write data rows
                    for (int rowIndex = 0; rowIndex < data.Count; rowIndex++)
                    {
                        var row = data[rowIndex];
                        for (int colIndex = 0; colIndex < headers.Count; colIndex++)
                        {
                            var cell = worksheet.Cells[rowIndex + 2, colIndex + 1];
                            var value = row[headers[colIndex]];

                            if (value != null)
                            {
                                cell.Value = value;

                                // Apply formatting based on column type or custom format
                                if (columnFormats != null && columnFormats.TryGetValue(headers[colIndex], out var format))
                                {
                                    cell.Style.Numberformat.Format = format;
                                }
                                else if (value is decimal || value is double || value is float)
                                {
                                    cell.Style.Numberformat.Format = "#,##0.00";
                                }
                                else if (headers[colIndex].Contains("Percentage"))
                                {
                                    cell.Style.Numberformat.Format = "0.00\"%\"";
                                }
                            }
                        }
                    }

                    // Auto-fit columns
                    worksheet.Cells.AutoFitColumns();

                    // Set minimum column width
                    for (int i = 1; i <= headers.Count; i++)
                    {
                        if (worksheet.Column(i).Width < 12)
                        {
                            worksheet.Column(i).Width = 12;
                        }
                    }

                    _logger.LogInformation($"Exporting {data.Count} rows to Excel");
                    return await Task.FromResult(package.GetAsByteArray());
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error exporting to Excel: {ex.Message}", ex);
                throw;
            }
        }

        /// <summary>
        /// Export data to CSV format
        /// </summary>
        public async Task<byte[]> ExportToCsvAsync(
            List<Dictionary<string, object>> data,
            string reportTitle)
        {
            try
            {
                if (data == null || !data.Any())
                {
                    throw new ArgumentException("No data to export");
                }

                var sb = new StringBuilder();

                // Get headers from first row
                var headers = data.First().Keys.ToList();

                // Write headers with quotes and escape commas
                sb.AppendLine(string.Join(",", headers.Select(h => $"\"{h}\"")));

                // Write data rows
                foreach (var row in data)
                {
                    var values = headers.Select(h =>
                    {
                        var value = row[h];
                        if (value == null)
                            return "\"\"";

                        var stringValue = value.ToString();
                        // Escape quotes and wrap in quotes if contains comma or newline
                        if (stringValue.Contains(",") || stringValue.Contains("\"") || stringValue.Contains("\n"))
                        {
                            stringValue = "\"" + stringValue.Replace("\"", "\"\"") + "\"";
                        }
                        return stringValue;
                    });

                    sb.AppendLine(string.Join(",", values));
                }

                _logger.LogInformation($"Exporting {data.Count} rows to CSV");
                return await Task.FromResult(Encoding.UTF8.GetBytes(sb.ToString()));
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error exporting to CSV: {ex.Message}", ex);
                throw;
            }
        }

        /// <summary>
        /// Export data to PDF format using QuestPDF
        /// </summary>
        public async Task<byte[]> ExportToPdfAsync(
            List<Dictionary<string, object>> data,
            string reportTitle,
            Dictionary<string, object>? chartData = null)
        {
            try
            {
                if (data == null || !data.Any())
                {
                    throw new ArgumentException("No data to export");
                }

                // Set QuestPDF license (Community license for open source)
                QuestPDF.Settings.License = LicenseType.Community;

                var headers = data.First().Keys.ToList();

                var document = Document.Create(container =>
                {
                    container.Page(page =>
                    {
                        page.Size(PageSizes.A4.Landscape());
                        page.Margin(30);
                        page.DefaultTextStyle(x => x.FontSize(10));

                        // Header
                        page.Header().Column(col =>
                        {
                            col.Item().Text(reportTitle)
                                .FontSize(18)
                                .Bold()
                                .FontColor(Colors.Blue.Darken2);
                            
                            col.Item().Text($"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}")
                                .FontSize(9)
                                .FontColor(Colors.Grey.Medium);
                            
                            col.Item().PaddingBottom(10);
                        });

                        // Content - Data Table
                        page.Content().Table(table =>
                        {
                            // Define columns
                            table.ColumnsDefinition(columns =>
                            {
                                foreach (var _ in headers)
                                {
                                    columns.RelativeColumn();
                                }
                            });

                            // Header row
                            table.Header(header =>
                            {
                                foreach (var headerText in headers)
                                {
                                    header.Cell()
                                        .Background(Colors.Blue.Darken2)
                                        .Padding(5)
                                        .Text(headerText)
                                        .FontColor(Colors.White)
                                        .Bold()
                                        .FontSize(9);
                                }
                            });

                            // Data rows
                            bool alternate = false;
                            foreach (var row in data)
                            {
                                var bgColor = alternate ? Colors.Grey.Lighten4 : Colors.White;
                                alternate = !alternate;

                                foreach (var header in headers)
                                {
                                    var value = row.ContainsKey(header) ? row[header] : null;
                                    var displayValue = FormatValueForPdf(value);

                                    table.Cell()
                                        .Background(bgColor)
                                        .BorderBottom(1)
                                        .BorderColor(Colors.Grey.Lighten2)
                                        .Padding(5)
                                        .Text(displayValue)
                                        .FontSize(9);
                                }
                            }
                        });

                        // Footer
                        page.Footer().AlignCenter().Text(x =>
                        {
                            x.Span("Page ");
                            x.CurrentPageNumber();
                            x.Span(" of ");
                            x.TotalPages();
                        });
                    });
                });

                using var stream = new MemoryStream();
                document.GeneratePdf(stream);
                
                _logger.LogInformation($"Exporting {data.Count} rows to PDF");
                return await Task.FromResult(stream.ToArray());
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error exporting to PDF: {ex.Message}", ex);
                throw;
            }
        }

        /// <summary>
        /// Format value for PDF display
        /// </summary>
        private string FormatValueForPdf(object? value)
        {
            if (value == null) return "";
            
            return value switch
            {
                DateTime dt => dt.ToString("yyyy-MM-dd"),
                decimal d => d.ToString("#,##0.00"),
                double dbl => dbl.ToString("#,##0.00"),
                float f => f.ToString("#,##0.00"),
                _ => value.ToString() ?? ""
            };
        }

        /// <summary>
        /// Generate file name for export
        /// </summary>
        public string GenerateFileName(string reportName, string fileFormat)
        {
            var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            return $"{reportName}_{timestamp}.{fileFormat.ToLower()}";
        }
    }
}
