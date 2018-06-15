-- Purpose : To identify TOP sql had performed high IO

-- Source : http://databaseperformance.blogspot.in/2013/11/awr-reporting-6-sql-statements.html
-- Column sql_time - Time in seconds
    --  The "sql_reads > 100000" is a filter so that not all SQL statements are listed, only those with a significant number of disk reads. can increase or decrease this threshold
-- This query will check Hist table / AWR snapshot of last 7 days
-- Hint : can pass this top SQL to AWR_create_tuning_task.sql to generate SQL Tuning Advisor

-- Sample output :
--SQL_ID        | SQL_READS | SQL_EXECS | SQL_TIME      | RNK_SQL_READS | RNK_SQL_EXECS | RNK_SQL_TIME
----------------+-----------+-----------+---------------+---------------+---------------+-------------
--bpq3txxubt71g |    102540 |       110 | 121472.869543 |            49 |           159 |            1
--0zc81fw23167r | 366532875 |      1460 |  93541.226547 |             1 |           116 |            2
--9by78xst5ujqs |    404525 |        28 |  53376.191487 |            24 |           180 |            3
--8235awkjrycwq |  74030160 |      2975 |  25726.912424 |             2 |            94 |            4


-- ------------------------------------------

with 
snaps as 
(select csnaps.snap_id
      , csnaps.dbid
      , min (csnaps.end_interval_time) end_snap_time
      , min (csnaps.end_interval_time) - min (csnaps.begin_interval_time) snap_interval
   from dba_hist_snapshot csnaps
  group by csnaps.snap_id, csnaps.dbid
) -- snaps
, sqlstats as
(
select sqlstat.snap_id
     , sqlstat.dbid
     , sqlstat.sql_id
     , sum (sqlstat.elapsed_time_delta)  sql_time
     , sum (sqlstat.executions_delta) sql_execs
     , sum (sqlstat.disk_reads_delta) sql_reads
  from dba_hist_sqlstat sqlstat
 group by sqlstat.snap_id
     , sqlstat.dbid
     , sqlstat.sql_id
)
, HighReadSQL as
(
select sqlstats.sql_id
     , sum (sqlstats.sql_reads)  sql_reads
     , sum (sqlstats.sql_execs)  sql_execs
     , sum (sqlstats.sql_time) / 1000000 sql_time
  from snaps
     join sqlstats
       on snaps.snap_id = sqlstats.snap_id and snaps.dbid = sqlstats.dbid
 where snaps.end_snap_time between 
       (trunc (sysdate) - 7) and (trunc (sysdate))
       -- and extract (hour from snaps.end_snap_time) between 8 and 17      -- to restrict it to the main working hours, say 8am to 6pm:
   and sql_reads > 100000
 group by sqlstats.sql_id
)
select HighReadSQL.*, dh.SQL_TEXT, 
			rank() over(order by sql_reads desc) rnk_sql_reads,
			rank() over(order by sql_execs desc) rnk_sql_execs,
			rank() over(order by sql_time desc) rnk_sql_time
from  HighReadSQL 
			join dba_hist_sqltext dh
				on HighReadSQL.sql_id = dh.sql_id 
					and dh.COMMAND_TYPE not in (47, 170, 9) 
--					and dh.SQL_TEXT like '%LIQ-%'		-- Filter LIQ sqls
 order by sql_reads desc
/

-- ------------------------------------------

-- Purpose :  Generate sql advisor for bulk SQLs 

-- get top 100 sqls using topsql_v2.sql
-- create table TOPSQL (sql_id varchar(30));
-- insert them in TOPSQL table
-- monitor them in OEM / performance tab -> sql tuning advisor for report


DECLARE
 ret_val VARCHAR2(4000);
 task_prefix VARCHAR2(20);
BEGIN

    task_prefix := 'sa1_';

    FOR c IN (SELECT sql_id FROM topsql)
    LOOP
        dbms_output.put_line('SQL_id : ' || c.sql_id);
    --  drop task if exists
        begin
            dbms_sqltune.drop_tuning_task(task_prefix || c.sql_id);
        EXCEPTION
           WHEN OTHERS THEN
              null;
        END;

        begin
    -- create  execute advisor; time_limit=>300 in seconds
       ret_val := DBMS_SQLTUNE.CREATE_TUNING_TASK ( begin_snap => 400, end_snap => 500, sql_id=>c.sql_id , scope => 'COMPREHENSIVE', time_limit => 500, task_name=> task_prefix || c.sql_id );
      dbms_sqltune.execute_tuning_task(task_prefix || c.sql_id);
        EXCEPTION
           WHEN OTHERS THEN
               dbms_output.put_line('Err while SQL_id : ' || c.sql_id);
        END;

    END LOOP;

END;
/
