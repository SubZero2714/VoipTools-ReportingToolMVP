# UI Cross-Validation Checklist

> **Purpose:** Manually verify that the Customer Service Dashboard report UI displays data that matches direct SQL queries. Run these checks before any release.

---

## Prerequisites
- Application running at `https://localhost:7209`
- SSMS or sqlcmd connected to production DB: `Server=3.132.72.134, Database=3CX Exporter`
- Report Designer open with `Similar to samuel sirs report manualtest_2.repx`

---

## Test Parameters (use these for ALL checks)

| Parameter | Value |
|-----------|-------|
| Period From | `2025-06-01` |
| Period To | `2025-10-31` |
| Queue DNs | `8000` |
| Wait Interval | `00:00:20` |

---

## CHECK 1: KPI Cards vs SQL

### Step 1: Get expected values from SQL
Run in SSMS:
```sql
EXEC dbo.sp_queue_kpi_summary_shushant 
    @period_from = '2025-06-01 00:00:00 +00:00',
    @period_to   = '2025-10-31 23:59:59 +00:00',
    @queue_dns   = '8000',
    @wait_interval = '00:00:20';
```

### Step 2: Run the report in Report Viewer
1. Navigate to `/reportviewer`
2. Open the manual test report
3. Set parameters: From=01-06-2025, To=31-10-2025, Queue=8000, Wait=00:00:20
4. Click Preview

### Step 3: Compare these values

| KPI Card | SQL Column | SQL Value | UI Value | Match? |
|----------|-----------|-----------|----------|--------|
| Total Calls | `total_calls` | ___ | ___ | ☐ |
| Answered Calls | `answered_calls` | ___ | ___ | ☐ |
| Abandoned Calls | `abandoned_calls` | ___ | ___ | ☐ |
| Answer Rate | `answered_percent` | ___% | ___% | ☐ |
| SLA Calls | `answered_within_sla` | ___ | ___ | ☐ |
| SLA % | `answered_within_sla_percent` | ___% | ___% | ☐ |
| Queue Name | `queue_display_name` | ___ | ___ | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## CHECK 2: Chart Data vs SQL

### Step 1: Get expected values from SQL
```sql
EXEC dbo.sp_queue_calls_by_date_shushant 
    @period_from = '2025-06-01 00:00:00 +00:00',
    @period_to   = '2025-10-31 23:59:59 +00:00',
    @queue_dns   = '8000',
    @wait_interval = '00:00:20';
```

### Step 2: Verify in report UI

| Check | Expected | Actual | Match? |
|-------|----------|--------|--------|
| Number of bars/data points | ___ rows from SQL | ___ visible | ☐ |
| First date on chart | ___ | ___ | ☐ |
| Last date on chart | ___ | ___ | ☐ |
| Spot-check a date's total | Pick row 3: total=___ | Chart shows ___ | ☐ |
| Spot-check a date's answered | Pick row 3: answered=___ | Chart shows ___ | ☐ |
| Legend at bottom of chart | Yes | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## CHECK 3: Agent Table vs SQL

### Step 1: Get expected values from SQL
```sql
EXEC dbo.qcall_cent_get_extensions_statistics_by_queues 
    @period_from = '2025-06-01 00:00:00 +00:00',
    @period_to   = '2025-10-31 23:59:59 +00:00',
    @queue_dns   = '8000',
    @wait_interval = '00:00:20';
```

### Step 2: Verify in report UI

| Check | Expected | Actual | Match? |
|-------|----------|--------|--------|
| Number of agent rows | ___ from SQL | ___ in report | ☐ |
| First agent name | ___ | ___ | ☐ |
| First agent answered count | ___ | ___ | ☐ |
| Last agent name | ___ | ___ | ☐ |
| All agents show queue_dn=8000 | Yes | ☐ |
| Header repeats on page 2+ | Yes | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## CHECK 4: Multi-Queue Validation

Repeat Checks 1-3 with **Queue DNs = `8000,8089`**

### KPI adjustments:
| Check | Expected | Match? |
|-------|----------|--------|
| Queue Name shows "Multiple Queues (2)" | ___ | ☐ |
| Total calls >= single queue total | ___ | ☐ |
| Agent table shows agents from both queues | ___ | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## CHECK 5: Export Verification

| Export Format | Opens correctly? | Data matches UI? |
|---------------|-----------------|------------------|
| PDF | ☐ | ☐ |
| Excel | ☐ | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## CHECK 6: Parameter Edge Cases

| Scenario | Expected Behavior | Actual | Pass? |
|----------|-------------------|--------|-------|
| Future date range (2027-01-01 to 2027-12-31) | All KPIs = 0, empty chart | ___ | ☐ |
| Single day (2025-06-15 to 2025-06-15) | ≤1 chart row, valid KPIs | ___ | ☐ |
| All queues (leave queue param empty) | Aggregated data for all 31 queues | ___ | ☐ |

**Result:** ☐ PASS / ☐ FAIL

---

## Summary

| Check | Result |
|-------|--------|
| CHECK 1: KPI Cards | ☐ PASS / ☐ FAIL |
| CHECK 2: Chart Data | ☐ PASS / ☐ FAIL |
| CHECK 3: Agent Table | ☐ PASS / ☐ FAIL |
| CHECK 4: Multi-Queue | ☐ PASS / ☐ FAIL |
| CHECK 5: Exports | ☐ PASS / ☐ FAIL |
| CHECK 6: Edge Cases | ☐ PASS / ☐ FAIL |

**Overall:** ☐ ALL PASS — Ready for release / ☐ FAIL — Fix issues before release

**Tester:** ___________________  
**Date:** ___________________  
**Version:** ___________________
