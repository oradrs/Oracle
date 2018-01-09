REM
REM DBAToolZ NOTE:
REM	This script was obtained from DBAToolZ.com
REM	Its configured to work with SQL Directory (SQLDIR).
REM	SQLDIR is a utility that allows easy organization and
REM	execution of SQL*Plus scripts using user-friendly menu.
REM	Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM 
REM File:
REM 	u_find_string.sql
REM
REM <SQLDIR_GRP>UTIL</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy 
REM	VMOGILEV
REM	(www.dbatoolz.com)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Searches for character string in all tables and views.
REM	</SQLDIR_TXT>
REM	
REM Usage:
REM	u_find_string.sql
REM 
REM Example:
REM	u_find_string.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM

set serveroutput on size 1000000
accept string char prompt "Enter Char String to search for:"
accept owner_name  prompt "Enter Owner Name:"

set term off
set verify off
set lines 80
set feedback off

spool find_string.tmp

prompt spool find_string.out
prompt set feedback off
prompt set pages 1000
prompt set lines 132
prompt set wrap on
prompt break on found_in skip 1
prompt col found_in format a55 heading "Found In <owner>.<object_name>.<column_name>"
prompt col string   format a70 heading "String Found"
-- prompt col row_id   format 99999999999999999999
prompt set term on
prompt 

declare

cursor varchar_tables_cur IS
    select owner
    ,      table_name
    ,      column_name
    from   dba_tab_columns
    where  owner != 'SYS'
    and    owner != 'SYSTEM'
    and    owner  = upper('&OWNER_NAME')
    and    data_type in ( 'VARCHAR2','VARCHAR','CHAR');

begin
 for v_t_rec in varchar_tables_cur loop
      dbms_output.put_line('--');
--       dbms_output.put_line('prompt '||v_t_rec.owner||'.'||v_t_rec.table_name||'.'||v_t_rec.column_name||'');
      dbms_output.put('select '''||v_t_rec.owner||'.'||v_t_rec.table_name||'.'||v_t_rec.column_name||''' Found_In ,');
      dbms_output.new_line;
      dbms_output.put(''||v_t_rec.column_name||' String ');
      dbms_output.new_line;
--      dbms_output.put_line('rowid                Row_id  ');
      dbms_output.put_line('from   '||v_t_rec.owner||'.'||v_t_rec.table_name||'');
      dbms_output.put_line('where  '||v_t_rec.column_name||' like '||chr(39)||'&string'||chr(39)||'');
      dbms_output.put_line('/');      
 end loop;
end;
/

prompt spool off
prompt prompt ====> created file find_string.out for your review

spool off

@find_string.tmp
