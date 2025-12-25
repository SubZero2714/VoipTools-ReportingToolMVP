namespace ReportingToolMVP.Models
{
    /// <summary>
    /// Represents a feature in the MVP testing checklist
    /// </summary>
    public class Feature
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string TestCriteria { get; set; } = string.Empty;
        public FeatureStatus Status { get; set; } = FeatureStatus.Planned;
        public bool IsCompleted { get; set; } = false;
        public string Notes { get; set; } = string.Empty;
    }

    /// <summary>
    /// Feature status enumeration
    /// </summary>
    public enum FeatureStatus
    {
        Completed,
        InProgress,
        Planned,
        Blocked
    }
}
