-- Purpose : To generate ASH HTML script for multiple AWR period

-- ------------------------------------------

-- Sample to get list of AWR period
select dbid,instance_number ino, SNAP_ID, begin_interval_time,end_interval_time
from dba_hist_snapshot
where BEGIN_INTERVAL_TIME between to_timestamp('28-jun-2018 11:30:00') and '29-jun-2018 8:30'
order by begin_interval_time;


-- Generate ASH html report script for AWR period
-- Modify time interval
select 
'spool ash_' || SNAP_ID || '_' || (SNAP_ID -1) || '.html;' || chr(10) 
|| 'SELECT output
 FROM
 TABLE(dbms_workload_repository.ash_report_HTML
 (' || dbid || ',' || instance_number || ','
|| 'to_Date(''' || to_char(begin_interval_time, 'MM/DD/YYYY HH24:MI') || ''', ''MM/DD/YYYY HH24:MI''),'
|| 'to_Date(''' || to_char(end_interval_time, 'MM/DD/YYYY HH24:MI') || ''', ''MM/DD/YYYY HH24:MI'')'
-- to_date('07/29/2009 16:25','MM/DD/YYYY HH24:MI'))
|| '));'
|| chr(10) 
|| 'Spool off;' 
from dba_hist_snapshot
where BEGIN_INTERVAL_TIME between to_timestamp('28-jun-2018 07:30:00') and '29-jun-2018 8:30'
order by begin_interval_time;

-- ------------------------------------------
-- Template to generate multiple ASH report using above script
clear break compute;                                                                                                                                                                                    
repfooter off;                                                                                                                                                                                          
ttitle off;                                                                                                                                                                                             
btitle off;                                                                                                                                                                                             
set time off timing off veri off space 1 flush on pause off termout on numwidth 10;                                                                                                                     
set pagesize 50000 newpage 1 recsep off;                                                                                                                                                                
set trimspool on trimout on define "&" concat "." serveroutput on;                                                                                                                                      
set underline on heading off echo off linesize 1500 termout on feedback off;                                                                                                                            

<<above qry output>>
