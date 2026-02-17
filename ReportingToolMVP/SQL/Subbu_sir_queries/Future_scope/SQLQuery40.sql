USE [3CX Exporter]
GO
 
/****** Object:  View [dbo].[callcent_queuecalls_view]    Script Date: 09-02-2026 03:12:44 PM ******/
SET ANSI_NULLS ON
GO
 
SET QUOTED_IDENTIFIER ON
GO
 
CREATE   VIEW [dbo].[callcent_queuecalls_view]
AS
SELECT 
    qc.q_num,
    qc.time_start,
    qc.time_end,
    qc.ts_waiting,
    qc.ts_polling,
    qc.ts_servicing,
 
    -- Convert TIME to seconds, add, convert back to TIME
    CAST(
        DATEADD(SECOND,
            DATEDIFF(SECOND, '00:00:00', qc.ts_waiting) +
            DATEDIFF(SECOND, '00:00:00', qc.ts_polling),
        '00:00:00'
        ) AS TIME
    ) AS ring_time,
 
    qc.reason_noanswercode,
    qc.reason_failcode,
    qc.call_history_id,
    qc.from_userpart,
    qc.from_displayname,
    qc.to_dn,
    qc.cb_num,
 
    -- is_answered flag
    CASE 
        WHEN qc.reason_noanswercode = 0 
         AND qc.reason_failcode = 0 
         AND qc.ts_servicing IS NOT NULL 
         AND ISNULL(qc.to_dn, '') <> '' 
        THEN 1 ELSE 0 
    END AS is_answered,
 
    -- is_callback flag
    CASE 
        WHEN qc.cb_num IS NOT NULL 
         AND ISNULL(qc.cb_num, '') <> '' 
        THEN 1 ELSE 0 
    END AS is_callback,
 
    qc.cdr_participant_id
FROM callcent_queuecalls qc;
GO