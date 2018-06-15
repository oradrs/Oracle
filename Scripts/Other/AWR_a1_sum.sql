-- Purpose : AWR by default gives report for an hour but which duration of day has high DB time that info is not easily available.
    -- Then it will be easy to check only relevant AWR instead of going through multiple AWR reports to know which duration of LOAD/AWR should be check

-- Source : http://databaseperformance.blogspot.in/2013/08/summary-reporting-on-awr-data-1.html

-- Sample Output :
--    SNAP_TIME      | SNAP_DURATION | DB_TIME        | SQL_EXEC_TIME 
--    ---------------+---------------+----------------+---------------
--    21/05/18 15:30 |      2574.607 |   38129.521221 |   34240.896344
--    21/05/18 16:30 |        3604.5 |   74341.106072 |   64131.453271
--    21/05/18 17:30 |      3574.607 |   60910.608043 |    50689.45865


-- This reports everything in the AWR, but you can restrict it to certain days by adding in a suitable WHERE clause. Here is one I use in SQL*Plus that refers to 2 numbers passed in as arguments when you invoke the script.

-- ------------------------------------------

col snap_duration format 999,990.9;
col db_time       format 999,990.99;
col sql_exec_time format 999,990.99;

with
snaps as 
(select csnaps.snap_id
      , csnaps.dbid
      , min (csnaps.end_interval_time) end_snap_time
      , min (csnaps.end_interval_time) - min (csnaps.begin_interval_time) snap_interval
   from dba_hist_snapshot csnaps
  group by csnaps.snap_id, csnaps.dbid
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
select to_char (snaps.end_snap_time, 'DD/MM/YY HH24:MI') snap_time
     , extract (second from snaps.snap_interval) 
       + (extract (minute from snaps.snap_interval) 
          + (extract (hour from snaps.snap_interval)
             + (extract (day from snaps.snap_interval) * 24)
             ) * 60
          ) * 60 snap_duration
     , dbtime.value / 1000000 db_time
     , sqlexectime.value / 1000000 sql_exec_time
  from snaps
     join (select * from systimes where stat_name = 'DB time') dbtime
       on snaps.snap_id = dbtime.snap_id and snaps.dbid = dbtime.dbid
     join (select * from systimes where stat_name = 'sql execute elapsed time') sqlexectime
       on snaps.snap_id = sqlexectime.snap_id and snaps.dbid = sqlexectime.dbid
--where snaps.end_snap_time between 
--       (trunc (sysdate) - &1) and (trunc (sysdate) - &1 + &2)
 order by snaps.end_snap_time
/
