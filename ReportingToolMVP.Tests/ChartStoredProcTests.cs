using System.Data;

namespace ReportingToolMVP.Tests;

/// <summary>
/// Tests for sp_queue_calls_by_date_shushant stored procedure.
/// Validates chart data against KPI SP and internal consistency.
/// </summary>
public class ChartStoredProcTests : DatabaseTestBase
{
    [Fact]
    public void SingleQueue_SumMatchesKpiTotal()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var kpiTotal = Convert.ToInt32(kpi.Rows[0]["total_calls"]);
        var kpiAnswered = Convert.ToInt32(kpi.Rows[0]["answered_calls"]);
        var kpiAbandoned = Convert.ToInt32(kpi.Rows[0]["abandoned_calls"]);

        var chartTotal = chart.AsEnumerable().Sum(r => Convert.ToInt32(r["total_calls"]));
        var chartAnswered = chart.AsEnumerable().Sum(r => Convert.ToInt32(r["answered_calls"]));
        var chartAbandoned = chart.AsEnumerable().Sum(r => Convert.ToInt32(r["abandoned_calls"]));

        Assert.Equal(kpiTotal, chartTotal);
        Assert.Equal(kpiAnswered, chartAnswered);
        Assert.Equal(kpiAbandoned, chartAbandoned);
    }

    [Fact]
    public void SingleQueue_EachRowAnsweredPlusAbandonedEqualsTotal()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in chart.Rows)
        {
            var total = Convert.ToInt32(row["total_calls"]);
            var answered = Convert.ToInt32(row["answered_calls"]);
            var abandoned = Convert.ToInt32(row["abandoned_calls"]);
            var date = row["call_date"]?.ToString();

            Assert.Equal(total, answered + abandoned);
        }
    }

    [Fact]
    public void SingleQueue_NoDuplicateDates()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var dates = chart.AsEnumerable()
            .Select(r => r["call_date"]?.ToString())
            .ToList();

        Assert.Equal(dates.Count, dates.Distinct().Count());
    }

    [Fact]
    public void SingleQueue_AnswerRatePercentageCorrect()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in chart.Rows)
        {
            var total = Convert.ToInt32(row["total_calls"]);
            if (total == 0) continue;

            var answered = Convert.ToInt32(row["answered_calls"]);
            var answerRate = Convert.ToDecimal(row["answer_rate"]);
            var expected = Math.Round(answered * 100.0m / total, 2);

            Assert.InRange(Math.Abs(answerRate - expected), 0, 0.02m);
        }
    }

    [Fact]
    public void SingleQueue_SlaPercentageCorrect()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in chart.Rows)
        {
            var answered = Convert.ToInt32(row["answered_calls"]);
            if (answered == 0) continue;

            var sla = Convert.ToInt32(row["answered_within_sla"]);
            var slaPct = Convert.ToDecimal(row["sla_percent"]);
            var expected = Math.Round(sla * 100.0m / answered, 2);

            Assert.InRange(Math.Abs(slaPct - expected), 0, 0.02m);
        }
    }

    [Fact]
    public void MultiQueue_SumMatchesKpiTotal()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var kpiTotal = Convert.ToInt32(kpi.Rows[0]["total_calls"]);
        var chartTotal = chart.AsEnumerable().Sum(r => Convert.ToInt32(r["total_calls"]));

        Assert.Equal(kpiTotal, chartTotal);
    }

    [Fact]
    public void MultiQueue_NoDuplicateDates()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var dates = chart.AsEnumerable()
            .Select(r => r["call_date"]?.ToString())
            .ToList();

        Assert.Equal(dates.Count, dates.Distinct().Count());
    }

    [Fact]
    public void InvalidQueue_ReturnsNoRows()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, InvalidQueue, WaitInterval.ToString());

        Assert.Empty(chart.Rows);
    }

    [Fact]
    public void EmptyQueue_ReturnsData()
    {
        using var conn = CreateConnection();
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            PeriodFrom, PeriodTo, "", WaitInterval.ToString());

        Assert.True(chart.Rows.Count > 0, "Empty queue param should return all queues data");
    }

    [Fact]
    public void NarrowDateRange_ChartMatchesKpi()
    {
        using var conn = CreateConnection();
        var narrowFrom = new DateTimeOffset(2025, 7, 1, 0, 0, 0, TimeSpan.Zero);
        var narrowTo = new DateTimeOffset(2025, 7, 7, 23, 59, 59, TimeSpan.Zero);

        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            narrowFrom, narrowTo, SingleQueue, WaitInterval.ToString());
        var chart = ExecuteSP(conn, "sp_queue_calls_by_date_shushant",
            narrowFrom, narrowTo, SingleQueue, WaitInterval.ToString());

        var kpiTotal = Convert.ToInt32(kpi.Rows[0]["total_calls"]);
        var chartTotal = chart.Rows.Count > 0
            ? chart.AsEnumerable().Sum(r => Convert.ToInt32(r["total_calls"]))
            : 0;

        Assert.Equal(kpiTotal, chartTotal);
        Assert.True(chart.Rows.Count <= 7, $"1-week range should have ≤7 rows, got {chart.Rows.Count}");
    }

    [Fact]
    public void NarrowRange_SubsetOfFullRange()
    {
        using var conn = CreateConnection();
        var narrowFrom = new DateTimeOffset(2025, 7, 1, 0, 0, 0, TimeSpan.Zero);
        var narrowTo = new DateTimeOffset(2025, 7, 7, 23, 59, 59, TimeSpan.Zero);

        var full = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var narrow = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            narrowFrom, narrowTo, SingleQueue, WaitInterval.ToString());

        var fullTotal = Convert.ToInt32(full.Rows[0]["total_calls"]);
        var narrowTotal = Convert.ToInt32(narrow.Rows[0]["total_calls"]);

        Assert.True(narrowTotal <= fullTotal,
            $"Narrow range ({narrowTotal}) should be <= full range ({fullTotal})");
    }
}
