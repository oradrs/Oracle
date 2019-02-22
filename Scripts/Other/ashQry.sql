-- https://www.dba-scripts.com/scripts/diagnostic-and-tuning/oracle-active-session-history-ash/sql-activity-last-hour/
-- This script can be used to show the top 10 SQL activity for the last hour.

SELECT trunc(sample_time,'MI'),
       sql_id,
       count(sql_id) as TOTAL
FROM v$active_session_history
WHERE sample_time between sysdate - interval '1' hour and sysdate
AND sql_id in (select sql_id from (
 select
     SQL_ID ,
     sum(decode(session_state,'WAITING',1,1))  as TOTAL_ACTIVITY
from v$active_session_history
WHERE sample_time between sysdate - interval '1' hour and sysdate
group by sql_id
order by sum(decode(session_state,'WAITING',1,1))   desc)
where rownum < 11)
group by trunc(sample_time,'MI'),sql_id 
order by trunc(sample_time,'MI') desc;

-- ------------------------------------------
-- https://www.dba-scripts.com/scripts/diagnostic-and-tuning/oracle-active-session-history-ash/top-10-queries-active_session_history/
-- This query returns the top 10 queries by resource consumption (CPU+IO+WAIT) in the last hour from v$active_session_history.

select * from (
	select
		 SQL_ID ,
		 sum(decode(session_state,'ON CPU',1,0)) as CPU,
		 sum(decode(session_state,'WAITING',1,0)) - sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as WAIT,
		 sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as IO,
		 sum(decode(session_state,'ON CPU',1,1)) as TOTAL
	from v$active_session_history
	where SQL_ID is not NULL
	group by sql_id
	order by sum(decode(session_state,'ON CPU',1,1))   desc
	)
where rownum <11;

-- ------------------------------------------
-- https://www.dba-scripts.com/scripts/diagnostic-and-tuning/oracle-active-session-history-ash/top-10-sessions-from-active_session_history/
-- This query returns the top 10 sessions from v$active_session_history. The result is ordered by total resources consumed by the session including I/O, WAITS and CPU

select * from (
select
     session_id,
	 session_serial#,
     program,
	 module,
	 action,
     sum(decode(session_state,'WAITING',0,1)) "CPU",
     sum(decode(session_state,'WAITING',1,0)) - sum(decode(session_state,'WAITING',decode(wait_class,'User I/O',1,0),0)) "WAITING" ,
     sum(decode(session_state,'WAITING',decode(wait_class,'User I/O',1,0),0)) "IO" ,
     sum(decode(session_state,'WAITING',1,1)) "TOTAL"
from v$active_session_history 
where session_type='FOREGROUND'
group by session_id,session_serial#,module,action,program
order by sum(decode(session_state,'WAITING',1,1)) desc)
where rownum <11;

-- ------------------------------------------
-- https://www.dba-scripts.com/scripts/diagnostic-and-tuning/oracle-active-session-history-ash/top-5-wait-events-vactive_session_history/
-- This query returns the top 5 wait events for the last hour from the v$active_session_history view.

select * from (
	select
		 WAIT_CLASS ,
		 EVENT,
		 count(sample_time) as EST_SECS_IN_WAIT
	from v$active_session_history
	where sample_time between sysdate - interval '1' hour and sysdate
	group by WAIT_CLASS,EVENT
	order by count(sample_time) desc
	)
where rownum <6;
