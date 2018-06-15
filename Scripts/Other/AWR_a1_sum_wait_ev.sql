-- Purpose : To get waits, wait class and other details for multiple AWR period
-- 
-- Source : http://databaseperformance.blogspot.in/2013/10/awr-summary-reporting-4-more-waits.html
--
-- Sample Output : 
--    SNAP_TIME      | SNAP_DURATION | DB_TIME        | SQL_EXEC_TIME  | ALL_WAIT_TIME  | BG_WAIT_TIME  | COMMIT_TIME   | CLUSTER_TIME | CONCURRENCY_TIME | NETWORK_TIME | SYSTEM_IO_TIME | USER_IO_TIME   | SEP | DB_FILE_SQRD_TIME | DB_FILE_SCTRD_TIME | DIRECT_PATH_READ_TIME | LOG_FILE_SYNC_TIME | LOG_FILE_PRL_WR_TIME | GC_BUFF_BUSY_TIME | GC_CR_BLK_BUSY_TIME | SEP | DB_FILE_SQRD_COUNT | DB_FILE_SCTRD_COUNT | DIRECT_PATH_READ_COUNT | LOG_FILE_SYNC_COUNT | LOG_FILE_PRL_WR_COUNT | GC_BUFF_BUSY_COUNT | GC_CR_BLK_BUSY_COUNT
--    ---------------+---------------+----------------+----------------+----------------+---------------+---------------+--------------+------------------+--------------+----------------+----------------+-----+-------------------+--------------------+-----------------------+--------------------+----------------------+-------------------+---------------------+-----+--------------------+---------------------+------------------------+---------------------+-----------------------+--------------------+---------------------
--    31/05/18 15:30 |      3601.781 |       9.786017 |       1.995857 |       4.280665 |      4.156535 |      0.058397 |            0 |         0.000071 |     0.061093 |       0.903276 |       1.495452 |  |  |          1.160702 |                  0 |                     0 |           0.058397 |              0.10454 |                 0 |                   0 |  |  |                  1 |                   1 |                      1 |                   1 |                     1 |                  0 |                    0
--    31/05/18 15:52 |      1360.803 |      12.842294 |       5.975242 |       4.301033 |      1.788514 |      0.022316 |            0 |         0.000112 |     0.023986 |       0.609096 |       2.976156 |  |  |            2.2859 |           0.378096 |              0.029579 |           0.022316 |             0.049843 |                 0 |                   0 |  |  |                  1 |                   1 |                      1 |                   1 |                     1 |                  0 |                    0
--    31/05/18 16:02 |       380.245 |   -4870.447034 |   -4766.699209 |    -417.294271 |    -29.989404 |     -0.341732 |            0 |        -0.034923 |    -0.454735 |      -6.608939 |    -400.487728 |  |  |       -202.698197 |         -103.96752 |             -77.58109 |          -0.341732 |             -0.72944 |                 0 |                   0 |  |  |                  1 |                   1 |                      1 |                   1 |                     1 |                  0 |                    0
--    31/05/18 17:30 |      5286.755 |     190.227048 |      159.61677 |     124.372456 |      5.483939 |      0.082018 |            0 |         0.000142 |     0.125827 |       1.939448 |     120.030993 |  |  |         50.555323 |          22.706168 |             43.015441 |           0.082018 |             0.356609 |                 0 |                   0 |  |  |                  1 |                   1 |                      1 |                   1 |                     1 |                  0 |                    0


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
col db_file_sqrd_time      format 999,990     heading 'DBF SEQ|RD TIME'
col db_file_sctrd_time      format 999,990     heading 'USER IO|WAIT TM'
col direct_path_read_time      format 999,990     heading 'USER IO|WAIT TM'
col log_file_sync_time      format 999,990     heading 'USER IO|WAIT TM'
col log_file_prl_wr_time      format 999,990     heading 'USER IO|WAIT TM'
col gc_buff_busy_time      format 999,990     heading 'USER IO|WAIT TM'
col gc_cr_blk_busy_time      format 999,990     heading 'USER IO|WAIT TM'


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
      , sum (sysevent.time_waited_micro) all_wait_time
      , sum (decode (sysevent.wait_class, 'Commit', sysevent.time_waited_micro, 0)) commit_time
      , sum (decode (sysevent.wait_class, 'Cluster', sysevent.time_waited_micro, 0)) cluster_time
      , sum (decode (sysevent.wait_class, 'Concurrency', sysevent.time_waited_micro, 0)) concurrency_time
      , sum (decode (sysevent.wait_class, 'Network', sysevent.time_waited_micro, 0)) network_time
      , sum (decode (sysevent.wait_class, 'System I/O', sysevent.time_waited_micro, 0)) system_io_time
      , sum (decode (sysevent.wait_class, 'User I/O', sysevent.time_waited_micro, 0)) user_io_time
      , sum (decode (sysevent.event_name, 'db file sequential read', sysevent.time_waited_micro, 0)) db_file_sqrd_time
      , sum (decode (sysevent.event_name, 'db file sequential read', 1, 0)) db_file_sqrd_count
      , sum (decode (sysevent.event_name, 'db file scattered read',  sysevent.time_waited_micro, 0)) db_file_sctrd_time
      , sum (decode (sysevent.event_name, 'db file scattered read',  1, 0)) db_file_sctrd_count
      , sum (decode (sysevent.event_name, 'direct path read',        sysevent.time_waited_micro, 0)) direct_path_read_time
      , sum (decode (sysevent.event_name, 'direct path read',        1, 0)) direct_path_read_count
      , sum (decode (sysevent.event_name, 'log file sync',           sysevent.time_waited_micro, 0)) log_file_sync_time
      , sum (decode (sysevent.event_name, 'log file sync',           1, 0)) log_file_sync_count
      , sum (decode (sysevent.event_name, 'log file parallel write', sysevent.time_waited_micro, 0)) log_file_prl_wr_time
      , sum (decode (sysevent.event_name, 'log file parallel write', 1, 0)) log_file_prl_wr_count
      , sum (decode (sysevent.event_name, 'gc buffer busy',          sysevent.time_waited_micro, 0)) gc_buff_busy_time
      , sum (decode (sysevent.event_name, 'gc buffer busy',          1, 0)) gc_buff_busy_count
      , sum (decode (sysevent.event_name, 'gc cr block busy',        sysevent.time_waited_micro, 0)) gc_cr_blk_busy_time
      , sum (decode (sysevent.event_name, 'gc cr block busy',        1, 0)) gc_cr_blk_busy_count
   -- -- from dba_hist_system_event sysevent, dba_hist_system_event psysevent
        from 
                (select sysevent2.snap_id
                      , sysevent2.dbid
                      , sysevent2.wait_class
                      , sysevent2.event_name
                      , sum (sysevent2.time_waited_micro - psysevent.time_waited_micro) time_waited_micro
                      , sum (sysevent2.total_waits - psysevent.total_waits) wait_count
                   from dba_hist_system_event sysevent2, dba_hist_system_event psysevent
                  where sysevent2.snap_id = psysevent.snap_id + 1
                    and sysevent2.dbid = psysevent.dbid
                    and sysevent2.instance_number = psysevent.instance_number
                    and sysevent2.event_id = psysevent.event_id
                    -- Ignore Idle wait events
                    and sysevent2.wait_class != 'Idle'
                    group by sysevent2.snap_id, sysevent2.dbid, sysevent2.wait_class, sysevent2.event_name
                ) sysevent
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
     , ' | ' Sep
     , syswaits.db_file_sqrd_time     / 1000000 db_file_sqrd_time
     , syswaits.db_file_sctrd_time    / 1000000 db_file_sctrd_time
     , syswaits.direct_path_read_time / 1000000 direct_path_read_time
     , syswaits.log_file_sync_time    / 1000000 log_file_sync_time
     , syswaits.log_file_prl_wr_time  / 1000000 log_file_prl_wr_time
     , syswaits.gc_buff_busy_time     / 1000000 gc_buff_busy_time
     , syswaits.gc_cr_blk_busy_time   / 1000000 gc_cr_blk_busy_time
     , ' | ' Sep
     , syswaits.db_file_sqrd_count     db_file_sqrd_count
     , syswaits.db_file_sctrd_count    db_file_sctrd_count
     , syswaits.direct_path_read_count direct_path_read_count
     , syswaits.log_file_sync_count    log_file_sync_count
     , syswaits.log_file_prl_wr_count  log_file_prl_wr_count
     , syswaits.gc_buff_busy_count     gc_buff_busy_count
     , syswaits.gc_cr_blk_busy_count   gc_cr_blk_busy_count
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
