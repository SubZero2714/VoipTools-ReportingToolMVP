USE [3CX Exporter]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_rpt__extension_statistics_cdr]    Script Date: 09-02-2026 07:04:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   FUNCTION [dbo].[fn_rpt__extension_statistics_cdr]
(
    @period_from          DATETIME2(3),
    @period_to            DATETIME2(3),
    @call_area            INT,
    @include_queue_calls  BIT,
    @wait_interval        TIME(0),               -- unused
    @members              NVARCHAR(4000) = '',
    @observers            NVARCHAR(4000) = ''    -- unused
)
RETURNS TABLE
AS
RETURN

WITH current_extensions AS
(
    SELECT
        uv.dn,
        uv.display_name
    FROM dbo.users_view AS uv
    WHERE @members = ''
       OR EXISTS (
           SELECT 1
           FROM (
               SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
           ) AS t
           CROSS APPLY x.nodes('/x') AS n(v)
           WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = uv.dn
       )
),
cdrs AS
(
    SELECT
        c.main_call_history_id,
        c.source_participant_id,
        c.source_dn_name,
        c.source_participant_name,
        c.source_dn_number,
        c.source_participant_is_incoming,
        c.source_participant_is_already_connected,
        --
        c.destination_participant_id,
        c.destination_dn_name,
        c.destination_participant_name,
        c.destination_dn_number,
        c.destination_participant_is_incoming,
        c.destination_participant_is_already_connected,
        --
        c.source_entity_type,
        c.source_dn_type,
        --
        c.destination_entity_type,
        c.destination_dn_type,
        --
        c.cdr_id,
        c.creation_method,
        --
        c.cdr_started_at,
        c.cdr_answered_at,
        c.cdr_ended_at,
        --
        c.originating_cdr_id,
        c.termination_reason_details
    FROM dbo.cdroutput AS c
    WHERE c.cdr_started_at >= @period_from
      AND c.cdr_started_at <  @period_to
      AND c.creation_method NOT IN ('barge_in', 'barge_in_listen', 'barge_in_whisper')
      AND NOT (c.creation_forward_reason = 'polling' AND c.cdr_answered_at IS NULL)
      AND NOT (c.source_entity_type = 'ivr' AND c.source_dn_number = 'MakeCall')
      AND c.destination_entity_type NOT IN ('endcall', 'unknown')
      AND c.source_entity_type      NOT IN ('endcall', 'unknown')
      AND (
          @members = ''
          OR EXISTS (
              SELECT 1
              FROM (
                  SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
              ) AS t
              CROSS APPLY x.nodes('/x') AS n(v)
              WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = c.source_dn_number
          )
          OR EXISTS (
              SELECT 1
              FROM (
                  SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
              ) AS t
              CROSS APPLY x.nodes('/x') AS n(v)
              WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = c.destination_dn_number
          )
      )
),
member_participants AS
(
    SELECT
        dn,
        participant_id,
        CAST(MAX(CASE WHEN is_incoming = 1 THEN 1 ELSE 0 END) AS BIT) AS is_incoming
    FROM (
        -- Source = extension
        SELECT
            c.source_dn_number AS dn,
            c.source_participant_id AS participant_id,
            c.source_participant_is_incoming AS is_incoming
        FROM cdrs c
        WHERE c.source_entity_type = 'extension'
          AND (
              @call_area = 0
              OR (@call_area = 1 AND c.destination_entity_type NOT IN ('external_line', 'outbound_rule'))
              OR (@call_area = 2 AND c.destination_entity_type IN ('external_line', 'outbound_rule'))
          )

        UNION ALL

        -- Destination = extension
        SELECT
            c.destination_dn_number AS dn,
            c.destination_participant_id AS participant_id,
            c.destination_participant_is_incoming AS is_incoming
        FROM cdrs c
        WHERE c.destination_entity_type = 'extension'
          AND (
              @call_area = 0
              OR (@call_area = 1 AND c.source_entity_type NOT IN ('external_line', 'outbound_rule'))
              OR (@call_area = 2 AND c.source_entity_type IN ('external_line', 'outbound_rule'))
          )
    ) t
    GROUP BY dn, participant_id
),
outgoing_calls_all AS
(
    SELECT
        mp.dn,
        mp.participant_id,
        c.destination_entity_type,
        COALESCE(a1.is_answered, a2.is_answered, CAST(0 AS BIT)) AS is_answered
    FROM member_participants mp
    INNER JOIN cdrs c
        ON c.source_participant_id = mp.participant_id
       AND c.creation_method = 'call_init'
    LEFT JOIN (
        SELECT 
            source_participant_id AS participant_id,
            CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_answered
        FROM cdrs
        WHERE cdr_answered_at IS NOT NULL
          AND destination_entity_type NOT IN ('ring_group_ring_all', 'ring_group_hunt', 'queue')
        GROUP BY source_participant_id
    ) a1 ON a1.participant_id = mp.participant_id

    LEFT JOIN (
        SELECT 
            destination_participant_id AS participant_id,
            CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_answered
        FROM cdrs
        WHERE cdr_answered_at IS NOT NULL
          AND source_entity_type NOT IN ('ring_group_ring_all', 'ring_group_hunt', 'queue')
        GROUP BY destination_participant_id
    ) a2 ON a2.participant_id = mp.participant_id
),
outgoing_calls AS
(
    SELECT
        dn,
        COUNT(CASE WHEN is_answered = 1 THEN 1 END) AS answered_calls_count,
        COUNT(CASE WHEN is_answered = 0 THEN 1 END) AS unanswered_calls_count
    FROM outgoing_calls_all
    WHERE @call_area = 0
       OR (@call_area = 1 AND destination_entity_type <> 'outbound_rule')
       OR (@call_area = 2 AND destination_entity_type = 'outbound_rule')
    GROUP BY dn
),
incoming_calls AS
(
    SELECT
        dn,
        COUNT(CASE WHEN is_answered = 1 THEN 1 END) AS answered_calls_count,
        COUNT(CASE WHEN is_answered = 0 THEN 1 END) AS unanswered_calls_count
    FROM (
        SELECT
            mp.dn,
            COALESCE(a1.is_answered, a2.is_answered, CAST(0 AS BIT)) AS is_answered
        FROM member_participants mp
        LEFT JOIN outgoing_calls_all oc ON oc.participant_id = mp.participant_id
        LEFT JOIN (
            SELECT 
                source_participant_id AS participant_id,
                CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_answered
            FROM cdrs
            WHERE cdr_answered_at IS NOT NULL
            GROUP BY source_participant_id
        ) a1 ON a1.participant_id = mp.participant_id

        LEFT JOIN (
            SELECT 
                destination_participant_id AS participant_id,
                CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_answered
            FROM cdrs
            WHERE cdr_answered_at IS NOT NULL
            GROUP BY destination_participant_id
        ) a2 ON a2.participant_id = mp.participant_id
        WHERE oc.participant_id IS NULL
    ) ic
    GROUP BY dn
),
first_talking_time AS
(
    SELECT
        source_dn_number AS dn,
		   SUM(DATEDIFF_BIG(MILLISECOND, cdr_answered_at, cdr_ended_at)) / 1000.0 AS talking_seconds
        --SUM(DATEDIFF(SECOND, cdr_answered_at, cdr_ended_at)) AS talking_seconds
    FROM cdrs
    WHERE cdr_answered_at IS NOT NULL
      AND source_entity_type = 'extension'
      AND (
          @call_area = 0
          OR (@call_area = 1 AND destination_entity_type NOT IN ('external_line', 'outbound_rule'))
          OR (@call_area = 2 AND destination_entity_type IN ('external_line', 'outbound_rule'))
      )
    GROUP BY source_dn_number
),
second_talking_time AS
(
    SELECT
        destination_dn_number AS dn,
			   SUM(DATEDIFF_BIG(MILLISECOND, cdr_answered_at, cdr_ended_at)) / 1000.0 AS talking_seconds
       -- SUM(DATEDIFF(SECOND, cdr_answered_at, cdr_ended_at)) AS talking_seconds
    FROM cdrs
    WHERE cdr_answered_at IS NOT NULL
      AND destination_entity_type = 'extension'
      AND (
          @call_area = 0
          OR (@call_area = 1 AND source_entity_type NOT IN ('external_line', 'outbound_rule'))
          OR (@call_area = 2 AND source_entity_type IN ('external_line', 'outbound_rule'))
      )
    GROUP BY destination_dn_number
),
real_statistics AS
(
    SELECT
        COALESCE(oc.dn, ic.dn) AS dn,
        MAX(ic.answered_calls_count)   AS inbound_answered_count,
        MAX(ic.unanswered_calls_count) AS inbound_unanswered_count,
        MAX(oc.answered_calls_count)   AS outbound_answered_count,
        MAX(oc.unanswered_calls_count) AS outbound_unanswered_count
    FROM outgoing_calls oc
    FULL JOIN incoming_calls ic ON ic.dn = oc.dn
    GROUP BY COALESCE(oc.dn, ic.dn)
)
SELECT
    ce.dn,
    ce.display_name,
    rs.inbound_answered_count,
	ISNULL(in_talk.talking_seconds, 0)  AS inbound_answered_talking_dur,


  --  DATEADD(SECOND, ISNULL(in_talk.talking_seconds, 0), CAST('00:00:00' AS TIME)) AS inbound_answered_talking_dur,
    rs.inbound_unanswered_count,
    rs.outbound_answered_count,
	ISNULL(out_talk.talking_seconds, 0) AS outbound_answered_talking_dur,
  --  DATEADD(SECOND, ISNULL(out_talk.talking_seconds, 0), CAST('00:00:00' AS TIME)) AS outbound_answered_talking_dur,
    rs.outbound_unanswered_count
