-- Tuning task created for a manually specified statement.

DECLARE
  l_sql               VARCHAR2(500);
  l_sql_tune_task_id  VARCHAR2(100);
BEGIN
  l_sql :=  'SELECT AMP_CDE_ACCRUAL , AMP_CDE_ACCT_MTHD , AMP_CDE_ACCT_NUM , AMP_CDE_BRANCH , AMP_CDE_CURRENCY , TEX_TXT_VALUE , ' ||
            'AMP_CDE_GL , AMP_CDE_GL_CLASS , AMP_CDE_GL_LOC , AMP_CDE_OUTSTD_TYP , AMP_CDE_PORTF_MAP , AMP_IND_ACTIVE , AMP_NUM_SORT_ORDER , AMP_RID_ACCT_MAP' ||
    'FROM' ||
      'VLS_ACCOUNTING_MAP ' ||
      'LEFT OUTER JOIN ' ||
      'VLS_TABLE_EXT ON AMP_RID_ACCT_MAP = TEX_RID_OWNER ' ||
    'WHERE' ||
      'AMP_IND_ACTIVE     =  CAST ( :b1 AS CHAR ( 1 ) ) ' ||
    'ORDER BY' ||
      'AMP_NUM_SORT_ORDER';

  l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
                          sql_text    => l_sql,
                          bind_list   => sql_binds(anydata.ConvertNumber(100)),
                          user_name   => 'LS2USER',
                          scope       => DBMS_SQLTUNE.scope_comprehensive,
                          time_limit  => 60,
                          task_name   => 'emp_dept_tuning_task',
                          description => 'Tuning task for an EMP to DEPT join query.');
  DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
END;
/

--  run the task
Exec DBMS_SQLTUNE.EXECUTE_TUNING_TASK( task_name => 'emp_dept_tuning_task' );

--  check the progress
SELECT status FROM USER_ADVISOR_TASKS WHERE task_name = 'emp_dept_tuning_task';

SELECT DBMS_SQLTUNE.report_tuning_task('emp_dept_tuning_task') AS recommendations FROM dual;

--  drop the task
Exec DBMS_SQLTUNE.drop_tuning_task(task_name => 'emp_dept_tuning_task');

