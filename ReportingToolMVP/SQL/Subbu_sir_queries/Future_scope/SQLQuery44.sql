USE [3CX Exporter]
GO
 
/****** Object:  StoredProcedure [dbo].[sp_rpt_extension_statistics_cdr]    Script Date: 09-02-2026 03:21:28 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE PROCEDURE [dbo].[sp_rpt_extension_statistics_cdr]
(
    @period_from          DATETIME2(3),
    @period_to            DATETIME2(3),
    @call_area            INT,
    @include_queue_calls  BIT,
    @wait_interval        TIME(0),
    @members              NVARCHAR(4000) = '',
    @observers            NVARCHAR(4000) = ''
)
AS
BEGIN
    SET NOCOUNT ON;
 
    WITH current_extensions AS
    (
        SELECT uv.dn, uv.display_name
        FROM dbo.users_view uv
        WHERE @members = ''
           OR EXISTS (
               SELECT 1
               FROM (
                   SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
               ) t
               CROSS APPLY x.nodes('/x') n(v)
               WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = uv.dn
           )
    ),
 
    cdrs AS
    (
        SELECT *
        FROM dbo.cdroutput c
        WHERE c.cdr_started_at >= @period_from
          AND c.cdr_started_at <  @period_to
          AND c.creation_method NOT IN ('barge_in', 'barge_in_listen', 'barge_in_whisper')
          AND NOT (c.creation_forward_reason = 'polling' AND c.cdr_answered_at IS NULL)
          AND NOT (c.source_entity_type = 'ivr' AND c.source_dn_number = 'MakeCall')
          AND c.destination_entity_type NOT IN ('endcall', 'unknown')
          AND c.source_entity_type NOT IN ('endcall', 'unknown')
          AND (
                @members = ''
                OR EXISTS (
                    SELECT 1
                    FROM (
                        SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
                    ) t
                    CROSS APPLY x.nodes('/x') n(v)
                    WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = c.source_dn_number
                )
                OR EXISTS (
                    SELECT 1
                    FROM (
                        SELECT CAST('<x>' + REPLACE(@members, ',', '</x><x>') + '</x>' AS XML) AS x
                    ) t
                    CROSS APPLY x.nodes('/x') n(v)
                    WHERE LTRIM(RTRIM(n.v.value('.', 'NVARCHAR(4000)'))) = c.destination_dn_number
                )
          )
    ),
 
    member_participants AS
    (
        SELECT dn, participant_id,
               CAST(MAX(CASE WHEN is_incoming = 1 THEN 1 ELSE 0 END) AS BIT) AS is_incoming
        FROM
        (
            SELECT source_dn_number AS dn, source_participant_id AS participant_id, source_participant_is_incoming AS is_incoming
            FROM cdrs
            WHERE source_entity_type = 'extension'
 
            UNION ALL
 
            SELECT destination_dn_number AS dn, destination_participant_id, destination_participant_is_incoming
            FROM cdrs
            WHERE destination_entity_type = 'extension'
        ) t
        GROUP BY dn, participant_id
    ),
 
    outgoing_calls_all AS
    (
        SELECT mp.dn, mp.participant_id, c.destination_entity_type,
               COALESCE(a1.is_answered, a2.is_answered, 0) AS is_answered
        FROM member_participants mp
        JOIN cdrs c 
            ON c.source_participant_id = mp.participant_id
           AND c.creation_method = 'call_init'
 
        LEFT JOIN (
            SELECT source_participant_id,
                   CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN 1 ELSE 0 END AS is_answered
            FROM cdrs
            GROUP BY source_participant_id
        ) a1 ON a1.source_participant_id = mp.participant_id
 
        LEFT JOIN (
            SELECT destination_participant_id,
                   CASE WHEN MAX(cdr_answered_at) IS NOT NULL THEN 1 ELSE 0 END AS is_answered
            FROM cdrs
            GROUP BY destination_participant_id
        ) a2 ON a2.destination_participant_id = mp.participant_id
    ),
 
    outgoing_calls AS
    (
        SELECT dn,
               COUNT(CASE WHEN is_answered = 1 THEN 1 END) AS answered_calls_count,
               COUNT(CASE WHEN is_answered = 0 THEN 1 END) AS unanswered_calls_count
        FROM outgoing_calls_all
        GROUP BY dn
    ),
 
    incoming_calls AS
    (
        SELECT dn,
               COUNT(CASE WHEN is_answered = 1 THEN 1 END) AS answered_calls_count,
               COUNT(CASE WHEN is_answered = 0 THEN 1 END) AS unanswered_calls_count
        FROM outgoing_calls_all
        GROUP BY dn
    ),
 
    first_talking_time AS
    (
        SELECT source_dn_number AS dn,
               SUM(DATEDIFF_BIG(MILLISECOND, cdr_answered_at, cdr_ended_at)) / 1000.0 AS talking_seconds
        FROM cdrs
        WHERE cdr_answered_at IS NOT NULL
          AND source_entity_type = 'extension'
        GROUP BY source_dn_number
    ),
 
    second_talking_time AS
    (
        SELECT destination_dn_number AS dn,
               SUM(DATEDIFF_BIG(MILLISECOND, cdr_answered_at, cdr_ended_at)) / 1000.0 AS talking_seconds
        FROM cdrs
        WHERE cdr_answered_at IS NOT NULL
          AND destination_entity_type = 'extension'
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
        rs.inbound_unanswered_count,
        rs.outbound_answered_count,
        ISNULL(out_talk.talking_seconds, 0) AS outbound_answered_talking_dur,
        rs.outbound_unanswered_count
    FROM real_statistics rs
    INNER JOIN current_extensions ce ON ce.dn = rs.dn
    LEFT JOIN first_talking_time out_talk ON out_talk.dn = rs.dn
    LEFT JOIN second_talking_time in_talk ON in_talk.dn = rs.dn;
 
END
GO