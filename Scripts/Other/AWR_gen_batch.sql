-- Purpose : To generate multiple AWR html reports for input snapshot ids range
-- How to :  @AWR_gen_batch.sql

set echo off heading off feedback off verify off
-- select 'Please enter dates in DD-MON-YYYY HH24 format:' from dual;
select 'You have entered:', '&&BEGIN_SNAPID', '&&END_SNAPID' from dual;
set pages 0 termout off 
spool batch.sql
SELECT DISTINCT '@AWR_gen_batch_2 '
                                ||b.snap_id
                                ||' '
                                ||e.snap_id
                                ||' '
                                || TO_CHAR(b.end_interval_time,'YYMMDD_HH24MI_')
                                ||TO_CHAR(e.end_interval_time,'HH24MI')
                                ||'.html' Commands,
                '-- '||TO_CHAR(b.end_interval_time,'YYMMDD_HH24MI') lineorder
FROM            dba_hist_snapshot b,
                dba_hist_snapshot e
WHERE           b.snap_id >=  &BEGIN_SNAPID and b.snap_id < &END_SNAPID
             and e.snap_id           =b.snap_id+1
ORDER BY        lineorder;

spool off
set termout on
select 'Generating Report Script batch.sql.....' from dual;
select 'Report file created for snap_ids between:', '&&BEGIN_SNAPID', '&&END_SNAPID', '. Check/Execute file batch.sql to generate AWR report' from dual;
set echo on termout on verify on heading on feedback on

undefine BEGIN_SNAPID
undefine END_SNAPID
