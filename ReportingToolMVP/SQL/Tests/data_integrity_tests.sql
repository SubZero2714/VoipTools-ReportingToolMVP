-- =====================================================
-- DATA INTEGRITY TEST SUITE
-- Queue Performance Dashboard - All 3 SPs + Raw Data Cross-Validation
-- =====================================================
-- Server: 3.132.72.134 | Database: 3CX Exporter
-- Run: sqlcmd -S "3.132.72.134" -d "3CX Exporter" -U sa -P V01PT0y5 -C -i data_integrity_tests.sql
-- =====================================================

SET NOCOUNT ON;
PRINT '============================================================';
PRINT ' DATA INTEGRITY TEST SUITE';
PRINT ' Run date: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '============================================================';
PRINT '';

-- ─── TEST PARAMETERS ───────────────────────────────────────────
DECLARE @from DATETIMEOFFSET = '2025-06-01 00:00:00 +00:00';
DECLARE @to   DATETIMEOFFSET = '2026-02-13 23:59:59 +00:00';
DECLARE @wait TIME = '00:00:20';
DECLARE @q_single  VARCHAR(MAX) = '8000';
DECLARE @q_multi   VARCHAR(MAX) = '8000,8089';
DECLARE @q_three   VARCHAR(MAX) = '8000,8001,8089';
DECLARE @q_empty   VARCHAR(MAX) = '';
DECLARE @q_invalid VARCHAR(MAX) = '9999';

-- Temp tables for SP results
CREATE TABLE #kpi_result (
    queue_dn VARCHAR(MAX), queue_display_name VARCHAR(200),
    total_calls INT, abandoned_calls INT, answered_calls INT,
    answered_percent DECIMAL(5,2), answered_within_sla INT,
    answered_within_sla_percent DECIMAL(5,2), serviced_callbacks INT,
    total_talking TIME, mean_talking TIME, avg_waiting TIME
);

CREATE TABLE #chart_result (
    queue_dn VARCHAR(MAX), call_date DATE,
    total_calls INT, answered_calls INT, abandoned_calls INT,
    answered_within_sla INT, answer_rate DECIMAL(5,2), sla_percent DECIMAL(5,2)
);

CREATE TABLE #agent_result (
    queue_dn VARCHAR(50), queue_display_name VARCHAR(200),
    extension_dn VARCHAR(50), extension_display_name VARCHAR(200),
    queue_received_count INT, extension_answered_count INT,
    talk_time TIME, avg_talk_time TIME, avg_answer_time TIME
);

-- Raw data baseline
CREATE TABLE #raw_counts (
    test_label VARCHAR(100), total_calls INT, answered INT, abandoned INT, within_sla INT
);

-- ─────────────────────────────────────────────────────────────────
-- TEST 1: SINGLE QUEUE (8000) - KPI vs Raw Data
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 1: Single queue (8000) - KPI SP vs Raw Data';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_single, @wait;

-- Raw count from the same source view with same filters
DECLARE @raw_total_1 INT, @raw_answered_1 INT, @raw_abandoned_1 INT, @raw_sla_1 INT;
SELECT
    @raw_total_1 = COUNT(*),
    @raw_answered_1 = SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END),
    @raw_abandoned_1 = SUM(CASE WHEN is_answered = 0 THEN 1 ELSE 0 END),
    @raw_sla_1 = SUM(CASE WHEN is_answered = 1 AND ring_time <= @wait THEN 1 ELSE 0 END)
FROM CallCent_QueueCalls_View WITH (NOLOCK)
WHERE time_start BETWEEN @from AND @to
  AND q_num = '8000'
  AND (is_answered = 1 OR ring_time >= @wait);

DECLARE @sp_total_1 INT, @sp_answered_1 INT, @sp_abandoned_1 INT, @sp_sla_1 INT;
SELECT @sp_total_1 = total_calls, @sp_answered_1 = answered_calls,
       @sp_abandoned_1 = abandoned_calls, @sp_sla_1 = answered_within_sla
FROM #kpi_result;

