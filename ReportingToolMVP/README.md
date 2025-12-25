# ReportingToolMVP - Configurable Reporting Tool

**Phase 0 MVP - DevExpress Evaluation & Prototype**

A standalone .NET 9 Blazor Server application for creating custom reports from the 3CX Exporter database. This is a dedicated reporting tool built to evaluate DevExpress Blazor components and test real-time dashboard capabilities.

## Project Goals

✅ **Evaluate DevExpress Capabilities**
- Test DxDataGrid for dynamic column handling
- Validate DxChart for real-time data visualization  
- Assess PDF/Excel export functionality
- Measure performance with 10K+ rows

✅ **Build MVP Prototype**
- Users configure reports via UI (column selection, filtering)
- Real-time preview in interactive grid + chart
- Export to PDF/Excel/CSV
- No database storage yet (Phase 1 feature)

## Quick Start

### Prerequisites
- .NET 9 SDK
- SQL Server (local or remote)
- 3CX Exporter database with call queue data

### Setup Instructions

```bash
# 1. Clone or download the project
cd VoipTools-ReportingToolMVP/ReportingToolMVP

# 2. Copy appsettings.json
cp appsettings.json.sample appsettings.json

# 3. Update connection string in appsettings.json
#    Replace YOUR_SERVER and YOUR_PASSWORD with actual values

# 4. Restore dependencies
dotnet restore

# 5. Run the project
dotnet run

# 6. Open browser
# https://localhost:7XXX
# Navigate to /test for feature checklist
```

### Environment Variables (Development)
```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet watch run
```

## Project Structure

```
ReportingToolMVP/
├── Models/                    # Data models for reports
│   ├── Feature.cs            # Testing checklist feature model
│   ├── ReportConfig.cs       # User selections/configuration
│   ├── ReportDataRow.cs      # Flexible row wrapper
│   └── QueueBasicInfo.cs     # Queue dropdown data
├── Services/                  # Service interfaces (implementations TBD)
│   ├── ICustomReportService.cs
│   └── IReportExportService.cs
├── Components/Pages/          # Razor pages
│   ├── Index.razor           # Landing page
│   └── Test.razor            # Feature tracking checklist
├── wwwroot/css/              # Stylesheets
├── Program.cs                # DI & Startup config
├── appsettings.json          # (gitignored - use .sample)
├── FEATURES.md               # Feature tracking & testing
└── README.md                 # This file
```

## Available Pages

- `/` - Home/Index page
- `/test` - Feature checklist & progress tracking
- `/reportbuilder` - Main report builder (TBD)

## Technology Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| .NET | 9.0 | Framework |
| Blazor Server | 9.0 | UI framework |
| DevExpress | 25.1.6 | UI components |
| Dapper | 2.1.66 | Data access (lightweight ORM) |
| Microsoft.Data.SqlClient | 6.1.2 | SQL Server driver |
| EPPlus | 7.0.0 | Excel export |

## Development Workflow

### Creating a New Feature
1. Update `FEATURES.md` with feature details
2. Create feature branch: `git checkout -b feature/description`
3. Implement feature with tests
4. Update feature status in `/test` page
5. Commit: `git commit -m "feat: description"`
6. Merge to main: `git checkout main && git merge feature/description`

### Testing
- Manual testing via `/test` page
- Check `FEATURES.md` for test criteria
- Update feature status as tests pass

## Database Connection

The application connects to the 3CX Exporter database using the connection string in `appsettings.json`.

**Key Tables Used:**
- `callcent_queuecalls` - Individual call records
- `queue` - Queue definitions
- `dn` - Phone numbers/extensions

## Notes for Next Phases

- **Phase 1:** Add report definition persistence (database tables)
- **Phase 1:** Add report sharing & role-based access control
- **Phase 2:** Add scheduled reports & email delivery
- **Phase 2:** Real-time auto-refresh (SignalR)
- **Phase 3:** Multi-tenant support
- **Future:** AI-powered report generation (natural language queries)

## Troubleshooting

### Connection String Errors
- Verify SQL Server is running
- Check connection string in `appsettings.json`
- Ensure 3CX Exporter database exists

### Build Errors
- Run `dotnet clean && dotnet restore`
- Check .NET 9 SDK is installed: `dotnet --version`

### Port Already in Use
- Change port in `Properties/launchSettings.json`
- Or kill process: `netstat -ano | findstr :7XXX`

## Resources

- [DevExpress Blazor Documentation](https://docs.devexpress.com/Blazor/)
- [Dapper GitHub](https://github.com/DapperLib/Dapper)
- [EPPlus Documentation](https://epplussoftware.com/)
- [FEATURES.md](FEATURES.md) - Feature tracking & test criteria

## License

VoIPTools - Internal Use Only

## Contact

**Project Lead:** Shushant Kumar  
**Stakeholders:** Matthew Sir, Subbu Sir

---

*Last Updated: December 23, 2025*