FROM real_statistics rs
INNER JOIN current_extensions ce ON ce.dn = rs.dn
LEFT JOIN first_talking_time  out_talk ON out_talk.dn = rs.dn
LEFT JOIN second_talking_time in_talk  ON in_talk.dn  = rs.dn;
GO


USE [3CX Exporter]
GO

/****** Object:  UserDefinedFunction [dbo].[cl_get_extension_statistics]    Script Date: 09-02-2026 07:04:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   FUNCTION [dbo].[cl_get_extension_statistics]
(
  @period_from          DATETIME2(3),
    @period_to            DATETIME2(3),
    @call_area            INT,
    @include_queue_calls  BIT,
    @wait_interval        TIME(0),
    @members              NVARCHAR(4000) = '',
    @observers            NVARCHAR(4000) = ''
)
RETURNS TABLE
AS
RETURN
WITH current_extensions AS
(
    SELECT
        uv.dn,
        uv.display_name
    FROM users_view uv
    WHERE
        (@members = '' OR uv.dn IN (SELECT value FROM STRING_SPLIT(@members, ',')))
        AND (@observers = '' OR uv.dn NOT IN (SELECT value FROM STRING_SPLIT(@observers, ',')))
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
    LEFT JOIN queue_calls qc ON sv.call_id = qc.call_id AND sv.dst_dn = qc.dst_dn
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
         --  SUM(DATEDIFF(SECOND, start_time, end_time)) AS inbound_answered_talking_dur
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
          -- SUM(DATEDIFF(SECOND, start_time, end_time)) AS outbound_answered_talking_dur
		   SUM(DATEDIFF_BIG(MILLISECOND, start_time, end_time)) / 1000.0 as outbound_answered_talking_dur
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
GO


USE [3CX Exporter]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_rpt__extension_statistics_cdr_united]    Script Date: 09-02-2026 07:04:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[fn_rpt__extension_statistics_cdr_united]
(
    @period_from         DATETIME2(3),
    @period_to           DATETIME2(3),
    @call_area           INT,
    @include_queue_calls BIT,
    @wait_interval       TIME(0),
    @members             VARCHAR(MAX) = '',
    @observers           VARCHAR(MAX) = ''
)
RETURNS TABLE
AS
RETURN
WITH cdr_stats AS
(
    SELECT *
    FROM dbo.fn_rpt__extension_statistics_cdr(
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval, @members, @observers
    )
),
cl_stats AS
(
    SELECT *
    FROM dbo.cl_get_extension_statistics(
        @period_from, @period_to, @call_area,
        @include_queue_calls, @wait_interval, @members, @observers
    )
),
combined AS
(
    SELECT * FROM cdr_stats
    UNION ALL
    SELECT * FROM cl_stats
),
agg AS
(
    SELECT
        dn,
        display_name,

        SUM(ISNULL(inbound_answered_count, 0))   AS inbound_answered,
        SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,

        SUM(ISNULL(outbound_answered_count, 0))   AS outbound_answered,
        SUM(ISNULL(outbound_unanswered_count, 0)) AS outbound_unanswered,
		SUM(ISNULL(inbound_answered_talking_dur, 0)) AS inbound_answered_talking_dur,
		SUM(ISNULL(outbound_answered_talking_dur, 0)) AS outbound_answered_talking_dur,
        SUM(
            ISNULL(inbound_answered_talking_dur, 0)
          + ISNULL(outbound_answered_talking_dur, 0)
        ) AS total_talking_seconds

    FROM combined
    GROUP BY dn, display_name
)

--agg AS
--(
--    SELECT
--        dn,
--        display_name,

--        SUM(ISNULL(inbound_answered_count, 0))   AS inbound_answered,
--        SUM(ISNULL(inbound_unanswered_count, 0)) AS inbound_unanswered,

--        SUM(ISNULL(outbound_answered_count, 0))   AS outbound_answered,
--        SUM(ISNULL(outbound_unanswered_count, 0)) AS outbound_unanswered,

--        SUM(ISNULL(inbound_answered_talking_dur, 0)
--          + ISNULL(outbound_answered_talking_dur, 0)) AS total_talking_seconds
--    FROM combined
--    GROUP BY dn, display_name
--)
SELECT
    a.dn            AS [Agent Extension],
    a.display_name  AS [Name],

    a.inbound_answered   AS [Inbound Answered],
    a.inbound_unanswered AS [Inbound Unanswered],

    a.outbound_answered   AS [Outbound Answered],
    a.outbound_unanswered AS [Outbound Unanswered],

    a.inbound_answered + a.outbound_answered
        AS [Total Answered],

    a.inbound_unanswered + a.outbound_unanswered
        AS [Total Unanswered],

		    RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.inbound_answered_talking_dur, 0), 108), 8)
        AS [Inbound Talking],
			    RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.outbound_answered_talking_dur, 0), 108), 8)
        AS [Outbound Talking],
    -- Convert seconds → HH:mm:ss (correct & exact)
    RIGHT(CONVERT(VARCHAR(8), DATEADD(SECOND, a.total_talking_seconds, 0), 108), 8)
        AS [Total Talking]

FROM agg a;
