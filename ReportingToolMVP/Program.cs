using DevExpress.Blazor;
using ReportingToolMVP.Components;
using ReportingToolMVP.Services;

var builder = WebApplication.CreateBuilder(args);

// Add Razor components
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add DevExpress services
builder.Services.AddDevExpressBlazor();

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

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
