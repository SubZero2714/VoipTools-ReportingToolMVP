using DevExpress.DataAccess.ConnectionParameters;
using DevExpress.DataAccess.Sql;
using DevExpress.DataAccess.Web;
using DevExpress.DataAccess.Wizard.Services;
using DevExpress.Xpo.DB;

namespace ReportingToolMVP.Services
{
    /// <summary>
    /// Validator that allows custom SQL queries to execute.
    /// DevExpress blocks custom SQL queries by default for security.
    /// This validator permits all queries - in production, add proper validation.
    /// </summary>
    public class AllowAllQueriesValidator : ICustomQueryValidator
    {
        public bool Validate(DataConnectionParametersBase connectionParameters, string sql, ref string message)
        {
            // Allow all queries (for development)
            // In production, validate query content for security
            message = string.Empty;
            return true;
        }
    }

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
                // Use CustomStringConnectionParameters with TrustServerCertificate for SSL compatibility
                var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                
                _logger.LogInformation($"Returning CustomStringConnectionParameters for {name}");
                return new CustomStringConnectionParameters(connectionString);
            }
            
            _logger.LogWarning($"Unknown connection name: {name}");
            return null;
        }
    }

    /// <summary>
    /// Factory for creating DB Schema Providers used by the Query Builder.
    /// This is REQUIRED for the Query Builder pencil icon to work!
    /// </summary>
    public class CustomDBSchemaProviderExFactory : IDBSchemaProviderExFactory
    {
        public IDBSchemaProviderEx Create()
        {
            // Returns the default DB schema provider which handles Query Builder operations
            return new DBSchemaProviderEx();
        }
    }

    /// <summary>
    /// Provides connection options for data connections in the designer.
    /// Required for editing queries in existing data sources.
    /// </summary>
    public class CustomConnectionProviderFactory : IConnectionProviderFactory
    {
        public IConnectionProviderService Create()
        {
            return new CustomConnectionProviderService();
        }
    }

    /// <summary>
    /// Service that provides database connections to the Query Builder.
    /// </summary>
    public class CustomConnectionProviderService : IConnectionProviderService
    {
        public SqlDataConnection? LoadConnection(string connectionName)
        {
            // Return a connection based on the name
            if (connectionName == "3CX_Exporter" || connectionName == "DefaultConnection")
            {
                var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                var connection = new SqlDataConnection(connectionName, new CustomStringConnectionParameters(connectionString));
                return connection;
            }
            return null;
        }
    }
}
