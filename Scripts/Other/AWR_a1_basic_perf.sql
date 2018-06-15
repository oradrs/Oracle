-- Purpose : Basic Performance Analysis using AWR data
    -- For multiple AWR, It gives result for AAS, Wait%,
-- Source : http://databaseperformance.blogspot.in/2013/11/basic-performance-analysis-using-awr.html
-- ------------------------------------------

set feedback off
set verify off
set linesize 1000
set trimout on
set trimspool on
--
col snap_time           format a15      heading 'SNAP TIME'
col user_calls_sec      format 9,990    heading 'UCALL/S'
col aas                 format 990.0     heading 'AAS'
col wait_pct            format 999999.0    heading 'WAIT%'
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
(select sysevent.snap_id
      , sysevent.dbid
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
) -- syswaits
select to_char (snaps.end_snap_time, 'DD/MM/YY HH24:MI') snap_time
     , (user_calls_st.value / snaps.snap_duration)              user_calls_sec
     , (dbtime.value / 1000000)       / snaps.snap_duration     aas
     , (100 * syswaits.time_waited_micro / dbtime.value)        wait_pct
  from snaps
     join (select * from systimes where stat_name = 'DB time') dbtime
       on snaps.snap_id = dbtime.snap_id and snaps.dbid = dbtime.dbid
     join syswaits
       on snaps.snap_id = syswaits.snap_id and snaps.dbid = syswaits.dbid
     join (select * from sysstats where stat_name = 'user calls') user_calls_st
       on snaps.snap_id = user_calls_st.snap_id and snaps.dbid = user_calls_st.dbid
 where snaps.end_snap_time between 
       (trunc (sysdate) - 7) and (trunc (sysdate))      -- Change range here
 order by snaps.end_snap_time
/
--
set feedback on
set lines 80
