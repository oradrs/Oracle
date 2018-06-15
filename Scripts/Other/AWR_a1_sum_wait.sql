-- Purpose : To get waits, wait class and other details for multiple AWR period
-- 
-- Source : http://databaseperformance.blogspot.in/2013/09/awr-summary-reporting-3-waits.html
--
-- Sample Output : 
--    SNAP                SNAP       DB SQL EXEC ALL WAIT  BG WAIT   COMMIT  CLUSTER CONCURNCY  NETWORK   SYS IO  USER IO
--    TIME            DURATION     TIME     TIME     TIME     TIME  WAIT TM  WAIT TM   WAIT TM  WAIT TM  WAIT TM  WAIT TM
--    --------------- -------- -------- -------- -------- -------- -------- -------- --------- -------- -------- --------
--    28/05/18 16:30     3,602    3,652    3,646    2,119       16        0        0         0        0     3    2,114
--    28/05/18 17:30     3,603    1,332    1,326      507       24        0        0         0        0     2 503
--    28/05/18 18:30     3,602        7        2        8        8        0        0         0        0     1   5
--    28/05/18 19:30     3,602        1        0        5        5        0        0         0        0     1   2
--    28/05/18 20:30     3,602        1        0        3        3        0        0         0        0     1   1
--    28/05/18 21:30     3,602        1        0        3        3        0        0         0        0     1   1
--    28/05/18 22:30     3,632    2,504    1,395    1,168        7        0        0       900        0     3 262
--    28/05/18 23:30     3,571        1        0        3        3        0        0         0        0     1   1
--    29/05/18 00:30     3,602        1        1        4        3        0        0         0        0     1   1
--    29/05/18 01:30     3,602        1        0        3        3        0        0         0        0     1   0

-- ------------------------------------------

set feedback off
set verify off
set linesize 1000
set trimout on
set trimspool on

col snap_time         format a15         heading 'SNAP|TIME'
col snap_duration     format 999,999     heading 'SNAP|DURATION'
col db_time           format 999,990     heading 'DB|TIME'
col sql_exec_time     format 999,990     heading 'SQL EXEC|TIME'

col all_wait_time     format 999,990     heading 'ALL WAIT|TIME'
col bg_wait_time      format 999,990     heading 'BG WAIT|TIME'
col commit_time       format 999,990     heading 'COMMIT|WAIT TM'
col cluster_time      format 999,990     heading 'CLUSTER|WAIT TM'
col concurrency_time  format 999,990     heading 'CONCURNCY|WAIT TM'
col network_time      format 999,990     heading 'NETWORK|WAIT TM'
col system_io_time    format 999,990     heading 'SYS IO|WAIT TM'
col user_io_time      format 999,990     heading 'USER IO|WAIT TM'


--
with
snaps as 
(select snap_id
      , dbid
      , end_snap_time
      , snap_interval
      , extract (second from snap_interval) 
       + (extract (minute from snap_interval) 
          + (extract (hour from snap_interval)
             + (extract (day from snap_interval) * 24)
             ) * 60
          ) * 60 snap_duration
  from (select csnaps.snap_id
             , csnaps.dbid
             , min (csnaps.end_interval_time) end_snap_time
             , min (csnaps.end_interval_time) - min (csnaps.begin_interval_time) snap_interval
          from dba_hist_snapshot csnaps
         group by csnaps.snap_id, csnaps.dbid
       )
) -- snaps
, systimes as 
-- One row per Database Time Model with change in value between snapshots
(select systime.snap_id
      , systime.dbid
      , systime.stat_name
      , sum (systime.value - psystime.value) value
         from dba_hist_sys_time_model systime, dba_hist_sys_time_model psystime
        where systime.snap_id = psystime.snap_id + 1
          and systime.dbid = psystime.dbid
          and systime.instance_number = psystime.instance_number
          and systime.stat_id = psystime.stat_id
-- Assume if stat_id the same so is the stat_name
        group by systime.snap_id, systime.dbid, systime.stat_name
) -- systimes
, sysbgwait as 
-- One row per System Wait Event with change in value between snapshots
(select sysevent.snap_id
      , sysevent.dbid
      , sum (sysevent.time_waited_micro - psysevent.time_waited_micro) time_waited_micro
         from dba_hist_bg_event_summary sysevent, dba_hist_bg_event_summary psysevent
        where sysevent.snap_id = psysevent.snap_id + 1
          and sysevent.dbid = psysevent.dbid
          and sysevent.instance_number = psysevent.instance_number
          and sysevent.event_id = psysevent.event_id
          and sysevent.wait_class != 'Idle'
        group by sysevent.snap_id, sysevent.dbid
) -- sysbgwait
, syswaits as 
(select sysevent.snap_id
      , sysevent.dbid
      , sum (sysevent.time_waited_micro - psysevent.time_waited_micro) all_wait_time
      , sum (decode (sysevent.wait_class, 'Commit', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) commit_time
      , sum (decode (sysevent.wait_class, 'Cluster', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) cluster_time
      , sum (decode (sysevent.wait_class, 'Concurrency', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) concurrency_time
      , sum (decode (sysevent.wait_class, 'Network', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) network_time
      , sum (decode (sysevent.wait_class, 'System I/O', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) system_io_time
      , sum (decode (sysevent.wait_class, 'User I/O', (sysevent.time_waited_micro - psysevent.time_waited_micro), 0)) user_io_time
   from dba_hist_system_event sysevent, dba_hist_system_event psysevent
  where sysevent.snap_id = psysevent.snap_id + 1
    and sysevent.dbid = psysevent.dbid
    and sysevent.instance_number = psysevent.instance_number
    and sysevent.event_id = psysevent.event_id
    -- Ignore Idle wait events
    and sysevent.wait_class != 'Idle'
  group by sysevent.snap_id
         , sysevent.dbid
) -- syswaits
select to_char (snaps.end_snap_time, 'DD/MM/YY HH24:MI') snap_time
     , extract (second from snaps.snap_interval) 
       + (extract (minute from snaps.snap_interval) 
          + (extract (hour from snaps.snap_interval)
             + (extract (day from snaps.snap_interval) * 24)
             ) * 60
          ) * 60 snap_duration
     , dbtime.value / 1000000 db_time
     , sqlexectime.value / 1000000 sql_exec_time
     , syswaits.all_wait_time / 1000000 all_wait_time
     , sysbgwait.time_waited_micro / 1000000 bg_wait_time
     , syswaits.commit_time / 1000000 commit_time
     , syswaits.cluster_time / 1000000 cluster_time
     , syswaits.concurrency_time / 1000000 concurrency_time
     , syswaits.network_time / 1000000 network_time
     , syswaits.system_io_time / 1000000 system_io_time
     , syswaits.user_io_time / 1000000 user_io_time
  from snaps
     join (select * from systimes where stat_name = 'DB time') dbtime
       on snaps.snap_id = dbtime.snap_id and snaps.dbid = dbtime.dbid
     join (select * from systimes where stat_name = 'sql execute elapsed time') sqlexectime
       on snaps.snap_id = sqlexectime.snap_id and snaps.dbid = sqlexectime.dbid
     join syswaits
       on snaps.snap_id = syswaits.snap_id and snaps.dbid = syswaits.dbid
     join sysbgwait
       on snaps.snap_id = sysbgwait.snap_id and snaps.dbid = sysbgwait.dbid
 order by snaps.end_snap_time
/
--
set feedback on
set lines 80
