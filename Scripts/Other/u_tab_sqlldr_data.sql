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
REM 	u_tab_sqlldr_data.sql
REM
REM <SQLDIR_GRP>UTIL TAB</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy 
REM	VMOGILEV
REM	(www.dbatoolz.com)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Formats table data for SQL*Loader
REM	</SQLDIR_TXT>
REM	
REM Usage:
REM	u_tab_sqlldr_data.sql
REM 
REM Example:
REM	u_tab_sqlldr_data.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM

set feedback off
set verify off

drop table select_text;

create table select_text (
text    varchar2(2000)
);

accept 1 prompt "Enter Table Name:"
accept 2 prompt "Enter Table Owner:"

declare
    cursor tab_col_cur IS
         select   owner
         ,        table_name
         ,        decode(data_type,
                    'NUMBER',column_name
                            ,'chr(34)'||chr(124)||chr(124)||column_name||chr(124)||chr(124)||'chr(34)')     column_name
         ,        decode(column_id,1,'','chr(44)')            char_type
         ,        column_id
         from     dba_tab_columns
         where    table_name = upper('&&1')
         and      owner      = upper('&&2')
         order by column_id;
    l_curr_line       VARCHAR2(2000);
    l_owner           sys.dba_tables.owner%TYPE;
    l_table_name      sys.dba_tables.table_name%TYPE;
    l_max_column_id   NUMBER(39);
    l_concat          VARCHAR2(200);
begin
    select max(column_id)
    into   l_max_column_id
    from   dba_tab_columns
    where    table_name = upper('&&1')
    and      owner      = upper('&&2');
    l_curr_line := '
set lines 3000
set trimspool on
set pages 0
set feedback on
set echo off
clear screen
spool select.dat
select ';
    for tab_col_rec in tab_col_cur loop
      if tab_col_rec.column_id = 1 then
       l_concat := tab_col_rec.column_name||chr(124)||chr(124);
      elsif tab_col_rec.column_id = l_max_column_id then
       l_concat := chr(124)||chr(124)||tab_col_rec.column_name;
      else
       l_concat := chr(124)||chr(124)||tab_col_rec.column_name||chr(124)||chr(124);
      end if;
      l_owner := tab_col_rec.owner;
      l_table_name := tab_col_rec.table_name;
      l_curr_line := l_curr_line||'
      '||tab_col_rec.char_type||l_concat;
    end loop;
    l_curr_line := l_curr_line||'
from '||l_owner||'.'||l_table_name||';

spool off
';
    insert into select_text values (l_curr_line);
    commit;
end;
/

set pages 900
set trimspool on
set lines 80
col text format a80
set head off
set term off

spool select.tmp

select * from select_text;

spool off
set term on

ed select.tmp
