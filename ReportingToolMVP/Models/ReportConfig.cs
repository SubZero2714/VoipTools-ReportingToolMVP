namespace ReportingToolMVP.Models
{
    /// <summary>
    /// Represents user's report configuration and selections
    /// Used to store the state of column selections, filters, and chart settings
    /// </summary>
    public class ReportConfig
    {
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        
        public List<string> SelectedColumns { get; set; } = new();
        public List<string> SelectedQueueIds { get; set; } = new();
        
        public string ChartType { get; set; } = "None"; // None, Bar, Pie, Line
        public string ChartXField { get; set; } = string.Empty;
        public string ChartYField { get; set; } = string.Empty;
    }
}
