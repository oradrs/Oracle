-- where.sql : To know currnet container name & set sql prompt

column where format a30
SELECT             'USER:         '||SYS_CONTEXT('USERENV','CURRENT_USER') 
       ||chr(10) ||'SCHEMA:       '||SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
       ||chr(10) ||'CONTAINER DB: '||SYS_CONTEXT('USERENV','CON_NAME')
       ||chr(10) ||'CONTAINER:    '||SYS_CONTEXT('USERENV','CDB_NAME')
      "WHERE" 
  FROM DUAL;

col CONT new_value CONT noprint
select sys_context('userenv', 'con_name') as CONT from dual;
set sqlprompt "_USER'@'_CONNECT_IDENTIFIER::&&CONT> ";
