USE [3CX Exporter]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_rpt__extension_statistics_cdr]    Script Date: 09-02-2026 03:29:21 PM ******/
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


