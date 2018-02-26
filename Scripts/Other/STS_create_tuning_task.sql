-- Purpose : Running SQL Tuning Advisor against cursor cache
-- Source : https://docs.oracle.com/database/121/ARPLS/d_sqltun.htm#ARPLS68414
-- Other Ref : https://oracle-base.com/articles/10g/automatic-sql-tuning-10g

SET echo on;

VARIABLE sts_task  VARCHAR2(64);

EXEC DBMS_SQLTUNE.CREATE_SQLSET(- 
  sqlset_name => 'my_workload', -
  description => 'complete application workload');

EXEC DBMS_SQLTUNE.CAPTURE_CURSOR_CACHE_SQLSET( -
                         sqlset_name     => 'my_workload', -
                         time_limit      => 30, -
                         repeat_interval => 5, -
                         capture_mode    => dbms_sqltune.MODE_ACCUMULATE_STATS);

-- EXEC :sts_task := DBMS_SQLTUNE.CREATE_TUNING_TASK( -
--   sqlset_name  => 'my_workload', -
--   rank1        => 'BUFFER_GETS', -
--   time_limit   => 3600, -
--   description  => 'tune my workload ordered by buffer gets');

  EXEC :sts_task := DBMS_SQLTUNE.CREATE_TUNING_TASK ( -
  sqlset_name   => 'my_workload',  -
  rank1         => 'ELAPSED_TIME', -
  time_limit    => 3600,           -
  description   => 'my workload ordered by elapsed time');

Prompt Task Name :sts_task

exec dbms_sqltune.execute_tuning_task(:sts_task);

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


