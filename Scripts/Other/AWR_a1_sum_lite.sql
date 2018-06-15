/**
 * Name      : awr_sum_lite
 * Purpose   : Minimal one line summary of each AWR snapshot from a day
 * Descrip'n : Based on awr_sum_range with unneeded stuff deleted
 *             Only key essential stuff is output:
 *                 SQL executions / sec, #User calls / sec
 *                 Average Active Sessions, Wait % of Busy time
 *                 Cluster Wait % of wait time, User I/O % of wait time
 *                 Avg disk read time, Avg redo write time, #Disk reads / sec
 *             Values directly calculated, rather than raw underlying values
 * Usage     : @awr_sum_lite
 * Assumption: Want the last 4 whole days
 *               Which is from midnight 4 days ago to last midnight
 * Source : http://databaseperformance.blogspot.in/2016/10/awr-summary-data-extracts.html
 * Can spool data into file and generate chart in Excel using this data
 */
--
set feedback off
set heading off
set newpage none
set verify off
--
set linesize 1000
set pages 28
set trimout on
set trimspool on
--
select ' ' from dual ;
select '                 AWR Lite Summary Report' from dual ;
select '                 =======================' from dual ;
-- select ' ' from dual ;
-- select ''
--    || '<= Database Time =>'
--    || '<= System Statistics ==>'
--    || '<== Waits ================>'
--  from dual ;
set newpage 1
set heading on
--
col snap_time           format a15      heading 'SNAP TIME'
col aas                 format 90.0     heading 'AAS'
col wait_pct            format 990.0    heading 'WAIT%'
col cluster_pct         format 90.0     heading 'CLUS%'
col user_io_pct         format 90.0     heading 'UIO%'
col executions_sec      format 9,990    heading 'EXEC/S'
col user_calls_sec      format 9,990    heading 'UCALL/S'
col physical_reads_sec  format 9,990    heading 'READS/S'
col avg_disk_read       format 990.0    heading '(MS)|AV RD'
col avg_redo_write      format 990.0    heading '(MS)|REDO W'
--
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
, sysstats as 
-- One row per System Statistic with change in value between snapshots
(select sysstat.snap_id
      , sysstat.dbid
      , sysstat.stat_name
      , sum (sysstat.value - psysstat.value) value
         from dba_hist_sysstat sysstat, dba_hist_sysstat psysstat
        where sysstat.snap_id = psysstat.snap_id + 1
          and sysstat.dbid = psysstat.dbid
          and sysstat.instance_number = psysstat.instance_number
          and sysstat.stat_id = psysstat.stat_id
-- Assume if stat_id the same so is the stat_name
        group by sysstat.snap_id, sysstat.dbid, sysstat.stat_name
) -- sysstats
, syswaits as 
-- One row for total wait time, plus break down into major wait classes, and events
(select syswaitevents.snap_id
      , syswaitevents.dbid
      , sum (syswaitevents.time_waited_micro) all_wait_time
      , sum (decode (syswaitevents.wait_class, 'Commit',      syswaitevents.time_waited_micro, 0)) commit_time
      , sum (decode (syswaitevents.wait_class, 'Cluster',     syswaitevents.time_waited_micro, 0)) cluster_time
      , sum (decode (syswaitevents.wait_class, 'Concurrency', syswaitevents.time_waited_micro, 0)) concurrency_time
      , sum (decode (syswaitevents.wait_class, 'Network',     syswaitevents.time_waited_micro, 0)) network_time
      , sum (decode (syswaitevents.wait_class, 'System I/O',  syswaitevents.time_waited_micro, 0)) system_io_time
      , sum (decode (syswaitevents.wait_class, 'User I/O',    syswaitevents.time_waited_micro, 0)) user_io_time
   from 
        (select sysevent.snap_id
              , sysevent.dbid
              , sysevent.wait_class
              , sysevent.event_name
              , sum (sysevent.time_waited_micro - psysevent.time_waited_micro) time_waited_micro
              , sum (sysevent.total_waits - psysevent.total_waits) wait_count
           from dba_hist_system_event sysevent, dba_hist_system_event psysevent
          where sysevent.snap_id = psysevent.snap_id + 1
            and sysevent.dbid = psysevent.dbid
            and sysevent.instance_number = psysevent.instance_number
            and sysevent.event_id = psysevent.event_id
            and sysevent.wait_class != 'Idle'  -- Ignore Idle wait events
          group by sysevent.snap_id
                 , sysevent.dbid
                 , sysevent.wait_class
                 , sysevent.event_name
        ) syswaitevents
  group by syswaitevents.snap_id
         , syswaitevents.dbid
) -- syswaits
-- Average Active Sessions, Wait % of Busy time
-- Cluster Wait % of wait time, User I/O % of wait time
-- SQL executions / sec, #User calls / sec
-- Avg disk read time, Avg redo write time, #Disk reads / sec
select to_char (snaps.end_snap_time, 'DD/MM/YY HH24:MI') snap_time
     , (user_calls_st.value / snaps.snap_duration)              user_calls_sec
     , (execs.value / snaps.snap_duration)                      executions_sec
     , (dbtime.value / 1000000)       / snaps.snap_duration     aas
-- If database active time is 1% of duration time or less ignore wait (0)
     , case when (dbtime.value / (1000 * snaps.snap_duration) ) > 1
            then (100 * syswaits.all_wait_time  / dbtime.value)
            else 0.0
       end wait_pct
     , (100 * syswaits.cluster_time   / syswaits.all_wait_time) cluster_pct
     , (100 * syswaits.user_io_time   / syswaits.all_wait_time) user_io_pct
     , (phys_reads.value / snaps.snap_duration)                 physical_reads_sec
     , (syswaits.user_io_time / phys_reads.value) / 1000        avg_disk_read
     , (redo_time_st.value * 10 / redo_write_st.value)          avg_redo_write
  from snaps
     join (select * from systimes where stat_name = 'DB time') dbtime
       on snaps.snap_id = dbtime.snap_id and snaps.dbid = dbtime.dbid
     join syswaits
       on snaps.snap_id = syswaits.snap_id and snaps.dbid = syswaits.dbid
     join (select * from sysstats where stat_name = 'execute count') execs
       on snaps.snap_id = execs.snap_id and snaps.dbid    = execs.dbid
     join (select * from sysstats where stat_name = 'user calls') user_calls_st
       on snaps.snap_id = user_calls_st.snap_id and snaps.dbid = user_calls_st.dbid
     join (select * from sysstats where stat_name = 'redo writes') redo_write_st
       on snaps.snap_id = redo_write_st.snap_id and snaps.dbid  = redo_write_st.dbid
     join (select * from sysstats where stat_name = 'redo write time') redo_time_st
       on snaps.snap_id = redo_time_st.snap_id and snaps.dbid  = redo_time_st.dbid
     join (select * from sysstats where stat_name = 'physical reads') phys_reads
       on snaps.snap_id = phys_reads.snap_id and snaps.dbid    = phys_reads.dbid
 where snaps.end_snap_time between 
       (trunc (sysdate) - 4) and (trunc (sysdate))      -- Change date range here
 order by snaps.end_snap_time
/
--
set feedback on
set lines 80
