USE [3CX Exporter]
GO
 
/****** Object:  View [dbo].[extensions_by_queues_view]    Script Date: 09-02-2026 03:11:41 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
 
	CREATE   VIEW [dbo].[extensions_by_queues_view]
AS
SELECT 
    uv.dn AS extension_dn,
    uv.display_name AS extension_display_name,
    qv.dn AS queue_dn,
    qv.display_name AS queue_display_name
FROM queue_view qv
INNER JOIN queue2dn q2dn 
    ON qv.id = q2dn.fkidqueue
INNER JOIN users_view uv 
    ON q2dn.fkiddn = uv.iddn;
GO