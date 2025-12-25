namespace ReportingToolMVP.Models
{
    /// <summary>
    /// Flexible data row representation for dynamic column reports
    /// Uses Dictionary to allow variable columns based on user selection
    /// </summary>
    public class ReportDataRow
    {
        public Dictionary<string, object?> Data { get; set; } = new();

        public ReportDataRow() { }

        public ReportDataRow(Dictionary<string, object?> data)
        {
            Data = data;
        }

        public object? GetValue(string columnName)
        {
            if (Data.TryGetValue(columnName, out var value))
                return value;
            return null;
        }

        public void SetValue(string columnName, object? value)
        {
            Data[columnName] = value;
        }
    }
}
