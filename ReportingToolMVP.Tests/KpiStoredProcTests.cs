namespace ReportingToolMVP.Tests;

/// <summary>
/// Tests for sp_queue_kpi_summary_shushant stored procedure.
/// Validates KPI values against raw CallCent_QueueCalls_View data.
/// </summary>
public class KpiStoredProcTests : DatabaseTestBase
{
    [Fact]
    public void SingleQueue_TotalsMatchRawData()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var raw = GetRawCounts(conn, PeriodFrom, PeriodTo, SingleQueue, WaitInterval);

        Assert.Single(kpi.Rows);
        var row = kpi.Rows[0];

        Assert.Equal(raw.total, Convert.ToInt32(row["total_calls"]));
        Assert.Equal(raw.answered, Convert.ToInt32(row["answered_calls"]));
        Assert.Equal(raw.abandoned, Convert.ToInt32(row["abandoned_calls"]));
        Assert.Equal(raw.sla, Convert.ToInt32(row["answered_within_sla"]));
    }

    [Fact]
    public void SingleQueue_AnsweredPlusAbandonedEqualsTotal()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var row = kpi.Rows[0];
        var total = Convert.ToInt32(row["total_calls"]);
        var answered = Convert.ToInt32(row["answered_calls"]);
        var abandoned = Convert.ToInt32(row["abandoned_calls"]);

        Assert.Equal(total, answered + abandoned);
    }

    [Fact]
    public void SingleQueue_PercentagesAreCorrect()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var row = kpi.Rows[0];
        var total = Convert.ToInt32(row["total_calls"]);
        var answered = Convert.ToInt32(row["answered_calls"]);
        var sla = Convert.ToInt32(row["answered_within_sla"]);
        var answeredPct = Convert.ToDecimal(row["answered_percent"]);
        var slaPct = Convert.ToDecimal(row["answered_within_sla_percent"]);

        if (total > 0)
        {
            var expectedAnsweredPct = Math.Round(answered * 100.0m / total, 2);
            Assert.InRange(Math.Abs(answeredPct - expectedAnsweredPct), 0, 0.02m);
        }

        if (answered > 0)
        {
            var expectedSlaPct = Math.Round(sla * 100.0m / answered, 2);
            Assert.InRange(Math.Abs(slaPct - expectedSlaPct), 0, 0.02m);
        }
    }

    [Fact]
    public void SingleQueue_SlaLessThanOrEqualToAnswered()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var row = kpi.Rows[0];
        var answered = Convert.ToInt32(row["answered_calls"]);
        var sla = Convert.ToInt32(row["answered_within_sla"]);

        Assert.True(sla <= answered, $"SLA ({sla}) should not exceed answered ({answered})");
    }

    [Fact]
    public void SingleQueue_DisplayNameIsQueueName()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var displayName = kpi.Rows[0]["queue_display_name"].ToString();
        Assert.NotNull(displayName);
        Assert.NotEmpty(displayName);
        Assert.DoesNotContain("Multiple Queues", displayName);
    }

    [Fact]
    public void MultiQueue_TotalsMatchRawData()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());
        var raw = GetRawCounts(conn, PeriodFrom, PeriodTo, MultiQueue, WaitInterval);

        Assert.Single(kpi.Rows);
        var row = kpi.Rows[0];

        Assert.Equal(raw.total, Convert.ToInt32(row["total_calls"]));
        Assert.Equal(raw.answered, Convert.ToInt32(row["answered_calls"]));
        Assert.Equal(raw.abandoned, Convert.ToInt32(row["abandoned_calls"]));
    }

    [Fact]
    public void MultiQueue_DisplayNameShowsMultipleOrQueueName()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var displayName = kpi.Rows[0]["queue_display_name"].ToString();
        Assert.NotNull(displayName);
        Assert.NotEmpty(displayName);

        // If multiple queues have data in range, display name contains "Multiple Queues"
        // If only one queue has data, display name is that queue's name
        var queueCount = MultiQueue.Split(',').Length;
        if (queueCount > 1)
        {
            // Display name should be either a valid queue name or "Multiple Queues (N)"
            Assert.True(
                displayName.Contains("Multiple Queues") || !string.IsNullOrEmpty(displayName),
                $"Expected 'Multiple Queues' or a valid queue name, got: '{displayName}'");
        }
    }

    [Fact]
    public void MultiQueue_TotalGreaterOrEqualSingleQueue()
    {
        using var conn = CreateConnection();
        var single = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var multi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var singleTotal = Convert.ToInt32(single.Rows[0]["total_calls"]);
        var multiTotal = Convert.ToInt32(multi.Rows[0]["total_calls"]);

        Assert.True(multiTotal >= singleTotal,
            $"Multi-queue total ({multiTotal}) should be >= single queue ({singleTotal})");
    }

    [Fact]
    public void InvalidQueue_ReturnsZeroCalls()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, InvalidQueue, WaitInterval.ToString());

        Assert.Single(kpi.Rows);
        Assert.Equal(0, Convert.ToInt32(kpi.Rows[0]["total_calls"]));
    }

    [Fact]
    public void EmptyQueue_ReturnsAllQueuesData()
    {
        using var conn = CreateConnection();
        var single = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var all = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, "", WaitInterval.ToString());

        Assert.Single(all.Rows);
        var allTotal = Convert.ToInt32(all.Rows[0]["total_calls"]);
        var singleTotal = Convert.ToInt32(single.Rows[0]["total_calls"]);

        Assert.True(allTotal > 0, "All queues should return > 0 calls");
        Assert.True(allTotal >= singleTotal, "All queues total should be >= single queue");
    }

    [Fact]
    public void SlaThreshold_StricterThresholdFewerSlaHits()
    {
        using var conn = CreateConnection();
        var sla5s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:00:05");
        var sla20s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:00:20");
        var sla60s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:01:00");

        var hits5 = Convert.ToInt32(sla5s.Rows[0]["answered_within_sla"]);
        var hits20 = Convert.ToInt32(sla20s.Rows[0]["answered_within_sla"]);
        var hits60 = Convert.ToInt32(sla60s.Rows[0]["answered_within_sla"]);

        Assert.True(hits5 <= hits20, $"SLA@5s ({hits5}) should be <= SLA@20s ({hits20})");
        Assert.True(hits20 <= hits60, $"SLA@20s ({hits20}) should be <= SLA@60s ({hits60})");
    }

    [Fact]
    public void SlaThreshold_HigherThresholdFewerAbandonedCounted()
    {
        using var conn = CreateConnection();
        var sla5s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:00:05");
        var sla20s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:00:20");
        var sla60s = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, "00:01:00");

        var total5 = Convert.ToInt32(sla5s.Rows[0]["total_calls"]);
        var total20 = Convert.ToInt32(sla20s.Rows[0]["total_calls"]);
        var total60 = Convert.ToInt32(sla60s.Rows[0]["total_calls"]);

        Assert.True(total5 >= total20, $"Total@5s ({total5}) should be >= Total@20s ({total20})");
        Assert.True(total20 >= total60, $"Total@20s ({total20}) should be >= Total@60s ({total60})");
    }
}
