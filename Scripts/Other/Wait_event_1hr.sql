/* Formatted on 01/31/2014 4:42:57 PM (QP5 v5.163.1008.3004) */
SET LINE 190 PAGES 1234

  SELECT DISTINCT --TO_CHAR(sample_time,'HH24:MI') end_time,
                  event, COUNT (*) sample_count_1hr
    FROM gv$active_session_history
   WHERE     -- (sample_time > localtimestamp - INTERVAL '60:00' MINUTE TO SECOND )
             sample_time > SYSDATE - 1 / 24
         AND event IS NOT NULL
         AND wait_class = '&WAIT_CLASS'
GROUP BY --(sample_time,'HH24:MI'),
         event
ORDER BY --end_time
         2;
  
--SELECT    *
--   FROM
--      (SELECT DISTINCT TO_CHAR(sample_time,'HH24:MI') end_time,
--            event                                             ,
--            COUNT(*) sample_count
--         FROM gv$active_session_history
--         WHERE
--            sample_time   > sysdate - 1/24
--            AND event    IS NOT NULL
--            AND wait_class='Network'
--         GROUP BY (sample_time,'HH24:MI'),event
--      ) PIVOT ( SUM(sample_count) FOR event IN
--      (--'SQL*Net more data from dblink','SQL*Net message from dblink'
--	  SELECT DISTINCT REPLACE(initcap(event), CHR(32), '') event FROM gv$active_session_history WHERE  event IS NOT NULL AND wait_class='Network'
--      ) )
--   ORDER BY end_time
