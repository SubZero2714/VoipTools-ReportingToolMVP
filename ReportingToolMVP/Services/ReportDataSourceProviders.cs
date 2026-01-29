using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.DataAccess.Web;
using DevExpress.DataAccess.Wizard.Services;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Provides available data connections for the Report Designer wizard.
    /// This service supplies connection strings to display in the Data Source Wizard.
    /// </summary>
    public class CustomDataSourceWizardConnectionStringsProvider : IDataSourceWizardConnectionStringsProvider
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<CustomDataSourceWizardConnectionStringsProvider> _logger;

        public CustomDataSourceWizardConnectionStringsProvider(
            IConfiguration configuration,
            ILogger<CustomDataSourceWizardConnectionStringsProvider> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        /// <summary>
        /// Returns connection descriptions that appear in the Data Source wizard dropdown.
        /// Key = connection name, Value = display description
        /// </summary>
        public Dictionary<string, string> GetConnectionDescriptions()
        {
            _logger.LogInformation("GetConnectionDescriptions called - returning available connections");
            
            return new Dictionary<string, string>
            {
                { "3CX_Exporter", "3CX Exporter Database (Call Queue Data)" },
                { "DefaultConnection", "Default SQL Server Connection" }
            };
        }

        /// <summary>
        /// Returns connection parameters for a named connection.
        /// These parameters are serialized and stored with the report.
        /// </summary>
        public DataConnectionParametersBase? GetDataConnectionParameters(string name)
        {
            _logger.LogInformation($"GetDataConnectionParameters called for: {name}");
            
            if (name == "3CX_Exporter" || name == "DefaultConnection")
            {
                var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                
                _logger.LogInformation($"Returning CustomStringConnectionParameters for {name}");
                return new CustomStringConnectionParameters(connectionString);
            }
            
            _logger.LogWarning($"Unknown connection name: {name}");
            return null;
        }
    }

    /// <summary>
    /// Validates custom SQL queries in the Report Designer's Query Builder.
    /// This implementation allows all queries - customize for production security.
    /// </summary>
    public class AllowAllQueriesValidator : ICustomQueryValidator
    {
        public bool Validate(DataConnectionParametersBase connectionParameters, string sql, ref string message)
        {
            // Allow all queries (for development)
            message = string.Empty;
            return true;
        }
    }

    /// <summary>
    /// Service that provides database connections for report execution.
    /// Called when previewing or running reports.
    /// </summary>
    public class CustomConnectionProviderService : IConnectionProviderService
    {
        public SqlDataConnection? LoadConnection(string connectionName)
        {
            if (connectionName == "3CX_Exporter" || connectionName == "DefaultConnection")
            {
                var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                return new SqlDataConnection(connectionName, new CustomStringConnectionParameters(connectionString));
            }
            return null;
        }
    }

    /// <summary>
    /// Factory for creating connection provider instances.
    /// </summary>
    public class CustomConnectionProviderFactory : IConnectionProviderFactory
    {
        public IConnectionProviderService Create()
        {
            return new CustomConnectionProviderService();
        }
    }

    /// <summary>
    /// Factory for creating DB Schema Provider instances.
    /// Required for the Query Builder in Report Designer to work.
    /// </summary>
    public class CustomDBSchemaProviderExFactory : DevExpress.DataAccess.Web.IDBSchemaProviderExFactory
    {
        public DevExpress.DataAccess.Sql.IDBSchemaProviderEx Create()
        {
            return new DevExpress.DataAccess.Sql.DBSchemaProviderEx();
        }
    }
}
