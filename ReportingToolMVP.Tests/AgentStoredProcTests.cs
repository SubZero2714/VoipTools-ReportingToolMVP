using System.Data;

namespace ReportingToolMVP.Tests;

/// <summary>
/// Tests for qcall_cent_get_extensions_statistics_by_queues stored procedure.
/// Validates agent performance data against KPI SP and internal consistency.
/// </summary>
public class AgentStoredProcTests : DatabaseTestBase
{
    [Fact]
    public void SingleQueue_AgentAnsweredNotExceedKpi()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var kpiAnswered = Convert.ToInt32(kpi.Rows[0]["answered_calls"]);
        var agentTotalAnswered = agents.AsEnumerable()
            .Sum(r => Convert.ToInt32(r["extension_answered_count"]));

        // Agent total may be less (agents removed from ext view) but never more
        Assert.True(agentTotalAnswered <= kpiAnswered,
            $"Agent SUM(answered)={agentTotalAnswered} should never exceed KPI answered={kpiAnswered}");
    }

    [Fact]
    public void SingleQueue_AllAgentsHaveCorrectQueueDn()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in agents.Rows)
        {
            var queueDn = row["queue_dn"]?.ToString();
            Assert.Equal(SingleQueue, queueDn);
        }
    }

    [Fact]
    public void SingleQueue_ConsistentQueueReceivedCount()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        var receivedCounts = agents.AsEnumerable()
            .Where(r => r["queue_dn"]?.ToString() == SingleQueue)
            .Select(r => Convert.ToInt32(r["queue_received_count"]))
            .Distinct()
            .ToList();

        Assert.True(receivedCounts.Count <= 1,
            $"Expected consistent queue_received_count but found {receivedCounts.Count} distinct values");
    }

    [Fact]
    public void SingleQueue_NoAgentExceedsQueueTotal()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in agents.Rows)
        {
            var agentAnswered = Convert.ToInt32(row["extension_answered_count"]);
            var queueReceived = Convert.ToInt32(row["queue_received_count"]);
            var agentName = row["extension_display_name"]?.ToString();

            Assert.True(agentAnswered <= queueReceived,
                $"Agent '{agentName}' answered={agentAnswered} exceeds queue total={queueReceived}");
        }
    }

    [Fact]
    public void SingleQueue_AllAgentsHaveDisplayName()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in agents.Rows)
        {
            var displayName = row["extension_display_name"]?.ToString();
            Assert.False(string.IsNullOrEmpty(displayName), "Agent display name should not be null or empty");
        }
    }

    [Fact]
    public void SingleQueue_AllAgentsHaveExtensionDn()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());

        foreach (System.Data.DataRow row in agents.Rows)
        {
            Assert.False(row.IsNull("extension_dn"), "extension_dn should not be null");
        }
    }

    [Fact]
    public void MultiQueue_ContainsAgentsFromBothQueues()
    {
        using var conn = CreateConnection();
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var distinctQueues = agents.AsEnumerable()
            .Select(r => r["queue_dn"]?.ToString())
            .Distinct()
            .ToList();

        var expectedQueues = MultiQueue.Split(',').Select(q => q.Trim()).ToList();
        Assert.Equal(expectedQueues.Count, distinctQueues.Count);
    }

    [Fact]
    public void MultiQueue_AgentAnsweredNotExceedKpi()
    {
        using var conn = CreateConnection();
        var kpi = ExecuteSP(conn, "sp_queue_kpi_summary_shushant",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());
        var agents = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        var kpiAnswered = Convert.ToInt32(kpi.Rows[0]["answered_calls"]);
        var agentTotalAnswered = agents.AsEnumerable()
            .Sum(r => Convert.ToInt32(r["extension_answered_count"]));

        Assert.True(agentTotalAnswered <= kpiAnswered,
            $"Agent SUM(answered)={agentTotalAnswered} should never exceed KPI answered={kpiAnswered}");
    }

    [Fact]
    public void MultiQueue_MoreRowsThanSingleQueue()
    {
        using var conn = CreateConnection();
        var single = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, SingleQueue, WaitInterval.ToString());
        var multi = ExecuteSP(conn, "qcall_cent_get_extensions_statistics_by_queues",
            PeriodFrom, PeriodTo, MultiQueue, WaitInterval.ToString());

        Assert.True(multi.Rows.Count >= single.Rows.Count,
            $"Multi-queue ({multi.Rows.Count} rows) should have >= single queue ({single.Rows.Count} rows)");
    }
}
