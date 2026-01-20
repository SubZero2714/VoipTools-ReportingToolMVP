/*
 * Queue Dashboard - Queue List Query
 * Purpose: Get list of all queues with their names for dropdown/filter
 * Used by: Report parameters, queue selection dropdown
 * 
 * Joins:
 *   - callcent_queuecalls: Get unique queue numbers that have calls
 *   - dn: Directory number table
 *   - queue: Queue name definitions
 */

-- Get all queues with call data and their names
SELECT 
    c.q_num AS QueueNumber,
    ISNULL(q.name, 'Queue ' + c.q_num) AS QueueName,
    q.name AS QueueDisplayName,
    COUNT(*) AS CallCount
FROM [dbo].[callcent_queuecalls] c
LEFT JOIN [dbo].[dn] d ON c.q_num = d.value
LEFT JOIN [dbo].[queue] q ON d.iddn = q.fkiddn
GROUP BY 
    c.q_num,
    q.name
ORDER BY 
    c.q_num;

/*
 * Simplified version (without call counts)
 */
-- SELECT DISTINCT
--     c.q_num AS QueueNumber,
--     ISNULL(q.name, 'Queue ' + c.q_num) AS QueueName
-- FROM [dbo].[callcent_queuecalls] c
-- LEFT JOIN [dbo].[dn] d ON c.q_num = d.value
-- LEFT JOIN [dbo].[queue] q ON d.iddn = q.fkiddn
-- ORDER BY c.q_num;
