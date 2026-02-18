using DevExpress.AspNetCore.Reporting;
using DevExpress.Blazor;
using DevExpress.Blazor.Reporting;
using DevExpress.XtraReports.Web.Extensions;
using Microsoft.AspNetCore.ResponseCompression;
using ReportingToolMVP.Components;
using ReportingToolMVP.Services;

var builder = WebApplication.CreateBuilder(args);

// ─── Scheduled Reports Services ──────────────────────────────
builder.Services.AddScoped<IReportScheduleRepository, ReportScheduleRepository>();
builder.Services.AddSingleton<IEmailService, EmailService>();
builder.Services.AddSingleton<IReportGeneratorService, ReportGeneratorService>();
builder.Services.AddHostedService<ReportSchedulerBackgroundService>();

// ─── Response Compression (Brotli + Gzip) ───────────────────────
// Critical for Blazor Server: compresses SignalR WebSocket frames
builder.Services.AddResponseCompression(opts =>
{
    opts.EnableForHttps = true;
    opts.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(new[]
    {
        "application/octet-stream",          // SignalR binary
        "application/javascript",            // JS bundles
        "text/css",                          // Stylesheets
        "image/svg+xml"                      // Icons
    });
    opts.Providers.Add<BrotliCompressionProvider>();
    opts.Providers.Add<GzipCompressionProvider>();
});
builder.Services.Configure<BrotliCompressionProviderOptions>(opts => opts.Level = System.IO.Compression.CompressionLevel.Fastest);
builder.Services.Configure<GzipCompressionProviderOptions>(opts => opts.Level = System.IO.Compression.CompressionLevel.Fastest);

// ─── In-Memory Caching (for report file storage) ────────────────
builder.Services.AddMemoryCache();

// Add MVC services (required by DevExpress Reporting)
builder.Services.AddControllersWithViews();

// Add Razor components
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// ─── SignalR Hub Optimization for Blazor Server ──────────────────
// Larger buffers prevent dropped frames for big report payloads
builder.Services.AddSignalR(opts =>
{
    opts.MaximumReceiveMessageSize = 1024 * 1024;    // 1 MB (default 32 KB)
    opts.StreamBufferCapacity = 30;                   // default 10
    opts.ClientTimeoutInterval = TimeSpan.FromSeconds(60);
    opts.KeepAliveInterval = TimeSpan.FromSeconds(15);
});

// Add DevExpress services
builder.Services.AddDevExpressBlazor();

// Add DevExpress Reporting services
builder.Services.AddDevExpressBlazorReporting();
builder.Services.AddDevExpressServerSideBlazorReportViewer();

// Configure Reporting Services - CRITICAL: Enable Custom SQL for Report Designer
builder.Services.ConfigureReportingServices(configurator => {
    configurator.ConfigureReportDesigner(designerConfigurator => {
        // Enable custom SQL queries in the Report Designer - THIS FIXES "Query X is not allowed"
        designerConfigurator.EnableCustomSql();
    });
    
    configurator.ConfigureWebDocumentViewer(viewerConfigurator => {
        viewerConfigurator.UseCachedReportSourceBuilder();
    });
});

// Register report storage service (file-based)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// Register SQL Data Source provider for Report Designer wizard
builder.Services.AddScoped<DevExpress.DataAccess.Web.IDataSourceWizardConnectionStringsProvider, CustomDataSourceWizardConnectionStringsProvider>();

// Register Connection Provider Service (provides connections at runtime) - in Wizard.Services namespace
builder.Services.AddScoped<DevExpress.DataAccess.Wizard.Services.IConnectionProviderService, CustomConnectionProviderService>();

// Register Connection Provider Factory for editing existing data source queries (uses the service above)
builder.Services.AddScoped<DevExpress.DataAccess.Web.IConnectionProviderFactory, CustomConnectionProviderFactory>();

// Register DB Schema Provider Factory - Required for Query Builder in Report Designer
builder.Services.AddScoped<DevExpress.DataAccess.Web.IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();



var app = builder.Build();

// Generate the Queue Performance Dashboard .repx using DevExpress API
// This ensures correct serialization of SqlDataSources and expression-bound SP parameters
{
    var repxPath = Path.Combine(app.Environment.ContentRootPath, "Reports", "Templates", "Similar_to_samuel_sirs_report.repx");
    try
    {
        ReportingToolMVP.Reports.QueuePerformanceDashboardGenerator.GenerateAndSave(repxPath);
        Console.WriteLine($"Generated report: {repxPath} ({new FileInfo(repxPath).Length} bytes)");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: Could not generate report: {ex.Message}");
    }
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseResponseCompression();                     // Must be early in pipeline
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        // Cache static assets (CSS, JS, fonts) for 7 days
        ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=604800,immutable");
    }
});
app.UseAntiforgery();

// Map MVC controllers (required by DevExpress Reporting)
app.MapControllers();

// DevExpress Reporting middleware
app.UseDevExpressBlazorReporting();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
