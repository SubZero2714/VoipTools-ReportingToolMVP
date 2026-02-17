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
                { "3CX_Exporter_Production", "3CX Exporter Production Database (LIVE DATA)" },
                { "3CX_Exporter_Local", "3CX Exporter Local Test Database" }
            };
        }

        /// <summary>
        /// Returns connection parameters for a named connection.
        /// These parameters are serialized and stored with the report.
        /// </summary>
        public DataConnectionParametersBase? GetDataConnectionParameters(string name)
        {
            _logger.LogInformation($"GetDataConnectionParameters called for: {name}");
            
            // Production database (LIVE)
            if (name == "3CX_Exporter_Production" || name == "3CX_Exporter" || name == "DefaultConnection")
            {
                var connectionString = @"XpoProvider=MSSqlServer;Data Source=3.132.72.134;Initial Catalog=3CX Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                
                _logger.LogInformation($"Returning PRODUCTION connection for {name}");
                return new CustomStringConnectionParameters(connectionString);
            }
            
            // Local test database
            if (name == "3CX_Exporter_Local")
            {
                var connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                
                _logger.LogInformation($"Returning LOCAL TEST connection for {name}");
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
    /// This is registered as a scoped service and injected into the factory.
    /// </summary>
    public class CustomConnectionProviderService : IConnectionProviderService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<CustomConnectionProviderService> _logger;

        public CustomConnectionProviderService(
            IConfiguration configuration,
            ILogger<CustomConnectionProviderService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public SqlDataConnection? LoadConnection(string connectionName)
        {
            _logger.LogInformation($"LoadConnection called for: '{connectionName}'");

            // Get connection string from configuration or use hardcoded defaults
            string? connectionString = null;

            // Production database (LIVE) - default for all connections
            if (string.IsNullOrEmpty(connectionName) || 
                connectionName == "3CX_Exporter_Production" || 
                connectionName == "3CX_Exporter" || 
                connectionName == "DefaultConnection")
            {
                connectionString = @"XpoProvider=MSSqlServer;Data Source=3.132.72.134;Initial Catalog=3CX Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                _logger.LogInformation($"Using PRODUCTION connection for '{connectionName}'");
            }
            // Local test database
            else if (connectionName == "3CX_Exporter_Local")
            {
                connectionString = @"XpoProvider=MSSqlServer;Server=LAPTOP-A5UI98NJ\SQLEXPRESS;Database=Test_3CX_Exporter;User Id=sa;Password=V01PT0y5;TrustServerCertificate=True;Encrypt=False;";
                _logger.LogInformation($"Using LOCAL TEST connection for '{connectionName}'");
            }
            else
            {
                _logger.LogWarning($"Unknown connection name: '{connectionName}', returning null");
                return null;
            }

            if (string.IsNullOrEmpty(connectionString))
            {
                _logger.LogError($"Connection string is null or empty for '{connectionName}'");
                return null;
            }

            var connectionParameters = new CustomStringConnectionParameters(connectionString);
            var connection = new SqlDataConnection(connectionName ?? "3CX_Exporter_Production", connectionParameters);
            _logger.LogInformation($"Successfully created SqlDataConnection for '{connectionName}'");
            return connection;
        }
    }

    /// <summary>
    /// Factory for creating connection provider instances.
    /// The service is injected via DI and returned when Create() is called.
    /// </summary>
    public class CustomConnectionProviderFactory : IConnectionProviderFactory
    {
        private readonly IConnectionProviderService _connectionProviderService;

        public CustomConnectionProviderFactory(IConnectionProviderService connectionProviderService)
        {
            _connectionProviderService = connectionProviderService;
        }

        public IConnectionProviderService Create()
        {
            return _connectionProviderService;
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