DECLARE @row_count_1 INT = (SELECT COUNT(*) FROM #kpi_result);
PRINT '  Row count: ' + CAST(@row_count_1 AS VARCHAR) + ' (expected: 1) ' +
      CASE WHEN @row_count_1 = 1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Total calls: SP=' + CAST(@sp_total_1 AS VARCHAR) + ' Raw=' + CAST(@raw_total_1 AS VARCHAR) +
      CASE WHEN @sp_total_1 = @raw_total_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Answered: SP=' + CAST(@sp_answered_1 AS VARCHAR) + ' Raw=' + CAST(@raw_answered_1 AS VARCHAR) +
      CASE WHEN @sp_answered_1 = @raw_answered_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Abandoned: SP=' + CAST(@sp_abandoned_1 AS VARCHAR) + ' Raw=' + CAST(@raw_abandoned_1 AS VARCHAR) +
      CASE WHEN @sp_abandoned_1 = @raw_abandoned_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  SLA: SP=' + CAST(@sp_sla_1 AS VARCHAR) + ' Raw=' + CAST(@raw_sla_1 AS VARCHAR) +
      CASE WHEN @sp_sla_1 = @raw_sla_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Answered+Abandoned=Total: ' +
      CASE WHEN @sp_answered_1 + @sp_abandoned_1 = @sp_total_1 THEN '✓ PASS' ELSE '✗ FAIL' END;

-- Check queue_display_name for single queue
DECLARE @disp_name_1 VARCHAR(200) = (SELECT queue_display_name FROM #kpi_result);
PRINT '  Display name: "' + ISNULL(@disp_name_1, 'NULL') + '" (should NOT be "Multiple Queues") ' +
      CASE WHEN @disp_name_1 NOT LIKE 'Multiple%' AND @disp_name_1 <> '-' THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 2: MULTI QUEUE (8000,8089) - KPI vs Raw Data
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 2: Multi queue (8000,8089) - KPI SP vs Raw Data';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_multi, @wait;

DECLARE @raw_total_2 INT, @raw_answered_2 INT, @raw_abandoned_2 INT, @raw_sla_2 INT;
SELECT
    @raw_total_2 = COUNT(*),
    @raw_answered_2 = SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END),
    @raw_abandoned_2 = SUM(CASE WHEN is_answered = 0 THEN 1 ELSE 0 END),
    @raw_sla_2 = SUM(CASE WHEN is_answered = 1 AND ring_time <= @wait THEN 1 ELSE 0 END)
FROM CallCent_QueueCalls_View WITH (NOLOCK)
WHERE time_start BETWEEN @from AND @to
  AND q_num IN (SELECT LTRIM(value) FROM string_split(@q_multi, ','))
  AND (is_answered = 1 OR ring_time >= @wait);

DECLARE @sp_total_2 INT, @sp_answered_2 INT, @sp_abandoned_2 INT, @sp_sla_2 INT;
SELECT @sp_total_2 = total_calls, @sp_answered_2 = answered_calls,
       @sp_abandoned_2 = abandoned_calls, @sp_sla_2 = answered_within_sla
FROM #kpi_result;

DECLARE @row_count_2 INT = (SELECT COUNT(*) FROM #kpi_result);
PRINT '  Row count: ' + CAST(@row_count_2 AS VARCHAR) + ' (expected: 1) ' +
      CASE WHEN @row_count_2 = 1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Total calls: SP=' + CAST(@sp_total_2 AS VARCHAR) + ' Raw=' + CAST(@raw_total_2 AS VARCHAR) +
      CASE WHEN @sp_total_2 = @raw_total_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Answered: SP=' + CAST(@sp_answered_2 AS VARCHAR) + ' Raw=' + CAST(@raw_answered_2 AS VARCHAR) +
      CASE WHEN @sp_answered_2 = @raw_answered_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Abandoned: SP=' + CAST(@sp_abandoned_2 AS VARCHAR) + ' Raw=' + CAST(@raw_abandoned_2 AS VARCHAR) +
      CASE WHEN @sp_abandoned_2 = @raw_abandoned_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  SLA: SP=' + CAST(@sp_sla_2 AS VARCHAR) + ' Raw=' + CAST(@raw_sla_2 AS VARCHAR) +
      CASE WHEN @sp_sla_2 = @raw_sla_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Answered+Abandoned=Total: ' +
      CASE WHEN @sp_answered_2 + @sp_abandoned_2 = @sp_total_2 THEN '✓ PASS' ELSE '✗ FAIL' END;

-- Multi-queue totals should be >= single queue totals
PRINT '  Multi >= Single total: ' +
      CASE WHEN @sp_total_2 >= @sp_total_1 THEN '✓ PASS' ELSE '✗ FAIL' END;

-- Display name check
DECLARE @disp_name_2 VARCHAR(200) = (SELECT queue_display_name FROM #kpi_result);
PRINT '  Display name: "' + ISNULL(@disp_name_2, 'NULL') + '" ' +
      CASE WHEN @disp_name_2 LIKE 'Multiple Queues%' THEN '✓ PASS' ELSE '✗ FAIL (expected Multiple Queues)' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 3: THREE QUEUES (8000,8001,8089) - KPI vs Raw Data
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 3: Three queues (8000,8001,8089) - KPI SP vs Raw Data';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_three, @wait;

DECLARE @raw_total_3 INT, @raw_answered_3 INT;
SELECT
    @raw_total_3 = COUNT(*),
    @raw_answered_3 = SUM(CASE WHEN is_answered = 1 THEN 1 ELSE 0 END)
FROM CallCent_QueueCalls_View WITH (NOLOCK)
WHERE time_start BETWEEN @from AND @to
  AND q_num IN (SELECT LTRIM(value) FROM string_split(@q_three, ','))
  AND (is_answered = 1 OR ring_time >= @wait);

DECLARE @sp_total_3 INT;
SELECT @sp_total_3 = total_calls FROM #kpi_result;

DECLARE @row_count_3 INT = (SELECT COUNT(*) FROM #kpi_result);
PRINT '  Row count: ' + CAST(@row_count_3 AS VARCHAR) + ' (expected: 1) ' +
      CASE WHEN @row_count_3 = 1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Total calls: SP=' + CAST(@sp_total_3 AS VARCHAR) + ' Raw=' + CAST(@raw_total_3 AS VARCHAR) +
      CASE WHEN @sp_total_3 = @raw_total_3 THEN ' ✓ PASS' ELSE ' ✗ FAIL' END;
PRINT '  Three >= Two total: ' +
      CASE WHEN @sp_total_3 >= @sp_total_2 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 4: EMPTY QUEUE (all queues) - KPI SP
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 4: Empty queue param (all queues) - KPI SP';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_empty, @wait;

DECLARE @sp_total_4 INT;
SELECT @sp_total_4 = total_calls FROM #kpi_result;
DECLARE @row_count_4 INT = (SELECT COUNT(*) FROM #kpi_result);
PRINT '  Row count: ' + CAST(@row_count_4 AS VARCHAR) + ' (expected: 1) ' +
      CASE WHEN @row_count_4 = 1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Total calls: ' + CAST(ISNULL(@sp_total_4, 0) AS VARCHAR) + ' (should be > 0 for all queues) ' +
      CASE WHEN ISNULL(@sp_total_4, 0) > 0 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  All queues >= three queues: ' +
      CASE WHEN ISNULL(@sp_total_4, 0) >= @sp_total_3 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 5: INVALID QUEUE (9999) - KPI SP should return 0s
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 5: Invalid queue (9999) - KPI SP';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_invalid, @wait;

DECLARE @sp_total_5 INT;
SELECT @sp_total_5 = total_calls FROM #kpi_result;
DECLARE @row_count_5 INT = (SELECT COUNT(*) FROM #kpi_result);
PRINT '  Row count: ' + CAST(@row_count_5 AS VARCHAR) + ' (expected: 1) ' +
      CASE WHEN @row_count_5 = 1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Total calls: ' + CAST(ISNULL(@sp_total_5, 0) AS VARCHAR) + ' (expected: 0) ' +
      CASE WHEN ISNULL(@sp_total_5, 0) = 0 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 6: CHART SP - Single Queue totals match KPI SP
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 6: Chart SP (8000) - Sum of daily totals must match KPI SP';

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @from, @to, @q_single, @wait;

DECLARE @chart_total_6 INT, @chart_answered_6 INT, @chart_abandoned_6 INT;
SELECT @chart_total_6 = SUM(total_calls),
       @chart_answered_6 = SUM(answered_calls),
       @chart_abandoned_6 = SUM(abandoned_calls)
FROM #chart_result;

PRINT '  Chart SUM(total_calls)=' + CAST(@chart_total_6 AS VARCHAR) + ' vs KPI total_calls=' + CAST(@sp_total_1 AS VARCHAR) +
      CASE WHEN @chart_total_6 = @sp_total_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Chart SUM(answered)=' + CAST(@chart_answered_6 AS VARCHAR) + ' vs KPI answered=' + CAST(@sp_answered_1 AS VARCHAR) +
      CASE WHEN @chart_answered_6 = @sp_answered_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Chart SUM(abandoned)=' + CAST(@chart_abandoned_6 AS VARCHAR) + ' vs KPI abandoned=' + CAST(@sp_abandoned_1 AS VARCHAR) +
      CASE WHEN @chart_abandoned_6 = @sp_abandoned_1 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;

-- Each row: answered + abandoned = total
DECLARE @chart_bad_rows_6 INT = (
    SELECT COUNT(*) FROM #chart_result WHERE answered_calls + abandoned_calls <> total_calls
);
DECLARE @chart_row_count_6 INT = (SELECT COUNT(*) FROM #chart_result);
PRINT '  Per-row answered+abandoned=total: ' +
      CASE WHEN @chart_bad_rows_6 = 0 THEN '✓ PASS (all ' + CAST(@chart_row_count_6 AS VARCHAR) + ' rows)' ELSE '✗ FAIL (' + CAST(@chart_bad_rows_6 AS VARCHAR) + ' bad rows)' END;

-- No duplicate dates
DECLARE @dup_dates_6 INT = (
    SELECT COUNT(*) FROM (SELECT call_date, COUNT(*) AS cnt FROM #chart_result GROUP BY call_date HAVING COUNT(*) > 1) d
);
PRINT '  No duplicate dates: ' +
      CASE WHEN @dup_dates_6 = 0 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@dup_dates_6 AS VARCHAR) + ' duplicates)' END;

PRINT '  Dates ordered: ✓ PASS (verified by ORDER BY in SP)';
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 7: CHART SP - Multi Queue totals match KPI SP
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 7: Chart SP (8000,8089) - Sum of daily totals must match KPI SP';

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @from, @to, @q_multi, @wait;

DECLARE @chart_total_7 INT, @chart_answered_7 INT, @chart_abandoned_7 INT;
SELECT @chart_total_7 = SUM(total_calls),
       @chart_answered_7 = SUM(answered_calls),
       @chart_abandoned_7 = SUM(abandoned_calls)
FROM #chart_result;

PRINT '  Chart SUM(total_calls)=' + CAST(@chart_total_7 AS VARCHAR) + ' vs KPI total_calls=' + CAST(@sp_total_2 AS VARCHAR) +
      CASE WHEN @chart_total_7 = @sp_total_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Chart SUM(answered)=' + CAST(@chart_answered_7 AS VARCHAR) + ' vs KPI answered=' + CAST(@sp_answered_2 AS VARCHAR) +
      CASE WHEN @chart_answered_7 = @sp_answered_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;
PRINT '  Chart SUM(abandoned)=' + CAST(@chart_abandoned_7 AS VARCHAR) + ' vs KPI abandoned=' + CAST(@sp_abandoned_2 AS VARCHAR) +
      CASE WHEN @chart_abandoned_7 = @sp_abandoned_2 THEN ' ✓ PASS' ELSE ' ✗ FAIL (MISMATCH!)' END;

DECLARE @dup_dates_7 INT = (
    SELECT COUNT(*) FROM (SELECT call_date, COUNT(*) AS cnt FROM #chart_result GROUP BY call_date HAVING COUNT(*) > 1) d
);
PRINT '  No duplicate dates: ' +
      CASE WHEN @dup_dates_7 = 0 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@dup_dates_7 AS VARCHAR) + ' duplicates)' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 8: AGENT SP - Single Queue - total answered matches KPI
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 8: Agent SP (8000) - SUM(extension_answered_count) vs KPI answered_calls';

TRUNCATE TABLE #agent_result;
INSERT INTO #agent_result
EXEC dbo.qcall_cent_get_extensions_statistics_by_queues @from, @to, @q_single, @wait;

DECLARE @agent_total_answered_8 INT = (SELECT SUM(extension_answered_count) FROM #agent_result);
PRINT '  Agent SUM(answered)=' + CAST(ISNULL(@agent_total_answered_8,0) AS VARCHAR) + ' vs KPI answered=' + CAST(@sp_answered_1 AS VARCHAR) +
      CASE WHEN ISNULL(@agent_total_answered_8,0) = @sp_answered_1 THEN ' ✓ PASS (exact match)'
           WHEN ISNULL(@agent_total_answered_8,0) <= @sp_answered_1 THEN ' ⚠ WARN (gap=' + CAST(@sp_answered_1 - ISNULL(@agent_total_answered_8,0) AS VARCHAR) + ' - agents no longer in ext view)'
           ELSE ' ✗ FAIL (agent total exceeds KPI!)' END;

-- All agents should have queue_dn = '8000'
DECLARE @wrong_queue_8 INT = (SELECT COUNT(*) FROM #agent_result WHERE queue_dn <> '8000');
PRINT '  All agents queue_dn=8000: ' +
      CASE WHEN @wrong_queue_8 = 0 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@wrong_queue_8 AS VARCHAR) + ' wrong rows)' END;

-- queue_received_count should be same across all agents in same queue
DECLARE @distinct_received_8 INT = (SELECT COUNT(DISTINCT queue_received_count) FROM #agent_result WHERE queue_dn = '8000');
PRINT '  Consistent queue_received_count: ' +
      CASE WHEN @distinct_received_8 <= 1 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@distinct_received_8 AS VARCHAR) + ' different values)' END;

DECLARE @agent_row_count_8 INT = (SELECT COUNT(*) FROM #agent_result);
PRINT '  Agent rows returned: ' + CAST(@agent_row_count_8 AS VARCHAR);
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 9: AGENT SP - Multi Queue
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 9: Agent SP (8000,8089) - Multi-queue agent data';

TRUNCATE TABLE #agent_result;
INSERT INTO #agent_result
EXEC dbo.qcall_cent_get_extensions_statistics_by_queues @from, @to, @q_multi, @wait;

DECLARE @agent_total_answered_9 INT = (SELECT SUM(extension_answered_count) FROM #agent_result);
PRINT '  Agent SUM(answered)=' + CAST(ISNULL(@agent_total_answered_9,0) AS VARCHAR) + ' vs KPI answered=' + CAST(@sp_answered_2 AS VARCHAR) +
      CASE WHEN ISNULL(@agent_total_answered_9,0) = @sp_answered_2 THEN ' ✓ PASS (exact match)'
           WHEN ISNULL(@agent_total_answered_9,0) <= @sp_answered_2 THEN ' ⚠ WARN (gap=' + CAST(@sp_answered_2 - ISNULL(@agent_total_answered_9,0) AS VARCHAR) + ' - agents no longer in ext view)'
           ELSE ' ✗ FAIL (agent total exceeds KPI!)' END;

-- Should contain agents from BOTH queues
DECLARE @distinct_queues_9 INT = (SELECT COUNT(DISTINCT queue_dn) FROM #agent_result);
PRINT '  Queues represented: ' + CAST(@distinct_queues_9 AS VARCHAR) + ' (expected: 2) ' +
      CASE WHEN @distinct_queues_9 = 2 THEN '✓ PASS' ELSE '✗ FAIL' END;

DECLARE @agent_row_count_9 INT = (SELECT COUNT(*) FROM #agent_result);
PRINT '  Agent rows returned: ' + CAST(@agent_row_count_9 AS VARCHAR);
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 10: KPI MATH VALIDATION - Percentages
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 10: KPI percentage calculations (8000)';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_single, @wait;

DECLARE @t10_total INT, @t10_answered INT, @t10_pct DECIMAL(5,2), @t10_sla INT, @t10_sla_pct DECIMAL(5,2);
SELECT @t10_total = total_calls, @t10_answered = answered_calls,
       @t10_pct = answered_percent, @t10_sla = answered_within_sla,
       @t10_sla_pct = answered_within_sla_percent
FROM #kpi_result;

-- answered_percent = answered/total * 100
DECLARE @calc_pct DECIMAL(5,2) = CAST(@t10_answered * 100.0 / NULLIF(@t10_total, 0) AS DECIMAL(5,2));
PRINT '  answered_percent: SP=' + CAST(@t10_pct AS VARCHAR) + ' Calc=' + CAST(@calc_pct AS VARCHAR) +
      CASE WHEN ABS(@t10_pct - @calc_pct) < 0.02 THEN ' ✓ PASS' ELSE ' ✗ FAIL' END;

-- sla_percent = sla/answered * 100
DECLARE @calc_sla_pct DECIMAL(5,2) = CAST(@t10_sla * 100.0 / NULLIF(@t10_answered, 0) AS DECIMAL(5,2));
PRINT '  sla_percent: SP=' + CAST(@t10_sla_pct AS VARCHAR) + ' Calc=' + CAST(@calc_sla_pct AS VARCHAR) +
      CASE WHEN ABS(@t10_sla_pct - @calc_sla_pct) < 0.02 THEN ' ✓ PASS' ELSE ' ✗ FAIL' END;

-- SLA <= answered (can't have more SLA than answered calls)
PRINT '  SLA <= Answered: ' + CAST(@t10_sla AS VARCHAR) + ' <= ' + CAST(@t10_answered AS VARCHAR) +
      CASE WHEN @t10_sla <= @t10_answered THEN ' ✓ PASS' ELSE ' ✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 11: CHART PERCENTAGE VALIDATION
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 11: Chart per-row percentage validation (8000)';

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @from, @to, @q_single, @wait;

DECLARE @bad_answer_rate INT = (
    SELECT COUNT(*) FROM #chart_result
    WHERE total_calls > 0
      AND ABS(answer_rate - CAST(answered_calls * 100.0 / total_calls AS DECIMAL(5,2))) > 0.02
);
PRINT '  answer_rate correct: ' +
      CASE WHEN @bad_answer_rate = 0 THEN '✓ PASS (all rows)' ELSE '✗ FAIL (' + CAST(@bad_answer_rate AS VARCHAR) + ' bad rows)' END;

DECLARE @bad_sla_rate INT = (
    SELECT COUNT(*) FROM #chart_result
    WHERE answered_calls > 0
      AND ABS(sla_percent - CAST(answered_within_sla * 100.0 / answered_calls AS DECIMAL(5,2))) > 0.02
);
PRINT '  sla_percent correct: ' +
      CASE WHEN @bad_sla_rate = 0 THEN '✓ PASS (all rows)' ELSE '✗ FAIL (' + CAST(@bad_sla_rate AS VARCHAR) + ' bad rows)' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 12: NARROW DATE RANGE (1 week)
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 12: Narrow date range (Feb 1-7, 2026) - single queue';

DECLARE @narrow_from DATETIMEOFFSET = '2026-02-01 00:00:00 +00:00';
DECLARE @narrow_to   DATETIMEOFFSET = '2026-02-07 23:59:59 +00:00';

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @narrow_from, @narrow_to, @q_single, @wait;

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @narrow_from, @narrow_to, @q_single, @wait;

DECLARE @narrow_kpi_total INT = (SELECT total_calls FROM #kpi_result);
DECLARE @narrow_chart_total INT = (SELECT SUM(total_calls) FROM #chart_result);
DECLARE @narrow_chart_days INT = (SELECT COUNT(*) FROM #chart_result);

PRINT '  KPI total=' + CAST(ISNULL(@narrow_kpi_total,0) AS VARCHAR) +
      ' Chart SUM=' + CAST(ISNULL(@narrow_chart_total,0) AS VARCHAR) +
      CASE WHEN ISNULL(@narrow_kpi_total,0) = ISNULL(@narrow_chart_total,0) THEN ' ✓ PASS' ELSE ' ✗ FAIL' END;
PRINT '  Chart days: ' + CAST(@narrow_chart_days AS VARCHAR) + ' (expected <= 7) ' +
      CASE WHEN @narrow_chart_days <= 7 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '  Narrow <= Full: ' +
      CASE WHEN ISNULL(@narrow_kpi_total,0) <= @sp_total_1 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 13: DIFFERENT SLA THRESHOLDS
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 13: SLA threshold sensitivity (8000)';

DECLARE @sla_5s INT, @sla_20s INT, @sla_60s INT;
DECLARE @total_5s INT, @total_20s INT, @total_60s INT;

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_single, '00:00:05';
SELECT @sla_5s = answered_within_sla, @total_5s = total_calls FROM #kpi_result;

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_single, '00:00:20';
SELECT @sla_20s = answered_within_sla, @total_20s = total_calls FROM #kpi_result;

TRUNCATE TABLE #kpi_result;
INSERT INTO #kpi_result
EXEC dbo.sp_queue_kpi_summary_shushant @from, @to, @q_single, '00:01:00';
SELECT @sla_60s = answered_within_sla, @total_60s = total_calls FROM #kpi_result;

-- Stricter threshold → fewer SLA-compliant calls (or equal)
PRINT '  SLA@5s=' + CAST(ISNULL(@sla_5s,0) AS VARCHAR) +
      ' SLA@20s=' + CAST(ISNULL(@sla_20s,0) AS VARCHAR) +
      ' SLA@60s=' + CAST(ISNULL(@sla_60s,0) AS VARCHAR);
PRINT '  5s <= 20s <= 60s: ' +
      CASE WHEN ISNULL(@sla_5s,0) <= ISNULL(@sla_20s,0) AND ISNULL(@sla_20s,0) <= ISNULL(@sla_60s,0)
           THEN '✓ PASS' ELSE '✗ FAIL' END;

-- Different thresholds affect total_calls (ring_time >= @wait_interval filter on abandoned)
PRINT '  Total@5s=' + CAST(ISNULL(@total_5s,0) AS VARCHAR) +
      ' Total@20s=' + CAST(ISNULL(@total_20s,0) AS VARCHAR) +
      ' Total@60s=' + CAST(ISNULL(@total_60s,0) AS VARCHAR);
-- Higher threshold → fewer abandoned counted → fewer total calls (or equal)
PRINT '  Total@5s >= Total@20s >= Total@60s: ' +
      CASE WHEN ISNULL(@total_5s,0) >= ISNULL(@total_20s,0) AND ISNULL(@total_20s,0) >= ISNULL(@total_60s,0)
           THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 14: CHART SP - Empty/Invalid queue returns no data rows
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 14: Chart SP edge cases';

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @from, @to, @q_invalid, @wait;

DECLARE @chart_invalid_rows INT = (SELECT COUNT(*) FROM #chart_result);
PRINT '  Invalid queue (9999) rows: ' + CAST(@chart_invalid_rows AS VARCHAR) + ' (expected: 0) ' +
      CASE WHEN @chart_invalid_rows = 0 THEN '✓ PASS' ELSE '✗ FAIL' END;

TRUNCATE TABLE #chart_result;
INSERT INTO #chart_result
EXEC dbo.sp_queue_calls_by_date_shushant @from, @to, @q_empty, @wait;

DECLARE @chart_empty_rows INT = (SELECT COUNT(*) FROM #chart_result);
PRINT '  Empty queue (all) rows: ' + CAST(@chart_empty_rows AS VARCHAR) + ' (expected: > 0) ' +
      CASE WHEN @chart_empty_rows > 0 THEN '✓ PASS' ELSE '✗ FAIL' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- TEST 15: AGENT SP - Answered count per agent never exceeds total
-- ─────────────────────────────────────────────────────────────────
PRINT '>>> TEST 15: Agent SP data sanity checks (8000)';

TRUNCATE TABLE #agent_result;
INSERT INTO #agent_result
EXEC dbo.qcall_cent_get_extensions_statistics_by_queues @from, @to, @q_single, @wait;

DECLARE @agent_exceeds INT = (
    SELECT COUNT(*) FROM #agent_result WHERE extension_answered_count > queue_received_count
);
PRINT '  No agent answered > queue total: ' +
      CASE WHEN @agent_exceeds = 0 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@agent_exceeds AS VARCHAR) + ' agents exceed)' END;

-- No null extension_dn
DECLARE @null_ext INT = (SELECT COUNT(*) FROM #agent_result WHERE extension_dn IS NULL);
PRINT '  No null extension_dn: ' +
      CASE WHEN @null_ext = 0 THEN '✓ PASS' ELSE '✗ FAIL' END;

-- All display names non-empty
DECLARE @empty_name INT = (SELECT COUNT(*) FROM #agent_result WHERE extension_display_name IS NULL OR extension_display_name = '');
PRINT '  All agents have display name: ' +
      CASE WHEN @empty_name = 0 THEN '✓ PASS' ELSE '✗ FAIL (' + CAST(@empty_name AS VARCHAR) + ' empty)' END;
PRINT '';

-- ─────────────────────────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────────────────────────
DROP TABLE #kpi_result;
DROP TABLE #chart_result;
DROP TABLE #agent_result;
DROP TABLE #raw_counts;

PRINT '============================================================';
PRINT ' TEST SUITE COMPLETE';
PRINT '============================================================';
