USE [3CX Exporter]
GO
 
/****** Object:  UserDefinedFunction [dbo].[cl_is_internal]    Script Date: 09-02-2026 03:26:27 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE   FUNCTION [dbo].[cl_is_internal]
(
    @dn_type   INT,
    @act_id    INT,
    @is_source BIT
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT;
 
    -- Simple dn types for internal dn
    IF @dn_type IN (0, 2, 3, 4, 9)
        RETURN 1;
 
    -- Simple dn types for external dn
    IF @dn_type IN (1, 13)
        RETURN 0;
 
    IF @is_source = 0 
       AND @dn_type = 12 
       AND @act_id IN (408, 426, 431, 432)
        RETURN 0;
 
    IF @is_source = 1 
       AND @dn_type = 12 
       AND @act_id IN (1, 6)
        RETURN 1;
 
    -- Equivalent of PostgreSQL RETURN NULL
    RETURN NULL;
END;
GO