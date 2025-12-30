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

// Register report storage service (file-based)
builder.Services.AddScoped<ReportStorageWebExtension, FileReportStorageService>();

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
