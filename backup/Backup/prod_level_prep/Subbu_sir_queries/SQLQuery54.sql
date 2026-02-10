USE [3CX Exporter]
GO
 
/****** Object:  UserDefinedFunction [dbo].[SplitString_XML]    Script Date: 09-02-2026 07:08:48 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
create FUNCTION [dbo].[SplitString_XML]
(
    @List      NVARCHAR(MAX),
    @Delimiter NVARCHAR(10) = N','
)
RETURNS @Items TABLE (Value NVARCHAR(4000) NOT NULL)
AS
BEGIN
    IF @List IS NULL OR @List = N'' 
        RETURN;
 
    INSERT @Items (Value)
    SELECT 
        LTRIM(RTRIM(CAST(m.n.value('.','NVARCHAR(4000)') AS NVARCHAR(4000))))
    FROM 
    (
        SELECT CAST(N'<x>' + REPLACE(@List, @Delimiter, N'</x><x>') + N'</x>' AS XML) AS x
    ) AS t
    CROSS APPLY x.nodes(N'/x') AS m(n);
 
    RETURN;
END;
GO