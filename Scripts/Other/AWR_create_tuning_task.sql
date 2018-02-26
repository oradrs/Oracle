-- Purpose : Running SQL Tuning Advisor against AWR data
-- Source : http://www.redstk.com/running-sql-tuning-advisor-against-awr-data/
-- Other Ref : https://oracle-base.com/articles/10g/automatic-sql-tuning-10g
-- Output : 
-- 
-- Prerequisite - sql_id (step 1) and AWR snap_id range (step 2); Both details will be available in AWR html report else use step #1 and #2. step#1 and 2 need to modify for current case.
--

-- ------------------------------------------
-- Step 1
-- Find the sql_id corresponding to your sql text. In this step we look for either SQL that has text that we know of, or, SQL that has been consuming lots of resources recently.

SELECT sql_id, sql_text
FROM dba_hist_sqltext
WHERE
--  add in the text of the SQL you’re looking for
lower(sql_text) LIKE’%i.station_id, i.spec_code, libsku.defaultskuspecid%'
and lower(sql_text) like '%inventory_transaction i%'
and lower(sql_text) like '%4624%'
and lower(sql_text) like '%500%'
and lower(sql_text) not like '%child_number%' ;
OR --  find heavy duty SQL recently
SELECT
ASH.SQL_ID, ASH.CPU, ASH.WAIT, ASH.IO, ASH.TOTAL, substr(HIST.SQL_TEXT,1,20) ntext
FROM
(
select
ash.SQL_ID ,
sum(decode(ash.session_state,'ON CPU',1,0)) "CPU",
sum(decode(ash.session_state,'WAITING',1,0)) -- 
sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0)) "WAIT" ,
sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0)) "IO" ,
sum(decode(ash.session_state,'ON CPU',1,1)) "TOTAL"
FROM v$active_session_history ash, v$event_name en
WHERE
SQL_ID is not NULL and en.event#=ash.event# and ash.SAMPLE_TIME > sysdate --  (300/(24*60))
GROUP BY sql_id
HAVING
sum(decode(ash.session_state,'ON CPU',1,1)) > 5 and
sum(decode(ash.session_state,'WAITING',1,0)) -- 
sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0)) > 5
ORDER BY sum(decode(session_state,'ON CPU',1,1)) desc
) ASH, DBA_HIST_SQLTEXT HIST
WHERE
ASH.sql_id = HIST.sql_id
and HIST.SQL_TEXT like '%libsku%' ;

-- ------------------------------------------
-- Step 2
-- Now, we find the AWR snapshots where your sql id lives. We will need these snapshot numbers when we use Tuning Advisor.

col parsed format a6
col sql_text format a40
set lines 200
set pages 300
SELECT
sql_text,
parsing_schema_name as parsed,
elapsed_time_delta/1000/1000 as elapsed_sec,
stat.snap_id,
to_char(snap.end_interval_time,'dd.mm hh24:mi:ss') as snaptime,
txt.sql_id
FROM
dba_hist_sqlstat stat, dba_hist_sqltext txt, dba_hist_snapshot snap
WHERE
stat.sql_id=txt.sql_id and
stat.snap_id=snap.snap_id and
--  how recently you're looking for
snap.begin_interval_time>=sysdate-2
--  enter in the text of the SQL you're looking for
and lower(sql_text) like '%inventory_transaction i%'
and lower(sql_text) like '%4624%'
and lower(sql_text) like '%500%'
and lower(sql_text) not like '%child_number%'
ORDER BY elapsed_time_delta asc;

-- ------------------------------------------
-- Step 3
-- Run Tuning Advisor out of AWR, using the sql id and the snap numbers

--  define the task
variable stmt_task VARCHAR2(64);
EXEC :stmt_task := DBMS_SQLTUNE.CREATE_TUNING_TASK ( begin_snap => 1326, end_snap => 1327, sql_id => '3vav5f9kauz4s' , scope => 'COMPREHENSIVE', time_limit => 2000, task_name => 'nf_sql_tuning_task' );

--  run the task
Exec DBMS_SQLTUNE.EXECUTE_TUNING_TASK( task_name => 'nf_sql_tuning_task' );

--  check the progress
SELECT status FROM USER_ADVISOR_TASKS WHERE task_name = 'nf_sql_tuning_task';

--  show the results
set long 50000
set longchunksize 500000
SET LINESIZE 150
Set pagesize 5000
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK( 'nf_sql_tuning_task') FROM DUAL;

--  drop the task
Exec DBMS_SQLTUNE.drop_tuning_task(task_name => 'nf_sql_tuning_task');

