-- ============================================================
-- Report Schedules Table
-- Stores email schedule configurations for automated report delivery
-- Database: 3CX Exporter (production: 3.132.72.134)
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[report_schedules]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[report_schedules] (
        [id]                    INT IDENTITY(1,1)   NOT NULL,
        [schedule_name]         NVARCHAR(200)       NOT NULL,
        [report_name]           NVARCHAR(500)       NOT NULL,   -- .repx filename (without extension)
        [is_enabled]            BIT                 NOT NULL DEFAULT 1,
        
        -- Schedule Configuration
        [frequency]             NVARCHAR(20)        NOT NULL DEFAULT 'Weekly',  -- Daily, Weekly, Monthly
        [day_of_week]           INT                 NULL,       -- 0=Sun, 1=Mon, ... 6=Sat (for Weekly)
        [day_of_month]          INT                 NULL,       -- 1-28 (for Monthly)
        [scheduled_time]        TIME                NOT NULL DEFAULT '08:00:00', -- Time of day to generate
        [timezone]              NVARCHAR(100)       NOT NULL DEFAULT 'India Standard Time',
        
        -- Report Parameters (stored as JSON)
        [report_params_json]    NVARCHAR(MAX)       NULL,
        
        -- Email Configuration
        [email_to]              NVARCHAR(MAX)       NOT NULL,   -- Comma-separated email addresses
        [email_cc]              NVARCHAR(MAX)       NULL,       -- Comma-separated CC addresses
        [email_subject]         NVARCHAR(500)       NULL,       -- Custom subject (null = auto-generated)
        [email_body]            NVARCHAR(MAX)       NULL,       -- Custom body (null = default template)
        [export_format]         NVARCHAR(10)        NOT NULL DEFAULT 'PDF',  -- PDF, XLSX, CSV
        
        -- Tracking
        [last_run_utc]          DATETIME2           NULL,
        [last_run_status]       NVARCHAR(20)        NULL,       -- Success, Failed, Running
        [last_run_error]        NVARCHAR(MAX)       NULL,
        [next_run_utc]          DATETIME2           NULL,
        [run_count]             INT                 NOT NULL DEFAULT 0,
        
        -- Audit
        [created_by]            NVARCHAR(100)       NULL,
        [created_utc]           DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
        [updated_utc]           DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT [PK_report_schedules] PRIMARY KEY CLUSTERED ([id]),
        CONSTRAINT [CK_report_schedules_frequency] CHECK ([frequency] IN ('Daily', 'Weekly', 'Monthly')),
        CONSTRAINT [CK_report_schedules_day_of_week] CHECK ([day_of_week] IS NULL OR [day_of_week] BETWEEN 0 AND 6),
        CONSTRAINT [CK_report_schedules_day_of_month] CHECK ([day_of_month] IS NULL OR [day_of_month] BETWEEN 1 AND 28),
        CONSTRAINT [CK_report_schedules_export_format] CHECK ([export_format] IN ('PDF', 'XLSX', 'CSV'))
    );

    PRINT 'Created table: report_schedules';
END
ELSE
BEGIN
    PRINT 'Table report_schedules already exists.';
END
GO

-- Index for scheduler lookups
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_report_schedules_next_run')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_report_schedules_next_run]
    ON [dbo].[report_schedules] ([is_enabled], [next_run_utc])
    INCLUDE ([report_name], [frequency], [scheduled_time], [timezone]);
    
    PRINT 'Created index: IX_report_schedules_next_run';
END
GO
