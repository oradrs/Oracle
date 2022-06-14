-- switchPDB.sql : to switch to another container

COL NAME FORMAT A15;
SELECT NAME, OPEN_MODE from v$pdbs;
PROMPT Enter Container Name :

set termout off verify off
col CONT new_value CONT noprint
alter session set container = &1;
select sys_context('userenv', 'con_name') as CONT from dual;
set sqlprompt "_USER'@'_CONNECT_IDENTIFIER::&&CONT> "
set termout on;
