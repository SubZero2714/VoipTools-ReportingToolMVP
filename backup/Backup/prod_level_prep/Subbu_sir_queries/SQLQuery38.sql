USE [3CX Exporter]
GO
 
/****** Object:  View [dbo].[queue_view]    Script Date: 09-02-2026 03:10:42 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
		CREATE   VIEW [dbo].[queue_view]
AS
SELECT q.fkiddn AS id,
    d.value AS dn,
    q.name AS display_name
   FROM queue q
     JOIN dn d ON q.fkiddn = d.iddn;
-- ORDER BY q.name;
GO