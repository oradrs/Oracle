set echo off verify off

prompt enter value for minutes and top_n

def minutes=&1
def top_n=&2

break on sql_id skip 1

WITH sql_class AS
(select sql_id, state, count(*) occur from 
  (select   sql_id
  ,  CASE  WHEN session_state = 'ON CPU' THEN 'CPU'       
           WHEN session_state = 'WAITING' AND wait_class IN ('User I/O') THEN 'IO'
           ELSE 'WAIT' END state            
    from v$active_session_history             
    where   session_type IN ( 'FOREGROUND')        
    and sample_time  between trunc(sysdate,'MI') - &minutes/24/60 and trunc(sysdate,'MI') )
    group by sql_id, state),
     ranked_sqls AS 
(select SQL_ID,  sum(occur) sql_occur  , rank () over (order by sum(occur)desc) xrank
from sql_class           
group by sql_id )
select sc.sql_id, state, occur from sql_class sc, ranked_sqls rs
where rs.sql_id = sc.sql_id 
AND rs.xrank <= &top_n 
order by xrank, state, sql_id;


undef minutes=&1
undef top_n=&2
