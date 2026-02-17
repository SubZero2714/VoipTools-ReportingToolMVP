USE [3CX Exporter]
GO
 
/****** Object:  View [dbo].[cl_segments_view]    Script Date: 09-02-2026 03:14:05 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
-- DROP VIEW IF EXISTS cl_segments_view;
 
CREATE VIEW [dbo].[cl_segments_view] AS
SELECT 
    s.call_id,
    s.id                  AS seg_id,
    s.type                AS seg_type,
    s.seq_order           AS seg_order,
    s.start_time,
    s.end_time,
 
    -- Source participant
    sp.id                 AS src_part_id,
    si.dn_type            AS src_dn_type,
    si.dn                 AS src_dn,
    si.display_name       AS src_display_name,
    si.firstlastname      AS src_firstlastname,
    sp.billing_rate       AS src_billing_rate,
    sp.billing_duration   AS src_billing_duration,
    si.dn_class           AS src_dn_class,
 
    -- Destination participant
    dp.id                 AS dst_part_id,
    dp.start_time         AS dst_start_time,
    dp.answer_time        AS dst_answer_time,
    dp.end_time           AS dst_end_time,
    dp.billing_rate       AS dst_billing_rate,
    dp.billing_duration   AS dst_billing_duration,
    di.dn_type            AS dst_dn_type,
    di.dn                 AS dst_dn,
    di.display_name       AS dst_display_name,
    di.firstlastname      AS dst_firstlastname,
    di.caller_number      AS dst_caller_number,
    di.dn_class           AS dst_dn_class,
 
    -- Action / transferred-to party (optional)
    s.action_id           AS act,
    ai.dn_type            AS act_dn_type,
    ai.dn                 AS act_dn,
    ai.display_name       AS act_display_name,
    ai.firstlastname      AS act_firstlastname
 
FROM cl_segments s
 
INNER JOIN cl_participants sp 
    ON sp.id = s.src_part_id
 
INNER JOIN cl_participants dp 
    ON dp.id = s.dst_part_id
 
INNER JOIN cl_party_info si 
    ON si.id = sp.info_id
 
INNER JOIN cl_party_info di 
    ON di.id = dp.info_id
 
LEFT JOIN cl_participants ap 
    ON ap.id = s.action_party_id
 
LEFT JOIN cl_party_info ai 
    ON ai.id = ap.info_id;
GO