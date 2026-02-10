USE [3CX Exporter]
GO
 
/****** Object:  UserDefinedFunction [dbo].[cl_is_answered_by_extension]    Script Date: 09-02-2026 03:26:15 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE   FUNCTION [dbo].[cl_is_answered_by_extension]
(
    @seg_type             INT,
    @src_dn_type          INT,
    @dst_dn_type          INT,
    @act_id               INT,
    @is_inbound           BIT,
    @is_answered_by_dst   BIT
)
RETURNS BIT
AS
BEGIN
    -- If both source and destination are not extensions
    IF @src_dn_type <> 0 AND @dst_dn_type <> 0
        RETURN NULL;
 
    -- if smb calls queue and was terminated - call is unanswered
    IF @dst_dn_type = 4 AND @act_id IN (5, 6)
        RETURN 0;
 
    -- if queue calls agent and call was terminated - call is unanswered
    IF @is_inbound = 1 
       AND @src_dn_type = 4 
       AND @dst_dn_type = 0 
       AND @act_id IN (5, 6)
        RETURN 0;
 
    -- inbound (? -> Extension)
    -- TerminatedBySrc, TerminatedByDst, FailedBXferOfSrc, FailedBXferOfDst,
    -- ReplacedSrc, ReplacedDst
    IF @is_inbound = 1 
       AND @dst_dn_type = 0 
       AND @act_id IN (5, 6, 7, 8, 9, 10, 12)
        RETURN 1;
 
    ---------------------------------------------------------------------
    -- act_id = 2 logic
    IF @act_id = 2 AND @is_answered_by_dst = 1
        RETURN 1;
    ELSE IF @act_id = 2 AND @is_answered_by_dst = 0
        RETURN 0;
    ---------------------------------------------------------------------
 
    -- outbound (Extension -> ?)
    IF @is_inbound = 0 
       AND @src_dn_type = 0 
       AND @act_id IN (5, 6, 7, 8, 9, 10, 12)
        RETURN 1;
 
    -- *20* EndCall failed — must not be reported
    IF @dst_dn_type = 12 AND @act_id = 400
        RETURN NULL;
 
    -- Canceled, Fwd_NoAnswer, Fwd_OnBusy, Failed, etc.
    IF @act_id IN (3, 101, 104, 102, 400, 404, 408, 409, 
                   422, 412, 413, 415, 416, 417)
        RETURN 0;
 
    -- Failed_Cancelled (418)
    IF @act_id = 418
    BEGIN
        -- If source is queue, hide the row
        IF @src_dn_type = 4
            RETURN NULL;
        ELSE
            RETURN 0;
    END;
 
    RETURN NULL;
END;
GO