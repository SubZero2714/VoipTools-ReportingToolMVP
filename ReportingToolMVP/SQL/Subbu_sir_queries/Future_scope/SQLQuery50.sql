USE [3CX Exporter]
GO
 
/****** Object:  StoredProcedure [dbo].[sp_cl_get_extension_statistics]    Script Date: 09-02-2026 03:33:04 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE   PROCEDURE [dbo].[sp_cl_get_extension_statistics]
(
    @period_from DATETIME2(3),
    @period_to DATETIME2(3),
    @call_area INT,
    @include_queue_calls BIT,
    @wait_interval TIME(0),
    @members NVARCHAR(4000) = '',
    @observers NVARCHAR(4000) = ''
)
AS
BEGIN
    SET NOCOUNT ON;
 
    ;WITH current_extensions AS
    (
        SELECT uv.dn, uv.display_name
        FROM users_view uv
        WHERE
            (@members = '' OR uv.dn IN (SELECT LTRIM(value) FROM STRING_SPLIT(@members, ',')))
        AND (@observers = '' OR uv.dn NOT IN (SELECT LTRIM(value) FROM STRING_SPLIT(@observers, ',')))
    ),
 
    queue_calls AS
    (
        SELECT sv.call_id, sv.act_dn AS dst_dn
        FROM cl_segments_view sv
        JOIN cl_calls c ON c.id = sv.call_id
        WHERE
            c.start_time >= @period_from
            AND c.start_time < @period_to
            AND sv.act_dn IS NOT NULL
            AND sv.dst_dn_type = 4
            AND sv.act NOT IN (13)
        GROUP BY sv.call_id, sv.act_dn
    ),
 
    segments AS
    (
        SELECT
            sv.call_id,
            sv.seg_id,
            sv.src_dn_type,
            sv.src_dn,
            COALESCE(NULLIF(sv.src_firstlastname, ''), sv.src_display_name) AS src_display_name,
            sv.dst_dn_type,
            sv.dst_dn,
            COALESCE(NULLIF(sv.dst_firstlastname, ''), sv.dst_display_name) AS dst_display_name,
            sv.start_time,
            sv.end_time,
 
            dbo.cl_is_answered_by_extension(
                sv.seg_type, sv.src_dn_type, sv.dst_dn_type, sv.act, 1,
                CASE WHEN sv.dst_answer_time IS NOT NULL THEN 1 ELSE 0 END
            ) AS is_answered_inbound,
 
            dbo.cl_is_answered_by_extension(
                sv.seg_type, sv.src_dn_type, sv.dst_dn_type, sv.act, 0,
                CASE WHEN sv.dst_answer_time IS NOT NULL THEN 1 ELSE 0 END
            ) AS is_answered_outbound,
 
            sv.seg_type,
            sv.act
        FROM cl_segments_view sv
        JOIN cl_calls c ON c.id = sv.call_id
        LEFT JOIN queue_calls qc 
            ON sv.call_id = qc.call_id 
           AND sv.dst_dn = qc.dst_dn
        WHERE
            c.start_time >= @period_from
            AND c.start_time < @period_to
            AND
            (
                (sv.src_dn_type = 0 AND
                    ((dbo.cl_is_internal(sv.dst_dn_type, sv.act, 0) = 1 AND @call_area IN (0,1))
                  OR (dbo.cl_is_internal(sv.dst_dn_type, sv.act, 0) = 0 AND @call_area IN (0,2))))
                OR
                (sv.dst_dn_type = 0 AND
                    ((dbo.cl_is_internal(sv.src_dn_type, sv.act, 1) = 1 AND @call_area IN (0,1))
                  OR (dbo.cl_is_internal(sv.src_dn_type, sv.act, 1) = 0 AND @call_area IN (0,2))))
            )
            AND (@include_queue_calls = 1 OR qc.call_id IS NULL)
    ),
 
    src_segments AS
    (
        SELECT call_id, seg_id, seg_type,
               src_dn AS dn, src_display_name AS display_name,
               start_time, end_time,
               is_answered_outbound, act, dst_dn_type
        FROM segments
        WHERE src_dn_type = 0 AND is_answered_outbound IS NOT NULL
    ),
 
    dst_segments AS
    (
        SELECT call_id, seg_id, seg_type,
               dst_dn AS dn, dst_display_name AS display_name,
               start_time, end_time,
               is_answered_inbound
        FROM segments
        WHERE dst_dn_type = 0 AND is_answered_inbound IS NOT NULL
    ),
 
    inbound_answered AS
    (
        SELECT dn, display_name,
               COUNT(*) AS inbound_answered_count,
               SUM(DATEDIFF_BIG(MILLISECOND, start_time, end_time)) / 1000.0 AS inbound_answered_talking_dur
        FROM dst_segments
        WHERE seg_type = 2
        GROUP BY dn, display_name
    ),
 
    inbound_unanswered AS
    (
        SELECT dn, display_name,
               COUNT(*) AS inbound_unanswered_count
        FROM dst_segments s
        WHERE seg_type = 1
          AND NOT EXISTS (
              SELECT 1 FROM cl_segments_view a
              WHERE a.call_id = s.call_id
                AND a.seg_type = 2
                AND a.seg_id > s.seg_id
                AND a.dst_dn = s.dn
                AND a.dst_dn_type = 0
          )
        GROUP BY dn, display_name
    ),
 
    outbound_answered AS
    (
        SELECT dn, display_name,
               COUNT(*) AS outbound_answered_count,
               SUM(DATEDIFF_BIG(MILLISECOND, start_time, end_time)) / 1000.0 AS outbound_answered_talking_dur
        FROM src_segments
        WHERE seg_type = 2 AND is_answered_outbound = 1
        GROUP BY dn, display_name
    ),
 
    outbound_unanswered AS
    (
        SELECT dn, display_name,
               COUNT(*) AS outbound_unanswered_count
        FROM src_segments
        WHERE seg_type = 1 OR (act IN (5,6) AND dst_dn_type = 4)
        GROUP BY dn, display_name
    )
 
    SELECT
        COALESCE(ia.dn, iu.dn, oa.dn, ou.dn, ce.dn) AS dn,
        COALESCE(ia.display_name, iu.display_name, oa.display_name, ou.display_name, ce.display_name) AS display_name,
        ia.inbound_answered_count,
        ia.inbound_answered_talking_dur,
        iu.inbound_unanswered_count,
        oa.outbound_answered_count,
        oa.outbound_answered_talking_dur,
        ou.outbound_unanswered_count
    FROM inbound_answered ia
    FULL JOIN inbound_unanswered iu ON ia.dn = iu.dn
    FULL JOIN outbound_answered oa ON COALESCE(ia.dn, iu.dn) = oa.dn
    FULL JOIN outbound_unanswered ou ON COALESCE(ia.dn, iu.dn, oa.dn) = ou.dn
    FULL JOIN current_extensions ce ON COALESCE(ia.dn, iu.dn, oa.dn, ou.dn) = ce.dn;
 
END;
GO