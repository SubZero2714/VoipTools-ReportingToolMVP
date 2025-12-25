namespace ReportingToolMVP.Models
{
    /// <summary>
    /// Basic queue information for dropdown/selection lists
    /// </summary>
    public class QueueBasicInfo
    {
        public string QueueId { get; set; } = string.Empty;
        public string QueueNumber { get; set; } = string.Empty;
        public string QueueName { get; set; } = string.Empty;

        public string DisplayName => $"{QueueNumber} - {QueueName}";
    }
}
