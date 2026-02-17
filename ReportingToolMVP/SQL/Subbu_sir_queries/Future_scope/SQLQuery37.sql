USE [3CX Exporter]
GO
 
/****** Object:  View [dbo].[users_view]    Script Date: 09-02-2026 03:08:34 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
 
CREATE   VIEW [dbo].[users_view]
AS
SELECT 
    u.iduser                          AS id,
    d.iddn,
    d.value                           AS dn,
    CONCAT(u.firstname, ' ', u.lastname) AS display_name
FROM dbo.users u
INNER JOIN dbo.extension e 
    ON u.fkidextension = e.fkiddn
INNER JOIN dbo.dn d 
    ON e.fkiddn = d.iddn;
GO