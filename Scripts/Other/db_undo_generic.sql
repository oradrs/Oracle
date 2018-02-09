REM srdc_db_undo_generic.sql
REM collect Undo parameters and Segments details
define SRDCNAME='DB_Undo_Generic'
set pagesize 200 verify off sqlprompt "" term off entmap off echo off
set markup html on spool on
COLUMN SRDCSPOOLNAME NOPRINT NEW_VALUE SRDCSPOOLNAME
select 'SRDC_'||upper('&&SRDCNAME')||'_'||upper(instance_name)||'_'|| to_char(sysdate,'YYYYMMDD_HH24MISS') SRDCSPOOLNAME from v$instance;
spool &&SRDCSPOOLNAME..htm
select 'Diagnostic-Name : ' "Diagnostic-Name ", '&&SRDCNAME' "Report Info" from dual
union all
select 'Time : ' , to_char(systimestamp, 'YYYY-MM-DD HH24MISS TZHTZM' ) from dual
union all
select 'Machine : ' , host_name from v$instance
union all
select 'Version : ',version from v$instance
union all
select 'DBName : ',name from v$database
union all
select 'Instance : ',instance_name from v$instance
/
set echo on

--***********************PARAMETERS ***********************

select a.inst_id, a.ksppinm "Parameter",
b.ksppstvl "Session Value",
c.ksppstvl "Instance Value"
from x$ksppi a, x$ksppcv b, x$ksppsv c
where a.indx = b.indx and a.indx = c.indx
and a.inst_id=b.inst_id and b.inst_id=c.inst_id
and a.ksppinm in ('_undo_autotune', '_smu_debug_mode',
'_highthreshold_undoretention',
'undo_tablespace','undo_retention','undo_management')
order by 2;
/


select t.tablespace_name, t.status tb, d.status df,
extent_management, allocation_type, segment_space_management, retention,
autoextensible, (maxbytes/1024/1024) mx
from dba_tablespaces t, dba_data_files d
where t.tablespace_name = d.tablespace_name
and t.contents='UNDO'
/

select status, count(*) cnt
from dba_rollback_segs
group by status
/

-- *********************** WAITS FOR UNDO (Since Startup) ***********************

select * from v$enqueue_stat where eq_type='US'
union
select * from v$enqueue_stat where eq_type='HW'
/


-- *********************** LOCKS FOR UNDO ***********************

select /*+ RULE */ a.SID, b.process,
b.OSUSER, b.MACHINE, b.PROGRAM, 
addr, kaddr, lmode, request, round(ctime/60/60,0) ctime, block 
from 
v$lock a, 
v$session b 
where 
a.sid=b.sid
and a.type='US'
/


-- ***********************TUNED RETENTION HISTORY (Last 2 Days) ***********************
-- *********************** LOWEST AND HIGHEST DATA ***********************


select end_time, tuned_undoretention from v$undostat where tuned_undoretention = (
select min(tuned_undoretention) low
from v$undostat
where end_time > sysdate-2)
/

select end_time, tuned_undoretention from v$undostat where tuned_undoretention = (
select max(tuned_undoretention) high
from v$undostat
where end_time > sysdate-2)
/


*********************** CURRENT TRANSACTIONS ***********************


col sql_text format a40 word_wrapped head "SQL Code"

select a.start_date, a.start_scn, a.status, c.sql_text
from v$transaction a, v$session b, v$sqlarea c
where b.saddr=a.ses_addr and c.address=b.sql_address
and b.sql_hash_value=c.hash_value
/

select current_scn from v$database
/

--*********************** WHO'S STEALING WHAT? (Last 2 Days) ***********************

select unxpstealcnt a, expstealcnt b,
unxpblkreucnt c, expblkreucnt d
from v$undostat
where (unxpstealcnt > 0 or expstealcnt > 0)
and end_time > sysdate-2
/

set echo off
set sqlprompt "SQL> " term on
set verify on
spool off
set markup html off spool off
set echo on
