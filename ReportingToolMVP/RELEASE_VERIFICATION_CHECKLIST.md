# Release Verification Checklist

> **Purpose:** Complete this checklist before every production release of the Customer Service Dashboard.  
> **Total estimated time:** 30-45 minutes

---

## Pre-Release Info

| Field | Value |
|-------|-------|
| Release Version | ___ |
| Release Date | ___ |
| Verified By | ___ |
| Database Server | 3.132.72.134 |
| Database | 3CX Exporter |

---

## Phase 1: Automated Tests (10 min)

### 1.1 SQL Data Integrity Suite (15 tests)
```powershell
sqlcmd -S "3.132.72.134" -d "3CX Exporter" -U sa -P V01PT0y5 -C -i "ReportingToolMVP\SQL\Tests\data_integrity_tests.sql"
```
- [ ] All 15 tests show PASS (WARNs on Agent SP gap are acceptable)
- [ ] No FAIL results

### 1.2 C# Integration Tests (32 tests)
```powershell
cd ReportingToolMVP.Tests
dotnet test --verbosity normal
```
- [ ] All 32 tests pass
- [ ] No build errors

**Phase 1 Result:** [ ] PASS / [ ] FAIL

---

## Phase 2: Application Startup (5 min)

### 2.1 Build & Launch
```powershell
cd ReportingToolMVP
dotnet build
dotnet run
```
- [ ] Build succeeds with 0 errors
- [ ] Application starts on https://localhost:7209 (or configured port)
- [ ] No console errors on startup

### 2.2 Navigation Check
- [ ] Home page loads (`/`)
- [ ] Report Builder loads (`/reportbuilder`)
- [ ] Report Designer loads (`/reportdesigner`)
- [ ] Report Viewer loads (`/reportviewer`)
- [ ] Test Suite loads (`/test`)
- [ ] No JavaScript console errors

**Phase 2 Result:** [ ] PASS / [ ] FAIL

---

## Phase 3: Report Builder Validation (5 min)

### 3.1 Query Execution
- [ ] Queue dropdown populates with 31 queues
- [ ] Select Queue 8000, Date range: Jun 2025 - Oct 2025
- [ ] Select columns: QueueNumber, TotalCalls, AvgWaitTime
- [ ] Click Generate → data grid shows results
- [ ] TotalCalls > 0

### 3.2 Export
- [ ] Export to Excel works (file downloads, opens correctly)
- [ ] Export to PDF works (file downloads, opens correctly)

**Phase 3 Result:** [ ] PASS / [ ] FAIL

---

## Phase 4: Report Designer Validation (5 min)

### 4.1 Template Management
- [ ] Report Designer opens with toolbar
- [ ] Open existing `.repx` template (e.g., QueuePerformanceSummary)
- [ ] Template loads in designer canvas
- [ ] Can switch between Design and Preview modes

### 4.2 Data Source Connectivity
- [ ] Can open Data Source Wizard
- [ ] Connection to database succeeds
- [ ] Stored procedures are visible in Query Builder

**Phase 4 Result:** [ ] PASS / [ ] FAIL

---

## Phase 5: Customer Service Dashboard Report (10 min)

> This is the primary deliverable — validate thoroughly.

### 5.1 KPI Cards (use Queue 8000, Feb 01–17 2026, SLA 20s, India Standard Time)
Run this SQL to get expected values:
```sql
EXEC dbo.sp_queue_stats_summary
    @from            = '2026-02-01 00:00:00 +00:00',
    @to              = '2026-02-17 00:00:00 +00:00',
    @queue_dns       = '8000',
    @sla_seconds     = 20,
    @report_timezone = 'India Standard Time';
```

- [ ] Total Calls matches SQL
- [ ] Answered Calls matches SQL
- [ ] Abandoned Calls matches SQL
- [ ] Answer Rate % matches SQL (±0.02)
- [ ] SLA % matches SQL (±0.02)
- [ ] Queue name displays correctly

### 5.2 Chart
- [ ] Chart renders with daily bars
- [ ] Legend appears at bottom of chart
- [ ] Spot-check one date against Chart SP output
- [ ] answered + abandoned = total for spot-checked date

### 5.3 Agent Performance Table
- [ ] Agent table populates with rows
- [ ] All agents show queue_dn = 8000
- [ ] Agent display names are non-empty
- [ ] Table header repeats on page 2+ (if applicable)

### 5.4 Multi-Queue Test
- [ ] Switch to Queue DNs: 8000,8089
- [ ] Total calls >= single queue total
- [ ] Agent table shows agents from both queues (verify queue_dn column)

### 5.5 Export
- [ ] PDF export includes all 3 sections (KPI, Chart, Agent Table)
- [ ] Excel export works

**Phase 5 Result:** [ ] PASS / [ ] FAIL

---

## Phase 6: Edge Cases (5 min)

- [ ] Invalid queue (9999): All KPIs = 0, no chart data
- [ ] Future date range: All KPIs = 0
- [ ] Empty queue parameter (all queues): Returns aggregated data > 0
- [ ] Single day range: ≤ 1 chart data point, valid KPIs

**Phase 6 Result:** [ ] PASS / [ ] FAIL

---

## Phase 7: Known Issues Verification

| Issue | Status | Notes |
|-------|--------|-------|
| Agent SP gap (agents removed from ext view) | Expected WARN | Gap of ~17 calls is acceptable |
| Chart SP empty queue returns all data | By design | Matches KPI SP behavior |

---

## Release Decision

| Phase | Result |
|-------|--------|
| Phase 1: Automated Tests | [ ] PASS / [ ] FAIL |
| Phase 2: Application Startup | [ ] PASS / [ ] FAIL |
| Phase 3: Report Builder | [ ] PASS / [ ] FAIL |
| Phase 4: Report Designer | [ ] PASS / [ ] FAIL |
| Phase 5: Dashboard Report | [ ] PASS / [ ] FAIL |
| Phase 6: Edge Cases | [ ] PASS / [ ] FAIL |

### Final Decision
- [ ] **APPROVED FOR RELEASE** — All phases passed
- [ ] **BLOCKED** — Fix issues listed below before release

### Blocking Issues (if any)
| Issue | Severity | Phase |
|-------|----------|-------|
| | | |

---

**Signed off by:** ___________________  
**Date:** ___________________
