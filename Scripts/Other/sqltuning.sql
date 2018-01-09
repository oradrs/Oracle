SET LONG 1000000
VARIABLE tuning_task VARCHAR2(30)

DECLARE
  l_sql_id v$session.prev_sql_id%TYPE;
BEGIN
  
  :tuning_task := dbms_sqltune.create_tuning_task(sql_id => '&1');
  dbms_sqltune.execute_tuning_task(:tuning_task);
END;
/

SELECT dbms_sqltune.report_tuning_task(:tuning_task) 
FROM dual;

undef 1
