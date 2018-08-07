-- Purpose : To know which TOP SQL was running from ASH data for given date ranges
-- Source : https://docplayer.net/43499944-Active-session-history-advanced-analysis-david-kurtz.html
-- Sample output : 
--    SQL_ID        | SQL_PLAN_HASH_VALUE | ASH_SECS
--    --------------+---------------------+---------
--    ghqf4jdg5mc0r |          3860682664 |     1520
--    bpn62stty972b |          3618814358 |      470
--    0bcaqvmah7kzg |          1776075064 |      390

-- ------------------------------------------


SELECT /*+LEADING(x h) USE_NL(h)*/ h.sql_id,
       h.sql_plan_hash_value,
       SUM(10) ash_secs
FROM dba_hist_snapshot x,
     dba_hist_active_sess_history h
WHERE 
x.end_interval_time >= TO_DATE('201806282000','yyyymmddhh24mi')     -- modify FROM DTTM
AND   x.begin_interval_time <= TO_DATE('201806290530','yyyymmddhh24mi') -- -- modify TO DTTM
AND   
h.sample_time BETWEEN TO_DATE('201806282000','yyyymmddhh24mi') AND TO_DATE('201806290530','yyyymmddhh24mi') -- modify FROM and TO DTTM
AND   h.SNAP_id = X.SNAP_id
AND   h.dbid = x.dbid
AND   h.instance_number = x.instance_number
-- AND   h.module LIKE 'PSAPPSRV%'      -- uncomment and modify value if needed
GROUP BY h.sql_id,
         h.sql_plan_hash_value
ORDER BY ash_secs DESC;

-- ------------------------------------------

-- Then get Execution plan from AWR for sql_id and PHV
SELECT * from table(dbms_xplan.display_awr( 'ghqf4jdg5mc0r', 3860682664, NULL, 'ADVANCED'));

-- Get all execution plan from AWR for sql_id
SELECT * from table(dbms_xplan.display_awr( 'ghqf4jdg5mc0r', NULL, NULL, 'ADVANCED'));

-- ------------------------------------------
-- Purpose : To get SQL start and end time, total execution time for identified SQL_id
-- Source : https://community.toadworld.com/platforms/oracle/w/wiki/11333.forensic-investigation-on-sql-performance-degradation
-- Sample Output:
--    SQL_ID        | SQL_EXEC_ID | SQL_PLAN_HASH_VALUE | SQL_START_TIME          | SQL_END_TIME            | EXEC_TIME_IN_SEC
--    --------------+-------------+---------------------+-------------------------+-------------------------+-----------------
--    9by78xst5ujqs |    16777216 |                   0 | 2018-06-28 20:00:05:959 | 2018-06-29 05:13:34:238 |            33180

select sql_id,sql_exec_id,sql_plan_hash_value, min(sample_time) SQL_START_TIME,max(sample_time) SQL_END_TIME, SUM(10) exec_time_in_sec
from DBA_HIST_ACTIVE_SESS_HISTORY
where SQL_ID='9by78xst5ujqs'
-- and user_id=133
and sample_time between to_date('28-JUN-18 20:00:00','DD-MON-YY HH24:MI:SS') and to_date('29-JUN-18 06:00:00','DD-MON-YY HH24:MI:SS')
group by sql_id,sql_exec_id,sql_plan_hash_value
order by sql_plan_hash_value;

-- ------------------------------------------
-- Purpose : To check total seconds spent on each type of WAIT EVENT fo SQL_ID.
-- Source : https://community.toadworld.com/platforms/oracle/w/wiki/11333.forensic-investigation-on-sql-performance-degradation
-- Sample Output : 
--    EVENT                   | SESSION_STATE | EXEC_TIME_IN_SEC
--    ------------------------+---------------+-----------------
--                            | ON CPU        |            33120
--    db file sequential read | WAITING       |               50
--    db file scattered read  | WAITING       |               10


SELECT event,
       session_state,
       SUM(10) exec_time_in_sec
FROM dba_hist_active_sess_history
WHERE sql_id = '9by78xst5ujqs'
AND   sql_exec_id = 16777216
AND   sample_time BETWEEN TO_DATE('28-JUN-18 20:00:00','DD-MON-YY HH24:MI:SS') AND TO_DATE('29-JUN-18 06:00:00','DD-MON-YY HH24:MI:SS')
GROUP BY event,
         session_state
ORDER BY 3 desc;

-- ------------------------------------------
-- ASH query for time period
select sample_time, sql_id, sql_exec_id, time_waited, event
  from v$active_session_history
  where sample_time > timestamp '2018-06-19 15:08:21'
  and user_id = 107
  order by sample_time;
