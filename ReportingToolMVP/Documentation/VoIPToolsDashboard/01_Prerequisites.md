# Prerequisites

## Software Requirements

### 1. Development Environment
| Component | Version | Purpose |
|-----------|---------|---------|
| .NET SDK | 8.0+ | Runtime and build tools |
| Visual Studio / VS Code | 2022+ / Latest | IDE with Blazor support |
| SQL Server | 2019+ | Database (Express edition works) |
| DevExpress Blazor | 25.2.3 | All packages must match this version |

### 2. DevExpress NuGet Packages
```xml
<!-- All must be same version -->
<PackageReference Include="DevExpress.Blazor" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.Blazor.Reporting.Viewer" Version="25.2.3" />
<PackageReference Include="DevExpress.AspNetCore.Reporting" Version="25.2.3" />
<PackageReference Include="DevExpress.XtraReports" Version="25.2.3" />
```

---

## Database Requirements

### Required Table
The dashboard reads from the **3CX Call Center** export table:

```sql
-- Core table (must exist with this structure)
[dbo].[callcent_queuecalls]
├── time_start          -- Call start timestamp
├── ts_waiting          -- Time spent waiting in queue
├── ts_servicing        -- Time spent talking (00:00:00 = not answered)
├── q_num               -- Queue number
├── to_dn               -- Agent extension (who answered)
├── from_no             -- Caller phone number
├── reason_noanswercode -- Why call wasn't answered (NULL if answered)
└── ...
```

### Create SQL Views
Run this command to create the required views:

```powershell
# From project root directory
sqlcmd -S "LAPTOP-A5UI98NJ\SQLEXPRESS" -U sa -P "YOUR_PASSWORD" `
       -d Test_3CX_Exporter `
       -i "ReportingToolMVP/SQL/VoIPToolsDashboard/00_CreateAllViews.sql"
```

This creates:
| View | Purpose |
|------|---------|
| `vw_QueueKPIs` | Aggregated metrics for KPI cards |
| `vw_QueueAgentPerformance` | Agent stats for performance table |
| `vw_QueueCallTrends` | Daily counts for trend chart |
| `vw_QueueSummary` | Per-queue breakdown (optional) |

---

## Verify Prerequisites

### 1. Test Database Connection
```powershell
sqlcmd -S "LAPTOP-A5UI98NJ\SQLEXPRESS" -U sa -P "YOUR_PASSWORD" `
       -d Test_3CX_Exporter -Q "SELECT COUNT(*) as TotalRows FROM callcent_queuecalls"
```

Expected output: A number (e.g., `4192`)

### 2. Test Views
```powershell
# Test KPIs view
sqlcmd -S "LAPTOP-A5UI98NJ\SQLEXPRESS" -U sa -P "YOUR_PASSWORD" `
       -d Test_3CX_Exporter -Q "SELECT TotalCalls, AnsweredCalls FROM vw_QueueKPIs" -W

# Test Trends view
sqlcmd -S "LAPTOP-A5UI98NJ\SQLEXPRESS" -U sa -P "YOUR_PASSWORD" `
       -d Test_3CX_Exporter -Q "SELECT TOP 5 * FROM vw_QueueCallTrends ORDER BY CallDate DESC" -W
```

### 3. Start Application
```powershell
cd ReportingToolMVP
dotnet run
# Opens at https://localhost:7209
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Named Pipes Provider, error: 40` | Verify server name, enable SQL Server Browser service |
| `Login failed for user 'sa'` | Enable SQL authentication, reset sa password |
| `Invalid object name 'vw_QueueKPIs'` | Run the SQL views creation script |
| DevExpress license warning | Register your DevExpress license or use trial |
| Chart not showing data | Verify `dsTrends` connection string in .repx file |
