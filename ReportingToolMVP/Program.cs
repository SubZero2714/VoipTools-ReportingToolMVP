using DevExpress.AspNetCore.Reporting;
using DevExpress.Blazor;
using DevExpress.Blazor.Reporting;
using DevExpress.XtraReports.Web.Extensions;
using ReportingToolMVP.Components;
using ReportingToolMVP.Services;

var builder = WebApplication.CreateBuilder(args);

// Add MVC services (required by DevExpress Reporting)
builder.Services.AddControllersWithViews();

// Add Razor components
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

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

// Register Connection Provider Factory for editing existing data source queries
builder.Services.AddScoped<DevExpress.DataAccess.Web.IConnectionProviderFactory, CustomConnectionProviderFactory>();

// Register DB Schema Provider Factory - Required for Query Builder in Report Designer
builder.Services.AddScoped<DevExpress.DataAccess.Web.IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();

// Register custom services
builder.Services.AddScoped<ICustomReportService, CustomReportService>();
builder.Services.AddScoped<IReportExportService, ReportExportService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseAntiforgery();

// Map MVC controllers (required by DevExpress Reporting)
app.MapControllers();

// DevExpress Reporting middleware
app.UseDevExpressBlazorReporting();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
