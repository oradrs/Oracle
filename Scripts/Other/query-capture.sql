----------------------------------------------------------------------------------------
--
-- File name:   query-capture.sql
--
-- Purpose:     Used to run a query contained in a file and capture metrics on that query
-- If you know expensive SQL with its text then copy in text file and pass it to attached script (query-capture.sql) to generate plan, Active monitor report & other details about SQL execution.
-- This approach will run actual SQL in DB to generate above details.
-- Author:      Tyler D Muth
--
-- Usage:       This script takes in 4 parameters
--
-- Parameters:  1: The file name where the query is located
--
--				2: A name for this query
--
--				3: An alter session file used to change session parameters. You can also pass in 
--				   the name of an empty file such as null.sql
--
--				4: Output subdirectory, where the results are captured
--
--              See https://github.com/tmuth/Query-Test-Framework for additional information.
--
-- SAMPLE : cmd from sqlPlus prompt 
-- @C:\TEMP\query-capture.sql C:\TEMP\a.sql perfwow null.sql C:\TEMP\output
        --  C:\TEMP\query-capture.sql - is current script
--      Arg list
        -- 1 C:\TEMP\a.sql - is main SQL for which report need to generate
        -- 2 perfwow - output file name to use
        -- 3 null.sql - for session variable else use dummy name
        -- 4 C:\TEMP\output - is output dir
----------------------------------------------------------------------------------------- 

whenever sqlerror exit 2;
set termout on
set SERVEROUTPUT off
set timing off
set wrap off
set define '^'
set concat '.'
set verify on
set pagesize 10000
set linesize 300
column name format a70
set numwidth 16
--alter session force parallel query parallel ^5;
--alter session set parallel_degree_policy=MANUAL;
alter session set statistics_level=ALL;

@^3

prompt about to run ^2

spool ^4/^2..txt

set echo off
set timing on
set wrap off
@^1

set timing off

set termout off
column prev_sql_id new_value PREV_SQLID
column prev_child_number new_value PREV_CHILD_CURSOR
select prev_sql_id,prev_child_number from v$session where audsid=userenv('sessionid');

select s.name, m.value
  from v$mystat m, v$statname s
 where s.statistic# = m.statistic#
   and m.value > 0
 order by 1;




select * from table(dbms_xplan.display_cursor(sql_id => '^PREV_SQLID', cursor_child_no => ^PREV_CHILD_CURSOR,format=>'ALLSTATS LAST'));

--select * from table(dbms_xplan.display_cursor(sql_id => '^PREV_SQLID', format=>'advanced +parallel +partition +predicate'));


set linesize 110
set wrap off
column name format a42
column SQL_FEATURE format a22
column isdefault format a9
select name,sql_feature,isdefault,value from v$ses_optimizer_env where sid = sys_context('USERENV','SID') order by isdefault,name;



spool off

set serveroutput on
begin
	$IF dbms_db_version.ver_le_11_2 $THEN
		dbms_output.put_line('Version 11.2 or less, not setting event to disable XML compression');
	$ELSE
		dbms_output.put_line('Version is 12.1 or greater, setting event to disable XML compression');
--		execute immediate q'[ alter session set events='emx_control compress_xml=none' ]' ;
	$END
end;
/

set serveroutput ON SIZE 1000000 FORMAT WORD_WRAPPED
set wrap on
set verify off
set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000 feedback off
spool ^4/^2..html
select dbms_sqltune.report_sql_monitor(type=>'ACTIVE', report_level=>'ALL',sql_id=>'^PREV_SQLID') monitor_report from dual;
spool off


-- set serveroutput ON SIZE 1000000 FORMAT WORD_WRAPPED
-- set wrap on
-- set verify off
-- set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000 feedback off
-- spool ^4/^2..xml
-- select dbms_sqltune.report_sql_monitor(type=>'XML', report_level=>'BASIC+METRICS',sql_id=>'^PREV_SQLID') monitor_report from dual;
-- spool off

-- exit
