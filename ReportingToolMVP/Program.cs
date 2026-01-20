using DevExpress.Blazor;
using DevExpress.Blazor.Reporting;
using DevExpress.XtraReports.Web.Extensions;
using DevExpress.DataAccess.Web;
using DevExpress.DataAccess.Wizard.Services;
using DevExpress.DataAccess.Sql;
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

// Register report storage service (file-based)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

// Register SQL Data Source provider for Report Designer wizard
builder.Services.AddScoped<IDataSourceWizardConnectionStringsProvider, CustomDataSourceWizardConnectionStringsProvider>();

// Register DB Schema Provider Factory for Query Builder (REQUIRED for pencil icon to work!)
builder.Services.AddScoped<IDBSchemaProviderExFactory, CustomDBSchemaProviderExFactory>();

// Register Connection Provider Factory for editing existing data source queries
builder.Services.AddScoped<IConnectionProviderFactory, CustomConnectionProviderFactory>();

// Register custom SQL query validator to allow our dashboard queries
builder.Services.AddScoped<ICustomQueryValidator, AllowAllQueriesValidator>();

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
