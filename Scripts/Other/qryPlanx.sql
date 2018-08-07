-- Purpose : geneate execution plan & tuning report for sql
-- Manually copy paste each block
-- ------------------------------------------

SET SERVEROUTPUT OFF;

SET HEA ON LIN 500 PAGES 100 TAB OFF FEED OFF ECHO OFF VER OFF TRIMS ON TRIM ON TI OFF TIMI OFF;

ALTER SESSION SET nls_date_format='YYYY/MM/DD HH24:MI:SS';
COL current_time NEW_V current_time FOR A15 NOPRI;
SELECT 'current_time: ' x, TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') current_time FROM DUAL;


SPO qry_&&current_time..txt

-- ******** ADD/modify variables and its values
VAR v_tex_txt_value CHAR(8);
EXEC :v_tex_txt_value := 'OL9LJOTY';

----------- <QUERY paste here> ----------- 

-- SELECT * FROM EMP WHERE EMPID=:v_tex_txt_value;
;

WITH prev AS 
(SELECT prev_sql_id sql_id, prev_child_number child_number 
FROM v$session WHERE sid = SYS_CONTEXT('USERENV', 'SID'))
SELECT plan.plan_table_output execution_plan 
FROM prev, TABLE(DBMS_XPLAN.DISPLAY_CURSOR(prev.sql_id, prev.child_number, 'ADVANCED ALLSTATS LAST')) plan
/

SPOOL OFF;

-- ------------------------------------------

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
