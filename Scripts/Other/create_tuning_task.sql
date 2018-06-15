-- Source : http://kerryosborne.oracle-guy.com/2008/09/sql-tuning-advisor/

SET LONG 10000;
SET PAGESIZE 9999
SET LINESIZE 155
set verify off
col recommendations for a150
accept task_name -
       prompt 'Task_Name: '
DECLARE
 ret_val VARCHAR2(4000);

BEGIN

ret_val := dbms_sqltune.create_tuning_task(task_name=>'&&Task_name', sql_id=>'&sql_id', time_limit=>&time_limit);


dbms_sqltune.execute_tuning_task('&&Task_name');

END;
/

--  check the progress (from another session)
SELECT status FROM USER_ADVISOR_TASKS WHERE task_name = '&&Task_name';

SELECT DBMS_SQLTUNE.report_tuning_task('&&task_name') AS recommendations FROM dual;
undef task_name
undef sql_id

-- ------------------------------------------
-- Purpose :  Generate sql advisor for bulk SQLs 

-- get top 100 sqls using topsql_v2.sql
-- create table TOPSQL (sql_id varchar(30));
-- insert them in TOPSQL table
-- monitor them in OEM / performance tab -> sql tuning advisor for report

DECLARE
 ret_val VARCHAR2(4000);
 task_prefix VARCHAR2(20);
BEGIN

    task_prefix := 'sa1_';

    FOR c IN (SELECT sql_id FROM topsql WHERE SECONDS_SINCE_DATE > 1000 AND sql_id NOT IN ('9by78xst5ujqs', 'bpq3txxubt71g'))
    LOOP
        dbms_output.put_line('SQL_id : ' || c.sql_id);
    --  drop task if exists
        begin
            dbms_sqltune.drop_tuning_task(task_prefix || c.sql_id);
        EXCEPTION
           WHEN OTHERS THEN
              null;
        END;

        begin
    -- create  execute advisor; time_limit=>300 in seconds
       ret_val := dbms_sqltune.create_tuning_task(task_name=> task_prefix || c.sql_id, sql_id=>c.sql_id, time_limit=>60);
      dbms_sqltune.execute_tuning_task(task_prefix || c.sql_id);
        EXCEPTION
           WHEN OTHERS THEN
               dbms_output.put_line('Err while SQL_id : ' || c.sql_id);
        END;

    END LOOP;

END;
/
